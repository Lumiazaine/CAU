"""Regresiones offline: nunca invocar el backend real cuando se pide mock."""
import asyncio
import json

import pytest

from lazyremedy.config import Settings
from lazyremedy.models import SearchRequest
from lazyremedy.service import RemedyService


def test_mock_overrides_midtier_without_network(tmp_path):
    settings = Settings(backend="midtier", mock=True, output_dir=str(tmp_path), cross_process_lock=False)
    service = RemedyService(settings)
    result = asyncio.run(service.search(SearchRequest(incidencia_id="SYNTHETIC-001")))
    assert result.total == 2
    assert service.backend.name == "macro"


@pytest.mark.parametrize("backend", ["midtier", "macro"])
def test_unapproved_live_access_is_blocked_before_io(tmp_path, backend):
    from lazyremedy.errors import BackendNoDisponibleError
    from lazyremedy.backends.midtier import MidtierBackend
    from lazyremedy.engine import RemedyEngine

    settings = Settings(backend=backend, midtier_url="https://127.0.0.1", output_dir=str(tmp_path), cross_process_lock=False)
    if backend == "midtier":
        operation = MidtierBackend(settings)._ensure_client()
    else:
        operation = RemedyEngine(settings)._run_real(tmp_path / "not.arq", tmp_path / "not.txt")
    with pytest.raises(BackendNoDisponibleError, match="aprob"):
        asyncio.run(operation)


@pytest.mark.parametrize("value", ['x" OR 1=1', "x\x017=0", "x\nModify: 7=0", "x\\y"])
def test_query_inputs_cannot_inject_syntax(settings, value):
    from lazyremedy.query_builder import build_search_macro
    from lazyremedy.errors import CriterioInvalidoError
    with pytest.raises(CriterioInvalidoError):
        build_search_macro(settings, {"incidencia_id": value})


@pytest.mark.parametrize("field_id", ['1\x017=0', "1' OR '7", " 1", "-1"])
def test_field_tokens_cannot_inject_syntax(settings, field_id):
    from lazyremedy.query_builder import map_criterios_a_campos
    from lazyremedy.errors import CriterioInvalidoError
    settings = settings.model_copy(update={"search_field_map": {"incidencia_id": field_id}})
    with pytest.raises(CriterioInvalidoError):
        map_criterios_a_campos(settings, {"incidencia_id": "SYNTHETIC"})


def test_tls_is_verified_by_default():
    assert Settings().midtier_verify_ssl is True


def test_diagnostics_do_not_expose_subprocess_secrets(tmp_path, caplog):
    import logging
    import sys
    from lazyremedy.engine import RemedyEngine
    from lazyremedy.errors import RemedyEjecucionError

    marker = "SYNTHETIC_PRIVATE_MARKER"
    config = Settings(live_access_approved=True, remedy_runmacro=sys.executable,
                      runmacro_args=["-c", f"import sys; sys.stderr.write('{marker}'); sys.exit(1)"],
                      output_dir=str(tmp_path), cross_process_lock=False)
    macro = tmp_path / "synthetic.arq"
    macro.write_text("demo")
    with caplog.at_level(logging.INFO), pytest.raises(RemedyEjecucionError) as caught:
        asyncio.run(RemedyEngine(config).execute_macro(macro, tmp_path / "out.txt"))
    assert marker not in caplog.text
    assert marker not in json.dumps(caught.value.as_http())
    assert marker not in json.dumps(config.to_dict())


def test_midtier_requires_explicit_approved_paths():
    import httpx
    from lazyremedy.backends.midtier import MidtierBackend
    from lazyremedy.errors import BackendNoDisponibleError
    requests = []
    settings = Settings(live_access_approved=True, midtier_url="https://127.0.0.1")
    backend = MidtierBackend(settings)
    backend._client = httpx.AsyncClient(base_url="https://127.0.0.1", transport=httpx.MockTransport(lambda r: requests.append(r) or httpx.Response(200)))
    async def run():
        try:
            with pytest.raises(BackendNoDisponibleError, match="rutas"):
                await backend.search({"incidencia_id": "SYNTHETIC"})
        finally:
            await backend.close()
    asyncio.run(run())
    assert not requests


