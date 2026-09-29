"""Tests de las herramientas MCP (modo mock)."""

from __future__ import annotations

import asyncio
import json

from lazyremedy.server_mcp import create_mcp


def _texto(result) -> str:
    bloque = result.content[0]
    texto = getattr(bloque, "text", None)
    if texto is None:
        texto = str(bloque)
    return texto


def test_tool_listar_macros(settings):
    mcp = create_mcp(settings)

    async def _run():
        return await mcp.call_tool("remedy_listar_macros")

    result = asyncio.run(_run())
    assert result.is_error is False
    datos = json.loads(_texto(result))
    assert {m["id"] for m in datos} == {
        "CSU",
        "HELPDESK",
        "PENDIENTE_USUARIO",
        "MICROINFORMATICA",
    }


def test_tool_buscar_por_incidencia(settings):
    mcp = create_mcp(settings)

    async def _run():
        return await mcp.call_tool(
            "remedy_buscar", {"incidencia_id": "INC001"}
        )

    result = asyncio.run(_run())
    assert result.is_error is False
    datos = json.loads(_texto(result))
    assert datos["total"] == 2
    assert datos["criterios"]["incidencia_id"] == "INC001"


def test_tool_buscar_sin_criterios_devuelve_error(settings):
    mcp = create_mcp(settings)

    async def _run():
        return await mcp.call_tool("remedy_buscar", {})

    result = asyncio.run(_run())
    assert result.is_error is False
    datos = json.loads(_texto(result))
    assert datos["error"] == "sin_criterios"


def test_tool_ejecutar_macro(settings):
    mcp = create_mcp(settings)

    async def _run():
        return await mcp.call_tool("remedy_ejecutar_macro", {"macro_id": "CSU"})

    result = asyncio.run(_run())
    assert result.is_error is False
    datos = json.loads(_texto(result))
    assert datos["macro"] == "CSU"
    assert datos["total"] == 2


def test_tool_ejecutar_macro_desconocido(settings):
    mcp = create_mcp(settings)

    async def _run():
        return await mcp.call_tool(
            "remedy_ejecutar_macro", {"macro_id": "NOPE"}
        )

    result = asyncio.run(_run())
    assert result.is_error is False
    datos = json.loads(_texto(result))
    assert datos["error"] == "macro_no_encontrada"
