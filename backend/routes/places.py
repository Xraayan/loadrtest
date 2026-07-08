import json
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from fastapi import APIRouter, Depends, HTTPException, Query, status

from config import settings
from dependencies import CurrentUser, get_current_user

router = APIRouter()

BASE_URL = "https://api.geoapify.com/v1/geocode"


def _require_api_key() -> str:
    key = (settings.geoapify_api_key or "").strip()
    if not key:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Set GEOAPIFY_API_KEY in backend/.env",
        )
    return key


def _get_geoapify(path: str, params: dict) -> dict:
    params = {**params, "apiKey": _require_api_key()}
    url = f"{BASE_URL}/{path}?{urlencode(params)}"
    request = Request(url, headers={"User-Agent": "LoadR Backend"})
    try:
        with urlopen(request, timeout=10) as response:
            return json.loads(response.read().decode("utf-8"))
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Location provider failed: {e}",
        )


def _place_from_geoapify(item: dict) -> dict:
    formatted = str(item.get("formatted") or "").strip()
    line1 = str(item.get("address_line1") or "").strip()
    line2 = str(item.get("address_line2") or "").strip()
    fallback = ", ".join(part for part in [line1, line2] if part)

    return {
        "display_name": formatted or fallback,
        "latitude": item.get("lat"),
        "longitude": item.get("lon"),
        "city": item.get("city") or item.get("town") or item.get("village") or item.get("county") or "",
        "district": item.get("county") or item.get("district") or item.get("city") or "",
        "state": item.get("state") or "",
        "country": item.get("country") or "",
    }


@router.get("/autocomplete")
def autocomplete(
    query: str = Query(..., min_length=3),
    current_user: CurrentUser = Depends(get_current_user),
):
    data = _get_geoapify(
        "autocomplete",
        {
            "text": query.strip(),
            "format": "json",
            "filter": "countrycode:in",
            "limit": "6",
        },
    )
    results = data.get("results") if isinstance(data, dict) else []
    return [
        place
        for place in (_place_from_geoapify(item) for item in results or [])
        if str(place.get("display_name") or "").strip()
    ]


@router.get("/reverse")
def reverse_geocode(
    latitude: float,
    longitude: float,
    current_user: CurrentUser = Depends(get_current_user),
):
    data = _get_geoapify(
        "reverse",
        {
            "lat": str(latitude),
            "lon": str(longitude),
            "format": "json",
        },
    )
    results = data.get("results") if isinstance(data, dict) else []
    places = [
        place
        for place in (_place_from_geoapify(item) for item in results or [])
        if str(place.get("display_name") or "").strip()
    ]
    if not places:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Location lookup returned no address")
    return places[0]
