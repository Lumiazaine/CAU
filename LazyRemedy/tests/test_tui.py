"""Offline UI verification. Every ticket/policy/value is synthetic."""
import asyncio
import json
import threading
import pytest

pytest.importorskip("textual")
from textual.widgets import Button, Input, Static, TabbedContent


def policy_file(tmp_path):
    data = {
        "enabled": True, "read_only": True,
        "expected_host": "SYN-HOST", "expected_user": "SYN\\tester",
        "expected_session_id": 7, "client_executable": r"C:\Synthetic\aruser.exe",
        "typelib_guid": "{12345678-1234-1234-1234-123456789ABC}",
        "server": "SYN-SERVER", "form": "SYN:Incident", "expected_auth_user": "synthetic.tester",
        "incident_field": {"id": 900001, "label": "ID", "prefix": "SYN", "digits": 10},
        "approved_incident_ids": ["123", "456"],
        "fields": [{"id": 900002, "label": "Resumen"}],
    }
    path = tmp_path / "synthetic.json"
    path.write_text(json.dumps(data), encoding="utf-8")
    return path


def live(incident_id="123", **update):
    result = {"requested_incident_id": incident_id, "canonical_id": "SYN" + incident_id.zfill(10),
              "source": "live", "mode": "live-com-readonly", "writes_enabled": False,
              "values": {"Resumen": "Ficha sintética [bold]literal[/bold]", "Descripción": "Detalle sintético"}}
    result.update(update)
    return result


def text(app, selector):
    return str(app.query_one(selector, Static).content)


@pytest.mark.asyncio
@pytest.mark.parametrize("size", [(100, 30), (160, 45)])
async def test_keyboard_mouse_live_search_tabs_and_help(tmp_path, size):
    from lazyremedy.terminal.tui import RemedyApp
    calls = []
    def reader(incident_id, config):
        calls.append((incident_id, config, threading.get_ident()))
        return live(incident_id)
    app = RemedyApp(policy_file(tmp_path), reader=reader)
    main_thread = threading.get_ident()
    async with app.run_test(size=size) as pilot:
        assert "SOLO LECTURA" in text(app, "#readonly")
        await pilot.press("ctrl+f", "1", "2", "3", "enter")
        await app.workers.wait_for_complete()
        await pilot.pause()
        assert calls[0][:2] == ("123", app.com_config)
        assert calls[0][2] != main_thread
        assert "[bold]literal[/bold]" in text(app, "#summary")
        assert "SYN0000000123" in text(app, "#identity")
        assert "Remedy en vivo" in text(app, "#source")
        assert "No incluido" in text(app, "#journal")
        await pilot.click("#--content-tab-description-tab")
        assert app.query_one(TabbedContent).active == "description-tab"
        await pilot.click("#--content-tab-closure-tab")
        await pilot.click("#--content-tab-journal-tab")
        await pilot.press("f1")
        assert app.screen.id == "help-screen"
        await pilot.press("escape")
        app.query_one("#incident-id", Input).value = "456"
        await pilot.click("#search")
        await app.workers.wait_for_complete()
        assert len(calls) == 2
        await pilot.press("ctrl+q")


@pytest.mark.asyncio
async def test_initial_id_runs_real_reader_and_failure_clears_previous_details(tmp_path):
    from lazyremedy.terminal.tui import RemedyApp
    from lazyremedy.terminal.domain import TerminalError
    def reader(incident_id, config):
        if incident_id == "456":
            raise TerminalError("incident_not_approved")
        return live(incident_id)
    app = RemedyApp(policy_file(tmp_path), initial_id="123", reader=reader)
    async with app.run_test(size=(100, 30)) as pilot:
        await app.workers.wait_for_complete()
        assert "Ficha sintética" in text(app, "#summary")
        app.query_one("#incident-id", Input).value = "456"
        await pilot.click("#search")
        await app.workers.wait_for_complete()
        assert "Ficha sintética" not in text(app, "#summary")
        assert "Detalle sintético" not in text(app, "#description")
        assert "SYN0000000123" not in text(app, "#identity")
        assert "no autorizada" in text(app, "#status")
        assert "Sin lectura" in text(app, "#source")


@pytest.mark.asyncio
@pytest.mark.parametrize("bad", ["0123", " 123", "123 ", "１２３", "0", "-123", "", "1" * 31, "SYN0000000123"])
async def test_invalid_ids_do_not_reach_worker(tmp_path, bad):
    from lazyremedy.terminal.tui import RemedyApp
    app = RemedyApp(policy_file(tmp_path), reader=lambda *_: pytest.fail("worker reached"))
    async with app.run_test() as pilot:
        app.query_one("#incident-id", Input).value = bad
        await pilot.click("#search")
        assert "ID numérico" in text(app, "#status")
        assert not app.busy


