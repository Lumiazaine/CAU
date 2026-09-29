"""Generación de macros ``.arq`` dinámicos para búsquedas.

El formato se replica del que usan los macros reales de ``ARCmds``:
separadores ``\\x01`` (SOH), líneas CRLF y codificación Windows-1252.
"""

from __future__ import annotations

from pathlib import Path
from typing import Iterable

from .config import Settings
from .errors import CriterioInvalidoError, SinCriteriosError

#: Orden canónico de los criterios de búsqueda (estabilidad del macro).
CRITERIOS_SOPORTADOS: tuple[str, ...] = (
    "incidencia_id",
    "usuario_temis",
    "correo",
    "telefono",
)

#: Etiquetas legibles para logs / mensajes.
CRITERIO_LABELS: dict[str, str] = {
    "incidencia_id": "ID incidencia",
    "usuario_temis": "Usuario Temis (DNI)",
    "correo": "Correo funcionario",
    "telefono": "Teléfono",
}


def _normalize(criterios: dict[str, str]) -> dict[str, str]:
    """Filtra criterios vacíos y lanza SinCriteriosError si no queda ninguno."""
    limpios = {k: (v or "").strip() for k, v in criterios.items() if (v or "").strip()}
    if not limpios:
        raise SinCriteriosError(
            "Debe indicarse al menos un criterio de búsqueda.",
            detail="Criterios válidos: " + ", ".join(CRITERIOS_SOPORTADOS),
        )
    return limpios


def _field_ids(settings: Settings, criterios: dict[str, str]) -> dict[str, str]:
    """Traduce criterios -> (campo, valor). Valida el mapeo de campos."""
    result: dict[str, str] = {}
    faltantes: list[str] = []
    for criterio, valor in criterios.items():
        if criterio not in CRITERIOS_SOPORTADOS:
            raise CriterioInvalidoError(
                f"Criterio '{criterio}' no soportado.",
                detail="Criterios válidos: " + ", ".join(CRITERIOS_SOPORTADOS),
            )
        field_id = settings.field_id_for(criterio)
        if not field_id:
            faltantes.append(f"{criterio} ({CRITERIO_LABELS[criterio]})")
            continue
        result[field_id] = valor
    if faltantes:
        raise CriterioInvalidoError(
            "No hay campo Remedy configurado para los criterios indicados.",
            detail=(
                "Configura 'search_field_map' en lazyremedy.config.json. Faltan: "
                + ", ".join(faltantes)
            ),
        )
    return result


def map_criterios_a_campos(settings: Settings, criterios: dict[str, str]) -> dict[str, str]:
    """Traduce criterios de búsqueda a ``{campo Remedy -> valor}``.

    Normaliza (elimina vacíos, exige al menos uno) y valida el mapeo de campos.
    Lanza SinCriteriosError / CriterioInvalidoError. Usado por los backends
    ``macro`` y ``midtier`` para construir sus consultas.
    """
    return _field_ids(settings, _normalize(criterios))


def build_search_macro(
    settings: Settings, criterios: dict[str, str]
) -> tuple[str, dict[str, str]]:
    """Construye el contenido de un macro ``.arq`` de búsqueda dinámica.

    Devuelve (texto_del_macro, criterios_normalizados).
    """
    limpios = _normalize(criterios)
    campos = _field_ids(settings, limpios)

    query = "\x01".join(f"{field}={valor}" for field, valor in campos.items())
    lines = [
        "BUSQUEDA DINAMICA",
        f"Set-schema: {settings.remedy_schema}\x01{settings.remedy_server}",
        f"Query: \x01{query}",
        "Form-open: ",
        "Form-entry-list: 0",
        "Form-final: modify\x01@",
        "end",
    ]
    return "\r\n".join(lines) + "\r\n", limpios


def write_macro_file(settings: Settings, content: str, path: Path) -> Path:
    """Escribe el macro en disco con codificación Windows-1252."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="cp1252", newline="") as fh:
        fh.write(content)
    return path


def criterios_descripcion(criterios: Iterable[tuple[str, str]]) -> str:
    """Descripción legible de los criterios aplicados (para logs y MCP)."""
    return "; ".join(
        f"{CRITERIO_LABELS.get(k, k)}={v}" for k, v in criterios
    )
