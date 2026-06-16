from enum import Enum
from typing import Optional
import time

from fastapi import APIRouter, Depends, HTTPException, status
from firebase_admin import db
from pydantic import BaseModel

from dependencies import CurrentUser, get_current_user, require_current_user_uid
from onboarding import sync_onboarding_state, update_onboarding_progress

router = APIRouter()


class UserRole(str, Enum):
    user = "user"
    driver = "driver"


class RoleSelectionRequest(BaseModel):
    role: UserRole


class UserProfileUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None


@router.get("/{uid}")
def get_user(uid: str, current_user: CurrentUser = Depends(get_current_user)):
    """Get user profile and onboarding state."""
    require_current_user_uid(uid, current_user)
    try:
        user = db.reference(f"users/{uid}").get()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )
        sync_onboarding_state(uid, user)
        return user
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
        user_ref = db.reference(f"users/{uid}")
        existing_user = user_ref.get()
        if not existing_user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )

        role = request.role
        role_selected_at = int(time.time())

        updates = {
            "role": role.value,
            "role_selected": True,
            "role_selected_at": role_selected_at,
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
        user_ref = db.reference(f"users/{uid}")
        if not user_ref.get():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )

        updates = profile.model_dump(exclude_unset=True)
        if not updates:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No profile fields provided",
            )

        updates["updated_at"] = int(time.time())
        user_ref.update(updates)
        return {"message": "User profile updated", "uid": uid, **updates}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/{uid}/onboarding")
def get_onboarding(uid: str, current_user: CurrentUser = Depends(get_current_user)):
    """Get the user's normalized onboarding progress."""
    require_current_user_uid(uid, current_user)
    try:
        user = db.reference(f"users/{uid}").get()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )
        return sync_onboarding_state(uid, user)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
