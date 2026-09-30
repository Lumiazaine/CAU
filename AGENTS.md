# CAU — AGENTS.md

Herramientas del CAU (Centro de Atención de Usuarios) de la Junta de Andalucía, dept. Justicia.
**No hay gestor de paquetes, build system, tests globales ni CI de código.** Cada subcarpeta es un
sistema autónomo. No hay `package.json`, lockfile ni `requirements.txt` en ningún sitio: nada se
instala, todo se ejecuta in situ.

## Sistemas

| Sistema | Lenguaje | Entrypoint | Notas |
|---------|----------|------------|-------|
| `AD_ADMIN/` | PowerShell 5.1+ | `AD_UserManagement.ps1` | Único con tests (Pester) |
| `Macro Remedy/` | AHK **v1.1** y **v2.0** | `CAU_GUI - BETA.ahk` (producción) | Requiere `aruser.exe` (Remedy) abierto. Ver §Macro Remedy |
| `Scripts/` | PowerShell / Batch | `CAUJUS.ps1` / `CAUJUS_refactored.bat` | Batch = plan B sin PowerShell |
| `lazydirectory/` | PowerShell 5.1+ | `lazydirectory.ps1` | TUI Directorio Corporativo (correo), v1.1 |
| `lazytemis/` | PowerShell 5.1+ | `lazytemis.ps1` | TUI Temis (Escritorio Judicial), v2.0 |
| `Temis/` | PowerShell 5.1+ | `cambiar_password_temis.ps1` | Un solo uso, anula + establece contraseña |
| `Directorio correo/` | PowerShell 5.1+ | `cambiar_password_correo.ps1` | Un solo uso, cambia contraseña correo |
| `Proyecto_HD/` | HTML + JS + PowerShell | `dashboard_incidencias.html` | Ver sección dedicada abajo |
| `Otros_AD/`, `Otras herramientas/`, `Bateria de pruebas/` | PowerShell / Batch | varios | Scripts legacy sueltos, sin README. **No tocar sin pedido explícito** |
| `@web/@DRIANO.html`, `Recursos/AutoGUI.7z` | — | — | Recursos binarios / volcado de 650 KB |
| `LazyRemedy/` | Python 3.10+ (FastAPI + FastMCP) | `python -m lazyremedy` | pytest: `python -m pytest` (modo mock). Ver §Comandos exactos |

## Comandos exactos

