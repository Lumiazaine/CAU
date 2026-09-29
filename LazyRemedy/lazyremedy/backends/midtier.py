"""Backend HTTP contra el portal web de Remedy (Mid Tier).

Flujo (patrón lazydirectory/lazytemis, automatización HTTP de portales web):

1. **Login**: descubre el formulario de login desde el HTML (action + nombres
   de campos), lo rellena con las credenciales de config y guarda la cookie.
2. **Búsqueda**: construye la cualificación Remedy desde ``search_field_map``
   (p.ej. ``'536871059' = "x@y.es"``) y la envía a la URL de query del
   formulario ``101_INCIDENCIAS``.
3. **Parseo**: extrae la tabla HTML de resultados y la convierte a filas JSON.

> Los endpoints reales del Mid Tier 7.x deben calibrarse contra el host real
> (``probe``). Las rutas por defecto son las habituales y ajustables por config.
"""

from __future__ import annotations

import logging
from html.parser import HTMLParser
from typing import Any
from urllib.parse import urljoin

import httpx

from ..config import Settings
from ..errors import BackendNoDisponibleError, MacroNoEncontradoError
from ..macros import resolve_macro
from .base import RemedyBackend

logger = logging.getLogger("lazyremedy.backends.midtier")

#: Cualificaciones reales (extraídas de los macros de la máquina). Solo
#: HELPDESK está confirmado; el resto se calibra contra el Mid Tier real.
MACRO_QUERIES: dict[str, str] = {
    "HELPDESK": (
        "'1010000147' = \"Nivel 1\" AND "
        "'4' = \"Help-Desk\" AND "
        "'1010000199' = \"11\" AND "
        "'7' != \"Cerrada\""
    ),
}

_DEFAULT_LOGIN_PATH = "/arsys/login"
_DEFAULT_QUERY_PATH = "/arsys/forms/{schema}/query"


