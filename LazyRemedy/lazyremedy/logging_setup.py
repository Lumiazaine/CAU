"""Configuración del logging de LazyRemedy (mensajes en español)."""

from __future__ import annotations

import logging
import sys

_FORMAT = "%(asctime)s - %(name)s - [%(levelname)s] %(message)s"


def setup_logging(level: str = "INFO") -> logging.Logger:
    """Configura el logger raíz una sola vez y devuelve el de la app."""
    root = logging.getLogger()
    if not any(isinstance(h, logging.StreamHandler) for h in root.handlers):
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(logging.Formatter(_FORMAT))
        root.addHandler(handler)
    root.setLevel(level.upper())
    return logging.getLogger("lazyremedy")