```powershell
# ---- AD_ADMIN ----
cd AD_ADMIN
.\AD_UserManagement.ps1 -CSVFile "usuarios.csv" -WhatIf   # SIEMPRE -WhatIf antes de tocar AD real
.\AD_UserManagement.ps1 -CSVFile "usuarios.csv" -LogLevel INFO
.\TestModules.ps1                                       # ¿cargan los módulos?
.\Tests\Run-AllTests.ps1 -TestSuite Unit                # ⚠ ver Footgun 1
# CSV delimitado por ';' con cabecera: TipoAlta;Nombre;Apellidos;Email;UO;Grupos;SetPassword

# ---- Macro Remedy ----
cd "Macro Remedy"
# producción (AHK v1.1): hay que abrirlo con el intérprete v1, NO con el v2 de .vscode
"C:\Program Files\AutoHotkey\AutoHotkey.exe" "CAU_GUI - BETA.ahk"
# port a v2 (sin desplegar): sí funciona con el intérprete v2
"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" "CAU_GUI_BETA_v2.ahk"
.\ejecutar_v2.bat        # = AutoHotkey64.exe CAU_GUI_Refactored.ahk (refactor abandonado)
.\compilar.bat           # Ahk2Exe → CAU_GUI_v2.exe  ⚠ ver Footgun 2
.\verificar_indices.ps1  # contrasta la tabla de índices contra el ARCmds real

# ---- Scripts (CAUJUS) ----
cd Scripts
.\CAUJUS.ps1 -LogLevel Debug        # requiere Administrador (#Requires -RunAsAdministrator)
.\CAUJUS_refactored.bat             # legacy, sin PowerShell

# ---- lazydirectory (menú v1.1, auto-conecta al inicio) ----
.\lazydirectory\lazydirectory.ps1
# Menú: 1=Buscar 2=Crear usuario 3=Cambiar contraseña 4=Listas 5=Sirhus 0=Salir
# Búsqueda: 1=uid 2=DNI 3=email 4=Nombre/Apellidos 5=Tipo 6=Edificio 7=Servicio
# Desde perfil: 1=Cambiar contraseña 2=Ver campos raw 3=Ver HTML debug 4=Editar datos
# Atajo global: `s <uid>` busca sin volver al menú

# ---- lazytemis (menú v2.0) ----
.\lazytemis\lazytemis.ps1     # atajo `s <DNI>`; requiere certificado digital + VPN

# ---- Cambio de contraseña puntual ----
.\Temis\cambiar_password_temis.ps1 -TemisUser "12345678X" -WhatIf
.\Temis\cambiar_password_temis.ps1 -TemisUser "12345678X" [-NewPassword "X"] [-ShowBrowser]
.\"Directorio correo"\cambiar_password_correo.ps1 -TargetUser "usuario" -WhatIf
.\"Directorio correo"\cambiar_password_correo.ps1 -TargetUser "usuario.ius" -Interno   # ámbito ius

# LazyRemedy - API wrapper dual REST+MCP sobre BMC Remedy (solo lectura)
python -m lazyremedy rest --port 8000 --mock        # API REST (modo simulación)
python -m lazyremedy both --port 8000 --mock        # REST + MCP en un proceso (cerrojo compartido)
python -m lazyremedy mcp --transport stdio          # servidor MCP para agentes IA
python -m lazyremedy search --incidencia INC123 --json   # one-shot desatendido
python -m lazyremedy macro CSU
python -m lazyremedy probe http://hostname/arsys    # calibrar Mid Tier real
python -m pytest                                     # tests (dentro de LazyRemedy/, mock + midtier simulado)
# Backends (config.backend): midtier (HTTP, requiere midtier_url) | macro (runmacro.exe) | mock
# runmacro.exe NO existe en LAP06776; el backend primario es midtier. Ver LazyRemedy/docs/PLAN.md
# Despliegue persistente LAP06776: tarea HKCU\...\Run -> deploy\start_hidden.vbs -> both
```

## Proyecto_HD — pipeline de datos (los `*_data.js` son artefactos generados)

`dashboard_incidencias.html` es un único HTML de ~2600 líneas. Los datos se regeneran con scripts
PowerShell; los `.js` son artefactos generados, se commitean para poder abrir el HTML sin tooling.

```
scrape_wiki.ps1   → wiki_data/raw/*.txt   (DokuWiki SSDJ extranet.chap, ~85 páginas, cookies hardcoded)
process_wiki.ps1  → wiki_knowledge.js     (WIKI_ROUTING 43, WIKI_KW 7, WIKI_DESC 7, WIKI_PT_KW 50)
ods_processor.ps1 → ods_data.js           (ODS_CASOS 93, ODS_GRUPO, ODS_NIVEL_CSU) desde ods_data.json
predictor_data.js                         (SIN generador: se edita a mano. TIPO_PRIOR, CASO_TIPO, ROUTING_PRIOR, KW_PROFILES)
scraper_criticas.ps1 → criticas_data.js    (daemon, poll 60 s a infosistemas.justicia...)
servidor_helpdesk.ps1                     (HttpListener localhost:8080, lee Remedy vía COM `Remedy.User`)
```

- Para regenerar hay que seguir el orden **scrape → process**; `process_wiki.ps1` sin `wiki_data/raw/`
  genera un archivo vacío.
- El dashboard carga `predictor_data.js`, `wiki_knowledge.js`, `ods_data.js` por `<script src>` y
  `criticas_data.js` por **inyección dinámica** con cache-buster (`?t=`), para evitar CORS.
- Chart.js vía CDN (`cdn.jsdelivr.net`) — es la única dependencia externa; sin internet la 1ª carga falla.
- Único `localStorage`: clave `dashboard_csv`.
- `servidor_helpdesk.ps1` tiene IP `10.241.130.25` y puerto `8080` **hardcodeados** en dos sitios;
  el dashboard los llama vía `HD_API` cada 120 s. Si el servidor no está, el dashboard funciona igual.
