"""All fixtures are synthetic; no corporate metadata or live attachment."""
import json
import pytest

from lazyremedy.terminal.domain import TerminalError
from lazyremedy.terminal.windows_readonly import _load_policy, read_incident
from test_incident_readonly import App, config, saved


class CanonicalApp(App):
    def __init__(self, incident_id="1234567"):
        super().__init__()
        self.canonical = "SYN" + incident_id.zfill(10)
        canonical = self.canonical
        self.search.entries.Item = lambda _: type("Entry", (), {"entryId": canonical})()
        self.display.fields[900001].Value = self.canonical

    def LoadForm(self, *args):
        assert args == (17, "SYN-SERVER", "SYN:Incident", self.canonical, 3, 0)
        self.log.append(("LoadForm",))
        return self.display


def all_policy():
    data = config()
    data["allow_all_incidents"] = True
    return data


def test_all_reads_one_exact_incident_outside_allowlist(tmp_path):
    app = CanonicalApp()
    data = all_policy()
    path = saved(tmp_path, data)
    assert _load_policy(path) == data
    result = read_incident("1234567", path, factory=lambda _: app)
    assert result["canonical_id"] == "SYN0001234567"
    assert result["values"] == {"Synthetic summary": "Synthetic result"}
    assert result["writes_enabled"] is False
    assert ("Query", "'900001' = \"SYN0001234567\"") in app.log
    assert app.log[-2:] == [("Close", True), ("Close", False)]
    json.dumps(result, allow_nan=False)


@pytest.mark.parametrize("scope", [None, False])
def test_absent_or_false_keeps_allowlist(tmp_path, scope):
    data = config()
    if scope is not None:
        data["allow_all_incidents"] = scope
    with pytest.raises(TerminalError, match="^incident_not_approved$"):
        read_incident("1234567", saved(tmp_path, data), factory=lambda _: pytest.fail("attached"))
    assert read_incident("7654321", saved(tmp_path, data), factory=lambda _: App())["source"] == "live"


@pytest.mark.parametrize("value", [1, 0, None, "true", "false", "*", [], {}])
def test_all_requires_exact_bool(tmp_path, value):
    data = config()
    data["allow_all_incidents"] = value
    with pytest.raises(TerminalError, match="^configuration_invalid$"):
        read_incident("1234567", saved(tmp_path, data), factory=lambda _: pytest.fail("attached"))


@pytest.mark.parametrize("update", [
    {"approved_incident_ids": []}, {"approved_incident_ids": ["*"]},
    {"approved_incident_ids": ["all"]}, {"unknown": True},
    {"fields": [{"id": 900002, "label": "Credentials"}]},
])
def test_all_does_not_relax_schema_or_secret_labels(tmp_path, update):
    data = all_policy()
    data.update(update)
    with pytest.raises(TerminalError, match="^configuration_invalid$"):
        read_incident("1234567", saved(tmp_path, data), factory=lambda _: pytest.fail("attached"))


@pytest.mark.parametrize("bad", [1, None, "", "0", "0123", " 123", "123 ", "１２３",
                                "-1", "1" * 11, "1" * 31, "SYN0001234567", '123\" OR 1=1'])
def test_all_invalid_ids_never_attach_or_initialize_com(tmp_path, monkeypatch, bad):
    from lazyremedy.terminal import tui
    path = saved(tmp_path, all_policy())
    with pytest.raises(TerminalError, match="^invalid_incident_id$"):
        read_incident(bad, path, factory=lambda _: pytest.fail("attached"))
    monkeypatch.setattr(tui, "com_runtime", lambda: pytest.fail("initialized"))
    with pytest.raises(TerminalError, match="^invalid_incident_id$"):
        tui.read_on_thread(bad, path, lambda *_: pytest.fail("read"))


