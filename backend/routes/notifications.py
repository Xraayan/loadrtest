import time

from fastapi import APIRouter, Depends, HTTPException, status
from firebase_admin import db
from pydantic import BaseModel

from dependencies import CurrentUser, get_current_user, require_current_user_uid

router = APIRouter()


class NotificationCreate(BaseModel):
    title: str
    message: str
    type: str = "general"


@router.get("/{uid}")
def get_notifications(uid: str, current_user: CurrentUser = Depends(get_current_user)):
    """Get notifications for the current user."""
    require_current_user_uid(uid, current_user)
    try:
        notifications = db.reference(f"notifications/{uid}").get()
        if not notifications:
            return []

        result = [
            {"notification_id": notification_id, **notification}
            for notification_id, notification in notifications.items()
        ]
        result.sort(key=lambda item: item.get("created_at") or 0, reverse=True)
        return result
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
        notification_ref = db.reference(f"notifications/{uid}").push()
        data = {
            **notification.model_dump(),
            "read": False,
            "created_at": int(time.time()),
        }
        notification_ref.set(data)
        return {
            "message": "Notification created",
            "notification_id": notification_ref.key,
            **data,
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
        notification_ref = db.reference(f"notifications/{uid}/{notification_id}")
        notification = notification_ref.get()
        if not notification:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Notification not found",
            )

        notification_ref.update({
            "read": True,
            "read_at": int(time.time()),
        })
        return {"message": "Notification marked as read"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
