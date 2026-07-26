import json
from math import atan2, cos, pi, pow, sin, sqrt
from typing import Optional
from urllib.error import HTTPError
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
    return earth_radius_km * 2 * atan2(sqrt(a), sqrt(1 - a))


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
    api_key = (settings.geoapify_api_key or "").strip()
    if not api_key:
        raise ValueError("Set GEOAPIFY_API_KEY in backend/.env")

    try:
        return _road_route_for(pickup, drop, api_key)
    except ValueError as error:
        last_error = str(error)

    if "unconnected regions" not in last_error.lower():
        raise ValueError(f"Geoapify could not calculate this route: {last_error}")

    drop_candidate = _address_route_candidate(drop, api_key)
    if drop_candidate is not None:
        try:
            return _road_route_for(pickup, drop_candidate, api_key)
        except ValueError as error:
            last_error = str(error)

    pickup_candidate = _address_route_candidate(pickup, api_key)
    if pickup_candidate is not None:
        try:
            return _road_route_for(pickup_candidate, drop, api_key)
        except ValueError as error:
            last_error = str(error)

    if pickup_candidate is not None and drop_candidate is not None:
        try:
            return _road_route_for(pickup_candidate, drop_candidate, api_key)
        except ValueError as error:
            last_error = str(error)

    raise ValueError(f"Geoapify could not calculate this route: {last_error}")


def _road_route_for(
    pickup: LocationPoint,
    drop: LocationPoint,
    api_key: str,
) -> tuple[float, list[dict]]:
    last_error = "No route returned"
    for mode in ("light_truck", "drive"):
        try:
            return _geoapify_route_for(pickup, drop, api_key, mode)
        except ValueError as error:
            last_error = str(error)

    raise ValueError(last_error)


def _address_route_candidate(
    place: LocationPoint,
    api_key: str,
) -> Optional[LocationPoint]:
    name = place.display_name.strip()
    if not name:
        return None

    query = urlencode(
        {
            "text": name,
            "filter": "countrycode:in",
            "limit": "1",
            "format": "json",
            "apiKey": api_key,
        }
    )
    request = Request(
        f"https://api.geoapify.com/v1/geocode/autocomplete?{query}",
        headers={"User-Agent": "LoadR Backend"},
    )
    try:
        with urlopen(request, timeout=8) as response:
            candidate = (json.loads(response.read().decode("utf-8")).get("results") or [])[0]
        latitude = float(candidate.get("lat"))
        longitude = float(candidate.get("lon"))
    except (IndexError, TypeError, ValueError):
        return None
    except Exception:
        return None

    if latitude == place.latitude and longitude == place.longitude:
        return None
    return LocationPoint(
        display_name=name,
        latitude=latitude,
        longitude=longitude,
        city=place.city,
        district=place.district,
        state=place.state,
    )


def _geoapify_route_for(
    pickup: LocationPoint,
    drop: LocationPoint,
    api_key: str,
    mode: str,
) -> tuple[float, list[dict]]:
    query = urlencode(
        {
            "waypoints": (
                f"{pickup.latitude},{pickup.longitude}|"
                f"{drop.latitude},{drop.longitude}"
            ),
            "mode": mode,
            "type": "balanced",
            "format": "geojson",
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
        provider_message = str(payload.get("message") or "").strip()
        if provider_message:
            provider_code = payload.get("statusCode") or "error"
            raise ValueError(f"{mode} failed ({provider_code}): {provider_message}")

        features = payload.get("features") or []
        if not features:
            raise ValueError(f"{mode} returned no route")
        feature = features[0]
        points = _route_points_from_geometry(feature.get("geometry", {}))
        distance_m = float(feature.get("properties", {}).get("distance") or 0)
        if len(points) < 2 or distance_m <= 0:
            raise ValueError(f"{mode} returned no usable route")
        if len(points) == 2 and distance_m > 500:
            raise ValueError(f"{mode} returned endpoint-only route")
        return distance_m / 1000, points
    except HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise ValueError(f"{mode} failed ({error.code}): {detail}") from error
    except ValueError:
        raise
    except Exception as error:
        raise ValueError(f"{mode} failed: {error}") from error


def _route_points_from_geometry(geometry: dict) -> list[dict]:
    coordinates = geometry.get("coordinates") or []
    first = coordinates[0] if coordinates else None
    if geometry.get("type") == "LineString" or _is_position(first):
        lines = [coordinates]
    else:
        lines = coordinates

    return [
        {"latitude": pair[1], "longitude": pair[0]}
        for line in lines
        if isinstance(line, list)
        for pair in line
        if isinstance(pair, list) and len(pair) >= 2
    ]


def _is_position(value: object) -> bool:
    return (
        isinstance(value, list)
        and len(value) >= 2
        and isinstance(value[0], (int, float))
        and isinstance(value[1], (int, float))
    )


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
