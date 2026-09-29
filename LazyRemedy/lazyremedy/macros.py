"""Registro de macros predefinidas de Remedy.

Los macros viven en OneDrive (``ARCmds``) y se mapean por ID a archivos ``.arq``.
La ejecución de estos ficheros está fuera de la API: runmacro.exe los dispara.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from .errors import MacroNoEncontradoError


@dataclass(frozen=True)
class MacroRef:
    """Referencia a un macro predefinido."""

    id: str
    archivo: str
    descripcion: str

    def ruta(self, macro_dir: Path) -> Path:
        return macro_dir / self.archivo


#: Registro canónico. Los IDs son los que se usan en API y MCP.
MACRO_REGISTRY: dict[str, MacroRef] = {
    "CSU": MacroRef(
        id="CSU",
        archivo="x1xxxCSU.arq",
        descripcion="Centro de Servicio al Usuario (incidencias CSU)",
    ),
    "HELPDESK": MacroRef(
        id="HELPDESK",
        archivo="x2xxxHEL.arq",
        descripcion="Help-Desk (incidencias de mesa de ayuda)",
    ),
    "PENDIENTE_USUARIO": MacroRef(
        id="PENDIENTE_USUARIO",
        archivo="x3xxxPEN.arq",
        descripcion="Pendiente de usuario (incidencias en espera)",
    ),
    "MICROINFORMATICA": MacroRef(
        id="MICROINFORMATICA",
        archivo="x5xxxMIC.arq",
        descripcion="Microinformática (incidencias de equipos y periféricos)",
    ),
}

#: Alias tolerados (mayúsculas/minúsculas y variantes comunes).
MACRO_ALIASES: dict[str, str] = {
    "CSU": "CSU",
    "HELPDESK": "HELPDESK",
    "HELP_DESK": "HELPDESK",
    "HELP-DESK": "HELPDESK",
    "HELP DESK": "HELPDESK",
    "PENDIENTE_USUARIO": "PENDIENTE_USUARIO",
    "PENDIENTE": "PENDIENTE_USUARIO",
    "PENDIENTES": "PENDIENTE_USUARIO",
    "PENDIENTES_USUARIO": "PENDIENTE_USUARIO",
    "MICROINFORMATICA": "MICROINFORMATICA",
    "MICROINFORMÁTICA": "MICROINFORMATICA",
    "MICRO": "MICROINFORMATICA",
    "MICROINFORMATICA_": "MICROINFORMATICA",
}


def list_macros() -> list[MacroRef]:
    """Devuelve todos los macros predefinidos en orden canónico."""
    return list(MACRO_REGISTRY.values())


def resolve_macro(macro_id: str) -> MacroRef:
    """Resuelve un ID/alias a su MacroRef. Lanza MacroNoEncontradoError si no existe."""
    key = (macro_id or "").strip().upper()
    canonical = MACRO_ALIASES.get(key)
    if canonical is None:
        raise MacroNoEncontradoError(
            f"Macro '{macro_id}' no registrado.",
            detail=f"IDs válidos: {', '.join(MACRO_REGISTRY.keys())}",
        )
    return MACRO_REGISTRY[canonical]
