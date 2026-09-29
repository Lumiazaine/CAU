"""Tests del backend Mid Tier (HTTP) contra un servidor web simulado.

Valida el flujo completo sin tocar el Mid Tier real: descubrimiento del
formulario de login, envío de credenciales, cookie de sesión, cualificación
de búsqueda y parseo de la tabla HTML de resultados.
"""

from __future__ import annotations

import asyncio
import json
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

import pytest
from fastapi.testclient import TestClient

from lazyremedy.backends.midtier import MidtierBackend
from lazyremedy.config import Settings
from lazyremedy.errors import BackendNoDisponibleError, MacroNoEncontradoError
from lazyremedy.server_rest import create_app

LOGIN_HTML = """
<html><body>
<form method="post" action="/login">
  <input type="text" name="j_username">
  <input type="password" name="j_password">
  <input type="submit">
</form>
</body></html>
"""

RESULT_HTML = """
<table>
<tr><th>ID incidencia</th><th>Usuario Temis</th><th>Estado</th></tr>
<tr><td>INC001</td><td>29567764</td><td>Abierta</td></tr>
<tr><td>INC002</td><td>48861904</td><td>Pendiente</td></tr>
</table>
"""

EMPTY_HTML = "<html><body>sin resultados</body></html>"


class _Estado:
    login_body: str | None = None
    cookie: str | None = None
    ultima_cualificacion: str | None = None
    llamadas_login: int = 0


ESTADO = _Estado()


class FakeMidtierHandler(BaseHTTPRequestHandler):
    def log_message(self, *args):  # silencio
        pass

    def _send(self, codigo: int, cuerpo: str) -> None:
        data = cuerpo.encode("utf-8")
        self.send_response(codigo)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:  # noqa: N802
        if self.path.startswith("/arsys/login"):
            self._send(200, LOGIN_HTML)
            return
        if self.path.startswith("/arsys/forms/101_INCIDENCIAS/query"):
            ESTADO.cookie = self.headers.get("Cookie")
            params = parse_qs(urlparse(self.path).query)
            ESTADO.ultima_cualificacion = params.get("q", [""])[0]
            if ESTADO.ultima_cualificacion:
                self._send(200, RESULT_HTML)
            else:
                self._send(200, EMPTY_HTML)
            return
        self._send(404, "not found")

    def do_POST(self) -> None:  # noqa: N802
        if self.path.startswith("/login"):
            length = int(self.headers.get("Content-Length", "0"))
            ESTADO.login_body = self.rfile.read(length).decode("utf-8")
            ESTADO.llamadas_login += 1
            self._send(200, "<html>ok</html>")
            return
        self._send(404, "not found")


@pytest.fixture
def midtier_settings(tmp_path):
    server = HTTPServer(("127.0.0.1", 0), FakeMidtierHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    yield Settings(
        backend="midtier",
        mock=False,
        cross_process_lock=False,
        midtier_url=f"http://127.0.0.1:{server.server_port}",
        midtier_timeout_sec=5.0,
        remedy_user="TESTUSER",
        remedy_password="TESTPASS",
        search_field_map={
            "incidencia_id": "1",
            "usuario_temis": "1010000170",
            "correo": "536871059",
            "telefono": "1010000167",
        },
    )
    server.shutdown()
    server.server_close()


async def _search(settings, **criterios):
    backend = MidtierBackend(settings)
    try:
        return await backend.search(criterios)
    finally:
        await backend.close()


def test_login_envia_credenciales(midtier_settings):
    filas = asyncio.run(_search(midtier_settings, incidencia_id="INC001"))
    assert ESTADO.login_body is not None
    assert "TESTUSER" in ESTADO.login_body
    assert "TESTPASS" in ESTADO.login_body
    assert ESTADO.llamadas_login == 1  # login único, sesión reutilizada
    assert len(filas) == 2


def test_cualificacion_usa_campos_reales(midtier_settings):
    asyncio.run(_search(midtier_settings, usuario_temis="29567764", telefono="955040955"))
    assert "'1010000170' = \"29567764\"" in ESTADO.ultima_cualificacion
    assert "'1010000167' = \"955040955\"" in ESTADO.ultima_cualificacion
    assert " AND " in ESTADO.ultima_cualificacion


def test_filas_parseadas(midtier_settings):
    filas = asyncio.run(_search(midtier_settings, incidencia_id="INC001"))
    assert filas[0]["ID incidencia"] == "INC001"
    assert filas[0]["Usuario Temis"] == "29567764"
    assert filas[0]["Estado"] == "Abierta"


def test_sin_criterios_error(midtier_settings):
    with pytest.raises(Exception):
        asyncio.run(_search(midtier_settings))


def test_macro_helpesk_usa_cualificacion_real(midtier_settings):
    backend = MidtierBackend(midtier_settings)
    asyncio.run(backend._ensure_login())
    asyncio.run(backend.run_macro("HELPDESK"))
    assert "'1010000147' = \"Nivel 1\"" in ESTADO.ultima_cualificacion
    assert "'7' != \"Cerrada\"" in ESTADO.ultima_cualificacion


def test_macro_no_calibrado_error(midtier_settings):
    backend = MidtierBackend(midtier_settings)
    with pytest.raises(MacroNoEncontradoError):
        asyncio.run(backend.run_macro("CSU"))


def test_macro_desconocido_error(midtier_settings):
    backend = MidtierBackend(midtier_settings)
    with pytest.raises(MacroNoEncontradoError):
        asyncio.run(backend.run_macro("NOEXISTE"))


def test_rest_search_via_midtier(midtier_settings):
    with TestClient(create_app(midtier_settings)) as client:
        resp = client.post("/api/v1/search", json={"incidencia_id": "INC001"})
        assert resp.status_code == 200
        assert resp.json()["total"] == 2

        health = client.get("/health").json()
        assert health["backend"] == "midtier"
        assert health["midtier_url"].startswith("http://127.0.0.1")


def test_backend_no_disponible_si_servidor_cae():
    settings = Settings(
        backend="midtier",
        mock=False,
        midtier_url="http://127.0.0.1:1",  # puerto cerrado
        midtier_timeout_sec=1.0,
        remedy_user="TESTUSER",
        remedy_password="TESTPASS",
    )
    backend = MidtierBackend(settings)
    with pytest.raises(BackendNoDisponibleError):
        asyncio.run(backend.search({"incidencia_id": "INC001"}))
