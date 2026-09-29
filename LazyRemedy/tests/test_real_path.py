"""Tests de integración del CAMINO REAL (subproceso) usando un simulador de runmacro.

En la máquina de desarrollo no existe runmacro.exe, así que se usa
``tests/fixtures/fake_runmacro.py`` como ejecutable de sustitución para validar
todo el flujo real: invocación asíncrona, env de salida, estabilización del
archivo, parseo, limpieza, códigos de error y cerrojo de concurrencia.
"""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from lazyremedy.config import Settings
from lazyremedy.engine import RemedyEngine
from lazyremedy.errors import RemedyEjecucionError, RemedyTimeoutError, SalidaTimeoutError
from lazyremedy.models import SearchRequest
from lazyremedy.server_rest import create_app
from lazyremedy.service import RemedyService

FAKE_RUNMACRO = Path(__file__).parent / "fixtures" / "fake_runmacro.py"
ARCHIVOS_ARQ = {
    "x1xxxCSU.arq",
    "x2xxxHEL.arq",
    "x3xxxPEN.arq",
    "x5xxxMIC.arq",
}


@pytest.fixture
def settings_real(tmp_path) -> Settings:
    macro_dir = tmp_path / "macros"
    macro_dir.mkdir()
    for archivo in ARCHIVOS_ARQ:
        (macro_dir / archivo).write_text("demo", encoding="cp1252")
    return Settings(
        mock=False,
        cross_process_lock=False,
        remedy_runmacro=sys.executable,
        runmacro_args=[str(FAKE_RUNMACRO)],
        remedy_macro_dir=str(macro_dir),
        output_dir=str(tmp_path),
        runmacro_timeout_sec=3.0,
        output_timeout_sec=1.5,
        output_poll_interval=0.02,
        output_stable_checks=2,
        search_field_map={
            "incidencia_id": "1",
            "usuario_temis": "1010000170",
            "correo": "536871059",
            "telefono": "1010000167",
        },
    )


def test_macro_camino_real(settings_real):
    service = RemedyService(settings_real)
    resultado = asyncio.run(service.run_macro("HELPDESK"))
    assert resultado.total == 2
    assert resultado.archivo == "x2xxxHEL.arq"
    assert resultado.filas[0]["ID incidencia"] == "INC001"
    assert resultado.filas[0]["Usuario Temis"] == "29567764"


def test_search_camino_real(settings_real):
    service = RemedyService(settings_real)
    resultado = asyncio.run(service.search(SearchRequest(incidencia_id="INC001")))
    assert resultado.total == 2
    assert resultado.criterios == {"incidencia_id": "INC001"}


def test_error_ejecucion_devuelve_502(settings_real, monkeypatch):
    monkeypatch.setenv("LAZYREMEDY_FAKE_FAIL", "1")
    service = RemedyService(settings_real)
    with pytest.raises(RemedyEjecucionError) as excinfo:
        asyncio.run(service.run_macro("CSU"))
    assert excinfo.value.http_status == 502


def test_timeout_salida_devuelve_504(settings_real, monkeypatch):
    monkeypatch.setenv("LAZYREMEDY_FAKE_NO_OUTPUT", "1")
    service = RemedyService(settings_real)
    with pytest.raises(SalidaTimeoutError) as excinfo:
        asyncio.run(service.run_macro("CSU"))
    assert excinfo.value.http_status == 504


def test_timeout_proceso_devuelve_504(settings_real, monkeypatch):
    monkeypatch.setenv("LAZYREMEDY_FAKE_DELAY", "5")
    settings_real = settings_real.model_copy(update={"runmacro_timeout_sec": 0.3})
    service = RemedyService(settings_real)
    with pytest.raises(RemedyTimeoutError) as excinfo:
        asyncio.run(service.run_macro("CSU"))
    assert excinfo.value.http_status == 504


def test_concurrencia_camino_real(settings_real, monkeypatch):
    monkeypatch.setenv("LAZYREMEDY_FAKE_DELAY", "0.3")
    engine = RemedyEngine(settings_real)

    async def _una(nombre):
        macro = settings_real.output_path / nombre
        macro.write_text("demo", encoding="cp1252")
        salida = settings_real.output_path / f"salida_{nombre}.txt"
        return len(await engine.execute_macro(macro, salida))

    async def _main():
        return await asyncio.gather(_una("a.arq"), _una("b.arq"), _una("c.arq"))

    totales = asyncio.run(_main())
    assert totales == [2, 2, 2]
    assert engine._proc_count == 0


def test_rest_camino_real(settings_real):
    with TestClient(create_app(settings_real)) as client:
        resp = client.post("/api/v1/macros/HELPDESK/run")
        assert resp.status_code == 200
        assert resp.json()["total"] == 2

        resp = client.post("/api/v1/search", json={"telefono": "955040955"})
        assert resp.status_code == 200
        assert resp.json()["total"] == 2
