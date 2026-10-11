"""Bounded snapshot import tests, independent of the optional Textual extra."""
import csv
import io
from datetime import datetime, timezone
import pytest
from lazyremedy.terminal.domain import TerminalError

SCHEMA = ["ID incidencia", "Fecha apertura", "Zona horaria", "Advertencia"]


def csv_file(tmp_path, rows, header=SCHEMA):
    path = tmp_path / "synthetic.csv"
    with path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.writer(stream, delimiter=";")
        writer.writerow(header)
        writer.writerows(rows)
    return path


def test_snapshot_validates_every_row_sorts_dates_and_id_ties(tmp_path):
    from lazyremedy.terminal.snapshot import load_snapshot
    rows = [["9", "2026-01-02 10:00:00", "UTC", ""],
            ["11", "02/01/2026 10:00:00", "UTC", "[red]texto[/red]"],
            ["10", "2026-01-01 23:00:00", "UTC", ""],
            ["SYN0000000123", "2026-01-03 10:00:00", "UTC", ""]]
    path = csv_file(tmp_path, rows)
    snapshot = load_snapshot(path)
    assert [row.incident_id for row in snapshot.rows] == ["SYN0000000123", "11", "9", "10"]
    assert snapshot.count == 4
    assert snapshot.mtime == datetime.fromtimestamp(path.stat().st_mtime, timezone.utc)
    assert snapshot.rows[1].warning == "[red]texto[/red]"
    assert snapshot.filter_ids("0000000123") == [snapshot.rows[0]]
    assert snapshot.filter_ids("[red]") == []


@pytest.mark.parametrize("bad_rows", [
    [["123", "2026-02-30 00:00:00", "UTC", ""]],
    [["123", "bad date", "UTC", ""]],
    [["123", "2026-01-01 00:00:00", "UTC", ""], ["123", "2026-01-02 00:00:00", "UTC", ""]],
    [["0123", "2026-01-01 00:00:00", "UTC", ""]],
    [[" 123", "2026-01-01 00:00:00", "UTC", ""]],
    [["123", "2026-01-01 00:00:00", "UTC"]],
    [["123", "2026-01-01 00:00:00", "UTC", "", "extra"]],
    [["123", "2026-01-01 00:00:00", "UTC", "x" * 1025]],
    [["123", "2026-01-01 00:00:00", "UTC", ""], ["456", "invalid", "UTC", ""]],
])
def test_malformed_rows_reject_entire_export(tmp_path, bad_rows):
    from lazyremedy.terminal.snapshot import load_snapshot
    with pytest.raises(TerminalError, match="^snapshot_invalid$"):
        load_snapshot(csv_file(tmp_path, bad_rows))


@pytest.mark.parametrize("header", [SCHEMA[::-1], SCHEMA + ["extra"], ["ID", "date", "zone", "warning"]])
def test_schema_is_exact(tmp_path, header):
    from lazyremedy.terminal.snapshot import load_snapshot
    with pytest.raises(TerminalError, match="^snapshot_invalid$"):
        load_snapshot(csv_file(tmp_path, [], header))


def test_empty_export_and_missing_file(tmp_path):
    from lazyremedy.terminal.snapshot import load_snapshot
    assert load_snapshot(csv_file(tmp_path, [])).count == 0
    with pytest.raises(TerminalError, match="^snapshot_invalid$"):
        load_snapshot(tmp_path / "missing.csv")


@pytest.mark.parametrize("payload", [b"", b"ID incidencia;Fecha apertura;Zona horaria;Advertencia\n", b"\xef\xbb\xbf\xff"])
def test_utf8_bom_is_required(tmp_path, payload):
    from lazyremedy.terminal.snapshot import load_snapshot
    path = tmp_path / "bad.csv"
    path.write_bytes(payload)
    with pytest.raises(TerminalError, match="^snapshot_invalid$"):
        load_snapshot(path)


def test_row_and_byte_bounds_are_fail_closed(tmp_path, monkeypatch):
    from lazyremedy.terminal import snapshot
    path = csv_file(tmp_path, [["123", "2026-01-01 00:00:00", "UTC", ""], ["456", "2026-01-02 00:00:00", "UTC", ""]])
    monkeypatch.setattr(snapshot, "MAX_ROWS", 1)
    with pytest.raises(TerminalError, match="^snapshot_invalid$"):
        snapshot.load_snapshot(path)
    monkeypatch.setattr(snapshot, "MAX_ROWS", 100000)
    monkeypatch.setattr(snapshot, "MAX_BYTES", 5)
    with pytest.raises(TerminalError, match="^snapshot_invalid$"):
        snapshot.load_snapshot(path)


def test_all_90000_rows_are_validated_and_counted(tmp_path):
    from lazyremedy.terminal.snapshot import load_snapshot
    rows = ([str(i), "2026-01-01 00:00:00", "UTC", ""] for i in range(1, 90001))
    snapshot = load_snapshot(csv_file(tmp_path, rows))
    assert snapshot.count == 90000
    assert snapshot.rows[0].incident_id == "90000"
    assert snapshot.rows[-1].incident_id == "1"
    assert len(snapshot.filter_ids("90000")) == 1


def test_canonical_selection_uses_exact_policy_not_input_repair():
    from lazyremedy.terminal.snapshot import numeric_selection
    spec = {"prefix": "SYN", "digits": 10}
    assert numeric_selection("SYN0000000123", spec) == "123"
    assert numeric_selection("123", spec) == "123"
    for bad in ("0123", "OTHER0000000123", "SYN123", "SYN0000000000", "SYN0000000123 "):
        with pytest.raises(TerminalError):
            numeric_selection(bad, spec)