@pytest.mark.parametrize("stage", ["entry", "identity", "identity_label", "label", "count"])
def test_all_preserves_identity_label_unique_guards_and_cleanup(tmp_path, stage):
    app = CanonicalApp()
    error = "incident_mismatch"
    if stage == "entry":
        app.search.entries.Item = lambda _: type("Entry", (), {"entryId": "SYN0007654321"})()
    elif stage == "identity":
        app.display.fields[900001].Value = "SYN0007654321"
    elif stage == "identity_label":
        app.display.fields[900001].label = "Unknown"
    elif stage == "label":
        app.display.fields[900002].label = "Unknown"
        error = "field_contract_mismatch"
    else:
        app.search.entries.Count = 2
        error = "incident_not_unique"
    with pytest.raises(TerminalError, match="^" + error + "$"):
        read_incident("1234567", saved(tmp_path, all_policy()), factory=lambda _: app)
    assert app.search.closed
    assert app.display.closed == (stage not in {"entry", "count"})


@pytest.mark.parametrize("scope", [True, False, None])
def test_worker_uses_same_scope_before_reader(tmp_path, scope):
    from lazyremedy.terminal.tui import read_on_thread
    data = config()
    if scope is not None:
        data["allow_all_incidents"] = scope
    calls = []
    app = CanonicalApp()
    def reader(incident_id, path):
        calls.append(incident_id)
        return read_incident(incident_id, path, factory=lambda _: app)
    path = saved(tmp_path, data)
    if scope is True:
        assert read_on_thread("1234567", path, reader)["canonical_id"] == app.canonical
        assert calls == ["1234567"]
    else:
        with pytest.raises(TerminalError, match="^incident_not_approved$"):
            read_on_thread("1234567", path, reader)
        assert calls == []


class DiaryField:
    def __init__(self, entries):
        self.entries = entries
        self.calls = []
        self.label = "Diario sintético"

    def GetFieldLabel(self):
        return self.label

    @property
    def Value(self):
        pytest.fail("diary must not read or write scalar Value")

    def GetDiaryHistoryList(self, mode):
        self.calls.append(mode)
        return self.entries


def diary_policy():
    data = all_policy()
    data["fields"] = [{"id": 900002, "label": "Diario sintético", "reader": "diary_history"}]
    return data


@pytest.mark.parametrize("entries, expected", [
    (("Primera entrada", "Segunda entrada\nDetalle"), "Primera entrada\n\nSegunda entrada\nDetalle"),
    ((), ""), (("",), ""), (("", ""), "\n\n"),
    (("Texto libre: password, API key, OTP",), "Texto libre: password, API key, OTP"),
])
def test_diary_history_tuple_join_is_literal_readonly_and_cleaned(tmp_path, entries, expected):
    app = CanonicalApp()
    field = DiaryField(entries)
    app.display.fields[900002] = field
    result = read_incident("1234567", saved(tmp_path, diary_policy()), factory=lambda _: app)
    assert result["values"] == {field.label: expected}
    assert field.calls == [0]
    assert result["writes_enabled"] is False
    assert app.log[-2:] == [("Close", True), ("Close", False)]
    json.dumps(result, allow_nan=False)


class StringSubclass(str):
    pass


class TupleSubclass(tuple):
    pass


@pytest.mark.parametrize("entries", [
    None, "text", ["text"], {"text": "text"}, object(), (None,), (1,), (True,),
    ({"entry": "text"},), (["text"],), (object(),), (StringSubclass("text"),), TupleSubclass(("text",)),
    ("",) * 10001, ("x" * (1024 * 1024 + 1),), ("x" * (512 * 1024),) * 2,
    ("é" * (512 * 1024 + 1),),
])
def test_diary_unsafe_types_or_limits_fail_closed_and_cleanup(tmp_path, entries):
    app = CanonicalApp()
    app.display.fields[900002] = DiaryField(entries)
    with pytest.raises(TerminalError, match="^field_value_unsupported$"):
        read_incident("1234567", saved(tmp_path, diary_policy()), factory=lambda _: app)
    assert app.log[-2:] == [("Close", True), ("Close", False)]


