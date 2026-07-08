from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from onboarding import update_onboarding_progress
from role_profiles import get_role_profile, upsert_role_profile
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
        driver_profile = get_role_profile("driver_profiles", "driver_uid", uid)
        selected_vehicle_type = (
            driver_profile or {}
        ).get("selected_vehicle_type")
        profile = (
            get_supabase()
            .table("profiles")
            .select("firebase_uid, preferences")
            .eq("firebase_uid", uid)
            .maybe_single()
            .execute()
            .data
        )
        if not selected_vehicle_type:
            preferences = profile.get("preferences") if profile else {}
            selected_vehicle_type = (preferences or {}).get("selected_vehicle_type")
        if not selected_vehicle_type:
            return []

        vehicle = (
            get_supabase()
            .table("vehicle_types")
            .select("*")
            .eq("name", selected_vehicle_type)
            .maybe_single()
            .execute()
            .data
        )
        return [vehicle] if vehicle else [{"name": selected_vehicle_type}]
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/{uid}/assign")
def assign_vehicle(uid: str, vehicle_number: str):
    """Assign vehicle type to driver.

    The query parameter is still named vehicle_number for frontend compatibility,
    but the value is a vehicle type such as "Pickups" or "Tipper Trucks".
    """
    try:
        profile = (
            get_supabase()
            .table("profiles")
            .select("preferences")
            .eq("firebase_uid", uid)
            .maybe_single()
            .execute()
            .data
        )
        preferences = profile.get("preferences") if profile else {}
        preferences = {
            **(preferences or {}),
            "selected_vehicle_type": vehicle_number,
        }
        driver_profile = upsert_role_profile(
            "driver_profiles",
            {
                "driver_uid": uid,
                "selected_vehicle_type": vehicle_number,
                "updated_at": _now(),
            },
            "driver_uid",
        )

        try:
            if driver_profile is not None:
                try:
                    get_supabase().table("profiles").upsert(
                        {
                            "firebase_uid": uid,
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
                            "updated_at": _now(),
                        },
                        on_conflict="firebase_uid",
                    ).execute()
            else:
                raise RuntimeError("driver_profiles table is not available")
        except Exception as e:
            if not _is_missing_column_error(e) and driver_profile is not None:
                raise
            try:
                get_supabase().table("profiles").upsert(
                    {
                        "firebase_uid": uid,
                        "preferences": preferences,
                        "vehicle_selected": True,
                        "updated_at": _now(),
                    },
                    on_conflict="firebase_uid",
                ).execute()
            except Exception as inner_error:
                if not _is_missing_column_error(inner_error):
                    raise
                get_supabase().table("profiles").upsert(
                    {
                        "firebase_uid": uid,
                        "preferences": preferences,
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

        return {
            "message": "Vehicle assigned",
            "selected_vehicle_type": vehicle_number,
            "onboarding": onboarding,
        }
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
