# LazyRemedy

API wrapper dual (**solo lectura**) sobre el cliente de escritorio legado **BMC Remedy User v7.0.01** del CAU (Justicia). Expone la información de Remedy de dos maneras simultáneas:

- **API REST (FastAPI)** — para alimentar la nueva interfaz gráfica en tiempo real.
- **Servidor MCP (FastMCP)** — herramientas de búsqueda nativas para agentes de IA.

Opera **100% desatendida** vía línea de comandos (zero-touch: sin ventanas ni interacción GUI).

---

## Arquitectura

```
LazyRemedy/
├── lazyremedy/
│   ├── __main__.py / cli.py      # CLI (rest, mcp, both, search, macro, macros, probe, config)
│   ├── config.py                 # Configuración (env LAZYREMEDY_* + JSON)
│   ├── errors.py                 # Jerarquía de errores -> códigos HTTP/MCP
│   ├── macros.py                 # Registro de macros predefinidos (.arq)
│   ├── query_builder.py          # Mapeo de campos + cualificaciones + macros .arq
│   ├── parser.py                 # Parseo de la salida en disco (CSV/TXT)
│   ├── lock.py                   # Cerrojo cross-proceso (mutex con nombre)
│   ├── engine.py                 # Motor asíncrono de runmacro.exe (cerrojo + subprocess)
│   ├── backends/                 # Backends de datos plugables (settings.backend)
│   │   ├── base.py               # Interfaz RemedyBackend (search + run_macro + preflight)
│   │   ├── midtier.py            # HTTP al Mid Tier (login + query + parseo HTML)
│   │   └── macro.py              # Ejecución de macros .arq (runmacro.exe / mock)
│   ├── service.py                # Despacho al backend configurado
│   ├── models.py                 # Modelos Pydantic
│   ├── server_rest.py            # Aplicación FastAPI
│   └── server_mcp.py             # Servidor FastMCP
├── docs/PLAN.md                  # Plan reestructurado (sin dependencia de runmacro.exe)
├── tests/                        # pytest (mock + midtier simulado + camino real)
├── lazyremedy.config.example.json
└── requirements.txt / pyproject.toml
```

```
┌────────────┐   ┌──────────────────────────┐   ┌───────────────────────┐
│ GUI nueva  │──▶│  FastAPI (REST)          │──▶│  RemedyService        │
│ Agentes IA │──▶│  FastMCP (MCP tools)     │──▶│  └ backend (config)   │
└────────────┘   └──────────────────────────┘   │   ├ midtier (HTTP)    │
                                                │   ├ macro (runmacro)  │
                                                │   └ mock (simulado)   │
                                                └───────────────────────┘
```

## Reglas críticas de diseño

1. **Concurrencia (CRÍTICA)**: `runmacro.exe` no soporta peticiones simultáneas.
   - `asyncio.Lock` serializa todas las peticiones dentro del proceso.
   - Mutex con nombre `Global\LazyRemedyRunmacro` protege cuando REST y MCP corren
     en **procesos separados** (ver `lock.py`).
   - Si se arranca `both`, REST y MCP comparten el mismo servicio y el mismo cerrojo.
2. **Zero-touch**: `CREATE_NO_WINDOW` en el subproceso; sin interacción gráfica.
3. **Solo lectura**: búsquedas y macros de consulta; nunca se modifican datos.

## Requisitos

- Windows x64, Python 3.10+.
- `C:\Program Files (x86)\AR System\User\runmacro.exe` (host objetivo).
- Macros en OneDrive: `C:\Users\CAU\OneDrive - AYESA\ARCmds`.

```powershell
pip install -r requirements.txt
# o: pip install ".[test]"  para desarrollo
```

## Configuración

Se lee, por orden de precedencia: valores por defecto → variables `LAZYREMEDY_*` → archivo JSON (`--config` o `LAZYREMEDY_CONFIG`).

```powershell
python -m lazyremedy config --ejemplo          # imprime ejemplo completo
python -m lazyremedy config                    # configuración efectiva
```

