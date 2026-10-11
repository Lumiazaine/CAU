"""Pilot tests for real export import, bounded rendering and guarded selection."""
import pytest
pytest.importorskip("textual")
from textual.widgets import DataTable, Input, Button
from test_tui import policy_file, live, text
from test_tui_snapshot import csv_file


@pytest.mark.asyncio
async def test_large_import_pagination_filter_and_selection_never_expand_permissions(tmp_path):
    from lazyremedy.terminal.tui import RemedyApp
    rows = ([str(i), "2026-01-01 00:00:00", "UTC", ""] for i in range(1, 90001))
    path = csv_file(tmp_path, rows)
    calls = []
    def reader(incident_id, config):
        calls.append(incident_id)
        return live(incident_id)
    app = RemedyApp(policy_file(tmp_path), journal_csv=path, reader=reader)
    async with app.run_test(size=(100, 30)) as pilot:
        await app.workers.wait_for_complete()
        await pilot.pause()
        table = app.query_one("#results", DataTable)
        assert table.row_count == 100
        assert "90000" in text(app, "#export-source")
        assert "NO EN VIVO" in text(app, "#export-source")
        assert "90000" in text(app, "#page-info")
        assert "modificado" in text(app, "#export-source")
        await pilot.click("#next")
        await pilot.pause()
        assert table.row_count == 100
        assert app.page == 1
        assert table.get_cell_at((0, 0)).plain == "89900"
        await pilot.click("#previous")
        assert app.page == 0
        app.query_one("#filter-id", Input).value = "90000"
        await pilot.pause()
        assert table.row_count == 1
        table.focus()
        await pilot.press("enter")
        await app.workers.wait_for_complete()
        assert app.query_one("#incident-id", Input).value == "90000"
        assert "no autorizada" in text(app, "#status")
        assert calls == []
        app.query_one("#filter-id", Input).value = "not-found"
        await pilot.pause()
        assert table.row_count == 0
        assert "0" in text(app, "#page-info")
        assert app.query_one("#next", Button).disabled


@pytest.mark.asyncio
async def test_mouse_and_arrow_selection_prefill_policy_confirmed_canonical_id(tmp_path):
    from lazyremedy.terminal.tui import RemedyApp
    path = csv_file(tmp_path, [["SYN0000000456", "2026-01-02 00:00:00", "UTC", "[red]literal[/red]"],
                               ["SYN0000000123", "2026-01-01 00:00:00", "UTC", ""]])
    calls = []
    def reader(incident_id, config):
        calls.append(incident_id)
        return live(incident_id)
    app = RemedyApp(policy_file(tmp_path), journal_csv=path, reader=reader)
    async with app.run_test(size=(160, 45)) as pilot:
        await app.workers.wait_for_complete()
        table = app.query_one("#results", DataTable)
        assert table.get_cell_at((0, 0)).plain == "SYN0000000456"
        assert table.get_cell_at((0, 3)).plain == "[red]literal[/red]"
        assert not table.get_cell_at((0, 3)).spans
        table.focus()
        await pilot.press("down")
        await pilot.pause()
        assert app.query_one("#incident-id", Input).value == "123"
        assert calls == []
        await pilot.press("enter")
        await app.workers.wait_for_complete()
        assert calls == ["123"]
        assert "SYN0000000123" in text(app, "#identity")
        await pilot.click("#results", offset=(5, 1))
        await pilot.pause()
        assert app.query_one("#incident-id", Input).value == "456"


@pytest.mark.asyncio
@pytest.mark.parametrize("malformed", [False, True])
async def test_empty_and_bad_export_have_human_status_and_no_partial_list(tmp_path, malformed):
    from lazyremedy.terminal.tui import RemedyApp
    rows = [["123", "invalid-date", "UTC", ""]] if malformed else []
    app = RemedyApp(policy_file(tmp_path), journal_csv=csv_file(tmp_path, rows))
    async with app.run_test() as pilot:
        await app.workers.wait_for_complete()
        assert app.query_one("#results", DataTable).row_count == 0
        assert "inválida" in text(app, "#export-source") if malformed else "0 filas" in text(app, "#export-source")
        assert app.query_one("#previous", Button).disabled
        assert app.query_one("#next", Button).disabled


