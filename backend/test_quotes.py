import json
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from routes.quotes import LocationPoint, _route_for, _route_points_from_geometry


class _Response:
    def __init__(self, distance=1250, coordinates=None, payload=None):
        self.distance = distance
        self.coordinates = coordinates or [
            [[76.5, 9.5], [76.505, 9.505], [76.51, 9.51]]
        ]
        self.payload = payload

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def read(self):
        if self.payload is not None:
            return json.dumps(self.payload).encode()
        return json.dumps(
            {
                "features": [
                    {
                        "properties": {"distance": self.distance},
                        "geometry": {
                            "coordinates": self.coordinates
                        },
                    }
                ]
            }
        ).encode()


class RouteForTest(unittest.TestCase):
    @patch("routes.quotes.urlopen", return_value=_Response())
    @patch("routes.quotes.settings", SimpleNamespace(geoapify_api_key="test-key"))
    def test_geojson_route_uses_road_distance_and_lon_lat_order(self, urlopen_mock):
        start = LocationPoint(display_name="Start", latitude=9.5, longitude=76.5)
        end = LocationPoint(display_name="End", latitude=9.51, longitude=76.51)

        distance_km, points = _route_for(start, end)

        self.assertEqual(distance_km, 1.25)
        self.assertEqual(points[-1], {"latitude": 9.51, "longitude": 76.51})
        self.assertIn("format=geojson", urlopen_mock.call_args[0][0].full_url)
        self.assertIn("mode=light_truck", urlopen_mock.call_args[0][0].full_url)

    @patch(
        "routes.quotes.urlopen",
        side_effect=[Exception("truck failed"), _Response()],
    )
    @patch("routes.quotes.settings", SimpleNamespace(geoapify_api_key="test-key"))
    def test_drive_mode_is_used_when_light_truck_fails(self, urlopen_mock):
        start = LocationPoint(display_name="Start", latitude=9.5, longitude=76.5)
        end = LocationPoint(display_name="End", latitude=9.51, longitude=76.51)

        distance_km, points = _route_for(start, end)

        self.assertEqual(distance_km, 1.25)
        self.assertEqual(points[0], {"latitude": 9.5, "longitude": 76.5})
        self.assertIn("mode=drive", urlopen_mock.call_args_list[1][0][0].full_url)

    @patch("routes.quotes.settings", SimpleNamespace(geoapify_api_key=""))
    def test_route_requires_geoapify_api_key(self):
        start = LocationPoint(display_name="Start", latitude=9.5, longitude=76.5)
        end = LocationPoint(display_name="End", latitude=9.51, longitude=76.51)

        with self.assertRaises(ValueError):
            _route_for(start, end)

    @patch("routes.quotes.urlopen", side_effect=Exception("provider down"))
    @patch("routes.quotes.settings", SimpleNamespace(geoapify_api_key="test-key"))
    def test_route_failure_does_not_return_straight_line(self, _urlopen):
        start = LocationPoint(display_name="Start", latitude=9.5, longitude=76.5)
        end = LocationPoint(display_name="End", latitude=9.51, longitude=76.51)

        with self.assertRaises(ValueError):
            _route_for(start, end)

    @patch(
        "routes.quotes.urlopen",
        return_value=_Response(
            payload={
                "statusCode": 400,
                "message": "Locations are in unconnected regions",
            }
        ),
    )
    @patch("routes.quotes.settings", SimpleNamespace(geoapify_api_key="test-key"))
    def test_provider_error_does_not_become_a_route(self, _urlopen):
        start = LocationPoint(display_name="Start", latitude=9.5, longitude=76.5)
        end = LocationPoint(display_name="End", latitude=9.51, longitude=76.51)

        with self.assertRaisesRegex(ValueError, "unconnected regions"):
            _route_for(start, end)

    @patch(
        "routes.quotes.urlopen",
        side_effect=[
            _Response(payload={"statusCode": 400, "message": "Locations are in unconnected regions"}),
            _Response(payload={"statusCode": 400, "message": "Locations are in unconnected regions"}),
            _Response(payload={"results": [{"lat": 9.49, "lon": 76.32}]}),
            _Response(),
        ],
    )
    @patch("routes.quotes.settings", SimpleNamespace(geoapify_api_key="test-key"))
    def test_broad_address_is_retried_with_geoapify_autocomplete(self, urlopen_mock):
        start = LocationPoint(display_name="Kottayam", latitude=9.5, longitude=76.5)
        end = LocationPoint(display_name="Alappuzha, India", latitude=9.5003, longitude=76.4123)

        distance_km, _ = _route_for(start, end)

        self.assertEqual(distance_km, 1.25)
        self.assertIn(
            "9.5%2C76.5%7C9.49%2C76.32",
            urlopen_mock.call_args_list[-1][0][0].full_url,
        )

    def test_linestring_geometry_is_used_for_route_points(self):
        points = _route_points_from_geometry(
            {
                "type": "LineString",
                "coordinates": [[76.5, 9.5], [76.51, 9.51]],
            }
        )

        self.assertEqual(
            points,
            [
                {"latitude": 9.5, "longitude": 76.5},
                {"latitude": 9.51, "longitude": 76.51},
            ],
        )

    def test_linestring_coordinates_work_without_geometry_type(self):
        points = _route_points_from_geometry(
            {"coordinates": [[76.5, 9.5], [76.51, 9.51]]}
        )

        self.assertEqual(points[0], {"latitude": 9.5, "longitude": 76.5})


if __name__ == "__main__":
    unittest.main()
