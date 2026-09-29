"""Fixtures compartidos de los tests de LazyRemedy."""

from __future__ import annotations

import pytest

from lazyremedy.config import Settings


@pytest.fixture
def settings(tmp_path) -> Settings:
    """Configuración en modo mock con directorios temporales aislados."""
    return Settings(
        mock=True,
        cross_process_lock=False,
        output_dir=str(tmp_path),
        runmacro_timeout_sec=5.0,
        output_timeout_sec=2.0,
        output_poll_interval=0.01,
        output_stable_checks=1,
        search_field_map={
            "incidencia_id": "1",
            "usuario_temis": "1010000170",
            "correo": "536871059",
            "telefono": "1010000167",
        },
    )


@pytest.fixture
def service(settings):
    from lazyremedy.service import RemedyService

    return RemedyService(settings)
