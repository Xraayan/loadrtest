from math import atan2, cos, pi, pow, sin, sqrt
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from dependencies import CurrentUser, get_current_user

router = APIRouter()


VEHICLE_RATES = {
    "Pickup": {"base_fare": 450.0, "per_km_rate": 38.0, "minimum_fare": 700.0},
    "Mini Truck": {"base_fare": 650.0, "per_km_rate": 48.0, "minimum_fare": 950.0},
    "Tipper": {"base_fare": 950.0, "per_km_rate": 68.0, "minimum_fare": 1400.0},
    "Tata 407": {"base_fare": 800.0, "per_km_rate": 58.0, "minimum_fare": 1200.0},
}

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
    vehicle_type: str = "Pickup"
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


def _round_to_nearest(value: float, nearest: int) -> float:
    return round(value / nearest) * float(nearest)


def _quote_for(vehicle_type: str, distance_km: float) -> dict:
    rate = VEHICLE_RATES.get(vehicle_type, VEHICLE_RATES["Pickup"])
    raw_amount = rate["base_fare"] + (distance_km * rate["per_km_rate"])
    amount = max(rate["minimum_fare"], raw_amount)
    return {
        "vehicle_type": vehicle_type,
        "distance_km": distance_km,
        "base_fare": rate["base_fare"],
        "per_km_rate": rate["per_km_rate"],
        "minimum_fare": rate["minimum_fare"],
        "amount": _round_to_nearest(amount, 10),
    }


def _suggest_vehicle_type(distance_km: float) -> str:
    if distance_km < 12:
        return "Pickup"
    if distance_km < 35:
        return "Mini Truck"
    if distance_km < 80:
        return "Tata 407"
    return "Tipper"


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


def _astar_route(pickup: LocationPoint, drop: LocationPoint, grid_size: int = 28) -> list[dict]:
    start = (0, 0)
    goal = (grid_size - 1, grid_size - 1)
    came_from: dict[tuple[int, int], tuple[int, int]] = {}
    g_score = {start: 0.0}
    open_set = [start]

    while open_set:
        open_set.sort(key=lambda node: g_score.get(node, float("inf")) + _heuristic(node, goal))
        current = open_set.pop(0)
        if current == goal:
            return _nodes_to_points(_reconstruct_path(came_from, current), pickup, drop, grid_size)

        for next_node in _neighbors(current, grid_size):
            move_cost = 1.0 if next_node[0] == current[0] or next_node[1] == current[1] else 1.35
            tentative_score = g_score.get(current, float("inf")) + move_cost
            if tentative_score >= g_score.get(next_node, float("inf")):
                continue
            came_from[next_node] = current
            g_score[next_node] = tentative_score
            if next_node not in open_set:
                open_set.append(next_node)

    return [
        {"latitude": pickup.latitude, "longitude": pickup.longitude},
        {"latitude": drop.latitude, "longitude": drop.longitude},
    ]


def _neighbors(node: tuple[int, int], grid_size: int) -> list[tuple[int, int]]:
    neighbors = []
    for dx in range(-1, 2):
        for dy in range(-1, 2):
            if dx == 0 and dy == 0:
                continue
            x = node[0] + dx
            y = node[1] + dy
            if x < 0 or y < 0 or x >= grid_size or y >= grid_size:
                continue
            neighbors.append((x, y))
    return neighbors


def _heuristic(a: tuple[int, int], b: tuple[int, int]) -> float:
    return sqrt(pow(a[0] - b[0], 2) + pow(a[1] - b[1], 2))


def _reconstruct_path(
    came_from: dict[tuple[int, int], tuple[int, int]],
    current: tuple[int, int],
) -> list[tuple[int, int]]:
    path = [current]
    while current in came_from:
        current = came_from[current]
        path.append(current)
    path.reverse()
    return path


def _nodes_to_points(
    nodes: list[tuple[int, int]],
    pickup: LocationPoint,
    drop: LocationPoint,
    grid_size: int,
) -> list[dict]:
    points = []
    for node in nodes:
        progress = node[0] / (grid_size - 1)
        cross_progress = node[1] / (grid_size - 1)
        curve = sin(progress * pi) * 0.12
        latitude = _lerp(pickup.latitude, drop.latitude, progress)
        longitude = _lerp(pickup.longitude, drop.longitude, cross_progress)
        perpendicular_lat = (drop.longitude - pickup.longitude) * curve
        perpendicular_lng = (pickup.latitude - drop.latitude) * curve
        points.append(
            {
                "latitude": latitude + perpendicular_lat,
                "longitude": longitude + perpendicular_lng,
            }
        )
    return points


def _lerp(start: float, end: float, progress: float) -> float:
    return start + ((end - start) * progress)


@router.post("/estimate")
def estimate_quote(
    request: QuoteRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Estimate route distance and vehicle pricing on the trusted backend."""
    try:
        distance_km = _haversine_km(request.pickup, request.drop)
        quotes = [_quote_for(vehicle_type, distance_km) for vehicle_type in VEHICLE_RATES]
        selected_quote = next(
            (quote for quote in quotes if quote["vehicle_type"] == request.vehicle_type),
            quotes[0],
        )

        suggested_vehicle_type = _suggest_vehicle_type(distance_km)
        return {
            "distance_km": distance_km,
            "route_points": _astar_route(request.pickup, request.drop),
            "selected_quote": selected_quote,
            "vehicle_quotes": quotes,
            "pickup_metadata": _parse_location_metadata(request.pickup),
            "drop_metadata": _parse_location_metadata(request.drop),
            "suggested_vehicle_type": suggested_vehicle_type,
        }
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
