"""Cerrojo cross-proceso para runmacro.exe.

runmacro.exe NO soporta peticiones concurrentes. Además del ``asyncio.Lock``
interno (que protege dentro de un mismo proceso), este módulo ofrece un cerrojo
a nivel de sistema operativo para cuando REST y MCP corren en procesos
separados:

- Windows: mutex con nombre (CreateMutexW/WaitForSingleObject).
- POSIX: ``fcntl.flock`` sobre un archivo de bloqueo.

El acquire se ejecuta en un hilo (``asyncio.to_thread``) para no bloquear el
event loop mientras se espera.
"""

from __future__ import annotations

import asyncio
import os
import platform
import sys
from pathlib import Path

from .errors import CerrojoExpiradoError

_WINDOWS = platform.system() == "Windows"

#: Constantes Win32 (WAIT_OBJECT_0, WAIT_TIMEOUT, WAIT_ABANDONED).
_WAIT_OBJECT_0 = 0x00000000
_WAIT_TIMEOUT = 0x00000102
_WAIT_ABANDONED = 0x00000080
_INFINITE = 0xFFFFFFFF


def _win_mutex(handle: object, wait_ms: int) -> None:
    import ctypes
    from ctypes import wintypes

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    wait_for = kernel32.WaitForSingleObject
    wait_for.restype = wintypes.DWORD
    wait_for.argtypes = [wintypes.HANDLE, wintypes.DWORD]

    result = wait_for(ctypes.c_void_p(handle), wintypes.DWORD(wait_ms))
    if result in (_WAIT_OBJECT_0, _WAIT_ABANDONED):
        return
    if result == _WAIT_TIMEOUT:
        raise CerrojoExpiradoError(
            "Tiempo de espera agotado para adquirir el cerrojo runmacro.",
            detail="Otra petición está ejecutando runmacro.exe.",
        )
    raise CerrojoExpiradoError(f"Error al adquirir el mutex (código {result}).")


class CrossProcessLock:
    """Cerrojo a nivel de sistema operativo (mutex con nombre / flock)."""

    def __init__(self, name: str, lock_file: Path | None = None) -> None:
        self._name = name
        self._handle: object | None = None
        self._lock_file: Path | None = lock_file
        self._fd: int | None = None

    def acquire(self, timeout_sec: float = 0.0) -> None:
        """Adquiere el cerrojo bloqueando hasta timeout_sec (0 = infinito)."""
        wait_ms = int(_INFINITE if timeout_sec <= 0 else timeout_sec * 1000)
        if _WINDOWS:
            import ctypes

            kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
            create_mutex = kernel32.CreateMutexW
            create_mutex.restype = ctypes.c_void_p
            create_mutex.argtypes = [
                ctypes.c_void_p,
                ctypes.c_int32,
                ctypes.c_wchar_p,
            ]
            # Namespace Local\ (misma sesión de escritorio): el prefijo Global\
            # exige SeCreateGlobalPrivilege (no disponible para usuarios normales).
            handle = create_mutex(None, False, f"Local\\{self._name}")
            if not handle:
                raise CerrojoExpiradoError("No se pudo crear el mutex runmacro.")
            self._handle = handle
            _win_mutex(handle, wait_ms)
        else:
            import fcntl

            path = self._lock_file or Path(os.path.join(sys.prefix, "lazyremedy.lock"))
            path.parent.mkdir(parents=True, exist_ok=True)
            self._fd = os.open(str(path), os.O_CREAT | os.O_RDWR)
            fcntl.flock(self._fd, fcntl.LOCK_EX)

    def release(self) -> None:
        if _WINDOWS and self._handle:
            import ctypes

            kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
            kernel32.ReleaseMutex(ctypes.c_void_p(self._handle))
            kernel32.CloseHandle(ctypes.c_void_p(self._handle))
            self._handle = None
        if self._fd is not None:
            import fcntl

            fcntl.flock(self._fd, fcntl.LOCK_UN)
            os.close(self._fd)
            self._fd = None

    async def acquire_async(self, timeout_sec: float = 0.0) -> None:
        await asyncio.to_thread(self.acquire, timeout_sec)

    async def __aenter__(self) -> "CrossProcessLock":
        await self.acquire_async()
        return self

    async def __aexit__(self, *exc) -> None:
        await asyncio.to_thread(self.release)
