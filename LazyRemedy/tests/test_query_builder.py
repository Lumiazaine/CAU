"""Tests del generador de macros de búsqueda dinámica."""

from __future__ import annotations

import pytest

from lazyremedy.errors import CriterioInvalidoError, SinCriteriosError
from lazyremedy.query_builder import build_search_macro


def test_arq_valido_con_campo_1(settings):
    contenido, criterios = build_search_macro(settings, {"incidencia_id": "INC001"})
    assert "Set-schema: 101_INCIDENCIAS\x0110.241.130.25" in contenido
    assert "Query: \x011=INC001" in contenido
    assert "Form-final: modify\x01@" in contenido
    assert contenido.endswith("end\r\n")
    assert criterios == {"incidencia_id": "INC001"}


def test_arq_con_varios_criterios(settings):
    contenido, _ = build_search_macro(
        settings, {"usuario_temis": "12345678Z", "telefono": "955000001"}
    )
    assert "1010000170=12345678Z" in contenido
    assert "1010000167=955000001" in contenido


def test_sin_criterios_levanta_error(settings):
    with pytest.raises(SinCriteriosError):
        build_search_macro(settings, {})


def test_criterios_vacios_ignorados(settings):
    _, criterios = build_search_macro(settings, {"incidencia_id": "  ", "correo": "x@y.es"})
    assert criterios == {"correo": "x@y.es"}


def test_criterio_sin_campo_mapeado(settings):
    settings = settings.model_copy(
        update={"search_field_map": {"incidencia_id": "1", "correo": "", "usuario_temis": "", "telefono": ""}}
    )
    with pytest.raises(CriterioInvalidoError):
        build_search_macro(settings, {"usuario_temis": "12345678Z"})


def test_criterio_desconocido(settings):
    with pytest.raises(CriterioInvalidoError):
        build_search_macro(settings, {"otra_cosa": "valor"})
