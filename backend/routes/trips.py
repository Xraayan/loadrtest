from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from firebase_admin import db
from typing import Optional, List
import time

router = APIRouter()

class Trip(BaseModel):
    pickup_location: str
    dropoff_location: str
    pickup_coords: dict
    dropoff_coords: dict
    status: str = "pending"
    amount: Optional[float] = None

@router.post("/")
def create_trip(uid: str, trip: Trip):
    """Create a new trip"""
    try:
        trip_ref = db.reference("trips").push()
        trip_data = trip.dict()
        trip_data["driver_id"] = uid
        trip_data["created_at"] = int(time.time())
        trip_ref.set(trip_data)
        return {"message": "Trip created", "trip_id": trip_ref.key}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

@router.get("/{uid}")
def get_trips(uid: str):
    """Get all trips for a driver"""
    try:
        trips_ref = db.reference("trips")
        all_trips = trips_ref.get()
        if not all_trips:
            return []
        
        driver_trips = [trip for trip in all_trips.values() if trip.get("driver_id") == uid]
        return driver_trips
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

@router.get("/trip/{trip_id}")
def get_trip(trip_id: str):
    """Get trip details"""
    try:
        trip_ref = db.reference(f"trips/{trip_id}")
        trip = trip_ref.get()
        if not trip:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trip not found")
        return trip
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

@router.patch("/trip/{trip_id}/status")
def update_trip_status(trip_id: str, status: str):
    """Update trip status"""
    try:
        trip_ref = db.reference(f"trips/{trip_id}")
        trip_ref.update({"status": status})
        return {"message": "Trip status updated"}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
