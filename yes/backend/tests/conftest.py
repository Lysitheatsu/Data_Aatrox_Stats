"""Shared test setup.

None of the tests call the real OSM servers, they're all mocked with respx.
Keeps them fast and means they work offline.
"""

from __future__ import annotations

import pytest

from app.modules.maps.services import http as http_service


@pytest.fixture(autouse=True)
def fresh_http_state(monkeypatch):
    """Clean cache and no waiting between calls.

    The 1 second gap is needed for real use but would make the tests crawl.
    """
    monkeypatch.setattr(http_service, "MIN_REQUEST_GAP", 0.0)
    http_service.clear_cache()
    yield
    http_service.clear_cache()
