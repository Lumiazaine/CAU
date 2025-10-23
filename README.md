# CAU - Centro de Atención de Usuarios

Repositorio integral de herramientas y mejoras para el CAU del sistema judicial de Andalucía. Incluye tres sistemas principales: **AD_ADMIN** (gestión de Active Directory), **Macro Remedy** (gestión de incidencias) y **Scripts** (utilidades de soporte IT).

## Sistemas Incluidos 🏗️

### 1. AD_ADMIN - Sistema de Gestión de Active Directory
**Ubicación:** `AD_ADMIN/`
**Descripción:** Sistema modular en PowerShell para automatización de gestión de usuarios en el dominio `justicia.junta-andalucia.es`.

**Características principales:**
- ✅ **100% precisión** en mapeo de UOs con tiempo de respuesta <100ms
- 🔄 **Tres tipos de operaciones**: Altas normalizadas, traslados y compaginadas  
- 🎯 **Sistema de scoring avanzado** con 6 componentes y fuzzy matching
- 🧪 **Suite de testing completa** con Pester (500+ casos de prueba)
- 📊 **Optimización de rendimiento** con cache concurrente y métricas

**Archivos clave:**
- `AD_UserManagement.ps1` - Script principal
- `Modules/` - Módulos especializados (UOManager, PasswordManager, UserSearch, etc.)
- `Tests/` - Framework de testing con calidad empresarial

### 2. Macro Remedy - Sistema de Gestión de Incidencias
**Ubicación:** `Macro Remedy/`
**Descripción:** Aplicación AutoHotkey v2.0 con arquitectura orientada a objetos para gestión automatizada de incidencias en Remedy.

**Características principales:**
- 🎯 **42 tipos de incidencias** organizadas por categorías
- 🔄 **Actualización automática** desde GitHub
- 📊 **Sistema de logging avanzado** con niveles configurables
- ⚡ **Cálculo automático de DNI** español con validación
- 🏗️ **Arquitectura modular** con patrón Singleton

### 3. Scripts - Utilidades de Soporte IT
**Ubicación:** `Scripts/`
**Descripción:** Colección de scripts PowerShell y Batch para tareas de soporte técnico automatizadas.

**Características principales:**
- 🛠️ **CAUJUS** - Sistema integral de optimización y soporte
- 🔐 **Gestión de certificados** FNMT automatizada  
- 📊 **Diagnósticos de red** y conectividad
- ⚙️ **Instalación automatizada** de software corporativo

## Comenzando 🚀

### Pre-requisitos 📋

**Para AD_ADMIN:**
```
PowerShell 5.1+
Módulo ActiveDirectory de Windows
Windows Server 2019+ / Windows 10+
Permisos de administrador de dominio
```

**Para Macro Remedy:**
```
AutoHotkey v2.0+ (recomendado) o v1.1.33+
Windows 10/11
Remedy (aruser.exe) instalado
```

**Para Scripts:**
```
PowerShell 5.1+
Privilegios de administrador local
Acceso a recursos de red corporativos
```

### Instalación Rápida 🔧

#### AD_ADMIN
```powershell
# Clonar repositorio
git clone https://github.com/JUST3EXT/CAU.git
cd CAU/AD_ADMIN

# Probar módulos
.\TestModules.ps1

# Ejecutar con archivo CSV de ejemplo
.\AD_UserManagement.ps1 -CSVFile ".\Ejemplo_Usuarios.csv" -WhatIf
```

#### Macro Remedy
```bash
# Compilar aplicación (opcional)
Ahk2Exe.exe /in CAU_GUI_Refactored.ahk /out CAU_GUI.exe

# Ejecutar directamente
.\CAU_GUI_Refactored.ahk
```

#### Scripts
```powershell
# Versión PowerShell avanzada
.\Scripts\CAUJUS.ps1

# Versión Batch refactorizada
.\Scripts\CAUJUS_refactored.bat
```

## Comandos de Desarrollo 💻

### AD_ADMIN - Comandos Frecuentes
```powershell
# Testing y validación
.\TestModules.ps1                                    # Probar carga de módulos
.\Tests\Run-AllTests.ps1 -TestSuite All            # Suite completa de tests
.\Tests\Run-AllTests.ps1 -TestSuite Unit           # Solo tests unitarios
.\test_simple_functions.ps1                        # Test básico de funciones

# Uso en producción
.\AD_UserManagement.ps1 -CSVFile "usuarios.csv" -WhatIf    # Modo simulación
.\AD_UserManagement.ps1 -CSVFile "usuarios.csv"           # Ejecución real

# Uso de módulos individuales
Import-Module ".\Modules\UOManager.psm1"
Initialize-UOManager
Get-AvailableUOs
```

