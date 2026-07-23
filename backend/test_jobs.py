import unittest
from unittest.mock import patch

from fastapi import BackgroundTasks

from routes.jobs import accept_job


class AcceptJobTest(unittest.TestCase):
    @patch("routes.jobs.require_current_user_uid")
    @patch("routes.jobs._active_assignment_for_driver")
    def test_retrying_the_same_accepted_job_returns_the_active_trip(
        self, active_assignment, _require_current_user_uid
    ):
        active_assignment.return_value = {
            "job": {"job_id": "job-1", "assigned_trip_id": "trip-1"},
            "trip": {"trip_id": "trip-1"},
        }

        response = accept_job("job-1", "driver-1", BackgroundTasks(), None)

        self.assertEqual(response["message"], "Job already accepted")
        self.assertEqual(response["trip_id"], "trip-1")


if __name__ == "__main__":
    unittest.main()
