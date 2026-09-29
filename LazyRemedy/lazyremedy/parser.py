"""Parseo de la salida en disco (CSV/TXT) generada por Remedy.

Auto-detección de formato:
- Líneas ``clave: valor`` / ``clave=valor`` -> diccionario.
- CSV/TSV con cabecera -> lista de diccionarios (detección de delimitador).
- Columna única sin cabecera -> ``col0``/``col1``...

El archivo temporal se elimina siempre que se lee (responsabilidad del llamante
vía ``cleanup_output``).
"""

from __future__ import annotations

import csv
import io
import re
from pathlib import Path
from typing import Any

from .errors import SalidaParseError

_DELIM_CANDIDATES = (",", ";", "\t", "|")

_KV_RE = re.compile(r"^\s*([A-Za-z0-9_áéíóúñÁÉÍÓÚÑ\-\. ]{2,60})\s*[:=]\s*(.+)$")


def _read_text(path: Path, encoding: str, fallback_encoding: str) -> str:
    raw = path.read_bytes()
    # BOM UTF-8 -> decodificar como UTF-8 directamente.
    if raw.startswith(b"\xef\xbb\xbf"):
        return raw.decode("utf-8-sig", errors="replace")
    for enc in (encoding, fallback_encoding):
        try:
            return raw.decode(enc)
        except (UnicodeDecodeError, LookupError):
            continue
    return raw.decode("utf-8", errors="replace")


def _normalize_header(name: str) -> str:
    return re.sub(r"\s+", " ", name.strip())


def _looks_like_kv(text: str, sample_lines: list[str]) -> bool:
    """Heurística: al menos 2 líneas siguen el patrón clave: valor."""
    matched = 0
    for line in sample_lines[:10]:
        if _KV_RE.match(line):
            matched += 1
    return matched >= 2


def _parse_kv(text: str) -> list[dict[str, str]]:
    filas: list[dict[str, str]] = []
    actual: dict[str, str] = {}
    for line in text.splitlines():
        if not line.strip():
            if actual:
                filas.append(actual)
                actual = {}
            continue
        match = _KV_RE.match(line)
        if match:
            clave = _normalize_header(match.group(1))
            actual[clave] = match.group(2).strip()
        elif actual:
            # Continuación del valor anterior (descripciones multilínea).
            clave = next(reversed(actual))
            actual[clave] = f"{actual[clave]}\n{line.strip()}"
    if actual:
        filas.append(actual)
    return filas


def _count_delimiter(text: str, delim: str) -> int:
    """Cuenta delimitadores fuera de comillas en las primeras 20 líneas."""
    count = 0
    for line in text.splitlines()[:20]:
        in_quotes = False
        for ch in line:
            if ch == '"':
                in_quotes = not in_quotes
            elif ch == delim and not in_quotes:
                count += 1
    return count


def _detect_delimiter(text: str) -> str:
    best, best_count = text[0] if text else ",", -1
    for delim in _DELIM_CANDIDATES:
        count = _count_delimiter(text, delim)
        if count > best_count:
            best, best_count = delim, count
    return best


def _parse_delimited(text: str) -> list[dict[str, str]]:
    delim = _detect_delimiter(text)
    delim_present = _count_delimiter(text, delim) > 0
    try:
        reader = csv.DictReader(io.StringIO(text), delimiter=delim)
        headers = [_normalize_header(h) for h in (reader.fieldnames or [])]
        filas = []
        for raw in reader:
            fila: dict[str, str] = {}
            for i, header in enumerate(headers):
                fila[header] = (raw.get(reader.fieldnames[i]) or "").strip()
            if fila:
                filas.append(fila)
        if (filas or headers) and (delim_present or len(headers) > 1):
            return filas
    except csv.Error:
        raise SalidaParseError(
            "La salida parece delimitada pero no se pudo leer como CSV.",
        )
    # Sin delimitador real: cada línea es una fila de una única columna.
    return [
        {"col0": line.strip()}
        for line in text.splitlines()
        if line.strip()
    ]


def parse_output(path: Path, encoding: str = "cp1252", fallback_encoding: str = "utf-8") -> list[dict[str, Any]]:
    """Lee, parsea y devuelve las filas estructuradas del archivo de salida."""
    if not path.exists() or path.stat().st_size == 0:
        return []
    text = _read_text(path, encoding, fallback_encoding)
    lines = [l for l in text.splitlines() if l.strip()]
    if not lines:
        return []

    if _looks_like_kv(text, lines):
        return _parse_kv(text)

    filas = _parse_delimited(text)
    if not filas:
        raise SalidaParseError(
            "No se obtuvieron filas interpretables de la salida de Remedy.",
            detail=str(path),
        )
    return filas


def cleanup_output(path: Path) -> None:
    """Elimina el archivo temporal tolerando que ya no exista."""
    try:
        path.unlink(missing_ok=True)
    except OSError:
        pass
