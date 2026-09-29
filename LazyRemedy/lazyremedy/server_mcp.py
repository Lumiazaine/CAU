"""Servidor MCP (FastMCP) de LazyRemedy.

Expone herramientas de búsqueda nativas a agentes de IA. Comparte el mismo
``RemedyService`` que la API REST: el cerrojo de runmacro.exe es común.
"""

from __future__ import annotations

import logging
from typing import Any

from fastmcp import FastMCP

from . import __version__
from .config import Settings, load_settings
from .errors import LazyRemedyError
from .models import SearchRequest
from .service import RemedyService

logger = logging.getLogger("lazyremedy.mcp")

MCP_INSTRUCTIONS = (
    "LazyRemedy expone el cliente legado BMC Remedy User (solo lectura) del CAU. "
    "Las operaciones son: búsqueda dinámica de incidencias (por ID incidencia, "
    "usuario Temis/DNI, correo de funcionario o teléfono) y ejecución de macros "
    "predefinidos (CSU, HELPDESK, PENDIENTE_USUARIO, MICROINFORMATICA). "
    "La ejecución es serializada: las peticiones se encolan y no se lanzan de "
    "forma concurrente."
)


def create_mcp(settings: Settings | None = None, service: RemedyService | None = None) -> FastMCP:
    """Fábrica del servidor MCP. Permite inyectar settings/servicio (tests)."""
    settings = settings or load_settings()
    service = service or RemedyService(settings)

    mcp = FastMCP(
        "LazyRemedy",
        instructions=MCP_INSTRUCTIONS,
        version=__version__,
    )

    @mcp.tool(
        name="remedy_buscar",
        description=(
            "Busca incidencias en Remedy aplicando filtros opcionales: "
            "incidencia_id, usuario_temis (DNI), correo de funcionario o teléfono. "
            "Al menos un filtro es obligatorio."
        ),
    )
    async def remedy_buscar(
        incidencia_id: str | None = None,
        usuario_temis: str | None = None,
        correo: str | None = None,
        telefono: str | None = None,
    ) -> dict[str, Any]:
        try:
            request = SearchRequest(
                incidencia_id=incidencia_id,
                usuario_temis=usuario_temis,
                correo=correo,
                telefono=telefono,
            )
            resultado = await service.search(request)
            return resultado.model_dump()
        except LazyRemedyError as exc:
            logger.warning("Error MCP [%s]: %s", exc.error_code, exc.message)
            return exc.as_mcp()

    @mcp.tool(
        name="remedy_ejecutar_macro",
        description=(
            "Ejecuta un macro predefinido de Remedy. macro_id válidos: CSU, "
            "HELPDESK, PENDIENTE_USUARIO, MICROINFORMATICA. "
            "Devuelve las filas de incidencias activas de esa cola."
        ),
    )
    async def remedy_ejecutar_macro(macro_id: str) -> dict[str, Any]:
        try:
            resultado = await service.run_macro(macro_id)
            return resultado.model_dump()
        except LazyRemedyError as exc:
            logger.warning("Error MCP [%s]: %s", exc.error_code, exc.message)
            return exc.as_mcp()

    @mcp.tool(
        name="remedy_listar_macros",
        description="Lista los macros predefinidos disponibles y su descripción.",
    )
    async def remedy_listar_macros() -> list[dict[str, Any]]:
        return [m.model_dump() for m in service.list_macros()]

    return mcp
