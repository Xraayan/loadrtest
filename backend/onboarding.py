import time
from typing import Any, Dict, Optional

from firebase_admin import db


DRIVER_ONBOARDING_STEPS = (
    "role_selected",
    "vehicle_selected",
    "preferences_selected",
    "documents_uploaded",
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
    steps = {
        step: bool(user.get(step))
        for step in DRIVER_ONBOARDING_STEPS
    }
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
    user_ref = db.reference(f"users/{uid}")
    current_user = user if user is not None else user_ref.get()
    if not current_user:
        return {}

    state = build_onboarding_state(uid, current_user)
    updates = {}
    if current_user.get("profile_complete") != state["profile_complete"]:
        updates["profile_complete"] = state["profile_complete"]
    if current_user.get("onboarding_next") != state["onboarding_next"]:
        updates["onboarding_next"] = state["onboarding_next"]

    if updates:
        updates["updated_at"] = int(time.time())
        user_ref.update(updates)
        current_user.update(updates)

    return build_onboarding_state(uid, current_user)


def update_onboarding_progress(uid: str, updates: Dict[str, Any]) -> Dict[str, Any]:
    now = int(time.time())
    user_ref = db.reference(f"users/{uid}")
    current_user = user_ref.get()
    if not current_user:
        return {}

    updates = {
        **updates,
        "updated_at": now,
    }
    user_ref.update(updates)
    current_user.update(updates)
    return sync_onboarding_state(uid, current_user)
