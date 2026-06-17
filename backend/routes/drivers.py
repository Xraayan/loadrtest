from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from supabase_config import get_supabase

router = APIRouter()


class DriverProfile(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    vehicle_number: Optional[str] = None
    license_number: Optional[str] = None
    current_location: Optional[dict] = None


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _profile_or_404(uid: str) -> dict:
    response = (
        get_supabase()
        .table("profiles")
        .select("*")
        .eq("firebase_uid", uid)
        .maybe_single()
        .execute()
    )
    if not response.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Driver not found",
        )
    return response.data


@router.get("/{uid}")
def get_driver(uid: str):
    """Get driver profile."""
    try:
        profile = _profile_or_404(uid)
        location = (
            get_supabase()
            .table("driver_locations")
            .select("*")
            .eq("driver_uid", uid)
            .maybe_single()
            .execute()
            .data
        )
        if location:
            profile["current_location"] = location
        return profile
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.put("/{uid}")
def update_driver(uid: str, driver: DriverProfile):
    """Update driver profile."""
    try:
        data = driver.model_dump(exclude_unset=True)
        current_location = data.pop("current_location", None)

        if data:
            data["firebase_uid"] = uid
            data["updated_at"] = _now()
            get_supabase().table("profiles").upsert(
                data,
                on_conflict="firebase_uid",
            ).execute()

        if current_location:
            get_supabase().table("driver_locations").upsert(
                {
                    "driver_uid": uid,
                    "latitude": current_location.get("latitude"),
                    "longitude": current_location.get("longitude"),
                    "is_active": current_location.get("is_active", True),
                    "updated_at": _now(),
                },
                on_conflict="driver_uid",
            ).execute()

        return {"message": "Driver profile updated"}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/{uid}/location")
def update_location(uid: str, location: dict):
    """Update driver's current location."""
    try:
        get_supabase().table("driver_locations").upsert(
            {
                "driver_uid": uid,
                "latitude": location.get("latitude"),
                "longitude": location.get("longitude"),
                "is_active": location.get("is_active", True),
                "updated_at": _now(),
            },
            on_conflict="driver_uid",
        ).execute()
        return {"message": "Location updated"}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

