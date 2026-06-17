from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from dependencies import CurrentUser, get_current_user, require_current_user_uid
from onboarding import update_onboarding_progress
from supabase_config import get_supabase

router = APIRouter()


class PreferencesUpdate(BaseModel):
    preferred_states: List[str]
    preferred_vehicle_type: Optional[str] = None


@router.get("/{uid}")
def get_preferences(uid: str, current_user: CurrentUser = Depends(get_current_user)):
    """Get driver preferences."""
    require_current_user_uid(uid, current_user)
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
        if not profile:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
        return profile.get("preferences") or {}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.put("/{uid}")
def update_preferences(
    uid: str,
    preferences: PreferencesUpdate,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Save driver preferences and advance onboarding."""
    require_current_user_uid(uid, current_user)
    try:
        preferred_states = [
            state.strip()
            for state in preferences.preferred_states
            if state.strip()
        ]
        if not preferred_states:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="At least one preferred state is required",
            )

        data = preferences.model_dump(exclude_unset=True)
        data["preferred_states"] = preferred_states

        response = (
            get_supabase()
            .table("profiles")
            .update({"preferences": data})
            .eq("firebase_uid", uid)
            .execute()
        )
        if not response.data:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

        onboarding = update_onboarding_progress(uid, {"preferences_selected": True})
        return {
            "message": "Preferences updated",
            "preferences": data,
            "onboarding": onboarding,
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

