"""Official MCP Python SDK adapter; stdio only, no socket/listener."""
import json
from typing import Any

from pydantic import StrictInt, StrictStr

from mcp.server.mcpserver import MCPServer
from mcp.types import CallToolResult, TextContent, ToolAnnotations

from .application import RemedyApplication
from .domain import TerminalError


def create_server(app: RemedyApplication) -> MCPServer:
    server = MCPServer("RemedyTerminal", version="1.0.0", log_level="ERROR",
                       instructions="Offline only. Synthetic data is not live Remedy evidence. No writes.")
    annotations = ToolAnnotations(read_only_hint=True, destructive_hint=False,
                                  idempotent_hint=True, open_world_hint=False)

    @server.tool(name="remedy_health", annotations=annotations, structured_output=True)
    async def health() -> dict[str, Any]:
        """Local diagnostic only; no network, credentials, paths or Remedy login."""
        return app.health()

    @server.tool(name="remedy_capabilities", annotations=annotations, structured_output=True)
    async def capabilities() -> dict[str, Any]:
        """Actual supported offline tools and explicitly approved form/field policy."""
        return app.capabilities()

    if app.policy.read_enabled:
        @server.tool(name="remedy_search", annotations=annotations)
        async def search(form: StrictStr, criteria: dict[str, StrictStr],
                         fields: list[StrictStr], limit: StrictInt = 50) -> CallToolResult:
            """SYNTHETIC ONLY. Bounded exact AND equality; approved form/fields, no raw qualifier."""
            try:
                return _result(await app.search(form, criteria, fields, limit))
            except TerminalError as exc:
                return _result({"error": exc.code}, error=True)

        @server.tool(name="remedy_get", annotations=annotations)
        async def get(form: StrictStr, entry_id: StrictStr,
                      fields: list[StrictStr]) -> CallToolResult:
            """SYNTHETIC ONLY. Exact entry ID, explicitly selected approved fields. No alias guessing."""
            try:
                return _result(await app.get(form, entry_id, fields))
            except TerminalError as exc:
                return _result({"error": exc.code}, error=True)

    return server


def _result(data: dict, error: bool = False) -> CallToolResult:
    return CallToolResult(content=[TextContent(type="text", text=json.dumps(data, ensure_ascii=False))],
                          structured_content=data, is_error=error)