@pytest.mark.parametrize("action", ["https://other.invalid/login", "//other.invalid/login", "http://example.invalid/login"])
def test_login_never_posts_credentials_to_foreign_origin(action):
    import httpx
    from lazyremedy.backends.midtier import MidtierBackend
    from lazyremedy.errors import BackendNoDisponibleError
    requests = []
    def respond(request):
        requests.append(request)
        return httpx.Response(200, text=f'<form method="post" action="{action}"><input name="j_password" type="password"></form>')
    settings = Settings(live_access_approved=True, midtier_url="https://127.0.0.1", midtier_login_path="/login", midtier_query_path="/query")
    backend = MidtierBackend(settings)
    backend._client = httpx.AsyncClient(base_url=settings.midtier_url, transport=httpx.MockTransport(respond))
    async def run():
        try:
            with pytest.raises(BackendNoDisponibleError):
                await backend._ensure_login()
        finally:
            await backend.close()
    asyncio.run(run())
    assert [r.method for r in requests] == ["GET"]
    assert backend._login is None


def test_probe_is_blocked_without_approval(monkeypatch):
    import httpx
    from lazyremedy.cli import main
    attempts = []
    def forbidden(*args, **kwargs):
        attempts.append(True)
        raise AssertionError("El probe no debe abrir un cliente HTTP sin aprobación")
    monkeypatch.setattr(httpx, "AsyncClient", forbidden)
    assert main(["probe", "https://127.0.0.1/exact"]) == 1
    assert not attempts


