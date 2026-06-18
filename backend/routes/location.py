from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from supabase_config import get_supabase

router = APIRouter()


class LocationUpdate(BaseModel):
    latitude: float
    longitude: float
    is_active: Optional[bool] = True


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


@router.post("/update")
def update_location(uid: str, location: LocationUpdate):
    """Update driver's current realtime location."""
    try:
        data = {
            "driver_uid": uid,
            "latitude": location.latitude,
            "longitude": location.longitude,
            "is_active": location.is_active,
            "updated_at": _now(),
        }
        get_supabase().table("driver_locations").upsert(
            data,
            on_conflict="driver_uid",
        ).execute()
        return {"message": "Location updated", "location": data}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/{uid}")
def get_location(uid: str):
    """Get driver's current location."""
    try:
        location = (
            get_supabase()
            .table("driver_locations")
            .select("*")
            .eq("driver_uid", uid)
            .maybe_single()
            .execute()
            .data
        )
        if not location:
            return {"message": "Location not available"}
        return location
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

