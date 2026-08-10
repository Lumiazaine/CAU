# Revisión LAZYAPPS — rama `review/lazyapps`

Fecha: 2026-08-10
Alcance: `lazydirectory/lazydirectory.ps1` (2.202 líneas), `lazytemis/lazytemis.ps1` (570 líneas), READMEs y HTMLs de debug.
Método: análisis estático + verificación de los parsers (regex) contra los 6 HTMLs reales de `lazydirectory/debug/` (réplica exacta de la lógica en Python; el repositorio no se ejecutó contra los servicios reales de la Junta).

---

## 1. ESTRUCTURA

**Valoración: buena.** Monolitos terminales bien seccionados, patrón UI consistente.

| App | Líneas | Organización | Entrada |
|---|---|---|---|
| lazydirectory | 2202 | UI helpers → AUTH → SEARCH → PASSWORD → SCREENS → CREAR USUARIO → MAIN | `.\lazydirectory\lazydirectory.ps1` |
| lazytemis | 570 | UI helpers → AUTH → SEARCH → PASSWORD → SCREENS → MAIN | `.\lazytemis\lazytemis.ps1` |

- **Consistencia**: ambas apps comparten el mismo esqueleto UI (`ui/header/panel/footer/row/Write-Log/prompt/pause`) — copiado, no compartido. Aceptable según AGENTS.md (sistemas independientes), pero un módulo común (`CAU-UI.psm1`) eliminaría ~150 líneas duplicadas.
- **Código muerto**: `bar` y `empty` están definidas y jamás se llaman (en ambas apps).
- **Desincronización de versiones**: `lazytemis.ps1` dice `VERSION = "2.0"`, su README dice "v1.0". `lazydirectory.ps1` dice "1.1", README "v1.0".
- **`lazytemis/debug/`** se referencia en el código (`DEBUG_DIR`) pero no existe en el repo (los HTMLs de debug de Temis están en `Temis/debug/`).
- `prompt` redefine la función automática homónima de PowerShell. Funciona en el ámbito del script, pero es un footgun si alguien hace dot-source. Renombrar a `Read-Input`.

## 2. LÓGICA — verificada contra HTMLs reales

### ✅ Correcto (verificado empíricamente)

1. **Exact-hit de búsqueda** (`name="dn"` aparece 1 vez): parser OK. `search_david_luna_ius.html` → DN `uid=david.luna.ius,o=ius,...`; `search_mrosario_suarez.html` → `uid=mrosario.suarez,o=jus,...`.
2. **Estructura de DN construida** (`uid=$uid,o=$branch,o=empleados,o=juntadeandalucia,c=es`): **correcta** — coincide con los DN reales de ambos HTMLs. El fallback de DN construido en `Set-UserPassword`/`Get-UserProfile` es fiable.
3. **Extract-FormFields**: 46/45 campos extraídos de los perfiles reales. Bien.
4. **Extract-DisplayData**: mapea el label "Identificador" → `uid` correctamente en ambos perfiles (los perfiles NO llevan campo `name="uid"`: el uid se obtiene por el label, no por input).
5. **Búsqueda parcial** (`fila_par/impar` + spans `campo ancho2` + fallback uid del email): parsea correctamente las filas de resultados.

### ⚠️ Bugs y problemas de lógica

1. **`List-By-Organismo` (lazytemis) no lista por organismo — BUG funcional.**
   Hace el POST con `codigoPartidoJudicial`/`codigoOrganismo` y **descarta la respuesta**; a continuación llama a `Search-User -Query "" -SearchField "usuario"`, que hace OTRO POST con el body de búsqueda vacío. Los filtros de organismo se pierden; devuelve resultados sin filtrar (o nada). La intención era parsear la respuesta del primer POST.
2. **Auto-detección de rama incompleta (lazydirectory) — limitación funcional confirmada con evidencia.**
   `Ensure-Branch` solo cambia a `ius` si el query contiene `.ius`. Buscar a un interno por nombre, DNI o uid sin `.ius` se queda en `jus` → 0 resultados silencioso. Evidencia en el propio repo: `search_David.html`, `search_david_luna.html` y `search_luna.html` (12.740 bytes, 0 filas parseadas, 0 DN) — el mismo usuario `david.luna.ius` aparece al buscarlo con `.ius`. Sugerencia: ante 0 resultados en `jus`, reintentar en `ius` automáticamente.
3. **`screen-sirhus-bajas`: cambia la contraseña solo del primer usuario seleccionado** (`$users[$indices[0]]`) ignorando el resto de la selección. Con selección múltiple el comportamiento sorprende.
4. **`Sirhus-Validar`: `$selectedUsers` se calcula y no se usa** (código muerto; el bucle usa `$Indices`).
5. **`screen-edit` resumen de cambios**: compara el valor `_submit` (value del option) contra el texto mostrado — el diff puede marcar/no marcar cambios incorrectamente para los campos tipo select.
6. **Tokens desincronizados**: varios puntos hacen "Token no encontrado, usando anterior" — frágil si el servidor rota el token entre peticiones.
7. **`Connect-Temis`/`Connect-Directorio` marcan `authenticated=$true` incondicionalmente** si no hay excepción: una página de error HTTP 200 (login fallido, mensaje de error renderizado) se trataría como conexión correcta.
8. **`Test-Url` (lazytemis)**: usa HEAD; servidores que responden 405/403 a HEAD dan falso negativo ("No se puede acceder").
9. **Sanidad sintáctica**: balance de llaves/corchetes correcto en ambos; `lazydirectory.ps1` tiene un `(` sin cerrar neto (probablemente dentro de string; confirmar con `pwsh -NoProfile -Command "[scriptblock]::Create((Get-Content -Raw ...))"` antes de tocar nada).

