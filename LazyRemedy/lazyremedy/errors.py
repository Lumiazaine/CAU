"""Jerarquía de excepciones de LazyRemedy.

Cada excepción mapea a un código HTTP estándar y a un mensaje descriptivo
que también se devuelve a los agentes que consumen el servidor MCP.
"""

from __future__ import annotations


class LazyRemedyError(Exception):
    """Excepción base de LazyRemedy."""

    #: Código HTTP estándar asociado.
    http_status = 500
    #: Tipo corto para diagnósticos (p.ej. "timeout_remedy").
    error_code = "error_generico"

    def __init__(self, message: str, detail: str | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.detail = detail

    def as_http(self) -> dict:
        """Cuerpo JSON estándar para respuestas de error."""
        return {
            "error": self.error_code,
            "mensaje": self.message,
            "detalle": self.detail or None,
        }

    def as_mcp(self) -> dict:
        """Representación para herramientas MCP (siempre serializable)."""
        return self.as_http()


class ConfiguracionInvalidaError(LazyRemedyError):
    http_status = 500
    error_code = "configuracion_invalida"


class MacroNoEncontradoError(LazyRemedyError):
    http_status = 404
    error_code = "macro_no_encontrada"


class CriterioInvalidoError(LazyRemedyError):
    """Criterio de búsqueda inválido o sin campo Remedy mapeado."""

    http_status = 400
    error_code = "criterio_invalido"


class SinCriteriosError(LazyRemedyError):
    http_status = 400
    error_code = "sin_criterios"


class RunmacroNoEncontradoError(LazyRemedyError):
    """El ejecutable runmacro.exe no existe o no es accesible."""

    http_status = 500
    error_code = "runmacro_no_encontrado"


class BackendNoDisponibleError(LazyRemedyError):
    """Problemas de acceso a OneDrive / macros o infraestructura Remedy."""

    http_status = 503
    error_code = "backend_no_disponible"


class RemedyTimeoutError(LazyRemedyError):
    """El subproceso runmacro.exe excedió el tiempo máximo."""

    http_status = 504
    error_code = "timeout_remedy"


class RemedyEjecucionError(LazyRemedyError):
    """runmacro.exe terminó con código de error distinto de cero."""

    http_status = 502
    error_code = "error_ejecucion_remedy"


class SalidaTimeoutError(LazyRemedyError):
    """El archivo de salida no apareció / no se estabilizó a tiempo."""

    http_status = 504
    error_code = "timeout_salida"


class SalidaParseError(LazyRemedyError):
    """No se pudo interpretar el archivo de salida generado por Remedy."""

    http_status = 502
    error_code = "error_parseo_salida"


class CerrojoExpiradoError(LazyRemedyError):
    """El cerrojo cross-proceso no se pudo adquirir en el tiempo límite."""

    http_status = 503
    error_code = "cerrojo_expirado"
