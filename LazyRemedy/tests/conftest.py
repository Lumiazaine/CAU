"""Fixtures compartidos de los tests de LazyRemedy."""

from __future__ import annotations

import pytest

from lazyremedy.config import Settings


@pytest.fixture(autouse=True)
def offline_environment(monkeypatch):
    """La suite no hereda configuración live ni resuelve/conecta fuera de loopback."""
    import ipaddress
    import os
    import socket

    for key in tuple(os.environ):
        if key.startswith("LAZYREMEDY_"):
            monkeypatch.delenv(key)
    original_resolve = socket.getaddrinfo
    original_connect = socket.socket.connect
    original_connect_ex = socket.socket.connect_ex

    def allowed(host):
        if host in ("localhost", b"localhost", None):
            return True
        try:
            return ipaddress.ip_address(host.decode() if isinstance(host, bytes) else host).is_loopback
        except ValueError:
            return False

    def resolve(host, *args, **kwargs):
        assert allowed(host), "DNS externo prohibido en tests offline"
        return original_resolve(host, *args, **kwargs)

    def connect(sock, address):
        assert not isinstance(address, tuple) or allowed(address[0]), "Conexión externa prohibida en tests offline"
        return original_connect(sock, address)

    def connect_ex(sock, address):
        assert not isinstance(address, tuple) or allowed(address[0]), "Conexión externa prohibida en tests offline"
        return original_connect_ex(sock, address)

    monkeypatch.setattr(socket, "getaddrinfo", resolve)
    monkeypatch.setattr(socket.socket, "connect", connect)
    monkeypatch.setattr(socket.socket, "connect_ex", connect_ex)


@pytest.fixture
def settings(tmp_path) -> Settings:
    """Configuración en modo mock con directorios temporales aislados."""
    return Settings(
        mock=True,
        cross_process_lock=False,
        output_dir=str(tmp_path),
        runmacro_timeout_sec=5.0,
        output_timeout_sec=2.0,
        output_poll_interval=0.01,
        output_stable_checks=1,
        search_field_map={
            "incidencia_id": "1",
            "usuario_temis": "1010000170",
            "correo": "536871059",
            "telefono": "1010000167",
        },
    )


@pytest.fixture
def service(settings):
    from lazyremedy.service import RemedyService

    return RemedyService(settings)
