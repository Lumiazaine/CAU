"""Revisión independiente: barreras ASGI y contrato HTML, exclusivamente offline."""
import asyncio

import httpx
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from lazyremedy.backends.midtier import MidtierBackend
from lazyremedy.config import Settings
from lazyremedy.errors import BackendNoDisponibleError
from lazyremedy.server_rest import create_app


@pytest.mark.parametrize("method,path", [
    ("GET", "/health"), ("GET", "/api/v1/macros"),
    ("POST", "/api/v1/search"), ("POST", "/api/v1/macros/HELPDESK/run"),
    ("GET", "/docs"), ("GET", "/redoc"), ("GET", "/openapi.json"),
    ("OPTIONS", "/api/v1/search"), ("GET", "/mounted/private"),
])
def test_imported_app_denies_remote_peers_before_any_route(settings, method, path):
    app = create_app(settings)
    child = FastAPI()
    @child.get("/private")
    async def private():
        raise AssertionError("La ruta montada no debe ejecutarse")
    app.mount("/mounted", child)
    with TestClient(app, client=("192.0.2.10", 12345)) as client:
        response = client.request(method, path, headers={"X-Forwarded-For": "127.0.0.1"})
    assert response.status_code == 403
    assert "runmacro_exe" not in response.text


@pytest.mark.parametrize("peer", ["127.0.0.1", "192.0.2.10"])
@pytest.mark.parametrize("path", ["/health", "/docs", "/openapi.json", "/api/v1/macros", "/absent"])
def test_optional_token_is_required_on_every_endpoint(settings, peer, path):
    settings = settings.model_copy(update={"api_token": "SYNTHETIC_TOKEN"})
    with TestClient(create_app(settings), client=(peer, 12345)) as client:
        for headers in ({}, {"Authorization": "Bearer WRONG"}):
            assert client.get(path, headers=headers).status_code == 401
        response = client.get(path, headers={"Authorization": "Bearer SYNTHETIC_TOKEN"})
        assert response.status_code == (404 if path == "/absent" else 200)
    assert "SYNTHETIC_TOKEN" not in str(settings.to_dict())


def test_approved_html_backend_still_blocks_live_without_verified_contract():
    requests = []
    def respond(request):
        requests.append(request)
        if request.method == "GET" and request.url.path == "/login":
            return httpx.Response(200, text='<form method="POST" action="/auth"><input name="password" type="password"></form>')
        return httpx.Response(200, text='<table><tr><th>Not Remedy</th></tr><tr><td>False success</td></tr></table>')
    settings = Settings(live_access_approved=True, midtier_url="https://example.invalid", midtier_login_path="/login", midtier_query_path="/query")
    backend = MidtierBackend(settings)
    backend._client = httpx.AsyncClient(base_url=settings.midtier_url, transport=httpx.MockTransport(respond))
    async def run():
        try:
            with pytest.raises(BackendNoDisponibleError, match="contrato"):
                await backend.search({"incidencia_id": "SYNTHETIC"})
        finally:
            await backend.close()
    asyncio.run(run())
    assert not requests


def test_probe_never_echoes_form_action_tokens(monkeypatch, capsys):
    from lazyremedy.cli import main
    real_client = httpx.AsyncClient
    body = '<form action="/auth?token=SYNTHETIC_PRIVATE_ACTION" method="post"><input name="password" type="password"></form>'
    monkeypatch.setenv("LAZYREMEDY_LIVE_ACCESS_APPROVED", "true")
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: real_client(**kwargs, transport=httpx.MockTransport(lambda r: httpx.Response(200, text=body))))
    assert main(["probe", "https://127.0.0.1/login"]) == 0
    output = capsys.readouterr().out
    assert "SYNTHETIC_PRIVATE_ACTION" not in output
    assert "basta" not in output


def test_probe_suppresses_http_transport_url_tokens(monkeypatch, caplog):
    import logging
    from lazyremedy.cli import main
    real_client = httpx.AsyncClient
    marker = "SYNTHETIC_PRIVATE_PROBE_TOKEN"
    monkeypatch.setenv("LAZYREMEDY_LIVE_ACCESS_APPROVED", "true")
    for name in ("httpx", "httpcore"):
        monkeypatch.setattr(logging.getLogger(name), "level", logging.NOTSET)
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: real_client(**kwargs, transport=httpx.MockTransport(lambda r: httpx.Response(200, text="<html>fixture</html>"))))
    with caplog.at_level(logging.INFO):
        assert main(["probe", "https://127.0.0.1/login?token=" + marker]) == 2
    assert marker not in caplog.text


def test_cors_wildcard_is_rejected_even_when_configured_explicitly():
    with pytest.raises(ValueError, match="CORS"):
        Settings(cors_origins=["*"])


@pytest.mark.parametrize("field", ["midtier_login_path", "midtier_query_path"])
def test_loopback_html_fixture_cannot_escape_to_foreign_configured_paths(field):
    settings = Settings(live_access_approved=True, midtier_url="https://127.0.0.1", midtier_login_path="/login", midtier_query_path="/query")
    settings = settings.model_copy(update={field: "https://example.invalid/escape"})
    requests = []
    backend = MidtierBackend(settings)
    backend._client = httpx.AsyncClient(base_url=settings.midtier_url, transport=httpx.MockTransport(lambda r: requests.append(r) or httpx.Response(200)))
    async def run():
        try:
            with pytest.raises(BackendNoDisponibleError, match="origen"):
                await backend._ensure_client()
        finally:
            await backend.close()
    asyncio.run(run())
    assert not requests
