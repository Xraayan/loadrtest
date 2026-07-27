from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel

from dependencies import CurrentUser, get_current_user, require_current_user_uid
from routes.messages import delete_trip_chat
from routes.quotes import LocationPoint, _haversine_km
from supabase_config import get_supabase

router = APIRouter()
PICKUP_CONFIRM_RADIUS_KM = 0.05


class Trip(BaseModel):
    pickup_location: str
    dropoff_location: str
    pickup_coords: dict
    dropoff_coords: dict
    status: str = "pending"
    amount: Optional[float] = None


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _format_trip(trip: dict) -> dict:
    return {
        "trip_id": trip.get("id"),
        "driver_id": trip.get("driver_uid"),
        **trip,
    }


@router.post("/")
def create_trip(uid: str, trip: Trip):
    """Create a new trip."""
    try:
        data = {
            **trip.model_dump(),
            "driver_uid": uid,
            "created_at": _now(),
            "updated_at": _now(),
        }
        response = get_supabase().table("trips").insert(data).execute()
        created = response.data[0] if response.data else data
        return {
            "message": "Trip created",
            "trip_id": created.get("id"),
            "trip": _format_trip(created),
        }
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/{uid}")
def get_trips(uid: str):
    """Get all trips for a driver."""
    try:
        response = (
            get_supabase()
            .table("trips")
            .select("*")
            .eq("driver_uid", uid)
            .order("created_at", desc=True)
            .execute()
        )
        return [_format_trip(trip) for trip in (response.data or [])]
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/trip/{trip_id}")
def get_trip(trip_id: str):
    """Get trip details."""
    try:
        trip = (
            get_supabase()
            .table("trips")
            .select("*")
            .eq("id", trip_id)
            .maybe_single()
            .execute()
            .data
        )
        if not trip:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Trip not found",
            )
        return _format_trip(trip)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.patch("/trip/{trip_id}/status")
def update_trip_status(
    trip_id: str,
    next_status: str = Query(alias="status"),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Update trip status."""
    try:
        trip = (
            get_supabase()
            .table("trips")
            .select("*")
            .eq("id", trip_id)
            .maybe_single()
            .execute()
            .data
        )
        if not trip:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Trip not found",
            )

        require_current_user_uid(trip.get("driver_uid"), current_user)
        if next_status == "in_progress":
            _require_driver_near_pickup(trip)

        now = _now()
        response = (
            get_supabase()
            .table("trips")
            .update({"status": next_status, "updated_at": now})
            .eq("id", trip_id)
            .execute()
        )
        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Trip not found",
            )
        trip = response.data[0]
        job_id = trip.get("job_id")
        if job_id:
            get_supabase().table("jobs").update(
                {"status": next_status, "updated_at": now}
            ).eq("id", job_id).execute()
            if next_status in {"awaiting_payment", "completed"}:
                try:
                    job = (
                        get_supabase()
                        .table("jobs")
                        .select("customer_uid,title")
                        .eq("id", job_id)
                        .maybe_single()
                        .execute()
                        .data
                    )
                    customer_uid = (job or {}).get("customer_uid")
                    if customer_uid:
                        title = (
                            "Payment due"
                            if next_status == "awaiting_payment"
                            else "Trip completed"
                        )
                        message = (
                            "Your load has reached drop-off. Please complete payment."
                            if next_status == "awaiting_payment"
                            else "Your load has reached the drop-off location."
                        )
                        get_supabase().table("notifications").insert(
                            {
                                "user_uid": customer_uid,
                                "title": title,
                                "message": message,
                                "type": "trip",
                                "read": False,
                                "created_at": now,
                            }
                        ).execute()
                except Exception:
                    pass

        if next_status == "completed":
            _delete_chat_for_trip(get_supabase(), trip, job_id)

        return {"message": "Trip status updated", "trip": _format_trip(trip)}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/trip/{trip_id}/pay")
def pay_trip(
    trip_id: str,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Customer confirms payment; completed trips are counted in driver wallet."""
    try:
        supabase = get_supabase()
        trip = (
            supabase
            .table("trips")
            .select("*")
            .eq("id", trip_id)
            .maybe_single()
            .execute()
            .data
        )
        if not trip:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Trip not found",
            )

        job_id = trip.get("job_id")
        job = None
        if job_id:
            job = (
                supabase
                .table("jobs")
                .select("*")
                .eq("id", job_id)
                .maybe_single()
                .execute()
                .data
            )
        if not job:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Linked job is missing",
            )

        require_current_user_uid(job.get("customer_uid"), current_user)
        if trip.get("status") == "completed":
            _delete_chat_for_trip(supabase, trip, job_id)
            return {"message": "Payment already completed", "trip": _format_trip(trip)}
        if trip.get("status") != "awaiting_payment":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Trip is not ready for payment",
            )

        now = _now()
        updated = (
            supabase
            .table("trips")
            .update({"status": "completed", "updated_at": now})
            .eq("id", trip_id)
            .execute()
            .data
        )
        trip = updated[0] if updated else {**trip, "status": "completed"}
        supabase.table("jobs").update(
            {"status": "completed", "updated_at": now}
        ).eq("id", job_id).execute()
        _delete_chat_for_trip(supabase, trip, job_id)

        driver_uid = trip.get("driver_uid")
        if driver_uid:
            try:
                supabase.table("notifications").insert(
                    {
                        "user_uid": driver_uid,
                        "title": "Payment received",
                        "message": "Trip amount has been added to your wallet.",
                        "type": "trip",
                        "read": False,
                        "created_at": now,
                    }
                ).execute()
            except Exception:
                pass

        return {"message": "Payment completed", "trip": _format_trip(trip)}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


def _delete_chat_for_trip(supabase, trip: dict, job_id: Optional[str]) -> None:
    try:
        delete_trip_chat(
            supabase=supabase,
            job_id=job_id or trip.get("job_id"),
            trip_id=trip.get("id"),
        )
    except Exception:
        pass


def _require_driver_near_pickup(trip: dict) -> None:
    pickup = trip.get("pickup_coords")
    if not isinstance(pickup, dict):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Pickup coordinates are missing",
        )

    location = (
        get_supabase()
        .table("driver_locations")
        .select("latitude,longitude")
        .eq("driver_uid", trip.get("driver_uid"))
        .maybe_single()
        .execute()
        .data
    )
    if not location:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Driver live location is unavailable",
        )

    distance_km = _haversine_km(
        LocationPoint(
            display_name="Driver",
            latitude=float(location.get("latitude")),
            longitude=float(location.get("longitude")),
        ),
        LocationPoint(
            display_name="Pickup",
            latitude=float(pickup.get("latitude")),
            longitude=float(pickup.get("longitude")),
        ),
    )
    if distance_km > PICKUP_CONFIRM_RADIUS_KM:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Confirm pickup is available within 50 m of pickup",
        )
