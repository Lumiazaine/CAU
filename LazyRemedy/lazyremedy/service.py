"""Capa de servicio: lógica de negocio compartida por REST y MCP.

Despacha al backend de datos configurado (``settings.backend``):
- ``midtier``: MidtierBackend (HTTP).
- ``macro``/``mock``: MacroBackend (motor de macros).
"""

from __future__ import annotations

import logging
import time

from .backends.base import RemedyBackend
from .config import Settings
from .macros import list_macros, resolve_macro
from .models import MacroInfo, MacroRunResponse, SearchRequest, SearchResponse

logger = logging.getLogger("lazyremedy.service")


def _build_backend(settings: Settings) -> RemedyBackend:
    if settings.backend == "midtier":
        from .backends.midtier import MidtierBackend

        return MidtierBackend(settings)
    if settings.backend == "mock":
        # El backend de macros con mock activado no invoca ningún binario.
        from .backends.macro import MacroBackend

        return MacroBackend(settings.model_copy(update={"mock": True}))
    from .backends.macro import MacroBackend

    return MacroBackend(settings)


class RemedyService:
    """Servicio único compartido por el servidor REST y el MCP."""

    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.backend = _build_backend(settings)

    # ------------------------------------------------------------------
    # Búsqueda dinámica
    # ------------------------------------------------------------------
    async def search(self, request: SearchRequest) -> SearchResponse:
        criterios = request.to_criterios()
        inicio = time.perf_counter()
        filas = await self.backend.search(criterios)
        ejecucion_ms = int((time.perf_counter() - inicio) * 1000)
        logger.info("Búsqueda completada: %d resultado(s) en %d ms", len(filas), ejecucion_ms)
        return SearchResponse(
            criterios=criterios,
            total=len(filas),
            resultados=filas,
            ejecucion_ms=ejecucion_ms,
        )

    # ------------------------------------------------------------------
    # Macros predefinidos
    # ------------------------------------------------------------------
    async def run_macro(self, macro_id: str) -> MacroRunResponse:
        macro = resolve_macro(macro_id)
        inicio = time.perf_counter()
        filas = await self.backend.run_macro(macro_id)
        ejecucion_ms = int((time.perf_counter() - inicio) * 1000)
        logger.info("Macro %s completado: %d fila(s) en %d ms", macro.id, len(filas), ejecucion_ms)
        return MacroRunResponse(
            macro=macro.id,
            archivo=macro.archivo,
            total=len(filas),
            filas=filas,
            ejecucion_ms=ejecucion_ms,
        )

    def list_macros(self) -> list[MacroInfo]:
        return [
            MacroInfo(
                id=m.id,
                archivo=m.archivo,
                descripcion=m.descripcion,
                ruta=str(m.ruta(self.settings.macro_dir)),
            )
            for m in list_macros()
        ]