- `scrape_wiki.ps1` **contiene cookies de sesión de DokuWiki en texto plano**. No subirlos ni
  compartirlos; si caducan, reautenticar contra `extranet.chap.junta-andalucia.es`.

## Macro Remedy — la macro de producción

**La que usan los técnicos es `CAU_GUI - BETA.ahk` (AHK v1.1), no `CAU_GUI_Refactored.ahk`.**
La refactorizada v2 nunca se desplegó (`compilar.bat` falla).

| Fichero | Versión | Estado |
|---|---|---|
| `CAU_GUI - BETA.ahk` | AHK v1.1 | **En producción.** Híbrido v1/v2: `Gui, N:Add`/`Send,`/`StringReplace` son v1, pero `global` (6×) y `StrReplace` son v2 |
| `CAU_GUI_BETA_v2.ahk` | AHK v2.0 | Port con los **índices de macro corregidos**. **Sin desplegar** |
| `ARCmds/ARCmds/` | — | **Verdad del listado:** 46 `.arq` `ZZZ*` + 18 `x*` |
| `Core/ButtonManager.ahk` | AHK v2.0 | Refactor abandonado. Buena transcripción (32/40) pero le faltan 6 filas |
| `AUDIT_BETA.md` | — | Auditoría: listado de 46 filas, remapeo, 15 bugs |
| `verificar_indices.ps1` | PowerShell | Contrasta la tabla contra los `.arq`. Solo lectura |

### El número de macro NO es un ID — es una posición alfabética

La macro no habla con Remedy por API: es teclado sintético sobre el formulario Oracle.
`SeleccionarMacro(n)` hace `Send("{TAB 2}{End}{Up " n "}{Enter}")`. El formulario Alba lista
las macros **en orden alfabético** y el salto sube desde la última fila, así que

```
n = (nº de macros - 1) − posición alfabética        (con 46 macros: n = 45 − posición)
```

El prefijo `ZZZ` del nombre visible es lo que fuerza ese orden. El nombre está en la **línea 1**
de cada `.arq`, en **Windows-1252** (`ñ` = `0xF1`).

Consecuencias, todas ya materializadas en producción:

- Si alguien **añade, borra o renombra** una macro, todo lo de abajo se desplaza y **los botones
  ejecutan otra cosa sin ningún aviso**.
- Lo mismo con el `{Tab 22}`: asume posición fija del cursor en el formulario.
- **No escribir nunca el número dentro de un handler.** En el v1 estaba escrito a mano: por eso
  **22 de los 24 handlers apuntaban a la fila equivocada**. El port lo resuelve por nombre,
  `ExecuteAlbaMacro(EjecutarMacro("Contraseñas"), "Contraseñas")`, con el objeto `M` al principio
  del script como única fuente. `EjecutarMacro()` devuelve `-1` si el nombre no existe y el flujo
  aborta **sin enviar ninguna tecla**.
- **La fila 0 NO es "sin macro"**: es `ZZZZConnie` (Connexion). `{End}{Up 0}{Enter}` la selecciona y
  la ejecuta. En el port se llama `ULTIMA_FILA`.

### El listado se genera desde los `.arq`, no desde `ButtonManager.ahk`

`ButtonManager.ahk` acierta 32 de 40 pero **no cuenta el segundo `ZZZCorreoPassword`** (dos ficheros
distintos, mismo nombre visible), así que su zona alta va `+1` desplazada. La tabla `M` del port está
generada desde los `.arq`. Antes de tocar cualquier índice: `./verificar_indices.ps1`.

### Los `.arq` de ARCmds

- **Windows-1252** (`-Encoding Default`). Nunca guardarlos como UTF-8: se corrompen los acentos.
  Separador de campo: byte `0x01`. Fin de línea: CRLF.
