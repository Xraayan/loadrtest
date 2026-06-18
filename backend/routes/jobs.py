from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status

from dependencies import CurrentUser, get_current_user, require_current_user_uid
from supabase_config import get_supabase

router = APIRouter()


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _matches_filter(value: Optional[str], expected: Optional[str]) -> bool:
    if not expected:
        return True
    return expected.lower() in str(value or "").lower()


def _job_with_id(job: dict) -> dict:
    return {"job_id": job.get("id"), **job}


def _trip_with_id(trip: dict) -> dict:
    return {"trip_id": trip.get("id"), "driver_id": trip.get("driver_uid"), **trip}


@router.get("/")
def search_jobs(
    state: Optional[str] = None,
    city: Optional[str] = None,
    vehicle_type: Optional[str] = None,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Find open jobs by state, city, or vehicle type."""
    try:
        response = (
            get_supabase()
            .table("jobs")
            .select("*")
            .eq("status", "open")
            .order("created_at", desc=True)
            .execute()
        )

        jobs = []
        for job in response.data or []:
            if not _matches_filter(job.get("state"), state):
                continue
            if not _matches_filter(job.get("city"), city):
                continue
            if not _matches_filter(job.get("vehicle_type"), vehicle_type):
                continue
            jobs.append(_job_with_id(job))

        return jobs
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/{job_id}")
def get_job(job_id: str, current_user: CurrentUser = Depends(get_current_user)):
    """Get one job by ID."""
    try:
        job = (
            get_supabase()
            .table("jobs")
            .select("*")
            .eq("id", job_id)
            .maybe_single()
            .execute()
            .data
        )
        if not job:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")
        return _job_with_id(job)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/{job_id}/accept/{uid}")
def accept_job(
    job_id: str,
    uid: str,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Accept an open job and create a trip for the driver."""
    require_current_user_uid(uid, current_user)
    try:
        job = (
            get_supabase()
            .table("jobs")
            .select("*")
            .eq("id", job_id)
            .maybe_single()
            .execute()
            .data
        )
        if not job:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")
        if job.get("status") != "open":
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Job is not available")

        now = _now()
        trip_data = {
            "job_id": job_id,
            "driver_uid": uid,
            "pickup_location": job.get("pickup_location"),
            "dropoff_location": job.get("dropoff_location"),
            "pickup_coords": job.get("pickup_coords"),
            "dropoff_coords": job.get("dropoff_coords"),
            "status": "accepted",
            "amount": job.get("amount"),
            "created_at": now,
            "updated_at": now,
        }
        trip = get_supabase().table("trips").insert(trip_data).execute().data[0]

        get_supabase().table("jobs").update(
            {
                "status": "assigned",
                "assigned_driver_uid": uid,
                "assigned_trip_id": trip["id"],
                "assigned_at": now,
                "updated_at": now,
            }
        ).eq("id", job_id).execute()

        get_supabase().table("notifications").insert(
            {
                "user_uid": uid,
                "title": "Trip accepted",
                "message": f"You accepted {job.get('title', 'a job')}.",
                "type": "trip",
                "read": False,
                "created_at": now,
            }
        ).execute()

        return {
            "message": "Job accepted",
            "job_id": job_id,
            "trip_id": trip["id"],
            "trip": _trip_with_id(trip),
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

