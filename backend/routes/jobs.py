import asyncio
from datetime import datetime, timezone
from json import dumps
from typing import Optional
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from starlette.concurrency import run_in_threadpool

from dependencies import CurrentUser, get_current_user, require_current_user_uid
from role_profiles import get_role_profile
from routes.quotes import LocationPoint, _parse_location_metadata, _quote_for, _route_for
from supabase_config import get_supabase

router = APIRouter()

ACTIVE_TRIP_STATUSES = {
    "pending",
    "accepted",
    "assigned",
    "arriving",
    "in_progress",
    "awaiting_payment",
    "started",
    "on_the_way",
    "pickup",
    "loaded",
}

ACTIVE_JOB_STATUSES = {
    "assigned",
    "accepted",
    "arriving",
    "in_progress",
    "awaiting_payment",
}


class JobCreate(BaseModel):
    customer_uid: str
    title: str
    pickup_location: str
    dropoff_location: str
    pickup_coords: dict
    dropoff_coords: dict
    vehicle_type: str
    amount: float
    state: Optional[str] = None
    city: Optional[str] = None
    district: Optional[str] = None


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _notify_job_accepted(uid: str, title: str, created_at: str) -> None:
    try:
        get_supabase().table("notifications").insert(
            {
                "user_uid": uid,
                "title": "Trip accepted",
                "message": f"You accepted {title}.",
                "type": "trip",
                "read": False,
                "created_at": created_at,
            }
        ).execute()
    except Exception as error:
        print(f"Could not create trip acceptance notification: {error}")


def _matches_filter(value: Optional[str], expected: Optional[str]) -> bool:
    if not expected:
        return True
    return expected.lower() in str(value or "").lower()


def _job_with_id(job: dict) -> dict:
    return {"job_id": job.get("id"), **job}


def _job_with_driver(job: dict) -> dict:
    formatted_job = _job_with_id(job)
    driver_uid = job.get("assigned_driver_uid")
    if not driver_uid:
        return formatted_job

    driver = {"uid": driver_uid}
    try:
        profile = (
            get_supabase()
            .table("profiles")
            .select("firebase_uid,name")
            .eq("firebase_uid", driver_uid)
            .maybe_single()
            .execute()
            .data
        )
        if profile:
            driver.update(profile)
    except Exception:
        pass

    try:
        driver_profile = get_role_profile("driver_profiles", "driver_uid", driver_uid)
        if driver_profile:
            driver.update(driver_profile)
    except Exception:
        pass

    try:
        location = (
            get_supabase()
            .table("driver_locations")
            .select("latitude,longitude,is_active,updated_at")
            .eq("driver_uid", driver_uid)
            .maybe_single()
            .execute()
            .data
        )
        if location:
            driver["current_location"] = location
    except Exception:
        pass

    formatted_job["driver"] = driver
    return formatted_job


def _trip_with_id(trip: dict) -> dict:
    return {"trip_id": trip.get("id"), "driver_id": trip.get("driver_uid"), **trip}


def _get_active_trip_for_driver(uid: str) -> Optional[dict]:
    response = (
        get_supabase()
        .table("trips")
        .select("*")
        .eq("driver_uid", uid)
        .in_("status", list(ACTIVE_TRIP_STATUSES))
        .order("created_at", desc=True)
        .limit(1)
        .execute()
    )
    trips = response.data or []
    return trips[0] if trips else None


def _get_active_job_for_driver(uid: str) -> Optional[dict]:
    response = (
        get_supabase()
        .table("jobs")
        .select("*")
        .eq("assigned_driver_uid", uid)
        .in_("status", list(ACTIVE_JOB_STATUSES))
        .order("assigned_at", desc=True)
        .limit(1)
        .execute()
    )
    jobs = response.data or []
    return jobs[0] if jobs else None


def _active_assignment_for_driver(uid: str) -> Optional[dict]:
    trip = _get_active_trip_for_driver(uid)
    job = None
    if trip and trip.get("job_id"):
        job = (
            get_supabase()
            .table("jobs")
            .select("*")
            .eq("id", trip.get("job_id"))
            .maybe_single()
            .execute()
            .data
        )
    if not job:
        job = _get_active_job_for_driver(uid)
    if not trip and job and job.get("assigned_trip_id"):
        trip = (
            get_supabase()
            .table("trips")
            .select("*")
            .eq("id", job.get("assigned_trip_id"))
            .maybe_single()
            .execute()
            .data
        )
    if not job and not trip:
        return None
    return {
        "job": _job_with_id(job) if job else None,
        "trip": _trip_with_id(trip) if trip else None,
    }