- **Están marcados `-text` en `.gitattributes` a propósito.** Sin esa regla, el `core.autocrlf=true`
  que Git trae por defecto en Windows convierte los finales de línea y rompe las macros de
  producción. **No añadir reglas `eol=lf` para el código fuente**: con medio repo en CRLF
  legadose, un `--renormalize` reescribe de golpe `Bateria de pruebas/`, `Otras herramientas/` y
  `superbateria_test.ps1`, que no se deben tocar.
- `Alba.ps1` excluye a propósito los **18 `x*.arq`** y sustituye en los otros la fecha/hora literal
  (`1010000200=` / `1010000150=`) por `$DATE$ $TIME$`. Es *offline* y ya no se invoca desde la macro.
- **`Alba(n)` en el .ahk NO tiene relación con `Alba.ps1`.** El nombre es un resto; en el port v2 se
  renombró a `SeleccionarMacro()`. `Core/ButtonManager.ahk` **sí** lo sigue lanzando en cada click
  (`ExecuteAlbaScript`, línea 228), que es el diseño antiguo, y además apunta a una ruta inexistente
  (`AppConfig.ALBA_SCRIPT_PATH`).

### Otras reglas que no se deducen del código

- **git ≠ producción**: en `#6` git usa `Alba(0)` y producción `Alba(42)`. El port mantiene `42`.
- `SendInput` en `cierre()` es intencionado (envío por eventos, distinto del `SendMode Input` del
  resto). En AHK v2 el equivalente es `SendEvent()`; `Send()` usaría el método Input y cambiaría el
  comportamiento.
- Las plantillas de correo se envían con `SendRaw` porque el texto contiene `{}` que no debe
  interpretarse como teclas. No cambiar a `Send`.

## Entorno objetivo (NO es el entorno de desarrollo)

- Windows 7 y 10 corporativos de Justicia; **PowerShell deshabilitado por política en muchos equipos**.
- Sin internet directo. Rutas UNC que solo existen en la red corporativa:
  `\\iusnas05\SIJ\CAU-2012\logs`, `\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas`,
  `\\iusnas05\DDPP\COMUN\_DRIVERS`
- Perfiles de usuario en `E:\` por directivas corporativas.
- Endpoints: `directorio.juntadeandalucia.es`, `escritoriojudicial/temis.justicia.junta-andalucia.es`,
  `infosistemas.justicia.junta-andalucia.es`, `extranet.chap.junta-andalucia.es`.
- `.vscode/settings.json` apunta el intérprete AHK a `c:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`,
  pero `CAU_GUI - BETA.ahk` es **v1.1**: F5 en VS Code no lo launcha. Hay que abrirlo con el
  intérprete v1 (`AutoHotkey.exe` v1.1) o usar `.\ejecutar_v2.bat` para los ficheros v2.

## Convenciones

- UI, comentarios, logs y menús en **español**. Nombres de función/variable mezclan ambos idiomas
  (`Get-AvailableUOs`, `config_IslExe`, `Write-CAULog`).
- Logging: PowerShell → `Write-CAULog` / `Write-Log`; Batch → `:LogMessage` (solo en
  `CAUJUS_dev.bat` y `CAUJUS_refactored.bat`).
- Elevación: AD_ADMIN y los scripts nuevos usan `Get-Credential`; el Batch legacy usa
  `runas /user:%adUser%@JUSTICIA /savecred`.
- Password corporativa por defecto: `Justicia` + MMYY.
- Codificación: los `.js` de Proyecto_HD se escriben **UTF-8 sin BOM** salvo `predictor_data.js` y
  `ods_data.js` (con BOM, generados con `Set-Content -Encoding UTF8` de PS 5.1). No "normalizar" los
  BOM al editarlos: el HTML los carga con `<script src>` y un BOM doble rompe la última constante.

## Footguns

1. **`Tests\Run-AllTests.ps1` está roto tal cual**: `Initialize-TestEnvironment` hace `throw` si falta
   `Tests\pester.config.ps1`, y ese archivo **no está en el repo** (lo documenta `Tests/README.md`).
   Además `E2E/`, `Performance/`, `Security/` y `Regression/` están declarados en `Get-TestSuites` pero
   no existen en disco; solo hay `Unit/` (5 ficheros) e `Integration/`. Para correr tests hoy:
   `Invoke-Pester -Path .\Tests\Unit` directamente, o crear `pester.config.ps1`.
2. **`compilar.bat` fallará**: pasa `/icon "Assets\icon.ico"` y no existe `Macro Remedy\Assets\`.
   Además genera `CAU_GUI_v2.exe` (no `CAU_GUI.exe` como dice el README raíz).
3. **`instalar.ps1` (raíz) no usa el repo**: añade funciones `temis` / `ldap` / `lazydirectory` al
   perfil de PowerShell que hacen `irm https://raw.githubusercontent.com/Lumiazaine/CAU/...` **en cada
   llamada**. Editar una copia local no cambia lo que ejecutan los usuarios instalados.
