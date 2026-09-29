"""Backend de ejecución de macros (.arq) — heredado del motor runmacro.exe.

Convierte la lógica de orquestación del servicio (construir macro, escribir
archivo, ejecutar, limpiar temporales) en un backend con el contrato común.
Con ``settings.mock=True`` no se invoca ningún binario (datos simulados).
"""

from __future__ import annotations

import logging
import uuid
from pathlib import Path
from typing import Any

from ..config import Settings
from ..engine import RemedyEngine
from ..errors import MacroNoEncontradoError
from ..macros import resolve_macro
from ..query_builder import build_search_macro, criterios_descripcion, write_macro_file
from .base import RemedyBackend

logger = logging.getLogger("lazyremedy.backends.macro")


class MacroBackend(RemedyBackend):
    """Ejecuta macros .arq con el binario runmacro (o simulados en mock)."""

    name = "macro"

    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.engine = RemedyEngine(settings)

    async def search(self, criterios: dict[str, str]) -> list[dict[str, str]]:
        macro_text, criterios_limpios = build_search_macro(self.settings, criterios)
        macro_path = self._temp_path("busqueda", "arq")
        output_path = self._temp_path("salida", "txt")
        try:
            write_macro_file(self.settings, macro_text, macro_path)
            logger.info(
                "Búsqueda dinámica por: %s",
                criterios_descripcion(criterios_limpios.items()),
            )
            return await self.engine.execute_macro(macro_path, output_path)
        finally:
            self._cleanup_temp(macro_path, output_path)

    async def run_macro(self, macro_id: str) -> list[dict[str, str]]:
        macro = resolve_macro(macro_id)
        ruta = macro.ruta(self.settings.macro_dir)
        if not ruta.exists():
            raise MacroNoEncontradoError(
                f"El archivo '{macro.archivo}' no está disponible en OneDrive.",
                detail=str(ruta),
            )

        output_path = self._temp_path("macro", "txt")
        try:
            logger.info("Ejecutando macro %s (%s)", macro.id, macro.archivo)
            return await self.engine.execute_macro(ruta, output_path)
        finally:
            self._cleanup_temp(output_path)

    def preflight(self) -> dict[str, Any]:
        info = self.engine.preflight()
        info["backend"] = self.name
        return info

    # ------------------------------------------------------------------
    # Temporales
    # ------------------------------------------------------------------
    def _temp_path(self, prefijo: str, ext: str) -> Path:
        nombre = f"lazyremedy_{prefijo}_{uuid.uuid4().hex[:8]}.{ext}"
        return self.settings.output_path / nombre

    @staticmethod
    def _cleanup_temp(*paths: Path) -> None:
        for p in paths:
            try:
                p.unlink(missing_ok=True)
            except OSError:
                pass
