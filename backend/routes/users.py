from datetime import datetime, timezone
from enum import Enum
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from dependencies import CurrentUser, get_current_user, require_current_user_uid
from onboarding import sync_onboarding_state, update_onboarding_progress
from role_profiles import get_role_profile, upsert_role_profile
from supabase_config import get_supabase

router = APIRouter()


class UserRole(str, Enum):
    user = "user"
    driver = "driver"


class RoleSelectionRequest(BaseModel):
    role: UserRole


class UserProfileUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    current_location: Optional[dict] = None


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _get_profile(uid: str) -> dict:
    profile = _find_profile(uid)
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return profile


def _find_profile(uid: str) -> Optional[dict]:
    profile = (
        get_supabase()
        .table("profiles")
        .select("*")
        .eq("firebase_uid", uid)
        .maybe_single()
        .execute()
        .data
    )
    return profile


@router.get("/{uid}")
def get_user(uid: str, current_user: CurrentUser = Depends(get_current_user)):
    """Get user profile and onboarding state."""
    require_current_user_uid(uid, current_user)
    try:
        profile = _get_profile(uid)
        if profile.get("role") == UserRole.user.value:
            customer_profile = get_role_profile("customer_profiles", "customer_uid", uid)
            if customer_profile:
                profile["customer_profile"] = customer_profile
        elif profile.get("role") == UserRole.driver.value:
            driver_profile = get_role_profile("driver_profiles", "driver_uid", uid)
            if driver_profile:
                profile["driver_profile"] = driver_profile
        onboarding = sync_onboarding_state(uid, profile)
        return {**profile, "onboarding": onboarding}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.patch("/{uid}/role")
def select_role(
    uid: str,
    request: RoleSelectionRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Select whether the signed-in account is a user or driver."""
    require_current_user_uid(uid, current_user)
    try:
        updates = {
            "firebase_uid": uid,
            "role": request.role.value,
            "role_selected": True,
            "role_selected_at": _now(),
            "updated_at": _now(),
        }
        get_supabase().table("profiles").upsert(
            updates,
            on_conflict="firebase_uid",
        ).execute()
        if request.role == UserRole.user:
            upsert_role_profile(
                "customer_profiles",
                {
                    "customer_uid": uid,
                    "created_at": updates["updated_at"],
                    "updated_at": updates["updated_at"],
                },
                "customer_uid",
            )
        else:
            upsert_role_profile(
                "driver_profiles",
                {
                    "driver_uid": uid,
                    "created_at": updates["updated_at"],
                    "updated_at": updates["updated_at"],
                },
                "driver_uid",
            )
        onboarding = update_onboarding_progress(
            uid,
            {
                "role": request.role.value,
                "role_selected": True,
                "role_selected_at": updates["role_selected_at"],
            },
        )

        return {
            "message": "Role selected",
            "uid": uid,
            **updates,
            "onboarding": onboarding,
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.patch("/{uid}/profile")
def update_user_profile(
    uid: str,
    profile: UserProfileUpdate,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Update common profile fields shared by users and drivers."""
    require_current_user_uid(uid, current_user)
    try:
        current_profile = _find_profile(uid) or {}
        updates = profile.model_dump(exclude_unset=True)
        if not updates:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No profile fields provided",
            )

        current_location = updates.pop("current_location", None)
        customer_profile = None
        if current_location:
            location_data = {
                "latitude": current_location.get("latitude"),
                "longitude": current_location.get("longitude"),
                "updated_at": _now(),
            }
            customer_profile = upsert_role_profile(
                "customer_profiles",
                {
                    "customer_uid": uid,
                    "current_location": location_data,
                    "updated_at": _now(),
                },
                "customer_uid",
            )
            if customer_profile is None:
                current_preferences = current_profile.get("preferences") or {}
                updates["preferences"] = {
                    **current_preferences,
                    "customer_location": location_data,
                }

        updates["firebase_uid"] = uid
        updates["updated_at"] = _now()
        response = (
            get_supabase()
            .table("profiles")
            .upsert(updates, on_conflict="firebase_uid")
            .execute()
        )
        saved_profile = response.data[0] if response.data else updates
        if customer_profile:
            saved_profile["customer_profile"] = customer_profile
        return {"message": "User profile updated", "uid": uid, **saved_profile}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/{uid}/onboarding")
def get_onboarding(uid: str, current_user: CurrentUser = Depends(get_current_user)):
    """Get the user's normalized onboarding progress."""
    require_current_user_uid(uid, current_user)
    try:
        profile = _get_profile(uid)
        return sync_onboarding_state(uid, profile)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
