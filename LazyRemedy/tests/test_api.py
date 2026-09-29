"""Tests de la API REST con TestClient (modo mock)."""

from __future__ import annotations

from fastapi.testclient import TestClient

from lazyremedy.server_rest import create_app


def _client(settings):
    return TestClient(create_app(settings))


def test_health(settings):
    resp = _client(settings).get("/health")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ok"
    assert body["mock"] is True


def test_listar_macros(settings):
    resp = _client(settings).get("/api/v1/macros")
    assert resp.status_code == 200
    ids = {m["id"] for m in resp.json()}
    assert ids == {"CSU", "HELPDESK", "PENDIENTE_USUARIO", "MICROINFORMATICA"}


def test_search_ok(settings):
    resp = _client(settings).post("/api/v1/search", json={"incidencia_id": "INC001"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["total"] == 2
    assert body["resultados"][0]["ID incidencia"] == "INC001"


def test_search_por_correo(settings):
    resp = _client(settings).post("/api/v1/search", json={"correo": "a@b.es"})
    assert resp.status_code == 200
    assert resp.json()["total"] == 2


def test_search_sin_criterios_devuelve_400(settings):
    resp = _client(settings).post("/api/v1/search", json={})
    assert resp.status_code == 400
    assert resp.json()["error"] == "sin_criterios"


def test_macro_run_ok(settings):
    resp = _client(settings).post("/api/v1/macros/CSU/run")
    assert resp.status_code == 200
    body = resp.json()
    assert body["macro"] == "CSU"
    assert body["total"] == 2


def test_macro_desconocido_devuelve_404(settings):
    resp = _client(settings).post("/api/v1/macros/NO_EXISTE/run")
    assert resp.status_code == 404
    assert resp.json()["error"] == "macro_no_encontrada"


def test_macro_sin_archivo_en_onedrive_devuelve_404(settings, tmp_path):
    """macro_dir vacío => el .arq no existe en OneDrive => 404."""
    settings = settings.model_copy(update={"remedy_macro_dir": str(tmp_path / "vacio")})
    (tmp_path / "vacio").mkdir()
    resp = _client(settings).post("/api/v1/macros/HELPDESK/run")
    assert resp.status_code == 404
    assert "OneDrive" in resp.json()["mensaje"]
