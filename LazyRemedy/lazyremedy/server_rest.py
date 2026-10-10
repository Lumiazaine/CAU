"""Servidor REST FastAPI de LazyRemedy."""

from __future__ import annotations

import logging
from typing import Any

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from . import __version__
from .config import Settings, load_settings
from .errors import LazyRemedyError
from .models import (
    HealthResponse,
    MacroInfo,
    MacroRunResponse,
    SearchRequest,
    SearchResponse,
)
from .service import RemedyService

logger = logging.getLogger("lazyremedy.rest")

_APP_TITLE = "LazyRemedy - API Remedy (CAU)"
_APP_DESCRIPTION = (
    "Wrapper dual (REST + MCP) sobre el cliente legado BMC Remedy User v7.0.01. "
    "Adaptador experimental orientado a lecturas; contrato live no verificado."
)


class _AccessGuard:
    """Protect every route and mounted app; never trust forwarded headers here."""

    def __init__(self, app, token: str = ""):
        self.app = app
        self.token = token.encode("utf-8")

    async def __call__(self, scope, receive, send):
        if scope["type"] in {"http", "websocket"}:
            import ipaddress

            peer = scope.get("client")
            try:
                allowed = bool(peer) and ipaddress.ip_address(peer[0]).is_loopback
            except ValueError:
                allowed = False
            status = 403
            if self.token:
                import hmac

                headers = [value for name, value in scope.get("headers", []) if name.lower() == b"authorization"]
                allowed = len(headers) == 1 and hmac.compare_digest(headers[0], b"Bearer " + self.token)
                status = 401
            if not allowed:
                if scope["type"] == "websocket":
                    await send({"type": "websocket.close", "code": 1008})
                else:
                    await JSONResponse(status_code=status, content={"error": "Acceso no autorizado"})(scope, receive, send)
                return
        await self.app(scope, receive, send)


def create_app(
    settings: Settings | None = None,
    service: RemedyService | None = None,
    lifespan: Any = None,
) -> FastAPI:
    """Fábrica de la aplicación FastAPI. Permite inyectar settings/servicio (tests).

    ``lifespan`` se usa al montar la app HTTP de FastMCP (modo ``both``):
    es el contexto de vida del servidor MCP.
    """
    settings = settings or load_settings()
    service = service or RemedyService(settings)

    app = FastAPI(
        title=_APP_TITLE,
        description=_APP_DESCRIPTION,
        version=__version__,
        docs_url="/docs",
        redoc_url="/redoc",
        lifespan=lifespan,
    )
    app.state.settings = settings
    app.state.service = service

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Added last, so even CORS preflights and mounted MCP routes are guarded.
    app.add_middleware(_AccessGuard, token=settings.api_token)
    app.add_exception_handler(LazyRemedyError, _error_handler)

    _register_routes(app)
    return app


def _error_handler(request: Request, exc: LazyRemedyError) -> JSONResponse:
    logger.warning("Error %s en %s: %s", exc.error_code, request.url.path, exc.message)
    return JSONResponse(status_code=exc.http_status, content=exc.as_http())


def _register_routes(app: FastAPI) -> None:
    @app.get("/health", response_model=HealthResponse, tags=["sistema"])
    async def health() -> dict[str, Any]:
        info = app.state.service.backend.preflight()
        return {
            "status": "ok",
            "version": __version__,
            **info,
        }

    @app.get("/api/v1/macros", response_model=list[MacroInfo], tags=["macros"])
    async def get_macros() -> list[MacroInfo]:
        return app.state.service.list_macros()

    @app.post(
        "/api/v1/search",
        response_model=SearchResponse,
        tags=["busqueda"],
        summary="Búsqueda dinámica de incidencias",
    )
    async def search_incidencias(request: SearchRequest) -> SearchResponse:
        return await app.state.service.search(request)

    @app.post(
        "/api/v1/macros/{macro_id}/run",
        response_model=MacroRunResponse,
        tags=["macros"],
        summary="Ejecutar un macro predefinido",
    )
    async def run_macro(macro_id: str) -> MacroRunResponse:
        return await app.state.service.run_macro(macro_id)
