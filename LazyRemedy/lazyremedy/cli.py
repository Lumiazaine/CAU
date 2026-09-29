"""Interfaz de línea de comandos (CLI) de LazyRemedy.

Uso:
    python -m lazyremedy rest [--host H] [--port P] [--config FILE]
    python -m lazyremedy mcp [--transport stdio|http] [--host H] [--port P]
    python -m lazyremedy both [--host H] [--port P]
    python -m lazyremedy search --incidencia INC123 [--dni DNI] [--correo C] [--telefono T] [--json]
    python -m lazyremedy macro CSU [--json]
    python -m lazyremedy macros
    python -m lazyremedy config --ejemplo

Operación 100% desatendida vía línea de comandos (zero-touch).
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys

from . import __version__
from .config import default_config_example, load_settings
from .errors import LazyRemedyError
from .logging_setup import setup_logging
from .models import SearchRequest
from .service import RemedyService


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="lazyremedy",
        description="LazyRemedy - API wrapper dual (REST + MCP) sobre BMC Remedy User.",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--config", help="Archivo JSON de configuración")
    common.add_argument("--mock", action="store_true", help="Modo simulación (sin runmacro.exe)")
    common.add_argument("--log-level", default=None, help="DEBUG|INFO|WARNING|ERROR")

    sub = parser.add_subparsers(dest="comando", required=True)

    p_rest = sub.add_parser("rest", parents=[common], help="Servidor REST FastAPI")
    p_rest.add_argument("--host", default=None)
    p_rest.add_argument("--port", type=int, default=None)

    p_mcp = sub.add_parser("mcp", parents=[common], help="Servidor MCP (FastMCP)")
    p_mcp.add_argument("--transport", choices=["stdio", "http"], default="stdio")
    p_mcp.add_argument("--host", default=None)
    p_mcp.add_argument("--port", type=int, default=None)

    p_both = sub.add_parser(
        "both", parents=[common], help="REST + MCP en un único proceso (cerrojo compartido)"
    )
    p_both.add_argument("--host", default=None)
    p_both.add_argument("--port", type=int, default=None)

    p_search = sub.add_parser("search", parents=[common], help="Búsqueda one-shot (desatendida)")
    p_search.add_argument("--incidencia", dest="incidencia_id", default=None)
    p_search.add_argument("--dni", "--usuario-temis", dest="usuario_temis", default=None)
    p_search.add_argument("--correo", default=None)
    p_search.add_argument("--telefono", default=None)
    p_search.add_argument("--json", action="store_true", help="Salida JSON")

    p_probe = sub.add_parser(
        "probe", parents=[common], help="Diagnóstico de un Mid Tier (calibración)"
    )
    p_probe.add_argument("url", help="URL base del Mid Tier, p.ej. http://host/arsys")

    p_macro = sub.add_parser("macro", parents=[common], help="Ejecutar macro one-shot")
    p_macro.add_argument("macro_id")
    p_macro.add_argument("--json", action="store_true", help="Salida JSON")

    sub.add_parser("macros", parents=[common], help="Listar macros predefinidos")

    p_cfg = sub.add_parser("config", parents=[common], help="Gestión de configuración")
    p_cfg.add_argument("--ejemplo", action="store_true", help="Imprimir ejemplo de config JSON")

    return parser


def _settings(args: argparse.Namespace):
    settings = load_settings(args.config)
    if args.mock:
        settings = settings.model_copy(update={"mock": True})
    if args.log_level:
        settings = settings.model_copy(update={"log_level": args.log_level})
    return settings


def _imprimir_filas(titulo: str, filas: list[dict]) -> None:
    if not filas:
        print(f"{titulo}: 0 resultados")
        return
    cabeceras = list(filas[0].keys())
    anchos = {h: max(len(h), *(len(str(f.get(h, ""))) for f in filas)) for h in cabeceras}
    print(f"{titulo} ({len(filas)} resultado(s))")
    print(" | ".join(h.ljust(anchos[h]) for h in cabeceras))
    print("-+-".join("-" * anchos[h] for h in cabeceras))
    for fila in filas:
        print(" | ".join(str(fila.get(h, "")).ljust(anchos[h]) for h in cabeceras))


def _stdout_utf8() -> None:
    """Fuerza salida UTF-8 para --json (evita mojibake en consolas Windows)."""
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass


def _run_search(args: argparse.Namespace) -> int:
    settings = _settings(args)
    setup_logging(settings.log_level)
    service = RemedyService(settings)
    request = SearchRequest(
        incidencia_id=args.incidencia_id,
        usuario_temis=args.usuario_temis,
        correo=args.correo,
        telefono=args.telefono,
    )
    resultado = asyncio.run(service.search(request))
    if args.json:
        _stdout_utf8()
        print(json.dumps(resultado.model_dump(), ensure_ascii=False, indent=2))
    else:
        _imprimir_filas("Búsqueda", resultado.resultados)
    return 0


def _run_macro(args: argparse.Namespace) -> int:
    settings = _settings(args)
    setup_logging(settings.log_level)
    service = RemedyService(settings)
    resultado = asyncio.run(service.run_macro(args.macro_id))
    if args.json:
        _stdout_utf8()
        print(json.dumps(resultado.model_dump(), ensure_ascii=False, indent=2))
    else:
        print(f"Macro {resultado.macro} ({resultado.archivo})")
        _imprimir_filas("Incidencias", resultado.filas)
    return 0


def _run_macros_list(args: argparse.Namespace) -> int:
    settings = _settings(args)
    setup_logging(settings.log_level)
    service = RemedyService(settings)
    for m in service.list_macros():
        print(f"{m.id:<18} {m.archivo:<16} {m.descripcion}")
    return 0


def _run_config(args: argparse.Namespace) -> int:
    if args.ejemplo:
        print(default_config_example())
    else:
        settings = _settings(args)
        print(json.dumps(settings.to_dict(), ensure_ascii=False, indent=2))
    return 0


def _run_rest(args: argparse.Namespace) -> int:
    import uvicorn

    settings = _settings(args)
    setup_logging(settings.log_level)
    from .server_rest import create_app

    app = create_app(settings)
    uvicorn.run(
        app,
        host=args.host or settings.host,
        port=args.port or settings.port,
        log_level=settings.log_level.lower(),
    )
    return 0


def _run_mcp(args: argparse.Namespace) -> int:
    settings = _settings(args)
    setup_logging(settings.log_level)
    from .server_mcp import create_mcp

    mcp = create_mcp(settings)
    if args.transport == "http":
        mcp.run(
            transport="http",
            host=args.host or settings.host,
            port=args.port or settings.mcp_port,
            log_level=settings.log_level.lower(),
        )
    else:
        mcp.run(show_banner=False)
    return 0


def _run_both(args: argparse.Namespace) -> int:
    import uvicorn

    settings = _settings(args)
    setup_logging(settings.log_level)
    from .server_mcp import create_mcp
    from .server_rest import create_app

    service = RemedyService(settings)
    mcp = create_mcp(settings, service=service)
    mcp_app = mcp.http_app(path="/mcp")
    app = create_app(settings, service=service, lifespan=mcp_app.lifespan)
    app.mount("/", mcp_app)

    uvicorn.run(
        app,
        host=args.host or settings.host,
        port=args.port or settings.port,
        log_level=settings.log_level.lower(),
    )
    return 0


def _run_probe(args: argparse.Namespace) -> int:
    """Diagnostica un Mid Tier de Remedy para calibrar el backend HTTP."""

    import asyncio

    import httpx

    async def _probar() -> int:
        base = args.url.rstrip("/")
        try:
            async with httpx.AsyncClient(
                base_url=base,
                timeout=10.0,
                verify=False,
                follow_redirects=True,
                headers={"User-Agent": "LazyRemedy/1.0 (probe)"},
            ) as client:
                resp = await client.get("/arsys/login")
                print(f"GET {base}/arsys/login -> HTTP {resp.status_code}")
                if resp.status_code != 200:
                    print("  No parece un Mid Tier accesible en esa ruta.")
                    return 1
                from lazyremedy.backends.midtier import _LoginFormParser

                parser = _LoginFormParser()
                parser.feed(resp.text)
                if parser.formulario is None:
                    print("  No hay formulario de login en HTML (¿SSO/SAML?).")
                    print("  Fragmento:", " ".join(resp.text.split())[:200])
                    return 2
                f = parser.formulario
                print(
                    "  Formulario de login: "
                    f"action={f.action} method={f.method} "
                    f"campos={[c[0] for c in f.campos]}"
                )
                print("  El backend midtier puede usar esta URL: basta 'midtier_url' en config.")
                return 0
        except httpx.HTTPError as exc:
            print(f"ERROR de conexión: {exc}")
            return 1
        except Exception as exc:  # noqa: BLE001
            print(f"ERROR: {exc}")
            return 1

    return asyncio.run(_probar())


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    comando = args.comando
    try:
        if comando == "rest":
            return _run_rest(args)
        if comando == "mcp":
            return _run_mcp(args)
        if comando == "both":
            return _run_both(args)
        if comando == "search":
            return _run_search(args)
        if comando == "macro":
            return _run_macro(args)
        if comando == "macros":
            return _run_macros_list(args)
        if comando == "probe":
            return _run_probe(args)
        if comando == "config":
            return _run_config(args)
    except KeyboardInterrupt:
        return 130
    except LazyRemedyError as exc:
        print(f"ERROR [{exc.error_code}]: {exc.message}", file=sys.stderr)
        if exc.detail:
            print(f"  detalle: {exc.detail}", file=sys.stderr)
        return 1
    return 2


if __name__ == "__main__":
    sys.exit(main())
