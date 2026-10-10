"""Real official-SDK stdio subprocess tests; no network or live Remedy data."""
import asyncio
import os
from pathlib import Path
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

ROOT = Path(__file__).resolve().parents[1]


def server_parameters(tmp_path, config=None):
    # Apply a network kill switch in the CHILD too (pytest fixtures only guard parent).
    guard = tmp_path / "guard"
    guard.mkdir(exist_ok=True)
    (guard / "sitecustomize.py").write_text(
        "import socket\n"
        "def denied(*args, **kwargs):\n"
        "    raise AssertionError('network forbidden: offline MCP test')\n"
        "socket.getaddrinfo = denied\n"
        "socket.socket.connect = denied\n"
        "socket.socket.connect_ex = denied\n"
        "socket.socket.bind = denied\n", encoding="utf-8")
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(("LAZYREMEDY_", "REMEDY_"))}
    env["PYTHONPATH"] = os.pathsep.join([str(guard), str(ROOT)])
    args = ["-m", "lazyremedy.terminal", "mcp"]
    if config:
        args += ["--config", str(config)]
    return StdioServerParameters(command=sys.executable, args=args, env=env, cwd=str(ROOT))


import json


def test_real_stdio_synthetic_reads_and_errors(tmp_path):
    config = tmp_path / "terminal.json"
    config.write_text(json.dumps({"adapter": "synthetic", "read_approved": True,
                                 "forms": {"SYN:Tickets": ["summary", "status"]}}), encoding="utf-8")

    async def check():
        with (tmp_path / "server.stderr").open("w+") as errlog:
            async with stdio_client(server_parameters(tmp_path, config), errlog=errlog) as (read, write):
                async with ClientSession(read, write, read_timeout_seconds=10) as session:
                    await session.initialize()
                    tools = await session.list_tools()
                    assert {t.name for t in tools.tools} == {
                        "remedy_health", "remedy_capabilities", "remedy_search", "remedy_get"}
                    search = await session.call_tool("remedy_search", {
                        "form": "SYN:Tickets", "criteria": {"status": "open"},
                        "fields": ["summary"], "limit": 1})
                    assert search.is_error is False
                    assert search.structured_content["mode"] == "synthetic"
                    assert search.structured_content["live"] is False
                    assert search.structured_content["returned_count"] == 1
                    assert search.structured_content["has_more"] is True
                    entry = await session.call_tool("remedy_get", {
                        "form": "SYN:Tickets", "entry_id": "SYN-0001", "fields": ["status"]})
                    assert entry.is_error is False
                    assert entry.structured_content["values"] == {"status": "open"}
                    for name, arguments, code in [
                        ("remedy_search", {"form": "SYN:Tickets", "criteria": {},
                                           "fields": ["summary"]}, "invalid_request"),
                        ("remedy_get", {"form": "SYN:Tickets", "entry_id": "SYN-9999",
                                        "fields": ["summary"]}, "entry_not_found"),
                    ]:
                        error = await session.call_tool(name, arguments)
                        assert error.is_error is True
                        assert error.structured_content == {"error": code}
                        assert json.loads(error.content[0].text) == {"error": code}
            errlog.seek(0)
            assert "Traceback" not in errlog.read()
    asyncio.run(asyncio.wait_for(check(), 20))


import pytest


@pytest.mark.parametrize("approved", [None, False])
def test_real_stdio_initialize_list_call_default_closed(tmp_path, approved):
    config = None
    if approved is not None:
        config = tmp_path / "unapproved.json"
        config.write_text(json.dumps({"adapter": "synthetic", "read_approved": approved,
                                      "forms": {"SYN:Tickets": ["status"]}}), encoding="utf-8")
    async def check():
        with (tmp_path / "server.stderr").open("w+") as errlog:
            async with stdio_client(server_parameters(tmp_path, config), errlog=errlog) as (read, write):
                async with ClientSession(read, write, read_timeout_seconds=10) as session:
                    initialized = await session.initialize()
                    assert initialized.server_info.name == "RemedyTerminal"
                    tools = await session.list_tools()
                    assert {t.name for t in tools.tools} == {"remedy_health", "remedy_capabilities"}
                    for tool in tools.tools:
                        assert tool.annotations.read_only_hint is True
                        assert tool.annotations.open_world_hint is False
                    health = await session.call_tool("remedy_health", {})
                    assert health.is_error is False
                    assert health.structured_content["live"] is False
                    assert health.structured_content["read_enabled"] is False
                    caps = await session.call_tool("remedy_capabilities", {})
                    assert caps.structured_content["write_enabled"] is False
                    assert caps.structured_content["live_contract_verified"] is False
                    for forbidden in ["remedy_search", "remedy_get", "remedy_update", "remedy_create"]:
                        denied = await session.call_tool(forbidden, {})
                        assert denied.is_error is True
    asyncio.run(asyncio.wait_for(check(), 20))