4. **`REG ADD HKCU...` dentro de `runas`** (CAUJUS_dev.bat) escribe en el `HKCU` del usuario AD
  Elevado, no en el del técnico con sesión. Fallo silencioso clásico.
5. **Nunca asumas PowerShell en Batch**: `CAUJUS.bat` / `Bateria de pruebas\CAU.bat` existen para
   equipos con PS bloqueado.
6. **Fechas en Batch**: `%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%` asume locale `dd/mm/yyyy`.
   Cambiar locale rompe `CAUJUS.bat` y `CAUJUS_dev.bat`.
7. **`del "%~f0"` es intencionado** en varios `.bat` (scripts de un solo uso que se autoborran).
8. **Credenciales en claro**: `lazydirectory` y `Directorio correo` leen/escriben
   `%USERPROFILE%\.env` con `ADMIN_USER` / `ADMIN_PASS`. `.env` está en `.gitignore` — no commitearlo.
9. `.gitignore` excluye `*.csv` y `*.log`; los CSV de entrada son datos reales de empleados y se
   generan en el momento. También ignora `CLAUDE.md` y `Macro Remedy/nul`.
10. LazyRemedy: `runmacro.exe` **no soporta concurrencia** — respetar el cerrojo (`asyncio.Lock` + mutex).
    Búsquedas por `usuario_temis`/`correo`/`telefono` requieren `search_field_map` en config
    (solo `incidencia_id`=1 está garantizado). El backend por defecto es `midtier`: `runmacro.exe`
    no existe en LAP06776.
## Testing

Solo `AD_ADMIN/Tests/`. Pester 5.6.1 (`Install-Module Pester -Force -SkipPublisherCheck`).
Quality gates en `Run-AllTests.ps1`: cobertura mínima **95%** (`-CoverageThreshold`), umbral
configurable por parámetro. `Setup-TestEnvironment.ps1` requiere **Administrador**
(`#Requires -RunAsAdministrator`). Si el módulo `ActiveDirectory` no está, los módulos caen en modo
simulación automáticamente. El resto de sistemas no tiene suite.

## CI

Sin CI de código. Hay 5 workflows Gemini (`gemini-review`, `gemini-invoke`, `gemini-triage`,
`gemini-dispatch`, `gemini-scheduled-triage`) sobre `ubuntu-latest` con GCP (Vertex AI + WIF) que
solo revisan PRs/issues vía Gemini CLI. No ejecutan tests, linters ni typecheckers: **el CI no te
avisa de nada**, la verificación es manual.

## Documentos que están desfasados — no confiar sin verificar

- `README.md` y `GEMINI.md` (raíz) describen "tres sistemas"; hay al menos ocho.
- `Proyecto_HD/AGENTS.md`, `Proyecto_HD/README.md` y `Proyecto_HD/.opencode.jsonc` son anteriores a
  los ficheros `*_data.js`: afirman "no hay datos embebidos" y `ODS_TIPO_CASO` no lo usa nadie.
- `Scripts/GEMINI.md` marca `Meraki.ps1` como "needs further verification".
- `Proyecto_HD/AGENTS.md` sigue siendo la referencia buena de la lógica del dashboard
  (`BLOCK_DEFS`, `MACRO_MAP`, `predictCaseV3`); complétala, no la reescribas desde cero.
