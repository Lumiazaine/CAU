"""Visual read-only adapter. No COM object crosses the worker boundary."""
from __future__ import annotations

import asyncio
from datetime import datetime, timezone
import json
import re
import sys
import threading
import traceback
import unicodedata

from rich.text import Text
from textual import work
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual.screen import ModalScreen
from textual.widgets import Button, DataTable, Footer, Input, Static, TabbedContent, TabPane

from .domain import TerminalError
from .snapshot import load_snapshot, numeric_selection
from .windows_readonly import _load_policy, _numeric_id, incident_allowed, read_incident

# Remove entire control sequences, not merely ESC (which leaves printable payloads).
_ESCAPE = re.compile(
    r"(?:\x1b\]|\x9d).*?(?:\x07|\x1b\\|\x9c|$)"
    r"|(?:\x1b[P^_]|[\x90\x9e\x9f]).*?(?:\x1b\\|\x9c|$)"
    r"|(?:\x1b\[|\x9b)[0-?]*[ -/]*[@-~]"
    r"|\x1b[ -/]*[@-~]", re.DOTALL)


def display_text(value) -> Text:
    """Keep data literal, removing terminal controls and invisible/bidi formatters."""
    text = "" if value is None else str(value)
    text = _ESCAPE.sub("", text)
    text = "".join(c for c in text if c in "\n\t" or unicodedata.category(c) not in {"Cc", "Cf", "Cs"})
    return Text(text)


def com_runtime():
    if sys.platform == "win32":
        import pythoncom
        return pythoncom
    return None


def _discard_exception_frames(error) -> None:
    """Release worker-owned objects in every original exception chain."""
    pending = [error]
    seen = set()
    while pending:
        original = pending.pop()
        if id(original) in seen:
            continue
        seen.add(id(original))
        pending.extend(link for link in (original.__context__, original.__cause__) if link is not None)
        traceback.clear_frames(original.__traceback__)
        original.__traceback__ = original.__context__ = original.__cause__ = None


def read_on_thread(incident_id, com_config, reader=read_incident) -> dict:
    """Initialize COM on its owning thread; return only a validated scalar dict."""
    if not _numeric_id(incident_id):
        raise TerminalError("invalid_incident_id")
    if not com_config:
        raise TerminalError("configuration_required")
    policy = _load_policy(com_config)
    identity = policy["incident_field"]
    # This is a second gate, never a replacement/expansion of the adapter's policy.
    if not incident_allowed(policy, incident_id):
        raise TerminalError("incident_not_approved")
    runtime = com_runtime()
    if runtime is not None:
        runtime.CoInitialize()
    result = None
    scalar_result = {}
    error_code = None
    try:
        result = reader(incident_id, com_config)
        if (type(result) is not dict or result.get("source") != "live"
                or result.get("mode") != "live-com-readonly"
                or result.get("writes_enabled") is not False
                or result.get("requested_incident_id") != incident_id
                or result.get("canonical_id") != identity["prefix"] + incident_id.zfill(identity["digits"])
                or type(result.get("values")) is not dict):
            raise TerminalError("incident_mismatch")
        if any(type(label) is not str or (value is not None and type(value) not in (str, int, float, bool))
               for label, value in result["values"].items()):
            raise TerminalError("field_value_unsupported")
        try:
            scalar_result = json.loads(json.dumps(result, allow_nan=False))
        except (ValueError, TypeError):
            raise TerminalError("field_value_unsupported") from None
    except Exception as exc:
        error_code = "com_read_failed"
        if isinstance(exc, TerminalError) and type(exc.code) is str and exc.code in ERRORS:
            error_code = exc.code
        _discard_exception_frames(exc)
    finally:
        # This executing frame cannot be cleared by traceback.clear_frames.
        # Drop the raw result too, including rejected COM-valued responses.
        result = None
        if runtime is not None:
            runtime.CoUninitialize()
    # Outside the original handler: no context/cause or adapter frames survive.
    if error_code is not None:
        raise TerminalError(error_code)
    return scalar_result