@pytest.mark.asyncio
async def test_read_is_nonblocking_serial_and_busy_disables_submission(tmp_path):
    from lazyremedy.terminal.tui import RemedyApp
    gate = threading.Event()
    entered = threading.Event()
    calls = []
    def reader(incident_id, config):
        calls.append(incident_id)
        entered.set()
        assert gate.wait(5)
        return live(incident_id)
    app = RemedyApp(policy_file(tmp_path), reader=reader)
    async with app.run_test() as pilot:
        app.query_one("#incident-id", Input).value = "123"
        await pilot.click("#search")
        await asyncio.to_thread(entered.wait, 2)
        assert app.busy
        assert app.query_one("#search", Button).disabled
        assert app.query_one("#incident-id", Input).disabled
        assert "Consultando" in text(app, "#status")
        app.request_lookup()
        await pilot.press("f1")
        assert app.screen.id == "help-screen"  # Event loop still responsive.
        await pilot.press("escape")
        gate.set()
        await app.workers.wait_for_complete()
        assert calls == ["123"]
        assert not app.busy


@pytest.mark.parametrize("update", [
    {"source": "snapshot"}, {"mode": "synthetic"}, {"writes_enabled": True},
    {"writes_enabled": 0}, {"requested_incident_id": "456"}, {"canonical_id": "SYN0000000456"},
    {"canonical_id": "OTHER0000000123"}, {"values": {"Resumen": object()}},
])
def test_worker_rejects_nonlive_and_identity_mismatch(tmp_path, update):
    from lazyremedy.terminal.tui import read_on_thread
    from lazyremedy.terminal.domain import TerminalError
    with pytest.raises(TerminalError):
        read_on_thread("123", policy_file(tmp_path), lambda *_: live(**update))


@pytest.mark.parametrize("fails", [False, True])
def test_worker_com_init_uninit_even_on_failure(tmp_path, monkeypatch, fails):
    from lazyremedy.terminal import tui
    calls = []
    class COM:
        def CoInitialize(self): calls.append("init")
        def CoUninitialize(self): calls.append("uninit")
    monkeypatch.setattr(tui, "com_runtime", lambda: COM())
    def reader(*_):
        calls.append("read")
        if fails:
            raise RuntimeError("private path and ticket text")
        return live()
    if fails:
        with pytest.raises(Exception):
            tui.read_on_thread("123", policy_file(tmp_path), reader)
    else:
        assert tui.read_on_thread("123", policy_file(tmp_path), reader) == live()
    assert calls == ["init", "read", "uninit"]


def test_plain_text_controls_ansi_osc_and_bidi_are_not_interpreted():
    from lazyremedy.terminal.tui import display_text
    result = display_text("[bold]ID[/bold]\x1b[31m rojo\x1b[0m\x1b]8;;https://invalid\x07x\x1b]8;;\x07\u202e\x00\x9b31m")
    assert result.plain == "[bold]ID[/bold] rojox"
    assert not result.spans


@pytest.mark.asyncio
async def test_unknown_error_never_exposes_private_details(tmp_path):
    from lazyremedy.terminal.tui import RemedyApp
    def reader(*_): raise RuntimeError("PRIVATE SERVER/PATH ticket text")
    app = RemedyApp(policy_file(tmp_path), initial_id="123", reader=reader)
    async with app.run_test() as pilot:
        await app.workers.wait_for_complete()
        assert "PRIVATE" not in text(app, "#status")
        assert "No se pudo" in text(app, "#status")
        assert not app.busy


@pytest.mark.asyncio
@pytest.mark.parametrize("update", [{"source": "snapshot"}, {"mode": "synthetic"},
                                     {"writes_enabled": True}, {"canonical_id": "SYN0000000123"}])
async def test_source_guard_failure_clears_previously_verified_fields(tmp_path, update):
    from lazyremedy.terminal.tui import RemedyApp
    responses = iter([live(), live("456", **update)])
    app = RemedyApp(policy_file(tmp_path), initial_id="123", reader=lambda *_: next(responses))
    async with app.run_test() as pilot:
        await app.workers.wait_for_complete()
        assert "Ficha sintética" in text(app, "#summary")
        app.query_one("#incident-id", Input).value = "456"
        await pilot.click("#search")
        await app.workers.wait_for_complete()
        assert "Ficha sintética" not in text(app, "#summary")
        assert "Sin lectura" in text(app, "#source")
        assert "contrato" in text(app, "#status")