def _active_customer_jobs(uid: str) -> list[dict]:
    response = (
        get_supabase()
        .table("jobs")
        .select("*")
        .eq("customer_uid", uid)
        .in_(
            "status",
            [
                "open",
                "assigned",
                "accepted",
                "arriving",
                "in_progress",
                "awaiting_payment",
            ],
        )
        .order("created_at", desc=True)
        .execute()
    )
    return response.data or []


def _active_customer_job(uid: str, job_id: Optional[str] = None) -> Optional[dict]:
    if job_id:
        job = (
            get_supabase()
            .table("jobs")
            .select("*")
            .eq("customer_uid", uid)
            .eq("id", job_id)
            .in_(
                "status",
                [
                    "open",
                    "assigned",
                    "accepted",
                    "arriving",
                    "in_progress",
                    "awaiting_payment",
                ],
            )
            .maybe_single()
            .execute()
            .data
        )
        return job

    jobs = _active_customer_jobs(uid)
    return jobs[0] if jobs else None


@router.get("/")
def search_jobs(
    state: Optional[str] = None,
    city: Optional[str] = None,
    district: Optional[str] = None,
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
            if not _matches_filter(job.get("district"), district):
                continue
            if not _matches_filter(job.get("vehicle_type"), vehicle_type):
                continue
            jobs.append(_job_with_id(job))

        return jobs
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/")
def create_job(
    request: JobCreate,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Create an open customer job for drivers to accept."""
    require_current_user_uid(request.customer_uid, current_user)
    try:
        now = _now()
        pickup_point = LocationPoint(
            display_name=request.pickup_location,
            latitude=float(request.pickup_coords.get("latitude")),
            longitude=float(request.pickup_coords.get("longitude")),
            city=request.city,
            district=request.district,
            state=request.state,
        )
        drop_point = LocationPoint(
            display_name=request.dropoff_location,
            latitude=float(request.dropoff_coords.get("latitude")),
            longitude=float(request.dropoff_coords.get("longitude")),
        )
        distance_km, route_points = _route_for(pickup_point, drop_point)
        quote = _quote_for(request.vehicle_type, distance_km)
        metadata = _parse_location_metadata(pickup_point)
        data = {
            "id": str(uuid4()),
            "customer_uid": request.customer_uid,
            "title": request.title,
            "pickup_location": request.pickup_location,
            "dropoff_location": request.dropoff_location,
            "pickup_coords": route_points[0],
            "dropoff_coords": route_points[-1],
            "state": metadata["state"],
            "city": metadata["city"],
            "district": metadata["district"],
            "vehicle_type": request.vehicle_type,
            "amount": quote["amount"],
            "distance_km": distance_km,
            "route_points": route_points,
            "status": "open",
            "created_at": now,
            "updated_at": now,
        }
        response = get_supabase().table("jobs").insert(data).execute()
        created = response.data[0] if response.data else data
        return {
            "message": "Job created",
            "job_id": created.get("id"),
            "job": _job_with_id(created),
        }
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/driver/{uid}/active")
def get_active_driver_job(
    uid: str,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get the driver's currently active job/trip, if one exists."""
    require_current_user_uid(uid, current_user)
    try:
        active = _active_assignment_for_driver(uid)
        return active or {"job": None, "trip": None}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/driver/{uid}/active/stream")
async def stream_active_driver_job(
    request: Request,
    uid: str,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Push driver active job changes to the app without manual refresh."""
    require_current_user_uid(uid, current_user)

    async def events():
        last_payload = ""
        while not await request.is_disconnected():
            try:
                payload = dumps(
                    await run_in_threadpool(
                        lambda: _active_assignment_for_driver(uid)
                        or {"job": None, "trip": None}
                    ),
                    default=str,
                    sort_keys=True,
                )
                if payload != last_payload:
                    yield f"data: {payload}\n\n"
                    last_payload = payload
            except asyncio.CancelledError:
                return
            except Exception:
                yield 'event: error\ndata: {"message":"stream unavailable"}\n\n'
            await asyncio.sleep(2)

    return StreamingResponse(
        events(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache"},
    )


@router.get("/customer/{uid}/active")
def get_active_customer_job(
    uid: str,
    job_id: Optional[str] = None,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get the customer's latest open or assigned job."""
    require_current_user_uid(uid, current_user)
    try:
        return _active_customer_payload(uid, job_id)
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


def _active_customer_payload(uid: str, job_id: Optional[str] = None) -> dict:
    jobs = [_job_with_driver(job) for job in _active_customer_jobs(uid)]
    if job_id:
        job = _active_customer_job(uid, job_id)
        return {"job": _job_with_driver(job) if job else None, "jobs": jobs}

    job = next(
        (item for item in jobs if item.get("job_id") == job_id),
        jobs[0] if jobs else None,
    )
    return {"job": job, "jobs": jobs}


@router.get("/customer/{uid}/active/stream")
async def stream_active_customer_job(
    request: Request,
    uid: str,
    job_id: Optional[str] = None,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Push customer job changes to the app without client-side polling."""
    require_current_user_uid(uid, current_user)

    async def events():
        last_payload = ""
        while not await request.is_disconnected():
            try:
                payload = dumps(
                    await run_in_threadpool(_active_customer_payload, uid, job_id),
                    default=str,
                    sort_keys=True,
                )
                if payload != last_payload:
                    yield f"data: {payload}\n\n"
                    last_payload = payload
            except asyncio.CancelledError:
                return
            except Exception:
                yield 'event: error\ndata: {"message":"stream unavailable"}\n\n'
            await asyncio.sleep(2)

    return StreamingResponse(
        events(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache"},
    )


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
        return _job_with_driver(job)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.patch("/{job_id}/cancel")
def cancel_job(job_id: str, current_user: CurrentUser = Depends(get_current_user)):
    """Cancel a customer pickup before completion."""
    try:
        supabase = get_supabase()
        job = (
            supabase.table("jobs")
            .select("*")
            .eq("id", job_id)
            .maybe_single()
            .execute()
            .data
        )
        if not job:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")

        require_current_user_uid(job.get("customer_uid"), current_user)
        if job.get("status") in {
            "completed",
            "cancelled",
            "in_progress",
            "awaiting_payment",
            "started",
            "pickup",
            "loaded",
        }:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This pickup can no longer be cancelled",
            )

        now = _now()
        updated = (
            supabase.table("jobs")
            .update({"status": "cancelled", "updated_at": now})
            .eq("id", job_id)
            .execute()
            .data
        )
        if job.get("assigned_trip_id"):
            supabase.table("trips").update(
                {"status": "cancelled", "updated_at": now}
            ).eq("id", job["assigned_trip_id"]).execute()

        if job.get("assigned_driver_uid"):
            supabase.table("notifications").insert(
                {
                    "user_uid": job["assigned_driver_uid"],
                    "title": "Pickup cancelled",
                    "message": "Customer cancelled the pickup.",
                    "type": "trip",
                    "read": False,
                    "created_at": now,
                }
            ).execute()

        return {
            "message": "Pickup cancelled",
            "job": _job_with_id(updated[0] if updated else {**job, "status": "cancelled"}),
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/{job_id}/accept/{uid}")
def accept_job(
    job_id: str,
    uid: str,
    background_tasks: BackgroundTasks,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Accept an open job and create a trip for the driver."""
    require_current_user_uid(uid, current_user)
    try:
        active_assignment = _active_assignment_for_driver(uid)
        if active_assignment:
            active_job = active_assignment.get("job") or {}
            if active_job.get("job_id") == job_id:
                active_trip = active_assignment.get("trip") or {}
                return {
                    "message": "Job already accepted",
                    "job_id": job_id,
                    "trip_id": active_trip.get("trip_id") or active_job.get("assigned_trip_id"),
                    "job": active_job,
                    "trip": active_trip,
                }
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Complete your active job before accepting another load",
            )

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
        trip_id = str(uuid4())
        accepted_job = {
            **job,
            "status": "assigned",
            "assigned_driver_uid": uid,
            "assigned_trip_id": trip_id,
            "assigned_at": now,
            "updated_at": now,
        }
        update_response = (
            get_supabase()
            .table("jobs")
            .update(
                {
                    "status": accepted_job["status"],
                    "assigned_driver_uid": accepted_job["assigned_driver_uid"],
                    "assigned_trip_id": accepted_job["assigned_trip_id"],
                    "assigned_at": accepted_job["assigned_at"],
                    "updated_at": accepted_job["updated_at"],
                }
            )
            .eq("id", job_id)
            .eq("status", "open")
            .execute()
        )
        if not update_response.data:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Job is not available")

        trip_data = {
            "id": trip_id,
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

        background_tasks.add_task(
            _notify_job_accepted,
            uid,
            job.get("title", "a job"),
            now,
        )

        return {
            "message": "Job accepted",
            "job_id": job_id,
            "trip_id": trip["id"],
            "job": _job_with_id(accepted_job),
            "trip": _trip_with_id(trip),
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
