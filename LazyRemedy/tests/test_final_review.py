"""Regresiones finales offline; nunca abrir una conexión corporativa."""
import pytest


@pytest.mark.parametrize("url", [
    "https://example.invalid/login",
    "http://192.0.2.1/login",
    "https://localhost/login",
    "https://fixture:synthetic@127.0.0.1/login",
    "file:///offline/fixture",
    "https://127.0.0.1:bad/login",
])
def test_probe_refuses_non_literal_loopback_or_invalid_origins_before_io(monkeypatch, url):
    import httpx
    from lazyremedy.cli import main

    attempts = []
    monkeypatch.setenv("LAZYREMEDY_LIVE_ACCESS_APPROVED", "true")

    def forbidden_client(**kwargs):
        attempts.append(True)
        raise AssertionError("No HTTP client may be opened for this origin")

    monkeypatch.setattr(httpx, "AsyncClient", forbidden_client)
    assert main(["probe", url]) == 1
    assert attempts == []


def test_macro_search_logs_never_include_criterion_values(settings, monkeypatch, caplog):
    import asyncio
    import logging
    from lazyremedy.backends.macro import MacroBackend

    backend = MacroBackend(settings)

    async def no_process(*args):
        return []

    monkeypatch.setattr(backend.engine, "execute_macro", no_process)
    marker = "SYNTHETIC_PRIVATE_CRITERION"
    with caplog.at_level(logging.INFO):
        assert asyncio.run(backend.search({"usuario_temis": marker})) == []
    assert marker not in caplog.text
    assert "usuario_temis" in caplog.text