> **`search_field_map`** (esquema `101_INCIDENCIAS`, IDs reales extraídos de la macro):
> `incidencia_id` → `1` (Request ID), `usuario_temis` → `1010000170` (DNI),
> `correo` → `536871059`, `telefono` → `1010000167`. Si un criterio no está
> mapeado, la búsqueda devuelve 400 (`criterio_invalido`).

```powershell
# Modo desarrollo/simulación (sin runmacro.exe):
$env:LAZYREMEDY_MOCK = "1"
# o: python -m lazyremedy ... --mock
```

## Uso

### Servidor REST

```powershell
python -m lazyremedy rest --host 127.0.0.1 --port 8000
# Docs interactivas en http://127.0.0.1:8000/docs
```

### Servidor MCP

```powershell
python -m lazyremedy mcp --transport stdio      # para clientes MCP (Claude Desktop, etc.)
python -m lazyremedy mcp --transport http --port 8100
```

### Ambos en un único proceso (cerrojo compartido)

```powershell
python -m lazyremedy both --host 127.0.0.1 --port 8000
# REST  -> http://127.0.0.1:8000/docs
# MCP   -> http://127.0.0.1:8000/mcp  (transport HTTP)
```

### One-shot (desatendido)

```powershell
python -m lazyremedy search --incidencia INC123 --json
python -m lazyremedy search --dni 12345678Z --correo x@y.es --telefono 955000001
python -m lazyremedy macro CSU
python -m lazyremedy macros
```

## API REST

| Método | Ruta | Descripción |
|--------|------|-------------|
| `GET`  | `/health` | Estado: existe runmacro.exe, acceso a OneDrive, modo mock |
| `GET`  | `/api/v1/macros` | Lista de macros predefinidos |
| `POST` | `/api/v1/search` | Búsqueda dinámica (al menos un criterio) |
| `POST` | `/api/v1/macros/{macro_id}/run` | Ejecuta un macro predefinido |

`POST /api/v1/search` — cuerpo:

```json
{ "incidencia_id": "INC123", "usuario_temis": "", "correo": "", "telefono": "" }
```

`POST /api/v1/macros/CSU/run` — ejecuta `x1xxxCSU.arq`.

### Códigos de error

| HTTP | `error` | Significado |
|------|---------|-------------|
| 400 | `sin_criterios` / `criterio_invalido` | Petición inválida |
| 404 | `macro_no_encontrada` | Macro no registrado o .arq ausente en OneDrive |
| 502 | `error_ejecucion_remedy` / `error_parseo_salida` | runmacro falló o salida ilegible |
| 503 | `backend_no_disponible` / `cerrojo_expirado` | OneDrive/Remedy inaccesible o cola llena |
| 504 | `timeout_remedy` / `timeout_salida` | Subproceso o archivo de salida excedió el tiempo |

## Herramientas MCP

| Herramienta | Descripción |
|-------------|-------------|
| `remedy_buscar(incidencia_id, usuario_temis, correo, telefono)` | Búsqueda dinámica (igual que `POST /search`) |
| `remedy_ejecutar_macro(macro_id)` | CSU, HELPDESK, PENDIENTE_USUARIO, MICROINFORMATICA |
| `remedy_listar_macros()` | Catálogo de macros |

Los errores se devuelven como JSON con `error`, `mensaje` y `detalle`.

## Macros predefinidos

| ID (API/MCP) | Archivo | Descripción |
|--------------|---------|-------------|
| `CSU` | `x1xxxCSU.arq` | Centro de Servicio al Usuario |
| `HELPDESK` | `x2xxxHEL.arq` | Help-Desk |
| `PENDIENTE_USUARIO` | `x3xxxPEN.arq` | Pendiente de usuario |
| `MICROINFORMATICA` | `x5xxxMIC.arq` | Microinformática |

## Cómo funciona la invocación

