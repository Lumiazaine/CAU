# Scripts CAUJUS - Herramientas de Soporte CAU

## Descripcion

Conjunto de scripts de soporte para el Centro de Atencion de Usuarios (CAU)
de la Junta de Andalucia (Justicia). Proporcionan instalacion de software,
gestion de certificados, drivers y herramientas web.

## Scripts Principales

### CAUJUS.ps1 (PowerShell, recomendado)

Script interactivo con menu para tareas de soporte.

```powershell
.\Scripts\CAUJUS.ps1
.\Scripts\CAUJUS.ps1 -LogLevel Debug
.\Scripts\CAUJUS.ps1 -NoUpload
```

| Parametro | Descripcion |
|-----------|-------------|
| `-LogLevel` | Nivel de log: Error, Warning, Information (default), Debug |
| `-ConfigPath` | Ruta al JSON de configuracion |
| `-NoUpload` | No subir logs al recurso UNC |

**Requisitos:** PowerShell 5.1+, Administrador, no ejecutar en `IUSSWRDPCAU02`.

**Funcionalidades:**
- Instalacion de software: ISL, FNMT, AutoFirma, Chrome, LibreOffice
- Instalacion de drivers de lectores de DNIe y tarjetas
- Gestion de certificados FNMT (solicitar, renovar, descargar)
- Acceso a herramientas web (MiCuenta, certificados)
- Subida de logs al recurso UNC

**Archivos de configuracion:** Rutas UNC en `\\iusnas05\...` y URLs.

### CAUJUS_refactored.bat (Batch, legacy)

Version Batch para equipos donde PowerShell esta deshabilitado por politica.

```
.\Scripts\CAUJUS_refactored.bat
```

**Requisitos:** Windows, acceso a recursos UNC de la red corporativa.

**Notas:**
- Usa `runas /user:%adUser%@JUSTICIA /savecred` para elevacion
- Las fechas se parsean con `%DATE:~-4,4%%DATE:~-10,2%%DATE:~-7,2%` (locale `dd/mm/yyyy`)
- Autoborrado con `DEL "%~f0"` (scripts de un solo uso)
- Logging via `:LogMessage`

### CAUJUS_PowerShell_v3.ps1 (PowerShell v3)

Version avanzada con rutas actualizadas de software.

```powershell
.\Scripts\CAUJUS_PowerShell_v3.ps1
```

### CAUJUS_dev.bat / CAUJUS_dev.ps1 (Desarrollo)

Versiones de desarrollo con hooks de prueba.

```
.\Scripts\test_CAUJUS_dev.bat
```

## Scripts Auxiliares

| Script | Descripcion |
|--------|-------------|
| `Checkpoint_checker.ps1` | Verifica si Check Point VPN esta instalado y conecta |
| `Checkpoint_checker.bat` | Version Batch del anterior |
| `Meraki.ps1` | Creacion de usuarios AD desde CSV (legacy, mas antiguo) |
| `UO_Checker.ps1` | Enumeracion de todas las UOs en 11 dominios AD |

## Estructura

```
Scripts/
├── CAUJUS.ps1                      # Script principal (PowerShell)
├── CAUJUS_refactored.bat           # Version Batch (legacy)
├── CAUJUS_PowerShell_v3.ps1        # Version avanzada (PowerShell v3)
├── CAUJUS_dev.bat                  # Desarrollo (Batch)
├── CAUJUS_dev.ps1                  # Desarrollo (PowerShell)
├── CAUJUS.bat                      # Version original (Batch)
├── CAUJUS_Documentation.md         # Documentacion del sistema
├── CAUJUS_UserGuide.md             # Guia de usuario
├── GEMINI.md                       # Configuracion Gemini
├── test_CAUJUS_dev.bat             # Tests del sistema de logging
├── test_logs/                      # Logs de pruebas
├── Checkpoint_checker.ps1          # Verificador Check Point VPN
├── Checkpoint_checker.bat          # Version Batch
├── Meraki.ps1                      # Creacion de usuarios AD (legacy)
├── UO_Checker.ps1                  # Enumeracion de UOs
└── README.md
```

## Notas Tecnicas

### Recursos UNC

Todos los scripts usan rutas UNC en la red corporativa:
- `\\iusnas05\SIJ\CAU-2012\logs`
- `\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas`
- `\\iusnas05\DDPP\COMUN\_DRIVERS`

Estas rutas solo son accesibles dentro de la red de Justicia.

### Logging

- **PowerShell:** `Write-CAULog` con niveles Error, Warning, Information, Debug
- **Batch:** `:LogMessage` con fecha formateada en locale `dd/mm/yyyy`

### Entorno objetivo

- Windows 7 y 10 corporativos de la Junta de Andalucia (Justicia)
- PowerShell deshabilitado por politica en muchos equipos -> Batch es el plan B
- Perfiles de usuario en disco `E:\`
- Sin acceso a internet directo
- Sin npm, node, python, ni runtime externo

### Para futuros mantenedores

1. **Rutas de software:** Al actualizar versiones de ISL, FNMT, AutoFirma, etc.,
   actualizar las rutas en todos los scripts (PS y Batch). Preferir `CAUJUS.ps1`
   como fuente de verdad.
2. **Nuevos dominios:** Si se anaden dominios AD, actualizar `UO_Checker.ps1`.
3. **Tests:** El unico test automatizado es `test_CAUJUS_dev.bat` para el sistema
   de logging. No hay suite Pester.
4. **Recursos UNC:** Si cambia la IP o nombre del servidor `iusnas05`, actualizar
   en todos los scripts.
