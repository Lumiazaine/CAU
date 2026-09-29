"""Tests del parser de salida (CSV/TXT)."""

from __future__ import annotations

from pathlib import Path

import pytest

from lazyremedy.errors import SalidaParseError
from lazyremedy.parser import cleanup_output, parse_output

_ENCODING = "cp1252"


def _escribir(path: Path, texto: str) -> Path:
    path.write_text(texto, encoding=_ENCODING, newline="")
    return path


def test_csv_comas(tmp_path):
    path = _escribir(
        tmp_path / "out.txt",
        'ID incidencia,Estado,Importe\r\nINC001,Abierta,"1.234,56"\r\nINC002,Pendiente,0\r\n',
    )
    filas = parse_output(path, _ENCODING)
    assert filas[0]["ID incidencia"] == "INC001"
    assert filas[0]["Importe"] == "1.234,56"
    assert filas[1]["Estado"] == "Pendiente"


def test_csv_punto_y_coma(tmp_path):
    path = _escribir(
        tmp_path / "out.csv",
        "Incidencia;Estado\r\nINC1;Abierta\r\nINC2;Cerrada\r\n",
    )
    filas = parse_output(path, _ENCODING)
    assert filas[0]["Incidencia"] == "INC1"
    assert len(filas) == 2


def test_tsv(tmp_path):
    path = _escribir(tmp_path / "out.tsv", "ID\tEstado\nINC1\tAbierta\n")
    filas = parse_output(path, _ENCODING)
    assert filas[0]["ID"] == "INC1"


def test_clave_valor(tmp_path):
    path = _escribir(
        tmp_path / "out.txt",
        "ID incidencia: INC001\nEstado: Abierta\n\nID incidencia: INC002\nEstado: Cerrada\n",
    )
    filas = parse_output(path, _ENCODING)
    assert filas[0]["ID incidencia"] == "INC001"
    assert filas[1]["Estado"] == "Cerrada"


def test_utf8_bom(tmp_path):
    texto = "\ufeffIncidencia,Estado\nINC1,Abierta\n"
    path = tmp_path / "out_utf8.txt"
    path.write_bytes(texto.encode("utf-8"))
    filas = parse_output(path, _ENCODING)
    assert filas[0]["Incidencia"] == "INC1"


def test_vacio(tmp_path):
    path = _escribir(tmp_path / "out.txt", "")
    assert parse_output(path, _ENCODING) == []


def test_no_existe(tmp_path):
    assert parse_output(tmp_path / "noexiste.txt", _ENCODING) == []


def test_cleanup(tmp_path):
    path = _escribir(tmp_path / "out.txt", "a,b\n1,2\n")
    cleanup_output(path)
    assert not path.exists()
    cleanup_output(path)  # tolera que no exista


def test_columna_unica_sin_cabecera(tmp_path):
    path = _escribir(tmp_path / "out.txt", "INC001\nINC002\n")
    filas = parse_output(path, _ENCODING)
    assert filas[0]["col0"] == "INC001"
    assert len(filas) == 2
