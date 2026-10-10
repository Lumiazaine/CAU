"""New terminal contract: all data in these tests is SYNTHETIC, never Remedy live."""
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run_cli(*args):
    env = {key: value for key, value in os.environ.items()
           if not key.startswith(("LAZYREMEDY_", "REMEDY_"))}
    return subprocess.run([sys.executable, "-m", "lazyremedy.terminal", *args],
                          cwd=ROOT, env=env, capture_output=True, text=True, timeout=15)


def configured(tmp_path, **updates):
    data = {"adapter": "synthetic", "read_approved": True,
            "forms": {"SYN:Tickets": ["summary", "status"]}}
    data.update(updates)
    path = tmp_path / "terminal.json"
    path.write_text(json.dumps(data), encoding="utf-8")
    return path


def test_explicit_synthetic_approval_enables_only_read_capabilities(tmp_path):
    path = configured(tmp_path)
    result = run_cli("capabilities", "--config", str(path))
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout) == {
        "mode": "synthetic", "live": False, "verified_scope": "offline",
        "read_enabled": True, "write_enabled": False,
        "tools": ["remedy_health", "remedy_capabilities", "remedy_search", "remedy_get"],
        "forms": {"SYN:Tickets": ["summary", "status"]},
        "max_limit": 100, "live_contract_verified": False,
    }


import pytest


@pytest.mark.parametrize("updates", [
    {"adapter": "native", "read_approved": True},
    {"adapter": "rest", "read_approved": True},
    {"read_approved": "true"},
    {"write_approved": True},
    {"forms": {"SYN:Tickets": ["password"]}},
    {"forms": {"SYN:Tickets": ["status", "status"]}},
    {"forms": {"SYN:Tickets": []}},
    {"forms": {" SYN:Tickets": ["status"]}},
])
def test_invalid_policy_is_fail_closed_and_sanitized(tmp_path, updates):
    path = configured(tmp_path, **updates)
    result = run_cli("capabilities", "--config", str(path))
    assert result.returncode == 2
    assert not result.stdout
    assert json.loads(result.stderr) == {"error": "configuration_invalid"}
    assert "Traceback" not in result.stderr


def test_cli_search_returns_bounded_projected_synthetic_rows(tmp_path):
    path = configured(tmp_path)
    result = run_cli("search", "--config", str(path), "--form", "SYN:Tickets",
                     "--where", "status=open", "--field", "summary", "--limit", "1")
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout) == {
        "mode": "synthetic", "live": False, "form": "SYN:Tickets",
        "entries": [{"entry_id": "SYN-0001", "values": {"summary": "Prueba sintética uno"}}],
        "returned_count": 1, "has_more": True,
    }


def test_cli_get_reads_exact_synthetic_entry_id(tmp_path):
    path = configured(tmp_path)
    result = run_cli("get", "--config", str(path), "--form", "SYN:Tickets",
                     "--entry-id", "SYN-0001", "--field", "status")
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout) == {
        "mode": "synthetic", "live": False, "form": "SYN:Tickets",
        "entry_id": "SYN-0001", "values": {"status": "open"},
    }


@pytest.mark.parametrize("where", [["bad"], ["status=open", "status=closed"]])
def test_cli_criteria_rejects_malformed_or_duplicate_keys(tmp_path, where):
    path = configured(tmp_path)
    args = ["search", "--config", str(path), "--form", "SYN:Tickets", "--field", "summary"]
    for criterion in where:
        args += ["--where", criterion]
    result = run_cli(*args)
    assert result.returncode == 2
    assert result.stdout == ""
    assert json.loads(result.stderr) == {"error": "invalid_request"}


@pytest.mark.parametrize("forms", [
    {"UNVERIFIED:RealForm": ["status"]}, {"SYN:Tickets": ["unknown_field"]},
])
def test_synthetic_schema_cannot_imply_unverified_form_support(tmp_path, forms):
    result = run_cli("capabilities", "--config", str(configured(tmp_path, forms=forms)))
    assert result.returncode == 2
    assert result.stdout == ""
    assert json.loads(result.stderr) == {"error": "configuration_invalid"}


def test_package_pins_official_sdk_and_exposes_terminal_entrypoint():
    import tomllib
    project = tomllib.loads((ROOT / "pyproject.toml").read_text(encoding="utf-8"))["project"]
    assert "mcp==2.3.0" in project["dependencies"]
    assert project["scripts"]["remedy-terminal"] == "lazyremedy.terminal.cli:main"


def test_duplicate_json_policy_keys_fail_closed(tmp_path):
    path = tmp_path / "ambiguous.json"
    path.write_text('{"adapter":"synthetic","read_approved":false,"read_approved":true, '
                    '"forms":{"SYN:Tickets":["status"]}}', encoding="utf-8")
    result = run_cli("capabilities", "--config", str(path))
    assert result.returncode == 2
    assert result.stdout == ""
    assert json.loads(result.stderr) == {"error": "configuration_invalid"}


def test_default_health_is_offline_without_claiming_live():
    result = run_cli("health")
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout) == {
        "status": "blocked", "mode": "blocked", "live": False,
        "verified_scope": "offline", "read_enabled": False, "write_enabled": False,
    }
