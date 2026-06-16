from typing import Optional
import time

from fastapi import APIRouter, Depends, HTTPException, status
from firebase_admin import db

from dependencies import CurrentUser, get_current_user, require_current_user_uid

router = APIRouter()


def _matches_filter(value: Optional[str], expected: Optional[str]) -> bool:
    if not expected:
        return True
    return expected.lower() in str(value or "").lower()


def _job_with_id(job_id: str, job: dict) -> dict:
    return {"job_id": job_id, **job}


@router.get("/")
def search_jobs(
    state: Optional[str] = None,
    city: Optional[str] = None,
    vehicle_type: Optional[str] = None,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Find open jobs by state, city, or vehicle type."""
    try:
        all_jobs = db.reference("jobs").get()
        if not all_jobs:
            return []

        jobs = []
        for job_id, job in all_jobs.items():
            if job.get("status") != "open":
                continue
            if not _matches_filter(job.get("state"), state):
                continue
            if not _matches_filter(job.get("city"), city):
                continue
            if not _matches_filter(job.get("vehicle_type"), vehicle_type):
                continue
            jobs.append(_job_with_id(job_id, job))

        return jobs
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/{job_id}")
def get_job(job_id: str, current_user: CurrentUser = Depends(get_current_user)):
    """Get one job by ID."""
    try:
        job = db.reference(f"jobs/{job_id}").get()
        if not job:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")
        return _job_with_id(job_id, job)
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
        job_ref = db.reference(f"jobs/{job_id}")
        job = job_ref.get()
        if not job:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")
        if job.get("status") != "open":
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Job is not available")

        now = int(time.time())
        trip_ref = db.reference("trips").push()
        trip_data = {
            "job_id": job_id,
            "driver_id": uid,
            "pickup_location": job.get("pickup_location"),
            "dropoff_location": job.get("dropoff_location"),
            "pickup_coords": job.get("pickup_coords"),
            "dropoff_coords": job.get("dropoff_coords"),
            "state": job.get("state"),
            "city": job.get("city"),
            "vehicle_type": job.get("vehicle_type"),
            "status": "accepted",
            "amount": job.get("amount"),
            "created_at": now,
            "updated_at": now,
        }
        trip_ref.set(trip_data)

        job_ref.update({
            "status": "assigned",
            "assigned_driver_id": uid,
            "assigned_trip_id": trip_ref.key,
            "assigned_at": now,
            "updated_at": now,
        })

        db.reference(f"notifications/{uid}").push().set({
            "title": "Trip accepted",
            "message": f"You accepted {job.get('title', 'a job')}.",
            "type": "trip",
            "trip_id": trip_ref.key,
            "read": False,
            "created_at": now,
        })

        return {
            "message": "Job accepted",
            "job_id": job_id,
            "trip_id": trip_ref.key,
            "trip": {"trip_id": trip_ref.key, **trip_data},
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