def test_settings_do_not_implicitly_read_dotenv(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    (tmp_path / ".env").write_text("LAZYREMEDY_REMEDY_PASSWORD=SYNTHETIC_SECRET\n")
    assert Settings().remedy_password == ""


def test_noisy_subprocess_does_not_deadlock(tmp_path):
    import sys
    from lazyremedy.engine import RemedyEngine
    config = Settings(live_access_approved=True, remedy_runmacro=sys.executable,
        runmacro_args=["-c", "import os,sys,pathlib; sys.stdout.write('x'*1000000); sys.stderr.write('y'*1000000); pathlib.Path(os.environ['LAZYREMEDY_OUTPUT_FILE']).write_text('ID,Estado\\nSYNTHETIC,Abierta\\n')"],
        output_dir=str(tmp_path), cross_process_lock=False, runmacro_timeout_sec=1,
        output_poll_interval=0.01)
    macro = tmp_path / "synthetic.arq"
    macro.write_text("demo")
    assert asyncio.run(RemedyEngine(config).execute_macro(macro, tmp_path / "out.txt")) == [{"ID": "SYNTHETIC", "Estado": "Abierta"}]


def test_async_mutex_keeps_thread_affinity(monkeypatch, tmp_path):
    import threading
    from lazyremedy.lock import CrossProcessLock
    owners = []
    lock = CrossProcessLock("synthetic", tmp_path / "lock")
    monkeypatch.setattr(lock, "acquire", lambda timeout_sec=0: owners.append(threading.get_ident()))
    monkeypatch.setattr(lock, "release", lambda: owners.append(threading.get_ident()))
    async def run():
        async with lock:
            owners.append(threading.get_ident())
    asyncio.run(run())
    assert len(owners) == 3
    assert len(set(owners)) == 1


@pytest.mark.parametrize("body", ["<html>ARERR synthetic</html>", '<form action="/login"><input type="password" name="password"></form>'])
def test_midtier_does_not_misreport_invalid_html_as_zero_results(body):
    import httpx
    from lazyremedy.backends.midtier import MidtierBackend
    from lazyremedy.errors import BackendNoDisponibleError
    settings = Settings(live_access_approved=True, midtier_url="https://127.0.0.1", midtier_query_path="/approved/{schema}")
    backend = MidtierBackend(settings)
    backend._client = httpx.AsyncClient(base_url=settings.midtier_url, transport=httpx.MockTransport(lambda r: httpx.Response(200, text=body)))
    async def run():
        try:
            with pytest.raises(BackendNoDisponibleError):
                await backend._query('synthetic qualification')
        finally:
            await backend.close()
    asyncio.run(run())


def test_cancelling_wait_reaps_only_the_launched_child(tmp_path):
    import sys
    from lazyremedy.engine import RemedyEngine
    async def run():
        proc = await asyncio.create_subprocess_exec(sys.executable, "-c", "import time; time.sleep(30)")
        try:
            task = asyncio.create_task(RemedyEngine(Settings())._wait_process(proc))
            await asyncio.sleep(0.03)
            task.cancel()
            with pytest.raises(asyncio.CancelledError):
                await task
            assert proc.returncode is not None
        finally:
            if proc.returncode is None:
                proc.kill()
                await proc.wait()
    asyncio.run(run())


@pytest.mark.parametrize("command", ["rest", "both"])
def test_unauthenticated_wrapper_cannot_bind_external_interfaces(monkeypatch, command):
    import uvicorn
    from lazyremedy.cli import main
    attempts = []
    def forbidden(*args, **kwargs):
        attempts.append(True)
        return None
    monkeypatch.setattr(uvicorn, "run", forbidden)
    assert main([command, "--host", "0.0.0.0", "--mock"]) == 1
    assert not attempts


def test_mcp_http_cannot_bind_external_interfaces(monkeypatch):
    from fastmcp import FastMCP
    from lazyremedy.cli import main
    attempts = []
    monkeypatch.setattr(FastMCP, "run", lambda *a, **k: attempts.append(True))
    assert main(["mcp", "--transport", "http", "--host", "0.0.0.0", "--mock"]) == 1
    assert not attempts


def test_midtier_http_errors_never_expose_qualification():
    import httpx
    from lazyremedy.backends.midtier import MidtierBackend
    from lazyremedy.errors import BackendNoDisponibleError
    marker = "SYNTHETIC_PRIVATE_QUALIFICATION"
    settings = Settings(live_access_approved=True, midtier_url="https://127.0.0.1", midtier_query_path="/query")
    backend = MidtierBackend(settings)
    backend._client = httpx.AsyncClient(base_url=settings.midtier_url, transport=httpx.MockTransport(lambda r: httpx.Response(500)))
    async def run():
        try:
            with pytest.raises(BackendNoDisponibleError) as caught:
                await backend._query(marker)
            assert marker not in json.dumps(caught.value.as_http())
        finally:
            await backend.close()
    asyncio.run(run())


def test_midtier_login_error_never_exposes_url_tokens():
    import httpx
    from lazyremedy.backends.midtier import MidtierBackend
    from lazyremedy.errors import BackendNoDisponibleError
    marker = "SYNTHETIC_PRIVATE_LOGIN_TOKEN"
    settings = Settings(live_access_approved=True, midtier_url="https://127.0.0.1", midtier_login_path="/login?token=" + marker, midtier_query_path="/query")
    backend = MidtierBackend(settings)
    backend._client = httpx.AsyncClient(base_url=settings.midtier_url, transport=httpx.MockTransport(lambda r: httpx.Response(500)))
    async def run():
        try:
            with pytest.raises(BackendNoDisponibleError) as caught:
                await backend._ensure_login()
            assert marker not in json.dumps(caught.value.as_http())
        finally:
            await backend.close()
    asyncio.run(run())


def test_logging_setup_suppresses_http_transport_urls(caplog, monkeypatch):
    import httpx
    import logging
    from lazyremedy.backends.midtier import MidtierBackend
    from lazyremedy.errors import BackendNoDisponibleError
    from lazyremedy.logging_setup import setup_logging
    marker = "SYNTHETIC_PRIVATE_LOG_VALUE"
    for name in ("httpx", "httpcore"):
        transport_logger = logging.getLogger(name)
        monkeypatch.setattr(transport_logger, "level", logging.NOTSET)
    backend = MidtierBackend(Settings(live_access_approved=True, midtier_url="https://127.0.0.1", midtier_query_path="/query"))
    backend._client = httpx.AsyncClient(base_url="https://127.0.0.1", transport=httpx.MockTransport(lambda r: httpx.Response(500)))
    async def run():
        try:
            with pytest.raises(BackendNoDisponibleError):
                await backend._query(marker)
        finally:
            await backend.close()
    with caplog.at_level(logging.INFO):
        setup_logging("DEBUG")
        asyncio.run(run())
    assert marker not in caplog.text


def test_cors_not_open_to_arbitrary_websites_by_default():
    assert Settings().cors_origins == []
