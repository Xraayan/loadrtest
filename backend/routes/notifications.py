from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from dependencies import CurrentUser, get_current_user, require_current_user_uid
from supabase_config import get_supabase

router = APIRouter()


class NotificationCreate(BaseModel):
    title: str
    message: str
    type: str = "general"


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _notification_with_id(notification: dict) -> dict:
    return {"notification_id": notification.get("id"), **notification}


@router.get("/{uid}")
def get_notifications(uid: str, current_user: CurrentUser = Depends(get_current_user)):
    """Get notifications for the current user."""
    require_current_user_uid(uid, current_user)
    try:
        response = (
            get_supabase()
            .table("notifications")
            .select("*")
            .eq("user_uid", uid)
            .order("created_at", desc=True)
            .execute()
        )
        return [_notification_with_id(item) for item in (response.data or [])]
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/{uid}")
def create_notification(
    uid: str,
    notification: NotificationCreate,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Create a notification for the current user."""
    require_current_user_uid(uid, current_user)
    try:
        data = {
            "user_uid": uid,
            **notification.model_dump(),
            "read": False,
            "created_at": _now(),
        }
        created = get_supabase().table("notifications").insert(data).execute().data[0]
        return {
            "message": "Notification created",
            **_notification_with_id(created),
        }
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.patch("/{uid}/{notification_id}/read")
def mark_notification_read(
    uid: str,
    notification_id: str,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Mark one notification as read."""
    require_current_user_uid(uid, current_user)
    try:
        response = (
            get_supabase()
            .table("notifications")
            .update({"read": True, "read_at": _now()})
            .eq("id", notification_id)
            .eq("user_uid", uid)
            .execute()
        )
        if not response.data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Notification not found",
            )
        return {"message": "Notification marked as read"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