class _TableParser(HTMLParser):
    """Extrae la primera tabla con contenido del HTML de resultados."""

    def __init__(self) -> None:
        super().__init__()
        self._en_tabla = 0
        self._fila: list[str] | None = None
        self._celda: list[str] = []
        self.tablas: list[list[list[str]]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag == "table":
            self._en_tabla += 1
            self.tablas.append([])
        elif tag == "tr" and self._en_tabla:
            self._fila = []
        elif tag in ("td", "th") and self._fila is not None:
            self._celda = []

    def handle_data(self, data: str) -> None:
        if self._fila is not None:
            self._celda.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag in ("td", "th") and self._fila is not None:
            self._fila.append("".join(self._celda).strip())
            self._celda = []
        elif tag == "tr" and self._en_tabla and self._fila is not None:
            if any(self._fila):
                self.tablas[-1].append(self._fila)
            self._fila = None
        elif tag == "table":
            self._en_tabla = max(0, self._en_tabla - 1)


class _LoginForm:
    """Formulario de login descubierto desde el HTML."""

    def __init__(self, action: str, method: str, campos: list[tuple[str, str]]) -> None:
        self.action = action
        self.method = method.upper()
        self.campos = campos  # (name, default_value)

    def datos(self, usuario: str, password: str) -> dict[str, str]:
        data = {nombre: (valor or "") for nombre, valor in self.campos}
        for nombre, _ in self.campos:
            nombre_low = nombre.lower()
            if "pass" in nombre_low or "pwd" in nombre_low or "contra" in nombre_low:
                data[nombre] = password
            elif nombre_low in ("user", "usuario", "login", "u", "j_username"):
                data[nombre] = usuario
        return data


class _LoginFormParser(HTMLParser):
    """Descubre el formulario que contiene un campo de tipo password."""

    def __init__(self) -> None:
        super().__init__()
        self._en_form: dict[str, str] | None = None
        self._campos: list[tuple[str, str]] = []
        self.formulario: _LoginForm | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attrs = dict(attrs)
        if tag == "form" and self.formulario is None:
            self._en_form = {
                "action": attrs.get("action", ""),
                "method": attrs.get("method", "POST"),
            }
            self._campos = []
        elif tag == "input" and self._en_form is not None:
            nombre = attrs.get("name", "")
            if not nombre:
                return
            tipo = (attrs.get("type") or "text").lower()
            self._campos.append((nombre, attrs.get("value", "")))
            if tipo == "password":
                self.formulario = _LoginForm(
                    self._en_form["action"], self._en_form["method"], self._campos
                )


class MidtierBackend(RemedyBackend):
    """Acceso a Remedy vía el Mid Tier web (headless, read-only)."""

    name = "midtier"

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._base = (settings.midtier_url or "").rstrip("/")
        self._verify = settings.midtier_verify_ssl
        self._timeout = settings.midtier_timeout_sec
        self._client: httpx.AsyncClient | None = None
        self._login: _LoginForm | None = None

    @property
    def config_pendiente(self) -> bool:
        return not self._base

    async def _ensure_client(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(
                base_url=self._base,
                timeout=self._timeout,
                verify=self._verify,
                follow_redirects=True,
                headers={"User-Agent": "LazyRemedy/1.0"},
            )
        return self._client

    async def close(self) -> None:
        if self._client is not None:
            await self._client.aclose()
            self._client = None

    # ------------------------------------------------------------------
    # Login
    # ------------------------------------------------------------------
    async def _ensure_login(self) -> None:
        if self._login is not None:
            return
        if self.config_pendiente:
            raise BackendNoDisponibleError(
                "Falta configurar 'midtier_url' en lazyremedy.config.json"
            )
        client = await self._ensure_client()
        try:
            resp = await client.get("/arsys/login")
            resp.raise_for_status()
            parser = _LoginFormParser()
            parser.feed(resp.text)
            if parser.formulario is None:
                raise BackendNoDisponibleError(
                    message="No se encontró formulario de login en el Mid Tier"
                )
            self._login = parser.formulario
            action = urljoin(self._base, self._login.action)
            datos = self._login.datos(
                self._settings.remedy_user, self._settings.remedy_password
            )
            login_resp = await client.post(action, data=datos)
            login_resp.raise_for_status()
            logger.info("Login Mid Tier OK (status=%s)", login_resp.status_code)
        except httpx.HTTPError as exc:
            raise BackendNoDisponibleError(
                message=f"No se pudo iniciar sesión en el Mid Tier: {exc}"
            ) from exc

    # ------------------------------------------------------------------
    # Contrato RemedyBackend
    # ------------------------------------------------------------------
    def preflight(self) -> dict[str, Any]:
        return {
            "backend": self.name,
            "midtier_url": self._base,
            "config_pendiente": self.config_pendiente,
            "login_pendiente": self._login is None,
        }

    async def search(self, criterios: dict[str, str]) -> list[dict[str, str]]:
        await self._ensure_login()
        if not criterios:
            raise ValueError("criterios vacíos")
        from ..query_builder import map_criterios_a_campos

        campos = map_criterios_a_campos(self._settings, criterios)
        cualificacion = " AND ".join(
            f"'{campo}' = \"{valor}\"" for campo, valor in campos.items()
        )
        return await self._query(cualificacion)

    async def run_macro(self, macro_id: str) -> list[dict[str, str]]:
        resolve_macro(macro_id)  # lanza MacroNoEncontradoError si no existe
        cualificacion = MACRO_QUERIES.get(macro_id)
        if not cualificacion:
            raise MacroNoEncontradoError(
                macro_id, detail="Cualificación del macro no calibrada aún"
            )
        await self._ensure_login()
        return await self._query(cualificacion)

    # ------------------------------------------------------------------
    # Query + parseo
    # ------------------------------------------------------------------
    async def _query(self, cualificacion: str) -> list[dict[str, str]]:
        client = await self._ensure_client()
        url = _DEFAULT_QUERY_PATH.format(schema="101_INCIDENCIAS")
        try:
            resp = await client.get(url, params={"q": cualificacion})
            resp.raise_for_status()
        except httpx.HTTPError as exc:
            raise BackendNoDisponibleError(
                message=f"Error en la consulta al Mid Tier: {exc}"
            ) from exc

        parser = _TableParser()
        parser.feed(resp.text)
        if not parser.tablas or not parser.tablas[-1]:
            # Sin resultados: tabla vacía o ausente.
            return []
        tabla = parser.tablas[-1]
        cabecera = tabla[0]
        filas = []
        for fila in tabla[1:]:
            filas.append(dict(zip(cabecera, fila)))
        return filas
