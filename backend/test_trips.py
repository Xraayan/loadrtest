import unittest
from types import SimpleNamespace
from unittest.mock import patch

from fastapi import HTTPException

from routes.trips import _require_driver_near_pickup


class _Table:
    def __init__(self, data):
        self.data = data

    def select(self, *_args):
        return self

    def eq(self, *_args):
        return self

    def maybe_single(self):
        return self

    def execute(self):
        return SimpleNamespace(data=self.data)


class ConfirmPickupDistanceTest(unittest.TestCase):
    def _supabase(self, location):
        return SimpleNamespace(table=lambda _name: _Table(location))

    def test_driver_within_50_m_can_confirm_pickup(self):
        trip = {
            "driver_uid": "driver-1",
            "pickup_coords": {"latitude": 10.0, "longitude": 76.0},
        }
        location = {"latitude": 10.00036, "longitude": 76.0}

        with patch("routes.trips.get_supabase", return_value=self._supabase(location)):
            _require_driver_near_pickup(trip)

    def test_driver_outside_50_m_cannot_confirm_pickup(self):
        trip = {
            "driver_uid": "driver-1",
            "pickup_coords": {"latitude": 10.0, "longitude": 76.0},
        }
        location = {"latitude": 10.00054, "longitude": 76.0}

        with patch("routes.trips.get_supabase", return_value=self._supabase(location)):
            with self.assertRaises(HTTPException):
                _require_driver_near_pickup(trip)


if __name__ == "__main__":
    unittest.main()
