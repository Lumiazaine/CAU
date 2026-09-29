"""Motor de ejecución de runmacro.exe (BMC Remedy User).

Regla crítica de concurrencia: runmacro.exe no soporta peticiones
simultáneas. Este motor serializa todo el acceso con:

1. ``asyncio.Lock`` (protege el subproceso dentro del proceso actual).
2. ``CrossProcessLock`` opcional (mutex con nombre) cuando REST y MCP corren
   en procesos separados.

Flujo real:
- preflight (ejecutable y macro en OneDrive),
- subproceso asíncrono con ``asyncio.create_subprocess_exec`` y
  ``CREATE_NO_WINDOW`` (zero-touch),
- espera del archivo de salida en disco con estabilización,
- parseo y limpieza del temporal.

En modo ``mock`` (solo desarrollo) se simula la salida sin invocar a Remedy.
"""

from __future__ import annotations

import asyncio
import logging
import os
from pathlib import Path
from typing import Any

from .config import Settings
from .errors import (
    BackendNoDisponibleError,
    RemedyEjecucionError,
    RemedyTimeoutError,
    RunmacroNoEncontradoError,
    SalidaParseError,
    SalidaTimeoutError,
)
from .lock import CrossProcessLock
from .parser import cleanup_output, parse_output

logger = logging.getLogger("lazyremedy.engine")

#: Sin ventana de consola (zero-touch, sin parpadeos ni GUI).
CREATE_NO_WINDOW = 0x08000000

#: Encabezados de la salida simulada en modo mock.
_MOCK_HEADERS = ("ID incidencia", "Usuario Temis", "Correo", "Teléfono", "Estado")
_MOCK_ROWS = (
    ("INC001", "12345678Z", "funcionario@juntadeandalucia.es", "955000001", "Abierta"),
    ("INC002", "87654321X", "otro.funcionario@juntadeandalucia.es", "955000002", "Pendiente"),
)


