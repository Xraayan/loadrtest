from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from supabase_config import get_supabase

router = APIRouter()


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
def update_trip_status(trip_id: str, status: str):
    """Update trip status."""
    try:
        response = (
            get_supabase()
            .table("trips")
            .update({"status": status, "updated_at": _now()})
            .eq("id", trip_id)
            .execute()
        )
        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Trip not found",
            )
        return {"message": "Trip status updated", "trip": _format_trip(response.data[0])}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