### Macro Remedy - Comandos de Build
```bash
# Compilación
.\compilar.bat                                      # Compilar con Ahk2Exe

# Ejecución de desarrollo  
.\ejecutar_v2.bat                                   # Ejecutar versión de desarrollo
```

### Scripts - Comandos de Sistema
```powershell
# CAUJUS PowerShell (recomendado)
.\Scripts\CAUJUS.ps1                               # Menú interactivo
.\Scripts\CAUJUS.ps1 -LogLevel Debug              # Con logging detallado

# CAUJUS Batch (compatibilidad)
.\Scripts\CAUJUS_refactored.bat                   # Versión batch refactorizada
```

## Arquitectura del Sistema 🏗️

### AD_ADMIN - Arquitectura Modular
```
AD_UserManagement.ps1 (Núcleo)
├── Normalize-Text (Soporte UTF-8 mejorado)
├── Extract-LocationFromOffice (Matching fuzzy de provincias)
├── Get-EnhancedMatchingScore (Sistema scoring 6 componentes)
└── Get-UOMatchConfidence (Evaluación confianza dinámica)

Modules/
├── UOManager.psm1 (Cache optimizado + pooling conexiones)
├── PasswordManager.psm1 (Gestión Justicia+MM+AA)
├── UserSearch.psm1 (Búsqueda flexible usuarios)
├── UserTransfer.psm1 (Traslados directos/eliminar-copiar)
└── NormalizedUserCreation.psm1 (Altas normalizadas)
```

### Macro Remedy - Patrón Orientado a Objetos
```
CAUApplication (Singleton principal)
├── ButtonManager (Gestión 42 tipos incidencias)
├── UpdateManager (Auto-actualización GitHub)
├── Logger (Sistema logging multinivel)
└── DNIValidator (Validación DNI español)
```

## Especificaciones Técnicas ⚡

### AD_ADMIN - Métricas de Rendimiento
- **Precisión**: 100% en mapeo de UOs (casos de prueba validados)
- **Tiempo de respuesta**: <100ms (promedio 67ms en 100 operaciones)
- **Tolerancia a fallos**: 0 falsos positivos en funcionalidad core
- **Cobertura de tests**: 95% mínimo requerido
- **Soporte de caracteres**: UTF-8 completo con corrección de corrupción

### Macro Remedy - Optimizaciones AutoHotkey  
- **Resolución timer**: 5000ns alta precisión
- **Prioridad proceso**: High para operaciones críticas
- **Modo input**: Optimizado para máxima velocidad
- **Gestión memoria**: Optimizada para operaciones sostenidas

## Construido con 🛠️

