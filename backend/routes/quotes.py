import json
from math import atan2, cos, pi, pow, sin, sqrt
from typing import Optional
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from dependencies import CurrentUser, get_current_user
from config import settings
from supabase_config import get_supabase
from vehicle_catalog import DEFAULT_VEHICLE_TYPES, quote_for_vehicle

router = APIRouter()

KNOWN_STATES = {
    "andhra pradesh",
    "arunachal pradesh",
    "assam",
    "bihar",
    "chhattisgarh",
    "goa",
    "gujarat",
    "haryana",
    "himachal pradesh",
    "jharkhand",
    "karnataka",
    "kerala",
    "madhya pradesh",
    "maharashtra",
    "manipur",
    "meghalaya",
    "mizoram",
    "nagaland",
    "odisha",
    "punjab",
    "rajasthan",
    "sikkim",
    "tamil nadu",
    "telangana",
    "tripura",
    "uttar pradesh",
    "uttarakhand",
    "west bengal",
    "delhi",
    "kl",
}


class LocationPoint(BaseModel):
    display_name: str
    latitude: float
    longitude: float
    city: Optional[str] = None
    district: Optional[str] = None
    state: Optional[str] = None


class QuoteRequest(BaseModel):
    pickup: LocationPoint
    drop: LocationPoint
    vehicle_type: str = "Tata Ace"
    schedule: str = "Now"


def _degrees_to_radians(degrees: float) -> float:
    return degrees * pi / 180


def _haversine_km(pickup: LocationPoint, drop: LocationPoint) -> float:
    earth_radius_km = 6371.0
    d_lat = _degrees_to_radians(drop.latitude - pickup.latitude)
    d_lon = _degrees_to_radians(drop.longitude - pickup.longitude)
    pickup_lat = _degrees_to_radians(pickup.latitude)
    drop_lat = _degrees_to_radians(drop.latitude)

    a = pow(sin(d_lat / 2), 2) + cos(pickup_lat) * cos(drop_lat) * pow(sin(d_lon / 2), 2)
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return earth_radius_km * c


def _quote_for(vehicle_type: str, distance_km: float) -> dict:
    vehicles = _vehicle_types()
    vehicle = next(
        (
            item
            for item in vehicles
            if str(item.get("name", "")).lower() == vehicle_type.lower()
        ),
        vehicles[0],
    )
    return quote_for_vehicle(vehicle, distance_km)


def _vehicle_types() -> list[dict]:
    try:
        vehicles = (
            get_supabase()
            .table("vehicle_types")
            .select("*")
            .eq("active", True)
            .order("sort_order")
            .execute()
            .data
            or []
        )
        usable = [
            vehicle
            for vehicle in vehicles
            if vehicle.get("base_fare") is not None
            and vehicle.get("per_km_rate") is not None
            and vehicle.get("minimum_fare") is not None
        ]
        return usable or DEFAULT_VEHICLE_TYPES
    except Exception:
        return DEFAULT_VEHICLE_TYPES


def _suggest_vehicle_type(distance_km: float) -> str:
    if distance_km <= 5:
        return "3 Wheeler Ape"
    if distance_km <= 10:
        return "Tata Ace"
    return "Dost Pickup"


def _parse_location_metadata(place: LocationPoint) -> dict:
    state = (place.state or "").strip()
    city = (place.city or "").strip()
    district = (place.district or "").strip()

    if state or city or district:
        return {
            "city": city,
            "district": district or city,
            "state": state,
        }

    parts = [part.strip() for part in place.display_name.split(",") if part.strip()]
    for index, part in enumerate(parts):
        normalized = part.lower()
        if normalized in KNOWN_STATES:
            state = "Kerala" if normalized == "kl" else part
            if index > 0:
                city = parts[index - 1]
            if index > 1:
                district = parts[index - 2]
            break

    if not city and len(parts) >= 2:
        city = parts[-2]
    if not district:
        district = city

    return {
        "city": city,
        "district": district,
        "state": state,
    }


def _route_for(pickup: LocationPoint, drop: LocationPoint) -> tuple[float, list[dict]]:
    fallback = (
        _haversine_km(pickup, drop),
        [
            {"latitude": pickup.latitude, "longitude": pickup.longitude},
            {"latitude": drop.latitude, "longitude": drop.longitude},
        ],
    )
    api_key = (settings.geoapify_api_key or "").strip()
    if not api_key:
        return fallback

    query = urlencode(
        {
            "waypoints": (
                f"{pickup.latitude},{pickup.longitude}|"
                f"{drop.latitude},{drop.longitude}"
            ),
            "mode": "light_truck",
            "type": "balanced",
            "apiKey": api_key,
        }
    )
    request = Request(
        f"https://api.geoapify.com/v1/routing?{query}",
        headers={"User-Agent": "LoadR Backend"},
    )
    try:
        with urlopen(request, timeout=8) as response:
            payload = json.loads(response.read().decode("utf-8"))
        feature = (payload.get("features") or [])[0]
        lines = feature.get("geometry", {}).get("coordinates") or []
        points = [
            {"latitude": pair[1], "longitude": pair[0]}
            for line in lines
            for pair in line
            if isinstance(pair, list) and len(pair) >= 2
        ]
        distance_m = float(feature.get("properties", {}).get("distance") or 0)
        if len(points) < 2 or distance_m <= 0:
            return fallback
        return distance_m / 1000, points
    except Exception:
        return fallback


@router.post("/estimate")
def estimate_quote(
    request: QuoteRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Estimate route distance and vehicle pricing on the trusted backend."""
    try:
        distance_km, route_points = _route_for(request.pickup, request.drop)
        quotes = [
            quote_for_vehicle(vehicle, distance_km)
            for vehicle in _vehicle_types()
        ]
        selected_quote = next(
            (quote for quote in quotes if quote["vehicle_type"] == request.vehicle_type),
            quotes[0],
        )

        suggested_vehicle_type = _suggest_vehicle_type(distance_km)
        return {
            "distance_km": distance_km,
            "route_points": route_points,
            "selected_quote": selected_quote,
            "vehicle_quotes": quotes,
            "pickup_metadata": _parse_location_metadata(request.pickup),
            "drop_metadata": _parse_location_metadata(request.drop),
            "suggested_vehicle_type": suggested_vehicle_type,
        }
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
