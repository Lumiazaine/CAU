"""Configuración de LazyRemedy.

Los valores se leen, por orden de precedencia (menor a mayor):
1. Valores por defecto del código.
2. Variables de entorno con prefijo ``LAZYREMEDY_`` (p.ej. ``LAZYREMEDY_MOCK=1``).
3. Archivo de configuración JSON (--config / ``LAZYREMEDY_CONFIG``).

Todas las rutas están pensadas para el entorno corporativo de Justicia
(Windows 7/10, OneDrive, red interna).
"""

from __future__ import annotations

import json
import os
import tempfile
from pathlib import Path
from typing import Any

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

#: Ruta por defecto del ejecutable runmacro de BMC Remedy User.
DEFAULT_RUNMACRO_EXE = r"C:\Program Files (x86)\AR System\User\runmacro.exe"
#: Ruta por defecto de los macros .arq (OneDrive corporativo).
DEFAULT_MACRO_DIR = r"C:\Users\CAU\OneDrive - AYESA\ARCmds"
#: Servidor Remedy visto en los .arq existentes.
DEFAULT_REMEDY_SERVER = "10.241.130.25"
#: Esquema (formulario) de incidencias visto en los .arq existentes.
DEFAULT_REMEDY_SCHEMA = "101_INCIDENCIAS"

#: Mapeo criterio de búsqueda -> ID de campo Remedy (esquema 101_INCIDENCIAS).
#: IDs reales extraídos de la macro de prueba de Remedy:
#:   - incidencia_id -> 1 (Request ID, universal en Remedy).
#:   - usuario_temis  -> 1010000170 (DNI del usuario).
#:   - correo         -> 536871059  (correo corporativo del funcionario).
#:   - telefono       -> 1010000167 (teléfono de contacto de la incidencia).
DEFAULT_SEARCH_FIELD_MAP: dict[str, str] = {
    "incidencia_id": "1",
    "usuario_temis": "1010000170",
    "correo": "536871059",
    "telefono": "1010000167",
}


class Settings(BaseSettings):
    """Configuración central de LazyRemedy."""

    model_config = SettingsConfigDict(
        env_prefix="LAZYREMEDY_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # --- Remedy ---------------------------------------------------------
    remedy_runmacro: str = DEFAULT_RUNMACRO_EXE
    remedy_server: str = DEFAULT_REMEDY_SERVER
    remedy_schema: str = DEFAULT_REMEDY_SCHEMA
    remedy_user: str = ""
    remedy_password: str = ""
    remedy_macro_dir: str = DEFAULT_MACRO_DIR
    #: Argumentos extra para runmacro.exe (insertados antes del macro). P.ej.
    #: ["-r", "servidor", "-u", "usuario", "-p", "pass"] si el host lo exige.
    runmacro_args: list[str] = Field(default_factory=list)

    # --- Tiempos --------------------------------------------------------
    runmacro_timeout_sec: float = 120.0
    output_timeout_sec: float = 30.0
    output_poll_interval: float = 0.25
    output_stable_checks: int = 2
    lock_timeout_sec: float = 300.0

    # --- Salida / parseo ------------------------------------------------
    output_dir: str = Field(default_factory=lambda: tempfile.gettempdir())
    output_encoding: str = "cp1252"
    output_fallback_encoding: str = "utf-8"

    # --- Búsqueda dinámica ----------------------------------------------
    search_field_map: dict[str, str] = Field(default_factory=dict)

    # --- Modo operativo -------------------------------------------------
    #: Backend de datos: "midtier" (Mid Tier web), "macro" (runmacro.exe) o "mock".
    backend: str = "macro"
    mock: bool = False
    cross_process_lock: bool = True

    # --- Mid Tier (backend HTTP) ----------------------------------------
    midtier_url: str = ""
    midtier_verify_ssl: bool = False
    midtier_timeout_sec: float = 15.0

    # --- Servidores -----------------------------------------------------
    host: str = "127.0.0.1"
    port: int = 8000
    mcp_port: int = 8100
    log_level: str = "INFO"
    cors_origins: list[str] = Field(default_factory=lambda: ["*"])

    @field_validator("search_field_map", mode="before")
    @classmethod
    def _merge_search_field_map(cls, v: Any) -> dict[str, str]:
        merged = dict(DEFAULT_SEARCH_FIELD_MAP)
        if isinstance(v, dict):
            # Tolera IDs numéricos (enteros JSON) y los normaliza a string.
            merged.update({k: str(val) for k, val in v.items()})
        return merged

    @field_validator("backend")
    @classmethod
    def _validar_backend(cls, v: str) -> str:
        if v not in ("midtier", "macro", "mock"):
            raise ValueError(
                f"backend inválido '{v}': use 'midtier', 'macro' o 'mock'"
            )
        return v

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------
    @property
    def runmacro_path(self) -> Path:
        return Path(self.remedy_runmacro).expanduser()

    @property
    def macro_dir(self) -> Path:
        return Path(self.remedy_macro_dir).expanduser()

    @property
    def output_path(self) -> Path:
        return Path(self.output_dir).expanduser()

    def field_id_for(self, criterio: str) -> str | None:
        """Devuelve el ID de campo Remedy para un criterio o None si no está mapeado."""
        value = self.search_field_map.get(criterio)
        return str(value) if value else None

    def to_dict(self) -> dict[str, Any]:
        """Representación serializable para diagnóstico (sin credenciales)."""
        data = self.model_dump(exclude={"remedy_password", "remedy_user"})
        data["mock"] = self.mock
        data["cross_process_lock"] = self.cross_process_lock
        return data


def _load_json_config(path: str | Path) -> dict[str, Any]:
    """Carga un archivo JSON de configuración. Silencioso si no existe.

    Usa ``utf-8-sig`` para tolerar el BOM que añaden los editores de Windows
    (Notepad/PowerShell), además de UTF-8 plano.
    """
    config_path = Path(path).expanduser()
    if not config_path.exists():
        return {}
    with config_path.open("r", encoding="utf-8-sig") as fh:
        return json.load(fh)


def load_settings(config_file: str | Path | None = None) -> Settings:
    """Construye Settings aplicando el archivo JSON (mayor precedencia)."""
    config_path: str | Path | None = config_file or os.getenv("LAZYREMEDY_CONFIG")
    overrides: dict[str, Any] = {}
    if config_path:
        overrides = _load_json_config(config_path)
    return Settings(**overrides)


def default_config_example() -> str:
    """Genera un ejemplo de archivo de configuración JSON con los valores por defecto."""
    settings = Settings()
    data = settings.to_dict()
    return json.dumps(data, indent=4, ensure_ascii=False)