1. El servicio construye el `.arq` (o usa el predefinido) y lo escribe en `output_dir`.
2. `RemedyEngine` adquiere el cerrojo (en proceso + mutex) y lanza:

   ```python
   await asyncio.create_subprocess_exec(
       *cmd,                        # [runmacro.exe] + runmacro_args + [macro.arq]
       stdout=DEVNULL, stderr=PIPE, stdin=DEVNULL,
       creationflags=CREATE_NO_WINDOW,
       env={**os.environ, "LAZYREMEDY_OUTPUT_FILE": salida, "LAZYREMEDY_MACRO_PATH": macro},
   )
   ```

   El **contrato de salida**: runmacro.exe (o el macro que ejecuta) debe escribir el
   resultado en el archivo indicado por la variable de entorno
   `LAZYREMEDY_OUTPUT_FILE` (CSV/TXT). La variable `LAZYREMEDY_MACRO_PATH` contiene
   la ruta del macro lanzado.
3. Espera el subproceso (timeout configurable) y después el **archivo de salida**
   en disco hasta que aparece y se estabiliza (tamaño constante N comprobaciones).
4. Lee el archivo (auto-detecta CSV con `,`/`;`/`TAB`, o `clave: valor`), lo **parsea
   a JSON**, lo **elimina** y devuelve las filas.
5. Si runmacro devuelve código ≠ 0 → `502`; si no hay salida a tiempo → `504`.

> **`runmacro_args`**: si el `runmacro.exe` de tu entorno exige argumentos (servidor,
> usuario, etc.), configúralos aquí, p.ej. `["-r", "10.241.130.25", "-u", "user", "-p", "pass"]`.

## Formato de salida soportado

El parser (`parser.py`) auto-detecta:

```csv
ID incidencia,Estado,Importe
INC001,Abierta,"1.234,56"
```

```text
ID incidencia: INC001
Estado: Abierta

ID incidencia: INC002
Estado: Cerrada
```

## Backends (config `backend`)

| Backend | Vía | Requiere | Estado |
|---|---|---|---|
| `midtier` | HTTP al portal web de Remedy (login + query + parseo) | `midtier_url` + credencial | Implementado; **calibrar** contra el Mid Tier real |
| `macro` | Ejecución de macros `.arq` (`runmacro.exe`) | el binario | Funcional (fallback) |
| `mock` | Datos simulados | nada | Desarrollo/tests |

```json
{
  "backend": "midtier",
  "midtier_url": "http://REEMPLAZA_HOSTNAME/arsys",
  "remedy_user": "CAU09",
  "remedy_password": "***"
}
```

Diagnóstico del Mid Tier real antes de configurar:

```powershell
python -m lazyremedy probe http://hostname/arsys
```

> Si `midtier_url` está vacío, el servidor arranca igualmente y `/health` lo
> refleja con `config_pendiente: true`; las consultas devuelven `503
> backend_no_disponible` hasta configurarla. Ver `docs/PLAN.md` para el plan
> reestructurado (sin dependencia de `runmacro.exe`).

## Tests

```powershell
python -m pytest          # 71 tests
```

Dos niveles (más el backend midtier):
- **Mock** (`tests/test_*`, sin tocar Remedy): parser, macros, cerrojo, REST, MCP, CLI.
- **Mid Tier simulado** (`tests/test_midtier.py`): servidor HTTP local que imita
  el login y la tabla de resultados; valida descubrimiento del formulario,
  credenciales, cookie, cualificación y parseo.
- **Camino real** (`tests/test_real_path.py`): usa `tests/fixtures/fake_runmacro.py`
  como ejecutable de sustitución para validar el subproceso asíncrono real,
  el contrato `LAZYREMEDY_OUTPUT_FILE`, el parseo, los códigos 502/504 y la
  serialización de concurrencia. En la máquina de producción esos mismos tests
  se pueden ejecutar apuntando a `runmacro.exe` real.

## Ajustar para producción

1. Copiar `lazyremedy.config.example.json` a `lazyremedy.config.json`.
2. Confirmar `remedy_runmacro` (ruta de `runmacro.exe`) y `runmacro_args` si el
   host exige credenciales/parámetros.
3. Comprobar que los macros generan la salida en `LAZYREMEDY_OUTPUT_FILE`.
4. Probar primero con `--mock`, luego en modo real.
