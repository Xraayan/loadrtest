import json
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from routes.quotes import LocationPoint, _route_for


class _Response:
    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def read(self):
        return json.dumps(
            {
                "features": [
                    {
                        "properties": {"distance": 1250},
                        "geometry": {
                            "coordinates": [[[76.5, 9.5], [76.51, 9.51]]]
                        },
                    }
                ]
            }
        ).encode()


class RouteForTest(unittest.TestCase):
    @patch("routes.quotes.urlopen", return_value=_Response())
    @patch("routes.quotes.settings", SimpleNamespace(geoapify_api_key="test-key"))
    def test_geojson_route_uses_road_distance_and_lon_lat_order(self, _urlopen):
        start = LocationPoint(display_name="Start", latitude=9.5, longitude=76.5)
        end = LocationPoint(display_name="End", latitude=9.51, longitude=76.51)

        distance_km, points = _route_for(start, end)

        self.assertEqual(distance_km, 1.25)
        self.assertEqual(points[1], {"latitude": 9.51, "longitude": 76.51})


if __name__ == "__main__":
    unittest.main()