class RemedyEngine:
    """Orquesta la invocación serializada de runmacro.exe."""

    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        # Cerrojo en proceso: serializa subprocesos dentro de este proceso.
        self._lock = asyncio.Lock()
        # Cerrojo cross-proceso: protege contra otro proceso (REST/MCP aparte).
        self._os_lock: CrossProcessLock | None = None
        if settings.cross_process_lock:
            lock_file = settings.output_path / ".lazyremedy_mutex.lock"
            self._os_lock = CrossProcessLock("LazyRemedyRunmacro", lock_file)
        self._proc_count = 0

    # ------------------------------------------------------------------
    # Preflight
    # ------------------------------------------------------------------
    def preflight(self) -> dict[str, Any]:
        """Comprueba la infraestructura (ejecutable, OneDrive). Para /health."""
        exe = self.settings.runmacro_path
        macro_dir = self.settings.macro_dir
        exe_ok = exe.exists()
        macro_dir_ok = macro_dir.is_dir()
        return {
            "runmacro_exe": str(exe),
            "runmacro_existe": exe_ok,
            "macro_dir": str(macro_dir),
            "macro_dir_existe": macro_dir_ok,
            "mock": self.settings.mock,
        }

    # ------------------------------------------------------------------
    # API pública
    # ------------------------------------------------------------------
    async def execute_macro(self, macro_path: Path, output_path: Path) -> list[dict[str, Any]]:
        """Ejecuta un macro y devuelve las filas parseadas. Siempre serializado."""
        async with self._lock:
            if self._os_lock is not None:
                await self._os_lock.acquire_async(self.settings.lock_timeout_sec)
                try:
                    return await self._dispatch(macro_path, output_path)
                finally:
                    self._os_lock.release()
            return await self._dispatch(macro_path, output_path)

    # ------------------------------------------------------------------
    # Interno
    # ------------------------------------------------------------------
    async def _dispatch(self, macro_path: Path, output_path: Path) -> list[dict[str, Any]]:
        if self.settings.mock:
            return await self._run_mock(macro_path, output_path)
        return await self._run_real(macro_path, output_path)

    async def _run_real(self, macro_path: Path, output_path: Path) -> list[dict[str, Any]]:
        self._preflight_remedy(macro_path)
        # Limpiar un archivo de salida residual ANTES de lanzar el subproceso:
        # si se borrase al esperar, podría perderse una salida escrita muy rápido.
        try:
            output_path.unlink(missing_ok=True)
        except OSError:
            pass

        cmd = self._build_command(macro_path)
        logger.info("Ejecutando runmacro: %s", " ".join(str(c) for c in cmd))

        try:
            proc = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                stdin=asyncio.subprocess.DEVNULL,
                creationflags=CREATE_NO_WINDOW,
                env=self._build_env(macro_path, output_path),
            )
        except OSError as exc:
            raise BackendNoDisponibleError(
                f"No se pudo lanzar runmacro.exe: {exc}",
                detail=str(self.settings.runmacro_path),
            ) from exc

        self._proc_count += 1
        try:
            await self._wait_process(proc)
        finally:
            self._proc_count -= 1

        stderr_text = ""
        if proc.returncode != 0:
            try:
                stderr_bytes = await proc.stderr.read() if proc.stderr else b""
                stderr_text = stderr_bytes.decode(self.settings.output_encoding, errors="replace")
            except Exception:  # noqa: BLE001 - diagnóstico best-effort
                stderr_text = "(stderr no disponible)"
            raise RemedyEjecucionError(
                f"runmacro.exe terminó con código {proc.returncode}.",
                detail=stderr_text.strip()[:500] or "Sin salida de error.",
            )

        await self._wait_output_file(output_path)
        return self._consume_output(output_path)

    def _preflight_remedy(self, macro_path: Path) -> None:
        exe = self.settings.runmacro_path
        if not exe.exists():
            raise RunmacroNoEncontradoError(
                "No se encuentra runmacro.exe en la ruta configurada.",
                detail=str(exe),
            )
        try:
            if not macro_path.exists():
                raise BackendNoDisponibleError(
                    f"No se accede al macro '{macro_path.name}' en OneDrive.",
                    detail=str(macro_path),
                )
        except OSError as exc:
            raise BackendNoDisponibleError(
                "Problema de acceso a OneDrive (ARCmds) al comprobar el macro.",
                detail=f"{macro_path} -> {exc}",
            ) from exc

    def _build_command(self, macro_path: Path) -> list[str]:
        return (
            [str(self.settings.runmacro_path)]
            + list(self.settings.runmacro_args)
            + [str(macro_path)]
        )

    def _build_env(self, macro_path: Path, output_path: Path) -> dict[str, str]:
        """Env del subproceso: el macro/runmacro puede necesitar saber dónde escribir."""
        env = dict(os.environ)
        env["LAZYREMEDY_OUTPUT_FILE"] = str(output_path)
        env["LAZYREMEDY_MACRO_PATH"] = str(macro_path)
        return env

    async def _wait_process(self, proc: asyncio.subprocess.Process) -> None:
        try:
            await asyncio.wait_for(proc.wait(), timeout=self.settings.runmacro_timeout_sec)
        except asyncio.TimeoutError as exc:
            try:
                proc.kill()
                await asyncio.wait_for(proc.wait(), timeout=5)
            except Exception:  # noqa: BLE001 - el proceso ya es un zombie
                pass
            raise RemedyTimeoutError(
                f"runmacro.exe excedió el tiempo máximo de "
                f"{self.settings.runmacro_timeout_sec:g} s.",
            ) from exc

    async def _wait_output_file(self, output_path: Path) -> None:
        """Espera a que el archivo de salida aparezca y se estabilice."""
        loop = asyncio.get_running_loop()
        deadline = loop.time() + self.settings.output_timeout_sec
        last_size = -1
        stable = 0
        while loop.time() < deadline:
            if output_path.exists():
                size = output_path.stat().st_size
                if size == last_size and size > 0:
                    stable += 1
                    if stable >= self.settings.output_stable_checks:
                        return
                else:
                    last_size, stable = size, 0
            await asyncio.sleep(self.settings.output_poll_interval)

        raise SalidaTimeoutError(
            f"No apareció el archivo de salida en {self.settings.output_timeout_sec:g} s.",
            detail=str(output_path),
        )

    def _consume_output(self, output_path: Path) -> list[dict[str, Any]]:
        """Lee, parsea y elimina el archivo temporal."""
        try:
            filas = parse_output(
                output_path,
                encoding=self.settings.output_encoding,
                fallback_encoding=self.settings.output_fallback_encoding,
            )
        except SalidaParseError:
            cleanup_output(output_path)
            raise
        except OSError as exc:
            cleanup_output(output_path)
            raise SalidaParseError(
                f"No se pudo leer la salida generada: {exc}",
                detail=str(output_path),
            ) from exc
        finally:
            cleanup_output(output_path)
        return filas

    # ------------------------------------------------------------------
    # Modo simulación (solo desarrollo)
    # ------------------------------------------------------------------
    async def _run_mock(self, macro_path: Path, output_path: Path) -> list[dict[str, Any]]:
        await asyncio.sleep(0.1)
        logger.warning("MODO MOCK: no se invoca runmacro.exe (%s)", macro_path.name)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            output_path.unlink(missing_ok=True)
        except OSError:
            pass
        lines = [",".join(_MOCK_HEADERS)]
        for fila in _MOCK_ROWS:
            lines.append(",".join(fila))
        output_path.write_text("\r\n".join(lines) + "\r\n", encoding=self.settings.output_encoding)
        return self._consume_output(output_path)
