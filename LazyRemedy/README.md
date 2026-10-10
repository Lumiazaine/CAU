# LazyRemedy

Wrapper experimental REST (FastAPI) + MCP (FastMCP) para integrar lecturas de BMC Remedy. **No hay una integración con el servidor corporativo verificada.** La versión del cliente AR System User 7.0.01 no identifica la versión del servidor.

## Estado y límites

- La suite es offline: usa datos sintéticos, un servidor HTTP loopback y un ejecutable sustituto. Un resultado verde no prueba acceso a Remedy real.
- `mock=True` prevalece sobre el backend configurado y no abre conexiones a Remedy.
- El acceso no simulado está bloqueado por defecto (`live_access_approved=False`). Este indicador es un cierre preventivo local, **no concede permisos ni verifica un contrato**.
- Las operaciones expuestas son búsquedas y macros de consulta. La ausencia de escrituras en un macro instalado debe verificarse con su propietario antes de ejecutarlo; el wrapper no audita todos los comandos `.arq`.
- No se ha confirmado el contrato de `runmacro.exe` ni que acepte `LAZYREMEDY_OUTPUT_FILE`. En la comprobación SSH del Windows objetivo el ejecutable no estaba presente en la ruta esperada.
- Las rutas Mid Tier y el parseo HTML son experimentales: no son la API REST oficial del servidor AR. No se deducen endpoints desde una IP/alias del cliente.
- La CLI sigue limitada a bind loopback. Sin token configurado, `create_app()` rechaza peers no loopback (403), incluidos docs/OpenAPI y apps montadas. Con `LAZYREMEDY_API_TOKEN`, exige `Authorization: Bearer <token>` en **todas** las rutas; un peer remoto con token válido puede acceder a una app importada. Esto no autoriza exponerla: requiere TLS y revisión del despliegue. El token no aparece en diagnósticos. MCP HTTP standalone conserva la guardia de bind; el MCP montado en `both` hereda la guardia ASGI.
- CORS está vacío por defecto y rechaza comodines explícitos. No reenviar mediante proxy/túnel sin token: un proxy puede aparecer como peer loopback. No confiar en cabeceras forwarded de clientes externos; TLS y gestión/rotación del token requieren revisión antes de cualquier exposición.

Ver [seguridad y límites de verificación](docs/RELEASE-SECURITY.md). La evidencia detallada con metadata del entorno se conserva de forma privada, fuera del repositorio público.

## Instalación y pruebas

Python 3.10+; los backends nativos reales son dependientes de Windows y del contrato de integración.

```powershell
python -m pip install ".[test]"
python -m pytest -q -o addopts=""
```

La suite elimina variables `LAZYREMEDY_*` heredadas y bloquea DNS/conexiones externas; permite únicamente loopback para sus fixtures. `test_real_path.py` prueba un **subproceso local sintético**, no el cliente ni el servidor corporativo. No apuntar estos tests a producción.

## Uso offline

```powershell
python -m lazyremedy rest --mock --host 127.0.0.1 --port 8000
python -m lazyremedy mcp --mock --transport stdio
python -m lazyremedy both --mock --host 127.0.0.1 --port 8000
python -m lazyremedy search --mock --incidencia SYNTHETIC-001 --json
python -m lazyremedy macro --mock CSU --json
python -m lazyremedy macros
python -m lazyremedy config --ejemplo
```

Los resultados mock son fijos y sintéticos; no representan una búsqueda filtrada real. REST: `/docs`, `/health`, `/api/v1/macros`, `POST /api/v1/search`, `POST /api/v1/macros/{macro_id}/run`. MCP en modo `both`: `/mcp`.

## Configuración

Precedencia: defaults → variables `LAZYREMEDY_*` → JSON (`--config` o `LAZYREMEDY_CONFIG`). No se carga `.env` implícitamente. `config` omite usuario/contraseña y redacta argumentos del subproceso; no introducir secretos en URLs u otros campos de diagnóstico.

Generar el ejemplo desde `config --ejemplo`: los ejemplos históricos no acreditan valores seguros ni endpoints válidos. Mantener TLS verificado. No introducir contraseñas en `runmacro_args`, comandos, logs ni Git.

El mapeo predeterminado de campos es una hipótesis derivada de macros previos (`101_INCIDENCIAS`), no metadata del servidor verificada. El campo `1` es Request ID; no sustituir automáticamente por él un número visible de incidencia. Confirmar formulario, campo consultable e ID exactos con el propietario.

Para una futura prueba real se necesita: endpoint/version/auth documentados, aprobación del propietario, identidad autorizada y un único registro de prueba no sensible. Mid Tier exige rutas explícitas del mismo origen y **solo admite URLs con IP literal loopback para fixtures**. `live_access_approved=True` no habilita Mid Tier corporativo: falta un contrato de autenticación/resultados verificado. `probe` solo admite fixtures HTTP(S) de IP literal loopback, sin credenciales en URL ni puertos inválidos, incluso con aprobación; no descubre rutas. Encontrar un formulario HTML no prueba que la consulta esté soportada.

## Arquitectura

`cli.py` → `RemedyService` → backend `macro`/`mock` o `midtier`. REST y MCP comparten el servicio en modo `both`. El backend macro serializa subprocesos mediante `asyncio.Lock` y un mutex Win32 **`Local\\LazyRemedyRunmacro`** (POSIX: `flock`). El namespace Local no garantiza exclusión entre sesiones Windows distintas.

El motor descarta stdout/stderr para evitar bloqueos y exposición de datos, mata y espera únicamente su subproceso al cancelar/expirar, y consume un archivo de salida local. El adaptador externo debe producir ese archivo mediante un contrato confirmado. Esto no demuestra que el `runmacro.exe` oficial implemente dicho contrato.

La API devuelve errores estructurados 400/404/502/503/504. El backend HTML rechaza respuestas sin tabla reconocible; aun así, cualquier tabla no acredita una sesión autenticada ni un resultado Remedy válido. Por ello se bloquea el backend HTML fuera de loopback antes de enviar credenciales/consultas. Las consultas/macrocolas no tienen aún un límite de resultados verificable del lado servidor: no habilitarlas para exportaciones.
