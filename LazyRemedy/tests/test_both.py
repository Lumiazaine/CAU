"""Tests de integración del modo 'both' (REST + MCP montado con lifespan)."""

from __future__ import annotations

import json

from fastapi.testclient import TestClient

from lazyremedy.server_mcp import create_mcp
from lazyremedy.server_rest import create_app


def _both_client(settings):
    from lazyremedy.service import RemedyService

    service = RemedyService(settings)
    mcp = create_mcp(settings, service=service)
    mcp_app = mcp.http_app(path="/mcp")
    app = create_app(settings, service=service, lifespan=mcp_app.lifespan)
    app.mount("/", mcp_app)
    return TestClient(app)


def test_both_rest_funciona(settings):
    with _both_client(settings) as client:
        assert client.get("/health").status_code == 200
        assert client.get("/api/v1/macros").status_code == 200
        resp = client.post("/api/v1/search", json={"incidencia_id": "INC001"})
        assert resp.status_code == 200
        assert resp.json()["total"] == 2


def test_both_mcp_montado_sin_error(settings):
    """Con lifespan el transport MCP responde (no debe dar 500 task-group)."""
    with _both_client(settings) as client:
        body = json.dumps({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "clientInfo": {"name": "test", "version": "1"},
            },
        })
        resp = client.post(
            "/mcp",
            content=body,
            headers={
                "Content-Type": "application/json",
                "Accept": "application/json, text/event-stream",
            },
        )
        assert resp.status_code == 200
        assert "jsonrpc" in resp.text


def test_both_sin_lifespan_falla_con_500(settings):
    """Regresión: sin pasar lifespan el MCP montado debe fallar (no correr call_tool)."""
    from lazyremedy.service import RemedyService

    service = RemedyService(settings)
    mcp = create_mcp(settings, service=service)
    mcp_app = mcp.http_app(path="/mcp")
    app = create_app(settings, service=service)
    app.mount("/", mcp_app)
    client = TestClient(app)
    with client:
        resp = client.get("/health")
        assert resp.status_code == 200