ERRORS = {
    "invalid_incident_id": "Introduzca un ID numérico ASCII, sin espacios ni ceros iniciales (1–30 dígitos).",
    "configuration_required": "Falta la configuración privada de lectura autorizada.",
    "configuration_invalid": "La configuración privada no es válida o no está disponible.",
    "incident_not_approved": "Incidencia no autorizada por la política de lectura. No se ha ampliado el permiso.",
    "windows_backend_unavailable": "La lectura en vivo requiere Windows y el cliente Remedy autorizado.",
    "interactive_session_required": "Se necesita la sesión interactiva propia autorizada; no una sesión SSH.",
    "client_ownership_unverified": "No se pudo verificar el cliente Remedy de la sesión propia.",
    "session_unavailable": "No hay una sesión Remedy autenticada disponible.",
    "auth_user_mismatch": "La sesión autenticada no coincide con la política autorizada.",
    "incident_not_unique": "No se obtuvo una única incidencia coincidente.",
    "incident_mismatch": "La fuente o la identidad devuelta no cumple el contrato de lectura segura.",
    "field_contract_mismatch": "Los campos devueltos no coinciden con el contrato autorizado.",
    "field_value_unsupported": "La respuesta contiene valores no admitidos para lectura segura.",
    "cleanup_failed": "No se pudo completar el cierre de la consulta; ficha descartada.",
}


class HelpScreen(ModalScreen):
    BINDINGS = [Binding("escape", "dismiss", "Volver"), Binding("f1", "dismiss", "Volver")]

    def compose(self) -> ComposeResult:
        with Vertical(id="help-box"):
            yield Static("Ayuda · Remedy — SOLO LECTURA", classes="section-title")
            yield Static(
                "Ctrl+F: buscar por ID numérico. Enter o Consultar: leer la ficha autorizada.\n\n"
                "Listado: exportación local, no datos en vivo. Filtre solo por ID.\n"
                "Flechas o ratón: elegir fila y preparar el ID; Enter no amplía permisos.\n"
                "Anterior / Siguiente: recorrer páginas. Tab: cambiar de control.\n"
                "Resumen / Descripción / Cierre / Diario: consultar campos no editables.\n\n"
                "F1: ayuda · Esc: volver · Ctrl+Q: salir.\n"
                "No se modifican incidencias. No hay exportación ni registro de texto de tickets.", markup=False)
            yield Button("Volver", id="close-help", variant="primary")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        self.dismiss()


