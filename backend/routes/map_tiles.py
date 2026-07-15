from threading import Lock
from time import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from fastapi import APIRouter, HTTPException, Response, status

from config import settings

router = APIRouter()

_MAP_STYLE = "osm-bright-smooth"
_CACHE_TTL_SECONDS = 60 * 60 * 24
_MAX_CACHE_ITEMS = 1200
_tile_cache: dict[tuple[str, bool, int, int, int], tuple[float, bytes]] = {}
_tile_cache_lock = Lock()


def _cached_tile(key: tuple[str, bool, int, int, int]) -> bytes | None:
    with _tile_cache_lock:
        cached = _tile_cache.get(key)
        if not cached:
            return None
        cached_at, content = cached
        if time() - cached_at > _CACHE_TTL_SECONDS:
            _tile_cache.pop(key, None)
            return None
        return content


def _store_tile(key: tuple[str, bool, int, int, int], content: bytes) -> None:
    with _tile_cache_lock:
        if len(_tile_cache) >= _MAX_CACHE_ITEMS:
            oldest_key = min(_tile_cache, key=lambda item: _tile_cache[item][0])
            _tile_cache.pop(oldest_key, None)
        _tile_cache[key] = (time(), content)


@router.get("/geoapify/osm-bright-smooth/{z}/{x}/{y}@2x.png")
def get_retina_map_tile(z: int, x: int, y: int):
    return _get_map_tile(z, x, y, retina=True)


@router.get("/geoapify/osm-bright-smooth/{z}/{x}/{y}.png")
def get_map_tile(z: int, x: int, y: int):
    return _get_map_tile(z, x, y, retina=False)


def _get_map_tile(z: int, x: int, y: int, *, retina: bool):
    if z < 0 or z > 20:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported tile zoom",
        )

    max_tile = (1 << z) - 1
    if x < 0 or y < 0 or x > max_tile or y > max_tile:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid tile coordinates",
        )

    api_key = (settings.geoapify_api_key or "").strip()
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Set GEOAPIFY_API_KEY in backend/.env",
        )

    cache_key = (_MAP_STYLE, retina, z, x, y)
    cached = _cached_tile(cache_key)
    if cached is not None:
        return _tile_response(cached)

    scale = "@2x" if retina else ""
    tile_url = (
        f"https://maps.geoapify.com/v1/tile/{_MAP_STYLE}/"
        f"{z}/{x}/{y}{scale}.png?apiKey={api_key}"
    )
    request = Request(
        tile_url,
        headers={
            "User-Agent": "LoadR backend map tile proxy",
        },
    )

    try:
        with urlopen(request, timeout=8) as tile_response:
            content = tile_response.read()
        _store_tile(cache_key, content)
    except HTTPError as exc:
        raise HTTPException(
            status_code=exc.code,
            detail="Map tile request failed",
        ) from exc
    except URLError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Map tile server unavailable",
        ) from exc

    return _tile_response(content)


def _tile_response(content: bytes) -> Response:
    return Response(
        content=content,
        media_type="image/png",
        headers={
            "Cache-Control": "public, max-age=86400",
        },
    )
