from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from supabase_config import get_supabase
from dependencies import CurrentUser, get_current_user, require_current_user_uid
from routes.quotes import LocationPoint, _haversine_km

router = APIRouter()
_PICKUP_APPROACH_RADIUS_KM = 0.5


class LocationUpdate(BaseModel):
    latitude: float
    longitude: float
    is_active: Optional[bool] = True


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


@router.post("/update")
def update_location(
    uid: str,
    location: LocationUpdate,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Update driver's current realtime location."""
    require_current_user_uid(uid, current_user)
    try:
        data = {
            "driver_uid": uid,
            "latitude": location.latitude,
            "longitude": location.longitude,
            "is_active": location.is_active,
            "updated_at": _now(),
        }
        get_supabase().table("driver_locations").upsert(
            data,
            on_conflict="driver_uid",
        ).execute()
        try:
            _mark_arriving_if_near_pickup(uid, location.latitude, location.longitude)
        except Exception:
            pass
        return {"message": "Location updated", "location": data}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


def _mark_arriving_if_near_pickup(uid: str, latitude: float, longitude: float) -> None:
    job = (
        get_supabase()
        .table("jobs")
        .select("*")
        .eq("assigned_driver_uid", uid)
        .in_("status", ["assigned", "accepted"])
        .order("assigned_at", desc=True)
        .limit(1)
        .execute()
        .data
    )
    if not job:
        return

    active_job = job[0]
    pickup = active_job.get("pickup_coords")
    if not isinstance(pickup, dict):
        return
    pickup_latitude = pickup.get("latitude")
    pickup_longitude = pickup.get("longitude")
    if pickup_latitude is None or pickup_longitude is None:
        return
    try:
        pickup_point = LocationPoint(
            display_name="Pickup",
            latitude=float(pickup_latitude),
            longitude=float(pickup_longitude),
        )
    except (TypeError, ValueError):
        return

    distance_km = _haversine_km(
        LocationPoint(display_name="Driver", latitude=latitude, longitude=longitude),
        pickup_point,
    )
    if distance_km > _PICKUP_APPROACH_RADIUS_KM:
        return

    now = _now()
    get_supabase().table("jobs").update(
        {"status": "arriving", "updated_at": now}
    ).eq("id", active_job.get("id")).execute()

    trip_id = active_job.get("assigned_trip_id")
    if trip_id:
        get_supabase().table("trips").update(
            {"status": "arriving", "updated_at": now}
        ).eq("id", trip_id).execute()

    customer_uid = active_job.get("customer_uid")
    if customer_uid:
        get_supabase().table("notifications").insert(
            {
                "user_uid": customer_uid,
                "title": "Driver is reaching pickup",
                "message": "Your driver is near the pickup location.",
                "type": "trip",
                "read": False,
                "created_at": now,
            }
        ).execute()


@router.get("/nearby")
def nearby_locations(
    latitude: float,
    longitude: float,
    radius_km: float = 25,
    limit: int = 12,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Return active driver map points near a pickup without exposing identities."""
    try:
        origin = LocationPoint(display_name="Pickup", latitude=latitude, longitude=longitude)
        response = (
            get_supabase()
            .table("driver_locations")
            .select("latitude,longitude,updated_at")
            .eq("is_active", True)
            .execute()
        )
        nearby = []
        for location in response.data or []:
            point = LocationPoint(
                display_name="Driver",
                latitude=float(location.get("latitude")),
                longitude=float(location.get("longitude")),
            )
            distance_km = _haversine_km(origin, point)
            if distance_km <= max(1, min(radius_km, 50)):
                nearby.append({**location, "distance_km": distance_km})
        nearby.sort(key=lambda item: item["distance_km"])
        return nearby[: max(1, min(limit, 20))]
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/{uid}")
def get_location(
    uid: str,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Get driver's current location."""
    require_current_user_uid(uid, current_user)
    try:
        location = (
            get_supabase()
            .table("driver_locations")
            .select("*")
            .eq("driver_uid", uid)
            .maybe_single()
            .execute()
            .data
        )
        if not location:
            return {"message": "Location not available"}
        return location
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
