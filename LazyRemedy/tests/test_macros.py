"""Tests del registro de macros predefinidos."""

from __future__ import annotations

import pytest

from lazyremedy.errors import MacroNoEncontradoError
from lazyremedy.macros import list_macros, resolve_macro


def test_registry_completo():
    ids = {m.id for m in list_macros()}
    assert ids == {"CSU", "HELPDESK", "PENDIENTE_USUARIO", "MICROINFORMATICA"}


def test_archivos_esperados():
    archivos = {m.archivo for m in list_macros()}
    assert archivos == {"x1xxxCSU.arq", "x2xxxHEL.arq", "x3xxxPEN.arq", "x5xxxMIC.arq"}


@pytest.mark.parametrize(
    "alias, esperado",
    [
        ("CSU", "CSU"),
        ("helpdesk", "HELPDESK"),
        ("Help-Desk", "HELPDESK"),
        ("pendiente", "PENDIENTE_USUARIO"),
        ("micro", "MICROINFORMATICA"),
        ("MICROINFORMÁTICA", "MICROINFORMATICA"),
    ],
)
def test_aliases(alias, esperado):
    assert resolve_macro(alias).id == esperado


def test_desconocido():
    with pytest.raises(MacroNoEncontradoError):
        resolve_macro("NO_EXISTE")