class RemedyApp(App):
    TITLE = "Remedy · Solo lectura"
    ENABLE_COMMAND_PALETTE = False
    PAGE_SIZE = 100
    BINDINGS = [Binding("ctrl+f", "focus_search", "Buscar", priority=True),
                Binding("f1", "help", "Ayuda", priority=True),
                Binding("ctrl+q", "quit", "Salir", priority=True)]
    CSS = """
    Screen { background: #182330; color: #e5edf5; }
    #readonly { height: 4; background: #24445c; color: #ffffff; text-style: bold; padding: 1 2; }
    #search-bar { height: 3; margin: 1 1 0 1; }
    #search-label { width: 18; padding: 1 0; }
    #incident-id { width: 1fr; }
    #search { width: 17; margin-left: 1; }
    #status { height: 2; padding: 0 2; color: #ffe6a1; }
    #workspace { height: 1fr; margin: 0 1; }
    #list-panel { width: 46%; border: solid #56738b; padding: 0 1; }
    #detail-panel { width: 54%; border: solid #56738b; padding: 0 1; }
    .section-title { height: 1; color: #bcdff5; text-style: bold; }
    #export-source { height: 3; color: #b4c8d7; }
    #filter-id { height: 3; }
    #results { height: 1fr; }
    #pagination { height: 3; }
    #pagination Button { min-width: 10; width: 12; }
    #page-info { width: 1fr; content-align: center middle; }
    #identity { height: 2; text-style: bold; }
    #source { height: auto; min-height: 3; color: #b4c8d7; }
    TabbedContent { height: 1fr; }
    TabPane { padding: 1; }
    VerticalScroll { height: 1fr; }
    .field-text { height: auto; }
    Footer { background: #24445c; }
    HelpScreen { align: center middle; background: #00000088; }
    #help-box { width: 76; height: auto; border: thick #80b4d5; padding: 1 2; background: #182330; }
    #help-box Static { height: auto; margin-bottom: 1; }
    """

    def __init__(self, com_config=None, journal_csv=None, initial_id=None, reader=read_incident):
        super().__init__()
        self.com_config = com_config
        self.journal_csv = journal_csv
        self.initial_id = initial_id
        self.reader = reader
        self.busy = False
        self._generation = 0
        self._read_lock = threading.Lock()
        self.snapshot = None
        self.filtered_rows = []
        self.page = 0
        self.export_identity = None
        self._highlighted_row = 0

    def _authorization_text(self):
        # This describes local policy only, never authentication or server ACLs.
        try:
            policy = _load_policy(self.com_config) if self.com_config else None
        except TerminalError:
            policy = None
        if policy is None:
            return "Autorización de lectura: sin verificar."
        scope = "TODAS las incidencias" if policy.get("allow_all_incidents") is True else "lista de IDs aprobados"
        return "Autorización: " + scope + " (política local)."

    def compose(self) -> ComposeResult:
        authorization = self._authorization_text()
        yield Static("REMEDY   |   CONSULTA DE INCIDENCIAS   |   SOLO LECTURA\n" + authorization,
                     id="readonly", markup=False)
        with Horizontal(id="search-bar"):
            yield Static("ID de incidencia", id="search-label")
            yield Input(value=self.initial_id or "", placeholder="ID numérico exacto", id="incident-id")
            yield Button("Consultar", id="search", variant="primary")
        yield Static("Introduzca el ID de una incidencia autorizada.", id="status", markup=False)
        with Horizontal(id="workspace"):
            with Vertical(id="list-panel"):
                yield Static("Listado de incidencias", classes="section-title")
                yield Static("Sin exportación incluida.\nLa ficha se consulta por ID autorizado.", id="export-source", markup=False)
                yield Input(placeholder="Filtrar exportación solo por ID", id="filter-id", disabled=True)
                yield DataTable(id="results", cursor_type="row", zebra_stripes=True)
                with Horizontal(id="pagination"):
                    yield Button("Anterior", id="previous", disabled=True)
                    yield Static("0 resultados", id="page-info", markup=False)
                    yield Button("Siguiente", id="next", disabled=True)
            with Vertical(id="detail-panel"):
                yield Static("Ficha de incidencia · no editable", classes="section-title")
                yield Static("Sin incidencia seleccionada", id="identity", markup=False)
                yield Static("Sin lectura en vivo\n" + authorization, id="source", markup=False)
                with TabbedContent():
                    for title, tab_id, content_id in [("Resumen", "summary-tab", "summary"),
                                                     ("Descripción", "description-tab", "description"),
                                                     ("Cierre", "closure-tab", "closure"),
                                                     ("Diario", "journal-tab", "journal")]:
                        with TabPane(title, id=tab_id):
                            with VerticalScroll():
                                yield Static("Sin incidencia cargada.", id=content_id,
                                             classes="field-text", markup=False)
        yield Footer()

    def on_mount(self) -> None:
        table = self.query_one("#results", DataTable)
        for title, width in (("ID incidencia", 16), ("Fecha apertura", 19), ("Zona horaria", 14), ("Advertencia", 30)):
            table.add_column(title, width=width)
        self.query_one("#incident-id", Input).focus()
        if self.journal_csv is not None:
            self.query_one("#export-source", Static).update("Importando exportación local…\nNO EN VIVO; validando todas las filas.")
            self.import_export()
        if self.initial_id is not None:
            self.request_lookup()

    def _load_export(self):
        snapshot = load_snapshot(self.journal_csv)
        try:
            identity = _load_policy(self.com_config)["incident_field"] if self.com_config else None
        except TerminalError:
            identity = None  # Listing is not authority for a live lookup.
        return snapshot, identity

    @work(exit_on_error=False)
    async def import_export(self) -> None:
        try:
            snapshot, identity = await asyncio.to_thread(self._load_export)
            if not self.is_running:
                return
            self.snapshot, self.export_identity = snapshot, identity
            stamp = snapshot.mtime.strftime("%Y-%m-%d %H:%M:%S")
            self.query_one("#export-source", Static).update(
                f"Exportación · {snapshot.count} filas · NO EN VIVO\nArchivo modificado (UTC):\n{stamp}")
            self.apply_filter()
        except Exception:
            if self.is_running:
                self.snapshot = None
                self.filtered_rows = []
                self.query_one("#export-source", Static).update(
                    "Exportación inválida o no disponible.\nNo se ha importado ninguna fila.\nCompruebe el formato y los límites.")
                self.render_page()

    def on_input_changed(self, event: Input.Changed) -> None:
        if event.input.id == "filter-id" and self.snapshot is not None:
            self.apply_filter()

    def apply_filter(self) -> None:
        self.page = 0
        self.filtered_rows = self.snapshot.filter_ids(self.query_one("#filter-id", Input).value)
        self.render_page()

    def render_page(self) -> None:
        table = self.query_one("#results", DataTable)
        self._highlighted_row = 0
        table.clear()
        total = len(self.filtered_rows)
        pages = max(1, (total + self.PAGE_SIZE - 1) // self.PAGE_SIZE)
        self.page = max(0, min(self.page, pages - 1))
        start = self.page * self.PAGE_SIZE
        rows = self.filtered_rows[start:start + self.PAGE_SIZE]
        for row in rows:
            table.add_row(*(display_text(v) for v in (row.incident_id, row.opening, row.zone, row.warning)), key=row.incident_id)
        full = self.snapshot.count if self.snapshot is not None else 0
        self.query_one("#page-info", Static).update(
            f"{start + 1 if total else 0}–{start + len(rows)} / {total}\nTotal: {full}")
        self.update_read_controls()

    def update_read_controls(self) -> None:
        pages = max(1, (len(self.filtered_rows) + self.PAGE_SIZE - 1) // self.PAGE_SIZE)
        self.query_one("#search", Button).disabled = self.busy
        self.query_one("#incident-id", Input).disabled = self.busy
        self.query_one("#results", DataTable).disabled = self.busy
        self.query_one("#filter-id", Input).disabled = self.busy or self.snapshot is None
        self.query_one("#previous", Button).disabled = self.busy or self.page == 0
        self.query_one("#next", Button).disabled = self.busy or self.page + 1 >= pages

    def prepare_selection(self, canonical_id: str) -> bool:
        if self.busy:
            return False
        self.clear_details()
        try:
            numeric = numeric_selection(canonical_id, self.export_identity)
        except TerminalError:
            self.query_one("#incident-id", Input).value = ""
            self.query_one("#status", Static).update("El ID de la exportación no coincide con el formato de la política privada. No se consultará.")
            return False
        self.query_one("#incident-id", Input).value = numeric
        self.query_one("#status", Static).update("ID preparado desde la exportación. Enter en la fila o Consultar solicita la lectura autorizada en vivo.")
        return True

    def on_data_table_row_highlighted(self, event: DataTable.RowHighlighted) -> None:
        if self.busy:
            return
        changed = event.cursor_row != self._highlighted_row
        self._highlighted_row = event.cursor_row
        if changed and event.data_table.has_focus and event.row_key.value is not None:
            self.prepare_selection(event.row_key.value)

    def on_data_table_row_selected(self, event: DataTable.RowSelected) -> None:
        if event.row_key.value is not None and self.prepare_selection(event.row_key.value):
            self.request_lookup()

    def action_focus_search(self) -> None:
        self.query_one("#incident-id", Input).focus()

    def action_help(self) -> None:
        if not isinstance(self.screen, HelpScreen):
            self.push_screen(HelpScreen(id="help-screen"))

    def on_input_submitted(self, event: Input.Submitted) -> None:
        if event.input.id == "incident-id":
            self.request_lookup()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "search":
            self.request_lookup()
        elif event.button.id in {"previous", "next"} and not self.busy:
            self.page += 1 if event.button.id == "next" else -1
            self.render_page()

    def clear_details(self) -> None:
        authorization = self._authorization_text()
        self.query_one("#readonly", Static).update(
            "REMEDY   |   CONSULTA DE INCIDENCIAS   |   SOLO LECTURA\n" + authorization)
        self.query_one("#identity", Static).update("Sin incidencia seleccionada")
        self.query_one("#source", Static).update("Sin lectura en vivo\n" + authorization)
        for selector in ("#summary", "#description", "#closure", "#journal"):
            self.query_one(selector, Static).update("Sin incidencia cargada.")

    def request_lookup(self) -> None:
        if self.busy:
            return
        self._generation += 1
        self.clear_details()
        incident_id = self.query_one("#incident-id", Input).value
        if not _numeric_id(incident_id):
            self.query_one("#status", Static).update(ERRORS["invalid_incident_id"])
            return
        self.busy = True
        self.update_read_controls()
        self.query_one("#status", Static).update("Consultando Remedy… SOLO LECTURA. Espere; no se permite otra consulta simultánea.")
        self.lookup(incident_id, self._generation)

    def _serialized_read(self, incident_id):
        with self._read_lock:
            return read_on_thread(incident_id, self.com_config, self.reader)

    @work(exit_on_error=False)
    async def lookup(self, incident_id: str, generation: int) -> None:
        try:
            result = await asyncio.to_thread(self._serialized_read, incident_id)
            if generation != self._generation or not self.is_running:
                return
            # A programmatic input change must not put an old identity in a new search.
            if self.query_one("#incident-id", Input).value != incident_id:
                self.query_one("#status", Static).update("Consulta descartada: el ID de búsqueda ha cambiado.")
                return
            self.render_details(result)
            self.query_one("#status", Static).update(
                "Ficha recibida y verificada. SOLO LECTURA; solo campos autorizados.\n" + self._authorization_text())
        except Exception as exc:
            if generation == self._generation and self.is_running:
                self.clear_details()
                code = exc.code if isinstance(exc, TerminalError) else "com_read_failed"
                self.query_one("#status", Static).update(ERRORS.get(code, "No se pudo completar la lectura. Compruebe la sesión y la configuración autorizada."))
        finally:
            if generation == self._generation and self.is_running:
                self.busy = False
                self.update_read_controls()

    def render_details(self, result: dict) -> None:
        authorization = self._authorization_text()
        self.query_one("#readonly", Static).update(
            "REMEDY   |   CONSULTA DE INCIDENCIAS   |   SOLO LECTURA\n" + authorization)
        self.query_one("#identity", Static).update(display_text(result["canonical_id"]))
        stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
        self.query_one("#source", Static).update(
            "Remedy en vivo · COM solo lectura\nConsulta: " + stamp + "\n" + authorization)
        grouped = {"summary": [], "description": [], "closure": [], "journal": []}
        for label, value in result["values"].items():
            key = unicodedata.normalize("NFKD", label.casefold())
            key = "".join(c for c in key if not unicodedata.combining(c))
            if any(word in key for word in ("diario", "journal", "work log", "worklog")):
                group = "journal"
            elif any(word in key for word in ("cierre", "resolucion", "closure", "resolution")):
                group = "closure"
            elif any(word in key for word in ("descripcion", "description")):
                group = "description"
            else:
                group = "summary"
            grouped[group].append(f"{label}\n{'Sin valor' if value is None else value}")
        for group, fields in grouped.items():
            content = "\n\n".join(fields) if fields else "No incluido en los campos autorizados. No hay datos que mostrar."
            self.query_one("#" + group, Static).update(display_text(content))


def run_ui(com_config=None, journal_csv=None, initial_id=None):
    RemedyApp(com_config=com_config, journal_csv=journal_csv, initial_id=initial_id).run()
