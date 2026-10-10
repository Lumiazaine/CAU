# RemedyTerminal: contrato offline CLI/MCP

## Estado y compatibilidad

Implementación ejecutable, **no integración live**. La nueva entrada es
`remedy-terminal` / `python -m lazyremedy.terminal`; la CLI anterior
`python -m lazyremedy`, REST, macros y FastMCP se conservan sin reemplazarlos.
No se importa ni ejecuta el cliente COM/SSH del prototipo anterior.

Solo existen dos modos: `blocked` (por defecto) y `synthetic` (datos inventados
para pruebas en memoria). No hay endpoint, sesión Remedy, DLL, socket o GUI
detrás del adaptador sintético. Ningún indicador de aprobación activa red.
`live=false`, `verified_scope=offline`, `write_enabled=false` y
`live_contract_verified=false` son invariantes de esta versión.
`health` describe el proceso local, **no** conectividad/autenticación BMC.

## Arquitectura

```text
CLI JSON / MCP stdio oficial
           |
     RemedyApplication       validación y casos de uso compartidos
           |
        ReadPort             get/search; sin create/update/delete
           |
 SyntheticReadAdapter        dos registros sintéticos en memoria
```

- `domain.py`: entrada de datos, errores sanitizados e identificadores exactos;
  sin transportes ni SDK.
- `application.py`: autorización local, selección de campos, límites, validación
  de respuestas y errores del adaptador; no importa MCP, GUI, red ni COM.
- `ports.py`: contrato de lectura inyectable. Las pruebas de la frontera usan
  **spies sintéticos**, no un supuesto SDK nativo.
- `config.py`: carga explícita JSON estricta, sin heredar configuración Remedy.
- `bootstrap.py`: composición y comprobación del esquema realmente soportado.
- `cli.py`, `mcp_server.py`: adaptadores de presentación que comparten casos de uso.

