DEFAULT_VEHICLE_TYPES = [
    {
        "id": "three_wheeler_ape",
        "name": "3 Wheeler Ape",
        "capacity_label": "750 kg capacity",
        "capacity_kg": 750,
        "base_fare": 300.0,
        "minimum_fare": 300.0,
        "included_km": 3.0,
        "per_km_rate": 50.0,
        "active": True,
        "sort_order": 10,
    },
    {
        "id": "tata_ace",
        "name": "Tata Ace",
        "capacity_label": "1000 kg / 1 ton capacity",
        "capacity_kg": 1000,
        "base_fare": 600.0,
        "minimum_fare": 600.0,
        "included_km": 10.0,
        "per_km_rate": 60.0,
        "active": True,
        "sort_order": 20,
    },
    {
        "id": "dost_pickup",
        "name": "Dost Pickup",
        "capacity_label": "1.5 ton capacity",
        "capacity_kg": 1500,
        "base_fare": 800.0,
        "minimum_fare": 800.0,
        "included_km": 5.0,
        "per_km_rate": 40.0,
        "active": True,
        "sort_order": 30,
    },
    {
        "id": "tata_407_water_tanker",
        "name": "Tata 407 Water Tanker",
        "capacity_label": "5000 litre capacity",
        "capacity_litre": 5000,
        "base_fare": 1350.0,
        "minimum_fare": 1350.0,
        "included_km": 5.0,
        "per_km_rate": 30.0,
        "active": True,
        "sort_order": 40,
    },
]


def quote_for_vehicle(vehicle: dict, distance_km: float) -> dict:
    included_km = float(vehicle.get("included_km") or 0)
    extra_km = max(0.0, distance_km - included_km)
    raw_amount = float(vehicle["base_fare"]) + extra_km * float(vehicle["per_km_rate"])
    amount = max(float(vehicle["minimum_fare"]), raw_amount)
    return {
        "vehicle_type": vehicle["name"],
        "distance_km": distance_km,
        "base_fare": float(vehicle["base_fare"]),
        "per_km_rate": float(vehicle["per_km_rate"]),
        "minimum_fare": float(vehicle["minimum_fare"]),
        "included_km": included_km,
        "amount": round(amount / 10) * 10.0,
    }