@pytest.mark.parametrize("update", [
    {"reader": "unknown"}, {"reader": "value"}, {"reader": None}, {"reader": True},
    {"reader": ["diary_history"]}, {"extra": True}, {"label": "Unknown password"},
    {"label": "Ｃｒｅｄｅｎｔｉａｌｓ"}, {"id": 900001},
])
def test_diary_reader_does_not_relax_field_schema_or_credentials(tmp_path, update):
    data = diary_policy()
    data["fields"][0].update(update)
    with pytest.raises(TerminalError, match="^configuration_invalid$"):
        read_incident("1234567", saved(tmp_path, data), factory=lambda _: pytest.fail("attached"))


def test_identity_never_accepts_reader_metadata(tmp_path):
    data = all_policy()
    data["incident_field"]["reader"] = "diary_history"
    with pytest.raises(TerminalError, match="^configuration_invalid$"):
        read_incident("1234567", saved(tmp_path, data), factory=lambda _: pytest.fail("attached"))


@pytest.mark.parametrize("stage", ["label", "getter"])
def test_diary_checks_exact_label_before_getter_and_sanitizes_errors(tmp_path, stage):
    app = CanonicalApp()
    field = DiaryField(("Synthetic entry",))
    app.display.fields[900002] = field
    if stage == "label":
        field.label = "Unknown"
        error = "field_contract_mismatch"
    else:
        def fail(_):
            raise RuntimeError("PRIVATE synthetic backend detail")
        field.GetDiaryHistoryList = fail
        error = "com_read_failed"
    with pytest.raises(TerminalError, match="^" + error + "$"):
        read_incident("1234567", saved(tmp_path, diary_policy()), factory=lambda _: app)
    assert field.calls == []
    assert app.log[-2:] == [("Close", True), ("Close", False)]


def test_legacy_scalar_reader_still_uses_only_value(tmp_path):
    app = CanonicalApp()
    field = app.display.fields[900002]
    field.Value = "Original scalar"
    field.GetDiaryHistoryList = lambda _: pytest.fail("guessed diary reader")
    assert read_incident("1234567", saved(tmp_path, all_policy()), factory=lambda _: app)["values"] == {
        "Synthetic summary": "Original scalar"}


def pane_text(app, selector):
    from textual.widgets import Static
    return str(app.query_one(selector, Static).content)


@pytest.mark.asyncio
async def test_ui_initial_and_cleared_panes_are_neutral(tmp_path):
    from lazyremedy.terminal.tui import RemedyApp
    app = RemedyApp(saved(tmp_path))
    async with app.run_test():
        for selector in ("#summary", "#description", "#closure", "#journal"):
            assert pane_text(app, selector) == "Sin incidencia cargada."
        app.clear_details()
        for selector in ("#summary", "#description", "#closure", "#journal"):
            assert pane_text(app, selector) == "Sin incidencia cargada."


@pytest.mark.asyncio
@pytest.mark.parametrize("scope", [True, False])
async def test_ui_outside_allowlist_renders_only_when_all_authorized(tmp_path, scope):
    from lazyremedy.terminal.tui import RemedyApp
    data = diary_policy()
    data["allow_all_incidents"] = scope
    app_com = CanonicalApp()
    app_com.display.fields[900002] = DiaryField(("Entrada primera", "Entrada segunda"))
    calls = []
    def reader(incident_id, path):
        calls.append(incident_id)
        return read_incident(incident_id, path, factory=lambda _: app_com)
    app = RemedyApp(saved(tmp_path, data), initial_id="1234567", reader=reader)
    async with app.run_test(size=(100, 30)):
        await app.workers.wait_for_complete()
        if scope:
            assert calls == ["1234567"]
            assert "SYN0001234567" in pane_text(app, "#identity")
            assert "Entrada primera\n\nEntrada segunda" in pane_text(app, "#journal")
            assert "No incluido" in pane_text(app, "#summary")
            for selector in ("#readonly", "#source", "#status"):
                assert "TODAS las incidencias" in pane_text(app, selector)
                assert "política local" in pane_text(app, selector)
        else:
            assert calls == []
            assert "no autorizada" in pane_text(app, "#status")
            assert "TODAS" not in pane_text(app, "#readonly")
            for selector in ("#summary", "#description", "#closure", "#journal"):
                assert pane_text(app, selector) == "Sin incidencia cargada."


