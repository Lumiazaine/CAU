"""Modelos Pydantic de peticiones y respuestas de la API REST."""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field, model_validator

from .errors import SinCriteriosError
from .query_builder import CRITERIOS_SOPORTADOS


class SearchRequest(BaseModel):
    """Búsqueda dinámica de incidencias. Al menos un criterio es obligatorio."""

    incidencia_id: str | None = Field(default=None, description="ID de incidencia")
    usuario_temis: str | None = Field(default=None, description="Usuario Temis (DNI)")
    correo: str | None = Field(default=None, description="Correo funcionario")
    telefono: str | None = Field(default=None, description="Teléfono")

    @model_validator(mode="after")
    def _validar_al_menos_un_criterio(self) -> "SearchRequest":
        if not any(
            (getattr(self, criterio) or "").strip()
            for criterio in CRITERIOS_SOPORTADOS
        ):
            raise SinCriteriosError(
                "Debe indicarse al menos un criterio de búsqueda: "
                + ", ".join(CRITERIOS_SOPORTADOS)
            )
        return self

    def to_criterios(self) -> dict[str, str]:
        """Devuelve solo los criterios con valor, listos para la búsqueda."""
        return {
            criterio: str(getattr(self, criterio)).strip()
            for criterio in CRITERIOS_SOPORTADOS
            if (getattr(self, criterio) or "").strip()
        }


class SearchResponse(BaseModel):
    """Resultado estructurado de una búsqueda."""

    criterios: dict[str, str]
    total: int
    resultados: list[dict[str, Any]]
    ejecucion_ms: int


class MacroRunResponse(BaseModel):
    """Resultado de la ejecución de un macro predefinido."""

    macro: str
    archivo: str
    total: int
    filas: list[dict[str, Any]]
    ejecucion_ms: int


class MacroInfo(BaseModel):
    """Descripción de un macro predefinido disponible."""

    id: str
    archivo: str
    descripcion: str
    ruta: str


class HealthResponse(BaseModel):
    """Estado de la infraestructura de LazyRemedy."""

    status: str
    version: str
    backend: str = "macro"
    mock: bool = False
    runmacro_exe: str | None = None
    runmacro_existe: bool = False
    macro_dir: str | None = None
    macro_dir_existe: bool = False
    midtier_url: str | None = None
    config_pendiente: bool | None = None
    login_pendiente: bool | None = None