@pytest.mark.asyncio
async def test_changed_id_during_worker_discards_old_result(tmp_path):
    from lazyremedy.terminal.tui import RemedyApp
    gate = threading.Event()
    def reader(incident_id, config):
        assert gate.wait(5)
        return live(incident_id)
    app = RemedyApp(policy_file(tmp_path), reader=reader)
    async with app.run_test() as pilot:
        app.query_one("#incident-id", Input).value = "123"
        await pilot.click("#search")
        app.query_one("#incident-id", Input).value = "456"
        gate.set()
        await app.workers.wait_for_complete()
        assert "Ficha sintética" not in text(app, "#summary")
        assert "descartada" in text(app, "#status")


@pytest.mark.asyncio
async def test_default_reader_on_linux_reaches_existing_guard_without_fake_fallback(tmp_path, monkeypatch):
    import sys
    from lazyremedy.terminal.tui import RemedyApp
    monkeypatch.setattr(sys, "platform", "linux")
    for key in ("SSH_CONNECTION", "SSH_CLIENT", "SSH_TTY"):
        monkeypatch.delenv(key, raising=False)
    app = RemedyApp(policy_file(tmp_path), initial_id="123")
    async with app.run_test() as pilot:
        await app.workers.wait_for_complete()
        assert "requiere Windows" in text(app, "#status")
        assert "Sin lectura" in text(app, "#source")
        assert "Ficha sintética" not in text(app, "#summary")


@pytest.mark.asyncio
async def test_actual_read_incident_adapter_and_ui_share_guarded_scalar_contract(tmp_path):
    from lazyremedy.terminal.tui import RemedyApp
    from lazyremedy.terminal.windows_readonly import read_incident
    from test_incident_readonly import App as SyntheticCOMApp, saved
    com = SyntheticCOMApp()
    path = saved(tmp_path)
    app = RemedyApp(path, initial_id="7654321", reader=lambda incident_id, config: read_incident(
        incident_id, config, factory=lambda policy: com))
    async with app.run_test() as pilot:
        await app.workers.wait_for_complete()
        assert "Synthetic result" in text(app, "#summary")
        assert "SYN0007654321" in text(app, "#identity")
        assert com.search.closed and com.display.closed


@pytest.mark.asyncio
@pytest.mark.parametrize("stage", ["adapter", "reader_chain", "values", "metadata", "json"])
async def test_worker_releases_error_objects_before_uninit_and_sanitizes_async_traceback(
        tmp_path, monkeypatch, stage):
    import sys
    import weakref
    from lazyremedy.terminal import tui
    from lazyremedy.terminal.domain import TerminalError
    from lazyremedy.terminal.windows_readonly import read_incident
    from test_incident_readonly import App as SyntheticCOMApp, saved

    references = []
    uninit_state = []
    originals = []
    worker_threads = []

    class COM:
        def CoInitialize(self):
            worker_threads.append(threading.get_ident())

        def CoUninitialize(self):
            uninit_state.append((all(ref() is None for ref in references), sys.exception() is None))

    monkeypatch.setattr(tui, "com_runtime", lambda: COM())

    def factory(_):
        app = SyntheticCOMApp()
        app.GetUser = lambda _: (None, "other.synthetic.user")
        references.append(weakref.ref(app))
        return app

    def reader(incident_id, config):
        if stage == "adapter":
            return read_incident(incident_id, config, factory=factory)
        app = SyntheticCOMApp()
        references.append(weakref.ref(app))
        if stage == "reader_chain":
            try:
                raise RuntimeError("PRIVATE synthetic detail")
            except RuntimeError as cause:
                error = TerminalError("auth_user_mismatch")
                originals.extend((cause, error))
                raise error from cause
        result = live(incident_id)
        if stage == "values":
            result["values"]["Resumen"] = app
        elif stage == "metadata":
            result["extra"] = app
        else:
            result["extra"] = [app, float("nan")]
        return result

    main_thread = threading.get_ident()
    with pytest.raises(TerminalError) as received:
        await asyncio.to_thread(tui.read_on_thread, "7654321", saved(tmp_path), reader)

    expected = "auth_user_mismatch" if stage in {"adapter", "reader_chain"} else "field_value_unsupported"
    assert received.value.code == expected
    assert references and uninit_state == [(True, True)]
    assert worker_threads[0] != main_thread
    assert received.value not in originals
    assert received.value.__context__ is None
    assert received.value.__cause__ is None
    assert "PRIVATE" not in str(received.value)
    for original in originals:
        assert original.__traceback__ is None
        assert original.__context__ is None
        assert original.__cause__ is None
    trace = received.value.__traceback__
    while trace is not None:
        assert trace.tb_frame.f_code.co_name not in {"read_incident", "reader", "factory"}
        assert not any(isinstance(value, SyntheticCOMApp) for value in trace.tb_frame.f_locals.values())
        trace = trace.tb_next
