from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel

from dependencies import CurrentUser, get_current_user, require_current_user_uid
from supabase_config import get_supabase

router = APIRouter()


class MessageCreate(BaseModel):
    receiver_uid: str
    message: str
    job_id: Optional[str] = None
    trip_id: Optional[str] = None


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _profile_name(uid: str) -> str:
    try:
        profile = (
            get_supabase()
            .table("profiles")
            .select("name,phone")
            .eq("firebase_uid", uid)
            .maybe_single()
            .execute()
            .data
        )
        if profile:
            return profile.get("name") or profile.get("phone") or "LoadR user"
    except Exception:
        pass
    return "LoadR user"


@router.get("/{uid}/conversations")
def get_conversations(
    uid: str,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Return active trip contacts plus recent message threads."""
    require_current_user_uid(uid, current_user)
    try:
        conversations = {}

        sent = _messages_for("sender_uid", uid)
        received = _messages_for("receiver_uid", uid)
        for message in sent + received:
            other_uid = (
                message.get("receiver_uid")
                if message.get("sender_uid") == uid
                else message.get("sender_uid")
            )
            if not other_uid:
                continue
            key = f"{message.get('job_id') or ''}:{other_uid}"
            current = conversations.get(key)
            if current and str(current.get("last_message_at") or "") >= str(message.get("created_at") or ""):
                continue
            conversations[key] = {
                "job_id": message.get("job_id"),
                "trip_id": message.get("trip_id"),
                "other_uid": other_uid,
                "other_name": _profile_name(other_uid),
                "last_message": message.get("message"),
                "last_message_at": message.get("created_at"),
            }

        for job in _active_jobs_for(uid):
            customer_uid = job.get("customer_uid")
            driver_uid = job.get("assigned_driver_uid")
            if not customer_uid or not driver_uid:
                continue
            other_uid = driver_uid if uid == customer_uid else customer_uid
            key = f"{job.get('id') or job.get('job_id') or ''}:{other_uid}"
            conversations.setdefault(
                key,
                {
                    "job_id": job.get("id") or job.get("job_id"),
                    "trip_id": job.get("assigned_trip_id"),
                    "other_uid": other_uid,
                    "other_name": _profile_name(other_uid),
                    "last_message": "No messages yet",
                    "last_message_at": job.get("updated_at") or job.get("created_at"),
                },
            )

        items = list(conversations.values())
        items.sort(key=lambda item: str(item.get("last_message_at") or ""), reverse=True)
        return {"conversations": items}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/{uid}/thread")
def get_thread(
    uid: str,
    other_uid: str = Query(),
    job_id: Optional[str] = None,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Return messages between two users, optionally scoped to one job."""
    require_current_user_uid(uid, current_user)
    try:
        messages = [
            *_thread_half(uid, other_uid, job_id),
            *_thread_half(other_uid, uid, job_id),
        ]
        messages.sort(key=lambda item: str(item.get("created_at") or ""))
        return {"messages": messages, "other_name": _profile_name(other_uid)}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/{uid}/send")
def send_message(
    uid: str,
    request: MessageCreate,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Send one job-scoped chat message."""
    require_current_user_uid(uid, current_user)
    text = request.message.strip()
    if not text:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Message is empty")

    try:
        if request.job_id:
            _require_job_chat_member(uid, request.receiver_uid, request.job_id)

        data = {
            "sender_uid": uid,
            "receiver_uid": request.receiver_uid,
            "job_id": request.job_id,
            "trip_id": request.trip_id,
            "message": text,
            "created_at": _now(),
        }
        response = get_supabase().table("chat_messages").insert(data).execute()
        message = response.data[0] if response.data else data
        return {"message": message}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


def _messages_for(column: str, uid: str) -> list[dict]:
    return (
        get_supabase()
        .table("chat_messages")
        .select("*")
        .eq(column, uid)
        .order("created_at", desc=True)
        .limit(50)
        .execute()
        .data
        or []
    )


def _thread_half(sender_uid: str, receiver_uid: str, job_id: Optional[str]) -> list[dict]:
    query = (
        get_supabase()
        .table("chat_messages")
        .select("*")
        .eq("sender_uid", sender_uid)
        .eq("receiver_uid", receiver_uid)
    )
    if job_id:
        query = query.eq("job_id", job_id)
    return query.order("created_at", desc=False).limit(100).execute().data or []


def _active_jobs_for(uid: str) -> list[dict]:
    statuses = ["assigned", "accepted", "arriving", "in_progress", "awaiting_payment"]
    customer_jobs = (
        get_supabase()
        .table("jobs")
        .select("*")
        .eq("customer_uid", uid)
        .in_("status", statuses)
        .execute()
        .data
        or []
    )
    driver_jobs = (
        get_supabase()
        .table("jobs")
        .select("*")
        .eq("assigned_driver_uid", uid)
        .in_("status", statuses)
        .execute()
        .data
        or []
    )
    return customer_jobs + driver_jobs


def _require_job_chat_member(sender_uid: str, receiver_uid: str, job_id: str) -> None:
    job = (
        get_supabase()
        .table("jobs")
        .select("customer_uid,assigned_driver_uid")
        .eq("id", job_id)
        .maybe_single()
        .execute()
        .data
    )
    if not job:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")
    members = {job.get("customer_uid"), job.get("assigned_driver_uid")}
    if sender_uid not in members or receiver_uid not in members:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Chat is not available")
