# Evidencia RED → GREEN: RemedyTerminal

Se cargaron las skills test-driven-development y systematic-debugging. La
verificación inicial dio 134 tests existentes verdes. No se modificaron sus
interfaces ni se copió el cliente live experimental del prototipo.

Los siguientes ciclos se ejecutaron con el intérprete `.venv/bin/python` y
`-m pytest <selector> -q -o addopts=''`. Las parametrizaciones cubren distintas
entradas de una misma frontera, no respuestas del servidor corporativo.

| Frontera añadida | RED observado antes de implementar | GREEN observado |
|---|---|---|
| health CLI por defecto | comando falló: paquete terminal inexistente | health blocked, live=false; suite 135 |
| capabilities + política explícita | subcomando capabilities inexistente | 2 tests terminal |
| rechazo de política y diagnósticos sanitizados | 8 fallos: traceback o política sensible aceptada | 10 tests terminal |
| búsqueda CLI de fixture con proyección y límite | subcomando search inexistente | 11 tests terminal |
| autorización y validación antes del port | 15 fallos: no se rechazó o se llamó al spy | 26 tests terminal |
| get exacto CLI | subcomando get inexistente | 27 tests terminal |
| respuesta del port fuera de contrato | 6 fallos: forma/campos inválidos aceptados | 33 tests terminal |
| identidad exacta/malformed/missing en get | 6 fallos: ID cruzado aceptado o error incorrecto | 39 tests terminal |
| MCP oficial: initialize/list/call en proceso | Connection closed sin comando; luego salida structured ausente | test real stdio verde |
| MCP: herramientas y lecturas aprobadas + isError | tools/list solo tenía 2 herramientas, faltaban search/get | 41 tests terminal; suite 175 |
| criteria CLI ambiguos | 2 fallos: traceback o clave duplicada sobrescrita | selector verde |
| esquema sintético realmente soportado | 2 fallos: capabilities afirmó nombres no soportados | 45 tests terminal |
| batch de respuesta acotado y único | 3 fallos: None/IDs duplicados/batch excesivo | 30 tests de contrato |
| excepciones de adaptadores sanitizadas | 2 fallos: RuntimeError con diagnóstico de test sin sanitizar | 50 tests terminal |
| pin oficial + entrypoint instalable | faltaba mcp==2.3.0 | selector verde; instalación editable offline y comando real health |
| JSON con aprobación duplicada | last-wins habilitó lectura | rechazo configuration_invalid |

Investigación SDK: el entorno tiene mcp 2.3.0. El import de FastMCP oficial v1
falló con la indicación de usar MCPServer v2; se contrastó la documentación
oficial y las firmas instaladas. Al probar structured output, el SDK rechazó
el tipo de retorno bare dict. Se leyó su func_metadata.py y se usó
`dict[str, Any]`/`CallToolResult`, verificando de nuevo el proceso real. No se
sustituyó el SDK por un protocolo JSON-RPC artesanal ni por respuestas falsas.

El último escenario de MCP sin aprobación false es una ampliación de
caracterización de la guardia existente: no exigió cambios de implementación.
Los tests de stdout usan la respuesta del proceso real, no mocks del servidor.
La comprobación stdio impide DNS/conexiones/bind también en el hijo.

Hubo un timeout aislado de herramienta (30 s) al ejecutar el selector JSON.
La repetición con timeout 90 s pasó en 0.21 s. No se cambió código para ocultar
el timeout ni se afirmó su causa; la verificación final completa pasó.

Resultado final medido: **187 tests: 134 anteriores + 53 nuevos; sin fallos,
errores ni skips**. El prototipo anterior pasó también sus 19 unittest offline
sin modificaciones. compileall y comprobación de compatibilidad de 83 paquetes
pasaron. No se han probado Windows, GUI, COM, DLL, VPN o red corporativa.

Los artefactos XML/JSON y el transcript completo de initialize/list/call se
conservan como evidencia privada, fuera del repositorio público. El proceso
negoció protocolo 2025-11-25, enumeró cuatro herramientas y obtuvo cuatro
éxitos y un error de dominio isError=true; stderr vacío. Puede repetirse con
los tests stdio incluidos, sin conexión corporativa.
