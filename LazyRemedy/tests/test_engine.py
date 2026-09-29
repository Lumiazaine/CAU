"""Tests del motor de ejecución (modo mock)."""

from __future__ import annotations

import asyncio

from lazyremedy.engine import RemedyEngine


def _macro_y_salida(tmp_path, nombre="macro_test.arq"):
    macro = tmp_path / nombre
    macro.write_text("demo", encoding="cp1252")
    salida = tmp_path / f"salida_{nombre}.txt"
    return macro, salida


def test_ejecucion_mock_devuelve_filas(settings):
    engine = RemedyEngine(settings)
    macro, salida = _macro_y_salida(settings.output_path)
    filas = asyncio.run(engine.execute_macro(macro, salida))
    assert len(filas) == 2
    assert filas[0]["ID incidencia"] == "INC001"


def test_salida_temporal_se_limpia(settings):
    engine = RemedyEngine(settings)
    macro, salida = _macro_y_salida(settings.output_path)
    asyncio.run(engine.execute_macro(macro, salida))
    assert not salida.exists()


def test_ejecuciones_concurrentes_serializadas(settings):
    """runmacro no soporta concurrencia: el cerrojo debe encolarlas sin fallar."""
    engine = RemedyEngine(settings)

    async def _una(nombre):
        macro, salida = _macro_y_salida(settings.output_path, nombre)
        filas = await engine.execute_macro(macro, salida)
        return len(filas)

    async def _main():
        return await asyncio.gather(_una("a.arq"), _una("b.arq"), _una("c.arq"))

    totales = asyncio.run(_main())
    assert totales == [2, 2, 2]
    assert engine._proc_count == 0


def test_preflight_mock(settings):
    engine = RemedyEngine(settings)
    info = engine.preflight()
    assert info["mock"] is True
    assert "runmacro_exe" in info
