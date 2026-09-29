# LazyRemedy — Plan reestructurado (sin dependencia de runmacro.exe)

Fecha: 2026-08-15 · Estado: **en desarrollo**

## Contexto (verificado empíricamente en LAP06776)

| Hipótesis inicial | Realidad comprobada |
|---|---|
| Existe `runmacro.exe` en `C:\Program Files (x86)\AR System\User\` | **NO existe** (búsqueda recursiva de todo C: + OneDrive + AppData) |
| El servidor Remedy solo es accesible vía cliente de escritorio | El puerto 80/443 de `10.241.130.25` responde con firma del **Remedy Mid Tier** ("Bad Request (Invalid Hostname)") |
| Mapeo de campos era especulativo | **Confirmado** con macros y búsquedas reales: `1` (ID), `1010000170` (DNI), `536871059` (correo), `1010000167` (teléfono), `1010000274` (grupo CAU), `1010000147` (Nivel 1), `4` (Tipo), `7` (Estado) |
| Query HD | Real: `1010000147=Nivel 1` + `4=Help-Desk` + `1010000199=11` + `'7' != "Cerrada"` (de `x2xxxHEL.arq`) |

## Problema

El motor original ejecuta macros con `runmacro.exe`, que no está instalado.
Además `arapi70.dll` (API de Remedy del cliente) es de **32 bits**: no cargable
desde Python 3.13 64-bit, y no hay Python 32-bit en la máquina.

## Solución: backends plugables, seleccionables por configuración

```
config.backend = "midtier" | "macro" | "mock"
```

| Backend | Vía | Requiere | Zero-touch | Estado |
|---|---|---|---|---|
| `midtier` | HTTP (httpx) al portal web de Remedy (80/443) | hostname del Mid Tier + credencial | Sí | Implementado, **pendiente de calibrar** contra el Mid Tier real |
| `macro` | Ejecución de macros (`runmacro.exe` / `aruser -m`) | el binario (otra máquina) | Sí | Heredado, funcional como fallback |
| `mock` | Datos simulados | nada | Sí | Funcional (desarrollo/tests) |

### Backend `midtier` (primario)

Mismo patrón que `lazydirectory`/`lazytemis` (automatización HTTP de portales de
Justicia). Flujo:

1. **Login**: POST del formulario de login del Mid Tier → cookie de sesión.
2. **Búsqueda**: GET/POST sobre la URL de query del formulario
   `101_INCIDENCIAS` con la cualificación construida desde `search_field_map`
   (p.ej. `'536871059' = "x@y.es"`).
3. **Parseo**: la respuesta HTML (tabla de resultados) se convierte a filas JSON.

> **Pendiente de calibrar**: los endpoints exactos del Mid Tier 7.x
> (`/arsys/...`), el campo del formulario y el formato del HTML de resultados.
> Con el hostname real + credencial se hace una sesión de calibración con
> `python -m lazyremedy probe-midtier --url ...` y se ajustan los adaptadores.

### Backend `macro` (fallback legado)

El motor actual (`engine.py`) se conserva sin cambios: genera `.arq` dinámicos,
ejecuta el binario y parsea la salida en disco. No requiere Mid Tier ni hostname.

## Arquitectura de código

```
lazyremedy/
├── backends/
│   ├── __init__.py
│   ├── base.py          # protocolo RemedyBackend (search + run_macro)
│   ├── midtier.py       # backend HTTP del Mid Tier (httpx)
│   └── (macro_engine.py se reusa desde engine.py)
├── engine.py            # motor de macros (sin cambios)
├── service.py           # despacha al backend según config.backend
├── parser.py / query_builder.py   # reusados por engine.py
└── server_rest.py / server_mcp.py # sin cambios de contrato
```

## Seguridad

- Credenciales solo en `lazyremedy.config.json` (**gitignored**).
- El backend `midtier` admite `verify=false` temporal para entornos con
  certificados corporativos, documentado como opción explícita.

## Roadmap

1. ✅ Abstracción de backends + `mock` + `macro` sin cambios de contrato.
2. ✅ Backend `midtier` con flujo login+query, `probe` CLI y tests con servidor
   falso (login, cookie, cualificación real, parseo, 503/404, REST end-to-end).
3. ⏳ **Calibración contra el Mid Tier real** — BLOQUEADO por el hostname:
   - descubrimiento agotado en LAP06776 (DNS, hosts, historial Edge, wiki JA
     requiere login, 16 candidatos de Host header → todos 400),
   - se necesita el hostname real (p.ej. del equipo de aplicaciones, otra
     estación CAU o IT) → `python -m lazyremedy probe http://hostname/arsys`,
   - ajustar el parseo de resultados y probar con datos reales (`HELPDESK`).
4. ⏳ Despliegue final en `both` con `backend=midtier` (ya desplegado; servirá
   datos reales en cuanto se rellene `midtier_url`).
