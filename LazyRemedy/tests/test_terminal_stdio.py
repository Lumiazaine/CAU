"""Real official-SDK stdio subprocess tests; no network or live Remedy data."""
import asyncio
import os
from pathlib import Path
import sys
import subprocess

import pytest

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

ROOT = Path(__file__).resolve().parents[1]

# Windows uses a short-lived loopback socketpair for asyncio's private wakeup
# pipe. Permit ONLY that stdlib code object and its own pair endpoints; normal
# application DNS/connect/bind remain denied, including ordinary loopback.
CHILD_NETWORK_GUARD = '''import socket, sys
_pair_code = getattr(socket.socketpair, "__code__", None)
_bind = socket.socket.bind
_connect = socket.socket.connect

def denied(*args, **kwargs):
    raise AssertionError("network forbidden: offline MCP test")

def guarded_bind(sock, address):
    caller = sys._getframe(1)
    if (_pair_code is not None and caller.f_code is _pair_code
            and sock is caller.f_locals.get("lsock")
            and address in (("127.0.0.1", 0), ("::1", 0))):
        return _bind(sock, address)
    return denied()

def guarded_connect(sock, address):
    caller = sys._getframe(1)
    listener = caller.f_locals.get("lsock")
    if (_pair_code is not None and caller.f_code is _pair_code
            and sock is caller.f_locals.get("csock") and listener is not None
            and address[0] in ("127.0.0.1", "::1")
            and address == listener.getsockname()[:2]):
        return _connect(sock, address)
    return denied()

socket.getaddrinfo = denied
socket.socket.connect = guarded_connect
socket.socket.connect_ex = denied
socket.socket.bind = guarded_bind
'''


def server_parameters(tmp_path, config=None):
    # Apply a network kill switch in the CHILD too (pytest fixtures only guard parent).
    guard = tmp_path / "guard"
    guard.mkdir(exist_ok=True)
    (guard / "sitecustomize.py").write_text(CHILD_NETWORK_GUARD, encoding="utf-8")
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


@pytest.mark.parametrize("operation", [
    'socket.getaddrinfo("example.invalid", 443)',
    'socket.socket().connect(("203.0.113.1", 443))',
    'socket.socket().connect(("127.0.0.1", 9))',
    'socket.socket().connect_ex(("127.0.0.1", 9))',
    'socket.socket().bind(("127.0.0.1", 0))',
])
def test_child_guard_denies_ordinary_network(tmp_path, operation):
    parameters = server_parameters(tmp_path)
    code = ('import socket\ntry:\n    ' + operation
            + '\nexcept AssertionError:\n    print("DENIED")\n'
              'else:\n    raise RuntimeError("offline guard failed")\n')
    result = subprocess.run([sys.executable, "-c", code], env=parameters.env,
                            cwd=parameters.cwd, capture_output=True, text=True, timeout=5)
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == "DENIED"
    assert not result.stderr


def test_child_guard_allows_stdlib_private_socketpair(tmp_path):
    parameters = server_parameters(tmp_path)
    code = ('import socket\na,b=socket.socketpair()\n'
            'try:\n    a.sendall(b"x")\n    assert b.recv(1)==b"x"\n'
            'finally:\n    a.close()\n    b.close()\nprint("PAIR_OK")\n')
    result = subprocess.run([sys.executable, "-c", code], env=parameters.env,
                            cwd=parameters.cwd, capture_output=True, text=True, timeout=5)
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == "PAIR_OK"
    assert not result.stderr
