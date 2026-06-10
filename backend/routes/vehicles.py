from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from firebase_admin import db
from typing import Optional

router = APIRouter()

class Vehicle(BaseModel):
    number: str
    type: str
    capacity: int
    owner: str

@router.get("/")
def get_vehicles():
    """Get all available vehicles"""
    try:
        vehicles_ref = db.reference("vehicles")
        vehicles = vehicles_ref.get()
        if not vehicles:
            return []
        return list(vehicles.values())
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

@router.get("/{uid}")
def get_driver_vehicles(uid: str):
    """Get vehicles assigned to driver"""
    try:
        vehicles_ref = db.reference("vehicles")
        all_vehicles = vehicles_ref.get()
        if not all_vehicles:
            return []
        
        driver_vehicles = [v for v in all_vehicles.values() if v.get("owner") == uid]
        return driver_vehicles
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

@router.post("/{uid}/assign")
def assign_vehicle(uid: str, vehicle_number: str):
    """Assign vehicle to driver"""
    try:
        driver_ref = db.reference(f"users/{uid}")
        driver_ref.update({"vehicle_number": vehicle_number})
        return {"message": "Vehicle assigned"}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