**Tecnologías principales:**
* **[PowerShell 5.1+](https://docs.microsoft.com/powershell/)** - Automatización y gestión AD
* **[AutoHotkey v2.0](https://www.autohotkey.com/)** - Automatización GUI e incidencias
* **[Pester](https://pester.dev/)** - Framework de testing PowerShell
* **[Active Directory PowerShell Module](https://docs.microsoft.com/powershell/module/addsadministration/)** - Gestión directorio
* **[Visual Studio Code](https://code.visualstudio.com/)** - Editor principal de desarrollo

**Herramientas de desarrollo:**
* **Git** - Control de versiones
* **PowerShell ISE/VSCode** - Desarrollo y debugging
* **Ahk2Exe** - Compilación aplicaciones AutoHotkey
* **Remedy** - Sistema de gestión de incidencias

## Guías de Uso Específicas 📖

### AD_ADMIN - Tipos de Operaciones

**1. NORMALIZADA - Crear usuario nuevo:**
```csv
TipoAlta;Nombre;Apellidos;Email;UO;Grupos;SetPassword
NORMALIZADA;Juan;García López;juan.garcia@justicia.junta-andalucia.es;malaga;Usuarios_Malaga;Si
```

**2. TRASLADO - Mover usuario existente:**
```csv
TipoAlta;UsuarioExistente;UODestino;TipoTraslado
TRASLADO;juan.garcia;sevilla;Directo
TRASLADO;maria.lopez;cadiz;Eliminar_Copiar;maria.lopez.cadiz
```

**3. COMPAGINADA - Añadir membresías:**
```csv
TipoAlta;UsuarioExistente;GruposCompaginados;UOCompaginada
COMPAGINADA;pedro.sanchez;Grupo_Especial;cordoba
```

### Macro Remedy - Categorías de Incidencias

**📱 INCIDENCIAS:**
- Adriano, Escritorio judicial, Arconte
- Agenda señalamientos, Expediente digital
- Hermes, Jara, Quenda/Cita previa, @Driano

**📋 SOLICITUDES:**
- PortafirmasNG, Suministros, Internet libre
- Multiconferencia, Dragon Speaking, Formaciones

**✅ CIERRES:**  
- Orfila, Lexnet, Siraj2, Software, PIN tarjeta

**💻 DISPOSITIVOS:**
- Lector tarjeta, Equipo sin red, Teléfono
- Disco duro, Monitor, Teclado, Ratón

### Scripts - Funcionalidades CAUJUS

**🔧 Optimización Sistema:**
- Batería pruebas completa con limpieza cachés
- Cierre automático navegadores + limpieza temporal
- Aplicación optimizaciones rendimiento

**🔐 Certificados Digitales:**
- Configuración FNMT silenciosa/manual
- Gestión solicitud/renovación/descarga certificados
- Validación integridad certificados instalados

**⚙️ Utilidades Sistema:**
- Reset cola impresión + trabajos bloqueados
- Instalación software (Chrome 109, LibreOffice, AutoFirma)
- Gestión drivers tarjetas + diagnosticos hardware

## Dependencias de Red 🌐

Todos los sistemas dependen del acceso a:
- `\\iusnas05\SIJ\CAU-2012\logs` (logging centralizado)
- `\\iusnas05\DDPP\COMUN\Aplicaciones Corporativas` (repositorio software)
- `\\iusnas05\DDPP\COMUN\_DRIVERS` (repositorio drivers)
- **AD_ADMIN**: Controladores dominio `justicia.junta-andalucia.es`
- **Macro Remedy**: GitHub para auto-actualizaciones

## Solución de Problemas 🔧

### AD_ADMIN - Errores Comunes
```powershell
# Error: "Usuario ya existe"
# Solución: Usar tipo TRASLADO en lugar de NORMALIZADA

# Error: "UO no encontrada"  
Get-AvailableUOs  # Ver UOs disponibles
Initialize-UOManager -ForceFullLoad  # Forzar recarga

# Error: ActiveDirectory no disponible
# Los módulos funcionan en modo simulación automáticamente
```

### Macro Remedy - Problemas Frecuentes
```
# Error: "Remedy no encontrado"
# Solución: Abrir aruser.exe antes de ejecutar macro

# Error: "No se puede verificar actualizaciones"  
# Solución: Verificar conectividad internet/VPN
```

## Contribuyendo 🖇️

### Proceso de Desarrollo
1. **Fork** del repositorio
2. **Branch** para nuevas características (`feature/nueva-funcionalidad`)
3. **Desarrollo** con tests incluidos
4. **Pull Request** con descripción detallada
5. **Code Review** por equipo técnico
6. **Merge** tras aprobación

### Estándares de Código
**PowerShell:**
- Usar `[CmdletBinding()]` en funciones avanzadas
- Documentación con Comment-Based Help
- Manejo robusto de errores con try-catch
- Tests con Pester para toda funcionalidad nueva

**AutoHotkey:**
- Seguir convenciones v2.0 para desarrollo nuevo
- Arquitectura orientada a objetos para aplicaciones complejas
- Logging informativo para operaciones importantes
- Validación entrada usuario y manejo excepciones

Los pull request serán evaluados técnicamente y si obtienen el visto bueno, serán añadidos a main.

## Wiki 📖

Puedes encontrar mucho más de cómo utilizar este proyecto en nuestra [Wiki](https://github.com/JUST3EXT/CAU/wiki)

## Autores ✒️


* **David Luna González** - *Trabajo Inicial y documentación* - [Lumiazaine](https://github.com/Lumiazaine)

También puedes mirar la lista de todos los [contribuyentes](https://github.com/JUST3EXT/CAU/graphs/contributors) quíenes han participado en este proyecto. 

## Licencia 📄

Este proyecto está bajo la Licencia (GPL-3.0 license) - mira el archivo [LICENSE.md](LICENSE.md) para detalles

## Expresiones de Gratitud 🎁

* Invita un monster o un café ☕ a alguien del equipo. 

> Para todos aquellos compañeros del CAU de Justicia, por su apoyo, consejos, cariño y sugerencias a lo largo de este tiempo.
> Este proyecto es por y para vosotros ❤️

