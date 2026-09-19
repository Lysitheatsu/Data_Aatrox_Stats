"""Shared HTTP helper for all the OpenStreetMap calls.

The OSM servers block you if you don't send a User-Agent, and they only allow
about 1 request per second. So everything goes through here to keep those
rules in one place. Also caches repeat lookups so we don't ask twice.
"""

from __future__ import annotations

import asyncio
import json
import time
from typing import Any
from urllib.parse import urlparse

import httpx

# OSM servers reject requests that don't say who you are.
USER_AGENT = "ELLY-Maps/0.1 (ElectraWireless student project)"

# how long a cached answer is still good for (seconds)
CACHE_TTL = 300.0

# smallest gap allowed between two calls to the same server
MIN_REQUEST_GAP = 1.0

_client: httpx.AsyncClient | None = None

# host -> timestamp of the last request we sent it
_last_call: dict[str, float] = {}
_throttle_lock = asyncio.Lock()

# cache key -> (stored_at, response json)
_cache: dict[str, tuple[float, Any]] = {}


def get_client() -> httpx.AsyncClient:
    """Get the client, making it the first time it's needed."""
    global _client
    if _client is None:
        _client = httpx.AsyncClient(
            headers={"User-Agent": USER_AGENT},
            timeout=httpx.Timeout(20.0),
            follow_redirects=True,
        )
    return _client


async def close_client() -> None:
    """Shut the client down."""
    global _client
    if _client is not None:
        await _client.aclose()
        _client = None


def _cache_key(method: str, url: str, params: Any, data: Any) -> str:
    return json.dumps([method, url, params, data], sort_keys=True, default=str)


async def _wait_turn(url: str) -> None:
    """Wait a bit if we just called this server."""
    host = urlparse(url).netloc
    async with _throttle_lock:
        previous = _last_call.get(host)
        now = time.monotonic()
        if previous is not None:
            wait_for = MIN_REQUEST_GAP - (now - previous)
            if wait_for > 0:
                await asyncio.sleep(wait_for)
                now = time.monotonic()
        _last_call[host] = now


async def fetch_json(
    url: str,
    *,
    method: str = "GET",
    params: dict[str, Any] | None = None,
    data: dict[str, Any] | None = None,
    use_cache: bool = True,
) -> Any:
    """Call a service and give back the JSON.

    Throws httpx.HTTPError if it goes wrong. The router catches that and
    turns it into a 502.
    """
    key = _cache_key(method, url, params, data)

    if use_cache:
        cached = _cache.get(key)
        if cached is not None:
            stored_at, value = cached
            if time.monotonic() - stored_at < CACHE_TTL:
                return value
            # too old, get rid of it
            del _cache[key]

    await _wait_turn(url)

    client = get_client()
    response = await client.request(method, url, params=params, data=data)
    response.raise_for_status()
    payload = response.json()

    if use_cache:
        _cache[key] = (time.monotonic(), payload)

    return payload


def clear_cache() -> None:
    """Wipe the cache. Just for the tests."""
    _cache.clear()
    _last_call.clear()