@pytest.mark.asyncio
@pytest.mark.parametrize("failure", ["backend", "wrong_identity"])
async def test_ui_all_failure_clears_stale_fields_to_neutral(tmp_path, failure):
    from lazyremedy.terminal.tui import RemedyApp
    from textual.widgets import Input
    from test_tui import live
    calls = []
    def reader(incident_id, path):
        calls.append(incident_id)
        if len(calls) == 1:
            return live(incident_id)
        if failure == "backend":
            raise RuntimeError("PRIVATE synthetic backend trace")
        return live(incident_id, canonical_id="SYN0007654321")
    app = RemedyApp(saved(tmp_path, all_policy()), initial_id="1234567", reader=reader)
    async with app.run_test() as pilot:
        await app.workers.wait_for_complete()
        assert "Ficha sintética" in pane_text(app, "#summary")
        app.query_one("#incident-id", Input).value = "2345678"
        await pilot.click("#search")
        await app.workers.wait_for_complete()
        assert calls == ["1234567", "2345678"]
        for selector in ("#summary", "#description", "#closure", "#journal"):
            assert pane_text(app, selector) == "Sin incidencia cargada."
        assert "PRIVATE" not in pane_text(app, "#status")
        assert "Sin lectura" in pane_text(app, "#source")


@pytest.mark.asyncio
async def test_ui_invalid_policy_does_not_claim_all_authorization(tmp_path):
    from lazyremedy.terminal.tui import RemedyApp
    data = all_policy()
    data["unknown"] = True
    app = RemedyApp(saved(tmp_path, data), initial_id="1234567", reader=lambda *_: pytest.fail("read"))
    async with app.run_test():
        await app.workers.wait_for_complete()
        for selector in ("#readonly", "#source"):
            assert "sin verificar" in pane_text(app, selector)
            assert "TODAS" not in pane_text(app, selector)


def test_diary_failure_releases_com_references_before_worker_uninit(tmp_path, monkeypatch):
    import weakref
    from lazyremedy.terminal import tui
    refs, states = [], []
    class COM:
        def CoInitialize(self):
            pass
        def CoUninitialize(self):
            states.append(all(ref() is None for ref in refs))
    monkeypatch.setattr(tui, "com_runtime", lambda: COM())
    def factory(_):
        app = CanonicalApp()
        field = DiaryField((object(),))
        app.display.fields[900002] = field
        refs.extend((weakref.ref(app), weakref.ref(field)))
        return app
    def reader(incident_id, path):
        return read_incident(incident_id, path, factory=factory)
    with pytest.raises(TerminalError, match="^field_value_unsupported$"):
        tui.read_on_thread("1234567", saved(tmp_path, diary_policy()), reader)
    assert states == [True]


@pytest.mark.asyncio
@pytest.mark.parametrize("size", [(100, 30), (160, 45)])
async def test_ui_all_source_authorization_fits_without_clipping(tmp_path, size):
    from lazyremedy.terminal.tui import RemedyApp
    from textual.widgets import Static
    from test_tui import live
    app = RemedyApp(saved(tmp_path, all_policy()), initial_id="1234567", reader=lambda i, _: live(i))
    async with app.run_test(size=size) as pilot:
        await app.workers.wait_for_complete()
        await pilot.pause()
        source = app.query_one("#source", Static)
        natural_height = source.get_content_height(source.content_size, app.size, source.content_size.width)
        assert natural_height <= source.content_size.height
