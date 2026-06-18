import time
from typing import Any, Dict

from firebase_admin import db


DEFAULT_VEHICLE_TYPES = {
    "construction_excavator": {
        "name": "Construction Excavator",
        "capacity": 20,
        "active": True,
    },
    "backhoe_loader": {
        "name": "Backhoe Loader",
        "capacity": 10,
        "active": True,
    },
    "three_wheeler": {
        "name": "3 Wheelers",
        "capacity": 1,
        "active": True,
    },
    "pickup": {
        "name": "Pickups",
        "capacity": 2,
        "active": True,
    },
    "tipper_truck": {
        "name": "Tipper Trucks",
        "capacity": 15,
        "active": True,
    },
    "tata_407": {
        "name": "Tata 407",
        "capacity": 4,
        "active": True,
    },
}


DEFAULT_JOBS = {
    "job_kerala_tvm_001": {
        "title": "Construction materials delivery",
        "pickup_location": "Pappanamcode, Thiruvananthapuram",
        "dropoff_location": "Kazhakoottam, Thiruvananthapuram",
        "pickup_coords": {"latitude": 8.4808, "longitude": 76.9801},
        "dropoff_coords": {"latitude": 8.5689, "longitude": 76.8731},
        "state": "Kerala",
        "city": "Thiruvananthapuram",
        "vehicle_type": "Tipper Trucks",
        "amount": 3200,
        "status": "open",
    },
    "job_kerala_kochi_001": {
        "title": "Warehouse pickup",
        "pickup_location": "Edappally, Kochi",
        "dropoff_location": "Kakkanad, Kochi",
        "pickup_coords": {"latitude": 10.0261, "longitude": 76.3125},
        "dropoff_coords": {"latitude": 10.0159, "longitude": 76.3419},
        "state": "Kerala",
        "city": "Kochi",
        "vehicle_type": "Pickups",
        "amount": 1800,
        "status": "open",
    },
    "job_karnataka_bengaluru_001": {
        "title": "Industrial goods transfer",
        "pickup_location": "Peenya, Bengaluru",
        "dropoff_location": "Whitefield, Bengaluru",
        "pickup_coords": {"latitude": 13.0329, "longitude": 77.5273},
        "dropoff_coords": {"latitude": 12.9698, "longitude": 77.7499},
        "state": "Karnataka",
        "city": "Bengaluru",
        "vehicle_type": "Tata 407",
        "amount": 4500,
        "status": "open",
    },
}


DATABASE_SCHEMA: Dict[str, Any] = {
    "users/{uid}": {
        "phone": "string",
        "role": "user|driver|null",
        "role_selected": "boolean",
        "profile_complete": "boolean",
        "onboarding_next": "string",
        "current_location": "object",
        "preferences": "object",
        "documents": "object",
    },
    "jobs/{job_id}": {
        "title": "string",
        "pickup_location": "string",
        "dropoff_location": "string",
        "state": "string",
        "city": "string",
        "vehicle_type": "string",
        "amount": "number",
        "status": "open|assigned|cancelled",
        "assigned_driver_id": "uid|null",
    },
    "trips/{trip_id}": {
        "driver_id": "uid",
        "job_id": "job_id|null",
        "pickup_location": "string",
        "dropoff_location": "string",
        "status": "pending|accepted|in_progress|completed|cancelled",
        "amount": "number",
    },
    "notifications/{uid}/{notification_id}": {
        "title": "string",
        "message": "string",
        "read": "boolean",
        "created_at": "unix_timestamp",
    },
    "vehicle_types/{vehicle_type_id}": {
        "name": "string",
        "capacity": "number",
        "active": "boolean",
    },
}


def _set_defaults_if_empty(path: str, defaults: Dict[str, Any]) -> None:
    ref = db.reference(path)
    if not ref.get():
        now = int(time.time())
        data = {
            key: {
                **value,
                "created_at": now,
                "updated_at": now,
            }
            for key, value in defaults.items()
        }
        ref.set(data)


def seed_reference_data() -> None:
    """Seed Firebase RTDB with minimal data needed by app pages."""
    _set_defaults_if_empty("vehicle_types", DEFAULT_VEHICLE_TYPES)
    _set_defaults_if_empty("jobs", DEFAULT_JOBS)