@pytest.mark.asyncio
async def test_import_does_not_overwrite_initial_id_or_trigger_automatic_lookup(tmp_path):
    from lazyremedy.terminal.tui import RemedyApp
    path = csv_file(tmp_path, [["456", "2026-01-02 00:00:00", "UTC", ""]])
    calls = []
    def reader(incident_id, config):
        calls.append(incident_id)
        return live(incident_id)
    app = RemedyApp(policy_file(tmp_path), journal_csv=path, initial_id="123", reader=reader)
    async with app.run_test() as pilot:
        await app.workers.wait_for_complete()
        await pilot.pause()
        assert calls == ["123"]
        assert app.query_one("#incident-id", Input).value == "123"
        assert "SYN0000000123" in text(app, "#identity")


@pytest.mark.asyncio
async def test_full_opening_date_is_visible_at_minimum_terminal_size(tmp_path):
    from lazyremedy.terminal.tui import RemedyApp
    path = csv_file(tmp_path, [["SYN" + str(i).zfill(10), "2026-01-02 10:00:00", "UTC", ""] for i in range(1, 301)])
    app = RemedyApp(policy_file(tmp_path), journal_csv=path)
    async with app.run_test(size=(100, 30)) as pilot:
        await app.workers.wait_for_complete()
        await pilot.pause()
        visible = "\n".join(strip.text for strip in app.screen._compositor.render_strips())
        assert "2026-01-02 10:00:00" in visible


@pytest.mark.asyncio
@pytest.mark.parametrize("fails", [False, True])
@pytest.mark.parametrize("page_size", [1, 2])
async def test_busy_freezes_export_navigation_and_restores_controls(tmp_path, fails, page_size):
    import asyncio
    import threading
    from lazyremedy.terminal.tui import RemedyApp
    from lazyremedy.terminal.domain import TerminalError

    path = csv_file(tmp_path, [["SYN0000000123", "2026-01-02 00:00:00", "UTC", ""],
                               ["SYN0000000456", "2026-01-01 00:00:00", "UTC", ""]])
    entered, release = threading.Event(), threading.Event()
    calls = []

    def reader(incident_id, config):
        calls.append(incident_id)
        entered.set()
        assert release.wait(10)
        if fails:
            raise TerminalError("auth_user_mismatch")
        return live(incident_id)

    app = RemedyApp(policy_file(tmp_path), journal_csv=path, reader=reader)
    app.PAGE_SIZE = page_size
    async with app.run_test(size=(100, 30)) as pilot:
        await app.workers.wait_for_complete()
        await pilot.pause()
        table = app.query_one("#results", DataTable)
        filter_input = app.query_one("#filter-id", Input)
        assert app.prepare_selection("SYN0000000123")
        table.focus()
        await pilot.press("enter")
        try:
            assert await asyncio.to_thread(entered.wait, 2)
            assert app.busy
            await pilot.press("down")
            await pilot.pause()
            assert table.cursor_row == 0
            assert app._highlighted_row == 0
            assert app.query_one("#incident-id", Input).value == "123"
            for selector in ("#results", "#filter-id", "#previous", "#next", "#search", "#incident-id"):
                assert app.query_one(selector).disabled
            await pilot.click("#next")
            await pilot.click("#filter-id")
            await pilot.press("4", "5", "6")
            assert app.page == 0
            assert filter_input.value == ""
        finally:
            release.set()
            await app.workers.wait_for_complete()
            await pilot.pause()
        assert calls == ["123"]
        assert not app.busy
        assert not table.disabled and not filter_input.disabled
        assert not app.query_one("#search", Button).disabled
        assert not app.query_one("#incident-id", Input).disabled
        assert app.query_one("#previous", Button).disabled
        assert app.query_one("#next", Button).disabled == (page_size == 2)
        assert table.cursor_row == 0
        assert table.get_cell_at((0, 0)).plain == "SYN0000000123"
        assert app.query_one("#incident-id", Input).value == "123"
        if fails:
            assert "Sin incidencia" in text(app, "#identity")
            assert "Sin lectura" in text(app, "#source")
        else:
            assert "SYN0000000123" in text(app, "#identity")
            assert "Ficha sintética" in text(app, "#summary")
        table.focus()
        if page_size == 2:
            await pilot.press("down")
            assert app.query_one("#incident-id", Input).value == "456"
        else:
            await pilot.click("#next")
            assert app.page == 1
            assert app.query_one("#previous", Button).disabled is False
        assert calls == ["123"]
