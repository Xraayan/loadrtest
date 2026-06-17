from datetime import datetime, timezone
from enum import Enum
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from dependencies import CurrentUser, get_current_user, require_current_user_uid
from onboarding import sync_onboarding_state, update_onboarding_progress
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


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _get_profile(uid: str) -> dict:
    profile = (
        get_supabase()
        .table("profiles")
        .select("*")
        .eq("firebase_uid", uid)
        .maybe_single()
        .execute()
        .data
    )
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return profile


@router.get("/{uid}")
def get_user(uid: str, current_user: CurrentUser = Depends(get_current_user)):
    """Get user profile and onboarding state."""
    require_current_user_uid(uid, current_user)
    try:
        profile = _get_profile(uid)
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
        _get_profile(uid)
        updates = {
            "role": request.role.value,
            "role_selected": True,
            "role_selected_at": _now(),
        }
        onboarding = update_onboarding_progress(uid, updates)

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
        _get_profile(uid)
        updates = profile.model_dump(exclude_unset=True)
        if not updates:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No profile fields provided",
            )

        updates["updated_at"] = _now()
        response = (
            get_supabase()
            .table("profiles")
            .update(updates)
            .eq("firebase_uid", uid)
            .execute()
        )
        return {"message": "User profile updated", "uid": uid, **response.data[0]}
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

