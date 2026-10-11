"""JSON command adapter. stdout is reserved for results/protocol."""
import argparse
import asyncio
import json
import sys

from .bootstrap import build_application
from .domain import TerminalError


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="remedy-terminal")
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--config")
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ["health", "capabilities", "mcp"]:
        sub.add_parser(name, parents=[common])
    search = sub.add_parser("search", parents=[common])
    search.add_argument("--form", required=True)
    search.add_argument("--where", action="append", required=True)
    search.add_argument("--field", action="append", required=True)
    search.add_argument("--limit", type=int, default=50)
    get = sub.add_parser("get", parents=[common])
    get.add_argument("--form", required=True)
    get.add_argument("--entry-id", required=True)
    get.add_argument("--field", action="append", required=True)
    incident = sub.add_parser("incident")
    incident.add_argument("--id", required=True)
    incident.add_argument("--com-config")
    ui = sub.add_parser("ui", help="Interfaz visual de solo lectura")
    ui.add_argument("--com-config", required=True)
    ui.add_argument("--journal-csv")
    ui.add_argument("--id")
    args = parser.parse_args(argv)
    try:
        if args.command == "ui":
            try:
                from .tui import run_ui
            except ModuleNotFoundError as exc:
                if exc.name == "textual" or (exc.name or "").startswith("textual."):
                    raise TerminalError("ui_dependencies_missing") from None
                raise
            run_ui(com_config=args.com_config, journal_csv=args.journal_csv, initial_id=args.id)
            return 0
        if args.command == "incident":
            from .windows_readonly import read_incident
            result = read_incident(args.id, args.com_config)
            print(json.dumps(result, ensure_ascii=False))
            return 0
        app = build_application(args.config)
        if args.command == "mcp":
            from .mcp_server import create_server
            create_server(app).run(transport="stdio")
            return 0
        if args.command == "search":
            criteria = {}
            for item in args.where:
                key, separator, value = item.partition("=")
                if not separator or key in criteria:
                    raise TerminalError("invalid_request")
                criteria[key] = value
            result = asyncio.run(app.search(args.form, criteria, args.field, args.limit))
        elif args.command == "get":
            result = asyncio.run(app.get(args.form, args.entry_id, args.field))
        else:
            result = getattr(app, args.command)()
        print(json.dumps(result, ensure_ascii=False))
    except TerminalError as exc:
        print(json.dumps({"error": exc.code}), file=sys.stderr)
        return 2
    return 0
