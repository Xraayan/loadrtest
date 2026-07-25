from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel

from dependencies import CurrentUser, get_current_user, require_current_user_uid
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
            if next_status == "completed":
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
                        get_supabase().table("notifications").insert(
                            {
                                "user_uid": customer_uid,
                                "title": "Trip completed",
                                "message": "Your load has reached the drop-off location.",
                                "type": "trip",
                                "read": False,
                                "created_at": now,
                            }
                        ).execute()
                except Exception:
                    pass

        return {"message": "Trip status updated", "trip": _format_trip(trip)}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


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
