"""Interfaz común de los backends de datos de Remedy.

Cada backend implementa la misma operación: buscar incidencias y ejecutar
macros de consulta. ``RemedyService`` elige el backend según ``settings.backend``.

- ``midtier``: HTTP contra el portal web de Remedy (Mid Tier).
- ``macro``: ejecución de macros (.arq) con runmacro.exe.
- ``mock``: datos simulados (desarrollo/tests).
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any

from ..errors import (
    BackendNoDisponibleError,
    CriterioInvalidoError,
    MacroNoEncontradoError,
    SinCriteriosError,
)


class RemedyBackend(ABC):
    """Contrato de un backend de acceso a Remedy (solo lectura)."""

    name: str = "base"

    @abstractmethod
    async def search(self, criterios: dict[str, str]) -> list[dict[str, str]]:
        """Busca incidencias por criterios ya validados y mapeados a IDs."""

    @abstractmethod
    async def run_macro(self, macro_id: str) -> list[dict[str, str]]:
        """Ejecuta un macro de consulta predefinido."""

    def preflight(self) -> dict[str, Any]:
        """Estado del backend para /health. Por defecto solo el nombre."""
        return {"backend": self.name}

    # ------------------------------------------------------------------
    # Helpers compartidos (no abstractos)
    # ------------------------------------------------------------------
    @staticmethod
    def validar_criterios(criterios: dict[str, str]) -> dict[str, str]:
        if not criterios:
            raise SinCriteriosError()
        solo_falsos = all(not valor for valor in criterios.values())
        if solo_falsos:
            raise SinCriteriosError()
        return criterios


def normalize_extra_http_error(exc: Exception) -> BackendNoDisponibleError:
    """Envuelve errores de red/HTTP como BackendNoDisponibleError (HTTP 503)."""
    return BackendNoDisponibleError(
        message=f"No se pudo contactar con el Mid Tier de Remedy: {exc}"
    )
