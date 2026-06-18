from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from onboarding import update_onboarding_progress
from supabase_config import get_supabase

router = APIRouter()


class Vehicle(BaseModel):
    number: str
    type: str
    capacity: int
    owner: str


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _is_missing_column_error(error: Exception) -> bool:
    message = str(error)
    return "PGRST204" in message and "schema cache" in message


@router.get("/")
def get_vehicles():
    """Get all active vehicle types."""
    try:
        response = (
            get_supabase()
            .table("vehicle_types")
            .select("*")
            .eq("active", True)
            .order("name")
            .execute()
        )
        return response.data or []
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/{uid}")
def get_driver_vehicles(uid: str):
    """Get the vehicle selected by a driver."""
    try:
        profile = (
            get_supabase()
            .table("profiles")
            .select("firebase_uid, vehicle_number")
            .eq("firebase_uid", uid)
            .maybe_single()
            .execute()
            .data
        )
        if not profile or not profile.get("vehicle_number"):
            return []

        vehicle = (
            get_supabase()
            .table("vehicle_types")
            .select("*")
            .eq("name", profile["vehicle_number"])
            .maybe_single()
            .execute()
            .data
        )
        return [vehicle] if vehicle else [{"name": profile["vehicle_number"]}]
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/{uid}/assign")
def assign_vehicle(uid: str, vehicle_number: str):
    """Assign vehicle type to driver."""
    try:
        try:
            get_supabase().table("profiles").upsert(
                {
                    "firebase_uid": uid,
                    "vehicle_number": vehicle_number,
                    "vehicle_selected": True,
                    "updated_at": _now(),
                },
                on_conflict="firebase_uid",
            ).execute()
        except Exception as e:
            if not _is_missing_column_error(e):
                raise
            get_supabase().table("profiles").upsert(
                {
                    "firebase_uid": uid,
                    "vehicle_number": vehicle_number,
                    "updated_at": _now(),
                },
                on_conflict="firebase_uid",
            ).execute()

        try:
            onboarding = update_onboarding_progress(uid, {"vehicle_selected": True})
        except Exception as e:
            if not _is_missing_column_error(e):
                raise
            onboarding = {
                "warning": "Rerun backend/supabase_schema.sql to add onboarding columns."
            }

        return {"message": "Vehicle assigned", "onboarding": onboarding}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
