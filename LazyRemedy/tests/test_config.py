"""Tests de configuración: carga JSON (incluido BOM de Windows) y mapeo de campos."""

from __future__ import annotations

from pathlib import Path

from lazyremedy.config import DEFAULT_SEARCH_FIELD_MAP, Settings, load_settings


def test_mapeo_campos_por_defecto():
    assert DEFAULT_SEARCH_FIELD_MAP == {
        "incidencia_id": "1",
        "usuario_temis": "1010000170",
        "correo": "536871059",
        "telefono": "1010000167",
    }


def test_field_id_for_normaliza_a_string():
    settings = Settings(search_field_map={"incidencia_id": 1})
    assert settings.field_id_for("incidencia_id") == "1"


def test_load_json_con_bom_utf8(tmp_path):
    """Regresión: editores de Windows añaden BOM; la carga no debe fallar."""
    cfg = tmp_path / "config.json"
    cfg.write_bytes('{"mock": true}'.encode("utf-8-sig"))
    settings = load_settings(cfg)
    assert settings.mock is True


def test_load_json_sin_bom(tmp_path):
    cfg = tmp_path / "config.json"
    cfg.write_text('{"mock": true}', encoding="utf-8")
    settings = load_settings(cfg)
    assert settings.mock is True


def test_load_json_no_existe(tmp_path):
    settings = load_settings(tmp_path / "noexiste.json")
    assert settings.mock is False


def test_runmacro_args_se_preservan(tmp_path):
    cfg = tmp_path / "config.json"
    cfg.write_text(
        '{"runmacro_args": ["-r", "server", "-u", "user"]}', encoding="utf-8"
    )
    settings = load_settings(cfg)
    assert settings.runmacro_args == ["-r", "server", "-u", "user"]


def test_search_field_map_se_fusiona_con_defaults(tmp_path):
    """Un mapeo parcial no pierde los campos por defecto."""
    cfg = tmp_path / "config.json"
    cfg.write_text('{"search_field_map": {"correo": "999"}}', encoding="utf-8")
    settings = load_settings(cfg)
    assert settings.field_id_for("correo") == "999"
    assert settings.field_id_for("incidencia_id") == "1"
