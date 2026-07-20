# CAU - AGENTS.md

## Repositorio

Tres sistemas independientes en un mismo repo, sin dependencias entre sí. No hay gestor de paquetes, build system, ni tareas automatizadas locales.

| Sistema | Lenguaje | Entrypoint | Tests |
|---------|----------|------------|-------|
| `AD_ADMIN/` | PowerShell 5.1+ | `AD_UserManagement.ps1` | Pester: `Tests\Run-AllTests.ps1 -TestSuite All` |
| `Macro Remedy/` | AutoHotkey v2.0 | `CAU_GUI_Refactored.ahk` | No hay suite automatizada |
| `Scripts/` | PowerShell / Batch | `CAUJUS.ps1` o `CAUJUS_refactored.bat` | No hay suite automatizada |
| `Directorio correo/` | PowerShell 5.1+ | `cambiar_password_correo.ps1` | No hay suite automatizada |
| `Temis/` | PowerShell 5.1+ | `cambiar_password_temis.ps1` | No hay suite automatizada |

## Comandos exactos

```powershell
# AD_ADMIN - simulación (SIEMPRE usar -WhatIf primero)
.\AD_UserManagement.ps1 -CSVFile "usuarios.csv" -WhatIf
.\AD_UserManagement.ps1 -CSVFile "usuarios.csv"

# AD_ADMIN - tests
.\Tests\Run-AllTests.ps1 -TestSuite All        # suite completa
.\Tests\Run-AllTests.ps1 -TestSuite Unit        # solo unitarios
.\TestModules.ps1                               # verificar carga de módulos
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine  # si falla

# Macro Remedy - ejecutar desarrollo
.\CAU_GUI_Refactored.ahk
.\compilar.bat                                   # compilar a EXE con Ahk2Exe

# Scripts CAUJUS
.\CAUJUS.ps1                                     # PowerShell (recomendado)
.\CAUJUS.ps1 -LogLevel Debug                     # logging detallado
.\CAUJUS_refactored.bat                          # Batch (legacy, equipos sin PS)

# Directorio correo (cambiar contraseña de correo corporativo)
.\Directorio\ correo\cambiar_password_correo.ps1 -TargetUser "usuario" -WhatIf
.\Directorio\ correo\cambiar_password_correo.ps1 -TargetUser "usuario.ius" -Interno    # usuarios .ius
.\Directorio\ correo\cambiar_password_correo.ps1 -TargetUser "usuario"                  # Sirhus (default)

# Temis (anular + cambiar contraseña en Escritorio Judicial)
.\Temis\cambiar_password_temis.ps1 -TemisUser "15402487P" -WhatIf
.\Temis\cambiar_password_temis.ps1 -TemisUser "15402487P"
```

## Entorno objetivo (NO es desarrollo local)

- **Windows 7 y 10** corporativos de la Junta de Andalucía (Justicia)
- **PowerShell deshabilitado** por política en muchos equipos → Batch es el plan B
- **Perfiles de usuario en disco `E:\`** configurado por directivas corporativas
- **Sin acceso a internet** directo; dependencia de recursos UNC internos:
  - `\\iusnas05\SIJ\CAU-2012\logs`
  - `\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas`
  - `\\iusnas05\DDPP\COMUN\_DRIVERS`
- Sin npm, node, python, ni runtime externo

## Convenciones del código

- UI, comentarios, logs y menús en **español**
- Nombres de funciones/variables mezcla inglés/español (ej. `Get-AvailableUOs`, `config_IslExe`)
- Batch usa `:LogMessage` para logging; PS usa `Write-CAULog`
- `runas /user:%adUser%@JUSTICIA /savecred` es la elevación en Batch
- AD_ADMIN usa `Get-Credential`, no `runas`
- Batch puede autoborrarse con `DEL "%~f0"` — intencionado (scripts de un solo uso)

## CI / GitHub

- No hay CI tradicional. Workflows Gemini (`gemini-review`, `gemini-invoke`, `gemini-triage`) con Google Gemini CLI sobre PRs/issues.
- Se ejecutan en `ubuntu-latest`, requieren GCP (Vertex AI, WIF).
- No lanzan tests, linters ni typecheckers.

## Testing (AD_ADMIN únicamente)

- Pester 5+ requerido: `Install-Module -Name Pester -Force -SkipPublisherCheck`
- `Run-AllTests.ps1` con quality gates: cobertura mínima **95%**
- Suites: `Unit`, `Integration`, `E2E`, `Performance`, `Security`, `Regression`, `All`
- `Setup-TestEnvironment.ps1` prepara mock AD y datos de prueba
- Si ActiveDirectory module no existe → modo simulación automático

## Footguns

1. **NUNCA asumir PowerShell disponible** en scripts Batch — existe precisamente para cuando PS está deshabilitado.
2. Las fechas en Batch se parsean con `%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%` (locale `dd/mm/yyyy`). Cambio de locale rompe el script.
3. `REG ADD HKCU...` vía `runas` modifica el `HKCU` de `adUser@JUSTICIA`, **no** del usuario local con sesión. Bug silencioso frecuente.
4. `*.csv` y `*.log` en `.gitignore` — datos reales no se commitean.
5. `CLAUDE.md` en `.gitignore` — no crearlo.
6. Rutas UNC (`\\iusnas05\...`) solo funcionales dentro de la red corporativa de Justicia.
7. AHK v2 configurado en `.vscode/settings.json`: intérprete en `c:\Program Files\AutoHotkey\v2\AutoHotkey.exe`.

# Wiki Processing (PROYECTO_HD) - 2026-06-23
- process_wiki.ps1 v4: routing tables now extract correctly (43 entries from 3 sections: APLICACIONES, GESTIÓN_USUARIOS, SISTEMAS_INFRAESTRUCTURA)
- Case keyword extraction: 7 cases with keywords found (1.1, 6.1-6.4, 23, 1)
- wiki_knowledge.js: 7,076 bytes, WIKI_ROUTING, WIKI_KW, WIKI_DESC, WIKI_PT_KW constants
- Next: embed wiki_knowledge.js into dashboard and build predictCaseV3() with wiki as primary source

# Wiki Integration (2026-06-23 session)
- Fixed process_wiki.ps1 routing table parsing (correct column indexing: cols[1]=tipo, cols[2]=grupo)
- Fixed case extraction: hashtable instead of array, simpler regex without unbalanced parens
- wiki_knowledge.js now has 43 routing entries (3 sections), 7 case keyword profiles, 50 PT keywords
- Added predictCaseV3() in dashboard: wiki routing as primary source for non-NA, wiki keywords as 10% bonus for NA
  - New weighting: TIPO 25%, KW_PROFILES 15%, WIKI_KW 10%, Routing 10%
  - Non-NA: wiki routing (100% conf) -> historical routing fallback
  - Tooltip shows Tipo/KW/WikiKW/Routing breakdown + Fuente
- Added Fuente column to table (Wiki SSDJ vs Histórico 2025)
- Script includes: predictor_data.js + wiki_knowledge.js
- Training stats badge now shows: '3130 casos | Wiki: 43 rutas, 7 casos'
