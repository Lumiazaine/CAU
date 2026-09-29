"""Backends de datos de Remedy (solo lectura). Selección por settings.backend."""

from __future__ import annotations

from .base import RemedyBackend
from .macro import MacroBackend
from .midtier import MidtierBackend

__all__ = ["RemedyBackend", "MacroBackend", "MidtierBackend"]