El SDK oficial es `mcp==2.3.0`, no el paquete independiente `fastmcp` usado por
la interfaz antigua. La API oficial v2 utiliza `MCPServer`, no
`mcp.server.fastmcp.FastMCP`. El pin coincide con el SDK instalado y ejercitado.
Referencias revisadas: [metadatos PyPI 2.3.0](https://pypi.org/pypi/mcp/2.3.0/json)
y [migración oficial v2](https://py.sdk.modelcontextprotocol.io/v2/migration/).
PyPI declara esta versión no retirada y sin vulnerabilidades enumeradas en
sus metadatos; esto **no sustituye** una auditoría completa de dependencias.
Los demás paquetes heredados mantienen sus rangos anteriores.

## Configuración aprobada y cierre preventivo

Sin `--config`, solo se publican `remedy_health` y `remedy_capabilities`.
No se leen `LAZYREMEDY_*`, `REMEDY_*`, dotenv ni rutas corporativas por defecto.
Un archivo indicado que falta, JSON inválido, claves duplicadas/desconocidas,
booleanos de texto, campos sensibles o adaptadores no implementados abortan
con `configuration_invalid`; no se continúa con valores por defecto.

Copiar el ejemplo a una ubicación local fuera de Git. Está desactivado por
defecto. Para aprobar **únicamente el fixture sintético**, cambiar
`read_approved` a `true` explícitamente:

```json
{
  "adapter": "synthetic",
  "read_approved": false,
  "forms": {"SYN:Tickets": ["summary", "status"]}
}
```

Único formulario soportado: `SYN:Tickets`; únicos campos: `summary`, `status`.
Entradas sintéticas: `SYN-0001`, `SYN-0002`, ambas con `status=open`.
Cambiar el nombre del formulario a uno real se rechaza: configurar un nombre
no demuestra soporte de un contrato. `native`, `com`, `rest`, `midtier`,
credenciales, endpoints y cualquier opción de escritura no se aceptan.

## CLI

Instalar desde `LazyRemedy/` con Python 3.10+:

```bash
python -m pip install ".[test]"
remedy-terminal health
remedy-terminal capabilities --config /ruta/local/terminal.json
remedy-terminal search --config /ruta/local/terminal.json \
  --form 'SYN:Tickets' --where status=open --field summary --limit 1
remedy-terminal get --config /ruta/local/terminal.json \
  --form 'SYN:Tickets' --entry-id SYN-0001 --field status
remedy-terminal mcp --config /ruta/local/terminal.json
```

También funciona `python -m lazyremedy.terminal <comando>`. `--config` se coloca
**después** del subcomando. `health`/`capabilities` funcionan aun sin aprobación;
las lecturas no. Éxito: JSON por stdout, exit 0. Error de aplicación o
configuración: código fijo JSON por stderr, stdout vacío, exit 2. Errores de
uso de argparse: stderr y exit 2. No se imprimen diagnósticos de adaptadores.

## MCP stdio oficial

El host lanza directamente el proceso con comando absoluto al intérprete y
argumentos `-m lazyremedy.terminal mcp --config /ruta/local/terminal.json`.
No se ha cambiado configuración de Hermes ni de ningún host MCP.
No existe opción HTTP, host, port ni listener en esta entrada.
Stdout queda reservado exclusivamente al protocolo; no banners ni resultados
CLI adicionales. Stderr es el canal de diagnóstico del SDK.

| Tool | Disponibilidad | Contrato |
|---|---|---|
| `remedy_health` | Siempre | Diagnóstico local sin E/S de Remedy |
| `remedy_capabilities` | Siempre | Herramientas y formularios/campos aprobados realmente disponibles |
| `remedy_search` | Solo synthetic + read_approved + allowlist no vacía | form, criteria objeto no vacío, fields explícitos, limit 1..100 |
| `remedy_get` | Misma condición | form, entry_id exacto, fields explícitos |

Todas llevan `readOnlyHint=true`, `destructiveHint=false`,
`idempotentHint=true`, `openWorldHint=false`; estas anotaciones no reemplazan
las guardias de aplicación. Los éxitos llevan `structuredContent` y contenido
textual JSON. Errores de dominio usan **`isError=true`**, nunca falso éxito
con una clave error escondida. Herramientas ausentes y parámetros de tipo
incorrecto se rechazan por el SDK; no se aceptan escrituras ni macros remotos.
No enviar secretos como argumentos: los diagnósticos de validación del SDK
pueden describir la entrada rechazada.

## Contrato de lectura

- Formularios e IDs son exactos: no trim, reparación, alias o conversión desde
  un número visible de incidencia al AR Request ID. Límite de nombre/ID: 200.
- Campos explícitos: 1..50, únicos, aprobados y sin nombres de secretos.
- Criteria: 1..50 pares de campos aprobados y strings no vacíos, sin controles,
  máximo 1000 caracteres por valor. Se aplica igualdad literal AND; no SQL,
  cualificación AR raw, interpolación, expresiones ni búsqueda sin filtro.
- `limit` es entero estricto (booleanos no son límites), 1..100, default 50.
  El port recibe como máximo `limit+1`, solo para determinar `has_more`.
- Respuesta search: entries, returned_count de esta página y has_more. No hay
  total global inferido ni paginación/offset implementados; has_more no implica
  que se hayan entregado todos los resultados.
- Respuesta get: coincidencia exacta de form/entry_id y de todos los campos
  solicitados. Inexistente: `entry_not_found`.
- El port devuelve `Entry` con valores string y exactamente los campos pedidos;
  respuestas cruzadas, campos extra/ausentes, IDs duplicados o batch excesivo
  producen `adapter_contract_invalid` sin devolver filas parciales.
- Excepciones de adaptadores: `adapter_failed` sin contenido de la excepción.
  Cancelación del proceso no se convierte en éxito.

## Frontera live pendiente

Esta implementación no define ABI ni endpoint alguno. La DLL Remedy 7.0.1 x86,
metadatos TLB y modo ARDisplay no bastan para habilitar un adaptador seguro.
Antes de añadir otro adaptador deben confirmarse headers SDK de versión y
arquitectura exactas, ownership/lifecycle y cleanup, autenticación/permisos,
formulario/campos/Request ID y cualificación aceptada, ausencia de efectos de
workflows y contrato de salida. La aprobación local no reemplaza autorización
corporativa. Ninguna escritura se expone mientras no exista contrato real,
validación, permiso explícito, confirmación ligada a la operación y evidencia
live autorizada. Datos y credenciales reales deben permanecer fuera de Git.

## Verificación reproducible

```bash
python -m pytest tests/test_terminal.py tests/test_terminal_contract.py \
  tests/test_terminal_stdio.py -q -o addopts=""
python -m pytest -q -o addopts=""
```

`test_terminal_stdio.py` usa el **SDK oficial real** para initialize, tools/list,
tools/call y cierre de subprocesos. Ejercita modo sin configuración, aprobación
false y synthetic aprobado, resultados y errores. Un `sitecustomize` de test
en el hijo bloquea DNS, connect/connect_ex y bind: el test verde también exige
que stdio no abra red/listener. Los otros tests heredados conservan la guardia
no-loopback y sus fixtures loopback existentes. Solo se verificó ejecución en
Linux/Python 3.11; no se afirma prueba de instalación Windows ni lectura live.
Los resultados XML/JSON y el transcript detallado son artefactos privados, no
incluidos en este repositorio público. Los comandos anteriores regeneran los
resultados de forma local. Los ciclos RED→GREEN están resumidos en
`TERMINAL-TDD.md`. Las pruebas verdes no validan una API de Remedy.
