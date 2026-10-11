"""Public CLI tests; no UI dependency needed to execute these tests."""
import builtins
import sys
import types
import pytest
from lazyremedy.terminal import cli


def test_ui_dependency_is_optional_and_pinned():
    import ast
    from pathlib import Path
    content = (Path(__file__).parents[1] / "pyproject.toml").read_text()
    extras = content.split("[project.optional-dependencies]", 1)[1].split("\n[", 1)[0]
    ui = next((line.partition("=")[2] for line in extras.splitlines() if line.startswith("ui =")), "None")
    assert ast.literal_eval(ui.strip()) == ["textual==6.12.0"]
    dependencies = ast.literal_eval(content.split("dependencies = ", 1)[1].split("\n]\n", 1)[0] + "\n]")
    assert not any("textual" in dependency for dependency in dependencies)


def test_ui_bypasses_json_bootstrap_and_passes_explicit_options(monkeypatch, capsys):
    calls = []
    monkeypatch.setattr(cli, "build_application", lambda *_: pytest.fail("legacy bootstrap"))
    monkeypatch.setitem(sys.modules, "lazyremedy.terminal.tui", types.SimpleNamespace(
        run_ui=lambda **kwargs: calls.append(kwargs)))
    assert cli.main(["ui", "--com-config", "synthetic.json", "--journal-csv", "synthetic.csv", "--id", "123"]) == 0
    assert calls == [{"com_config": "synthetic.json", "journal_csv": "synthetic.csv", "initial_id": "123"}]
    assert not capsys.readouterr().out


def test_missing_ui_extra_returns_stable_error(monkeypatch, capsys):
    original = builtins.__import__
    def blocked(name, *args, **kwargs):
        if name == "tui":
            raise ModuleNotFoundError("No module named textual", name="textual")
        return original(name, *args, **kwargs)
    monkeypatch.setattr(builtins, "__import__", blocked)
    assert cli.main(["ui", "--com-config", "synthetic.json"]) == 2
    assert capsys.readouterr().err.strip() == '{"error": "ui_dependencies_missing"}'