## 3. FUNCIONALIDAD — veredicto

- **Autenticación**: flujo de 4 pasos (token login → login admin → modo admin → rama LDAP) coherente con el patrón del servlet del Directorio. El `dnEmpleado` hardcodeado (`uid=just9.sandetel.ext,...`) es la cuenta de servicio "guía" — si cambia, se rompe el login.
- **Búsqueda y perfil**: funcionan según lo verificado (exact-hit y parcial). El perfil depende del HTML de la búsqueda para el DN/email (los `profile_*.html` no contienen `name="dn"`): si se llama a `Get-UserProfile` sin búsqueda previa (p.ej. tras crear usuario), el DN sale del fallback construido — correcto según la estructura verificada.
- **Cambio de contraseña**: flujo `consulta` → `modificacion/confirmarPassword` con `dn` + `pwd_modificacion` duplicado, coherente con el formulario real (los campos `pwd_modificacion`/`pwd2_modificacion` existen en el HTML del form). `-WhatIf` bien integrado en ambas apps.
- **Crear usuario (lazydirectory)**: flujo `nuevo/pantalla1 → pantalla2 → pantalla3` con re-extracción de campos del form — patrón correcto, pero no verificable sin ejecución (los debug HTMLs de creación no están commiteados).
- **No ejecutable desde este entorno** (Android/Termux sin PowerShell): la verificación es estática + parsers contra HTMLs reales. La ejecución real contra el Directorio/Temis queda pendiente de un equipo Windows con las credenciales.

## 4. SEGURIDAD 🔴

**Hallazgo crítico: fuga de datos personales en un repositorio PÚBLICO.**

- **DNIs reales** de empleados en HTMLs capturados de páginas reales: 2 en `lazydirectory/debug/`, 2 en `Temis/debug/`, 3 en `Proyecto_HD/wiki_data/` (valores exactos omitidos deliberadamente en este informe — los archivos fueron purgados del historial).
- **~100 emails personales `@juntadeandalucia.es`** con nombres reales de empleados en `Proyecto_HD/wiki_data/`, `Temis/debug/`, `lazydirectory/debug/`, `AD_ADMIN/` (los de AD_ADMIN son claramente ficticios de ejemplo; los demás, reales).
- **`.har` commiteados** (`directorio.juntadeandalucia.es.har`, `..._alta.har`, `temis.justicia...har`): tráfico HTTP completo (cabeceras, sesiones, cookies) a pesar de que `*.har` está en `.gitignore` — se commiteó antes de añadirlo y siguen en la historia.
- **`debug/` no está en `.gitignore`**: los scripts escriben HTMLs de perfiles reales (`profile_*.html`, `passerr_*.html`, `edit_*.html`) en cada ejecución → riesgo continuo de re-fuga.
- **Credenciales de administrador del Directorio en claro** en `%USERPROFILE%\.env` (`ADMIN_USER`/`ADMIN_PASS`), sin ACL restrictiva. El script incluso pregunta "¿Guardar credenciales en .env?" por defecto `s`.
- Contraseñas por defecto predecibles (`Justicia.MMyy` / `JusticiaMMyy`) mostradas en claro por pantalla — es la política corporativa, pero el log (`lazydirectory.log`/`lazytemis.log`) también las registra.
- `TEMIS_URL` es `http://` (texto plano); mitigado por VPN de Justicia, pero frágil si se usa fuera de ella.

**Recomendaciones (por urgencia):**
1. **Ahora**: poner el repo en privado, o purgar el historial con `git filter-repo` (DNIs, emails, .har). Borrar los archivos no basta: la historia los conserva.
2. Añadir `debug/` (y `*.html` bajo `Temis/debug`, `lazydirectory/debug`, `lazytemis/debug`) a `.gitignore` + limpiar los existentes.
3. `.env`: guardar en el Windows Credential Manager (o `cmdkey`), no en texto plano.
4. Eliminar los `.har` de la historia y no regenerarlos en el repo (mover a `debug/` local ignorado).

## 5. NOTAS MENORES

- `-SessionVariable script:webSession`: patrón inusual (canónico: `-SessionVariable ws` + `$script:webSession = $ws`). Si funciona, ok; si algún día las sesiones no persisten, esto es lo primero a mirar.
- El log no rota ni se limpia; `Add-Content` crece indefinidamente.
- `Search-User` (lazydirectory) escribe el debug HTML **en cada búsqueda** (incluso en producción): es la causa raíz de la fuga de `search_*.html`.
- Duplicación de UID extraído: el parcial toma el uid del onClick `enviar(...)` con fallback del email; los dos caminos convergen bien.

---

**Resumen ejecutivo**: arquitectura sólida y parsers que funcionan contra el HTML real; 2 bugs de lógica confirmados (Listar por organismo en lazytemis; auto-detección de rama en lazydirectory); riesgo de seguridad crítico por datos personales en repo público.
