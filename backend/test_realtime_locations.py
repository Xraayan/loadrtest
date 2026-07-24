import unittest
from unittest.mock import patch

from realtime_locations import sync_driver_location


class FakeReference:
    def __init__(self):
        self.path = []
        self.payload = None

    def child(self, name):
        self.path.append(name)
        return self

    def set(self, payload):
        self.payload = payload


class SyncDriverLocationTest(unittest.TestCase):
    def test_sync_writes_driver_location_to_firebase(self):
        ref = FakeReference()

        with patch("realtime_locations.get_db", return_value=ref):
            synced = sync_driver_location(
                "driver-1",
                {
                    "latitude": 9.58,
                    "longitude": 76.52,
                    "is_active": True,
                    "updated_at": "2026-07-24T13:15:28+00:00",
                },
            )

        self.assertTrue(synced)
        self.assertEqual(ref.path, ["driver_locations", "driver-1"])
        self.assertEqual(ref.payload["driver_uid"], "driver-1")
        self.assertEqual(ref.payload["latitude"], 9.58)

    def test_sync_failure_does_not_break_location_update(self):
        with patch("realtime_locations.get_db", side_effect=RuntimeError("no db")):
            self.assertFalse(sync_driver_location("driver-1", {}))


if __name__ == "__main__":
    unittest.main()
