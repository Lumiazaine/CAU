"""Tests del cerrojo cross-proceso (mutex con nombre en Windows / flock en POSIX)."""

from __future__ import annotations

import asyncio
import threading
import time

import pytest

from lazyremedy.errors import CerrojoExpiradoError
from lazyremedy.lock import CrossProcessLock


def test_acquire_release_repetido():
    cerrojo = CrossProcessLock("LazyRemedyTestMutex")
    cerrojo.acquire()
    cerrojo.release()
    cerrojo.acquire()
    cerrojo.release()


def test_ocupado_en_otro_hilo_expira():
    """El dueño del mutex es otro hilo: la espera debe agotar el timeout."""
    a = CrossProcessLock("LazyRemedyTestOcupado")
    b = CrossProcessLock("LazyRemedyTestOcupado")

    bloqueado = threading.Event()
    soltar = threading.Event()
    errores: list[BaseException] = []

    def _ocupar():
        try:
            a.acquire()
            bloqueado.set()
            soltar.wait(5)
            a.release()
        except BaseException as exc:  # noqa: BLE001
            errores.append(exc)

    t = threading.Thread(target=_ocupar)
    t.start()
    assert bloqueado.wait(5), "el hilo no adquirió el cerrojo"
    try:
        with pytest.raises(CerrojoExpiradoError):
            b.acquire(timeout_sec=0.3)
    finally:
        soltar.set()
        t.join(5)
        assert not errores


def test_liberado_permite_nuevo_acquire():
    a = CrossProcessLock("LazyRemedyTestLibre")
    a.acquire()
    a.release()
    b = CrossProcessLock("LazyRemedyTestLibre")
    b.acquire(timeout_sec=1)
    b.release()


def test_contexto_async(tmp_path):
    cerrojo = CrossProcessLock("LazyRemedyTestAsync", lock_file=tmp_path / "mutex.lock")

    async def _main():
        async with cerrojo:
            return "dentro"

    assert asyncio.run(_main()) == "dentro"
