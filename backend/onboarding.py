from datetime import datetime, timezone
from typing import Any, Dict, Optional

from supabase_config import get_supabase


DRIVER_ONBOARDING_STEPS = (
    "role_selected",
    "vehicle_selected",
    "preferences_selected",
    "documents_uploaded",
)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _is_missing_column_error(error: Exception) -> bool:
    message = str(error)
    return "PGRST204" in message and "schema cache" in message


def _get_profile(uid: str) -> Optional[Dict[str, Any]]:
    return (
        get_supabase()
        .table("profiles")
        .select("*")
        .eq("firebase_uid", uid)
        .maybe_single()
        .execute()
        .data
    )


def get_onboarding_next(user: Dict[str, Any]) -> str:
    role = user.get("role")
    if not user.get("role_selected") or not role:
        return "role-selection"
    if role == "user":
        return "dashboard"
    if not user.get("vehicle_selected"):
        return "vehicles"
    if not user.get("preferences_selected"):
        return "preferences"
    if not user.get("documents_uploaded"):
        return "upload-license"
    return "dashboard"


def is_profile_complete(user: Dict[str, Any]) -> bool:
    role = user.get("role")
    if role == "user":
        return bool(user.get("role_selected"))
    if role == "driver":
        return all(bool(user.get(step)) for step in DRIVER_ONBOARDING_STEPS)
    return False


def build_onboarding_state(uid: str, user: Dict[str, Any]) -> Dict[str, Any]:
    steps = {step: bool(user.get(step)) for step in DRIVER_ONBOARDING_STEPS}
    return {
        "uid": uid,
        "role": user.get("role"),
        "profile_complete": is_profile_complete(user),
        "onboarding_next": get_onboarding_next(user),
        "steps": steps,
    }


def sync_onboarding_state(
    uid: str,
    user: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    current_user = user if user is not None else _get_profile(uid)
    if not current_user:
        return {}

    state = build_onboarding_state(uid, current_user)
    updates = {}
    if current_user.get("profile_complete") != state["profile_complete"]:
        updates["profile_complete"] = state["profile_complete"]
    if current_user.get("onboarding_next") != state["onboarding_next"]:
        updates["onboarding_next"] = state["onboarding_next"]

    if updates:
        updates["updated_at"] = _now()
        try:
            get_supabase().table("profiles").update(updates).eq("firebase_uid", uid).execute()
            current_user.update(updates)
        except Exception as e:
            if not _is_missing_column_error(e):
                raise
            state["warning"] = "Rerun backend/supabase_schema.sql to add onboarding columns."
            return state

    return build_onboarding_state(uid, current_user)


def update_onboarding_progress(uid: str, updates: Dict[str, Any]) -> Dict[str, Any]:
    current_user = _get_profile(uid)
    if not current_user:
        return {}

    updates = {
        **updates,
        "updated_at": _now(),
    }
    try:
        get_supabase().table("profiles").update(updates).eq("firebase_uid", uid).execute()
        current_user.update(updates)
    except Exception as e:
        if not _is_missing_column_error(e):
            raise
        state = build_onboarding_state(uid, current_user)
        state["warning"] = "Rerun backend/supabase_schema.sql to add onboarding columns."
        return state

    return sync_onboarding_state(uid, current_user)
