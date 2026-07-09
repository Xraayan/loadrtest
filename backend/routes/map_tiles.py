from threading import Lock
from time import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from fastapi import APIRouter, HTTPException, Response, status

router = APIRouter()

_CACHE_TTL_SECONDS = 60 * 60 * 24
_MAX_CACHE_ITEMS = 1200
_tile_cache: dict[tuple[int, int, int], tuple[float, bytes]] = {}
_tile_cache_lock = Lock()


def _cached_tile(key: tuple[int, int, int]) -> bytes | None:
    with _tile_cache_lock:
        cached = _tile_cache.get(key)
        if not cached:
            return None
        cached_at, content = cached
        if time() - cached_at > _CACHE_TTL_SECONDS:
            _tile_cache.pop(key, None)
            return None
        return content


def _store_tile(key: tuple[int, int, int], content: bytes) -> None:
    with _tile_cache_lock:
        if len(_tile_cache) >= _MAX_CACHE_ITEMS:
            oldest_key = min(_tile_cache, key=lambda item: _tile_cache[item][0])
            _tile_cache.pop(oldest_key, None)
        _tile_cache[key] = (time(), content)


@router.get("/tiles/{z}/{x}/{y}.png")
def get_osm_tile(z: int, x: int, y: int):
    if z < 0 or z > 19:
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

    cache_key = (z, x, y)
    cached = _cached_tile(cache_key)
    if cached is not None:
        return _tile_response(cached)

    tile_url = f"https://tile.openstreetmap.org/{z}/{x}/{y}.png"
    request = Request(
        tile_url,
        headers={
            "User-Agent": "LoadR development app; local backend tile proxy",
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
