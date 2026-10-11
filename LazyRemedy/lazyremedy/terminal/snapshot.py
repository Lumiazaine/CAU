"""Bounded local export import. It never supplies a live incident detail."""
from __future__ import annotations

import codecs
import csv
from dataclasses import dataclass
from datetime import datetime, timezone
import io
import os
from pathlib import Path
import re
import stat

from .domain import TerminalError
from .windows_readonly import _numeric_id

SCHEMA = ["ID incidencia", "Fecha apertura", "Zona horaria", "Advertencia"]
MAX_BYTES = 64 * 1024 * 1024
MAX_ROWS = 100000
FIELD_LIMITS = (61, 35, 128, 1024)
CANONICAL = re.compile(r"[A-Z][A-Z0-9_-]{0,29}[0-9]{1,30}")


@dataclass(frozen=True)
class ExportRow:
    incident_id: str
    opening: str
    zone: str
    warning: str
    opening_date: datetime


@dataclass(frozen=True)
class Snapshot:
    rows: tuple[ExportRow, ...]
    mtime: datetime

    @property
    def count(self):
        return len(self.rows)

    def filter_ids(self, query: str) -> list[ExportRow]:
        """Literal, ID-only substring filtering; no query to Remedy."""
        return [row for row in self.rows if query in row.incident_id]


def _date(value: str) -> datetime:
    for pattern, fmt in ((r"[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}", "%Y-%m-%d %H:%M:%S"),
                         (r"[0-9]{2}/[0-9]{2}/[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}", "%d/%m/%Y %H:%M:%S")):
        if re.fullmatch(pattern, value):
            return datetime.strptime(value, fmt)
    raise ValueError("date")


def load_snapshot(path) -> Snapshot:
    """Reject the whole file on any invalid row; never expose paths/error text."""
    try:
        with Path(path).open("rb") as stream:
            before = os.fstat(stream.fileno())
            if not stat.S_ISREG(before.st_mode) or before.st_size > MAX_BYTES:
                raise ValueError("file bounds")
            payload = stream.read(MAX_BYTES + 1)
            after = os.fstat(stream.fileno())
            if (len(payload) > MAX_BYTES or len(payload) != before.st_size
                    or (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns)):
                raise ValueError("changed export")
        if not payload.startswith(codecs.BOM_UTF8):
            raise ValueError("BOM")
        data = payload.decode("utf-8-sig", errors="strict")
        reader = csv.reader(io.StringIO(data, newline=""), delimiter=";", strict=True)
        if next(reader, None) != SCHEMA:
            raise ValueError("schema")
        rows = []
        seen = set()
        for raw in reader:
            if (len(rows) >= MAX_ROWS or len(raw) != 4
                    or any(len(value) > bound for value, bound in zip(raw, FIELD_LIMITS))):
                raise ValueError("row bounds")
            incident_id, opening, zone, warning = raw
            if (not (_numeric_id(incident_id) or CANONICAL.fullmatch(incident_id))
                    or incident_id in seen):
                raise ValueError("identity")
            parsed = _date(opening)
            seen.add(incident_id)
            rows.append(ExportRow(incident_id, opening, zone, warning, parsed))
        rows.sort(key=lambda row: (row.opening_date, int(re.search(r"[0-9]+$", row.incident_id).group()), row.incident_id), reverse=True)
        return Snapshot(tuple(rows), datetime.fromtimestamp(before.st_mtime, timezone.utc))
    except (OSError, ValueError, TypeError, OverflowError, csv.Error):
        raise TerminalError("snapshot_invalid") from None


def numeric_selection(incident_id: str, identity: dict | None) -> str:
    """Convert only policy-confirmed canonical export IDs, never repair user input."""
    if _numeric_id(incident_id):
        return incident_id
    if identity:
        prefix, digits = identity["prefix"], identity["digits"]
        if incident_id.startswith(prefix) and len(incident_id) == len(prefix) + digits:
            suffix = incident_id[len(prefix):]
            if re.fullmatch(r"[0-9]+", suffix):
                numeric = suffix.lstrip("0")
                if _numeric_id(numeric) and prefix + numeric.zfill(digits) == incident_id:
                    return numeric
    raise TerminalError("invalid_incident_id")
