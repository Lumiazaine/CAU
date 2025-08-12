# Sistema de Gestión de Altas de Usuarios AD

## Descripción
Sistema modular de PowerShell para la gestión automatizada de altas, traslados y compaginaciones de usuarios en Active Directory del dominio `justicia.junta-andalucia.es`.

## Estructura del Sistema

```
AD_ADMIN/
├── AD_UserManagement.ps1          # Script principal
├── Modules/
│   ├── UOManager.psm1             # Gestión de Unidades Organizativas
│   ├── UserSearch.psm1            # Búsqueda de usuarios
│   ├── NormalizedUserCreation.psm1 # Creación de usuarios nuevos
│   ├── UserTransfer.psm1          # Traslados de usuarios
│   └── CompoundUserCreation.psm1  # Altas compaginadas
├── Ejemplo_Usuarios.csv           # Archivo CSV de ejemplo
└── README.md                      # Este archivo
```

## Tipos de Altas Soportados

### 1. NORMALIZADA
- Crea un usuario completamente nuevo
- Genera SamAccountName automáticamente
- Configura todas las propiedades básicas
- Asigna grupos según especificación

### 2. TRASLADO
- **Directo**: Mueve el usuario a otra UO manteniendo sus propiedades
- **Eliminar_Copiar**: Elimina el usuario actual y crea uno nuevo copiando el perfil

### 3. COMPAGINADA
- Añade membresías adicionales a usuarios existentes
- Actualiza descripción y oficina para reflejar la compaginación

## Formato del Archivo CSV

El archivo CSV debe usar **punto y coma (;)** como separador y codificación **UTF-8**.

### Campos Obligatorios
- `TipoAlta`: NORMALIZADA, TRASLADO o COMPAGINADA
- `Nombre`: Nombre del usuario
- `Apellidos`: Apellidos del usuario

### Campos por Tipo de Alta

#### Para NORMALIZADA:
- `Email`: Dirección de correo electrónico
- `UO`: Unidad Organizativa de destino
- `Grupos`: Grupos separados por punto y coma

#### Para TRASLADO:
- `UsuarioExistente`: SamAccountName del usuario a trasladar
- `UODestino`: UO de destino
- `TipoTraslado`: "Directo" o "Eliminar_Copiar"
- `NuevoUsuario`: (Solo para Eliminar_Copiar) Nuevo SamAccountName

#### Para COMPAGINADA:
- `UsuarioExistente`: Usuario al que añadir membresías
- `GruposCompaginados`: Grupos adicionales separados por punto y coma
- `UOCompaginada`: UO de la cual obtener grupos automáticamente

### Campos Opcionales
- `Telefono`: Número de teléfono
- `Oficina`: Ubicación física
- `Descripcion`: Descripción del puesto
- `Departamento`: Departamento
- `Titulo`: Título del puesto
- `EmployeeID`: ID de empleado
- `Manager`: Nombre del manager
- `SetPassword`: "Si" para establecer contraseña
- `Password`: Contraseña específica (opcional)

## Uso del Sistema

### Ejecutar el Script Principal

```powershell
# Modo de prueba (WhatIf)
.\AD_UserManagement.ps1 -CSVFile ".\Ejemplo_Usuarios.csv" -WhatIf

# Ejecución real
.\AD_UserManagement.ps1 -CSVFile ".\Ejemplo_Usuarios.csv"

# Con ruta de logs personalizada
.\AD_UserManagement.ps1 -CSVFile ".\Ejemplo_Usuarios.csv" -LogPath "C:\Logs\AD_Custom"
```

### Usar Módulos Independientemente

```powershell
# Importar módulos
Import-Module ".\Modules\UserSearch.psm1"
Import-Module ".\Modules\UOManager.psm1"

# Buscar usuarios
$Users = Search-UserByName -FirstName "Juan" -LastName "García"
Format-UserSearchResults -Users $Users

# Verificar UOs disponibles
Initialize-UOManager
Get-AvailableUOs
```

## Funcionalidades Avanzadas

### Detección Automática de UOs
- Carga automática de todas las provincias de Andalucía
- Detección de nuevas UOs añadidas al dominio
- Cache de UOs para mejor rendimiento

### Búsqueda Flexible de Usuarios
- Búsqueda por nombre, apellidos, email, teléfono u oficina
- Soporte para búsquedas parciales y exactas
- Formateo automático de resultados

### Gestión de Contraseñas
- Generación de contraseñas temporales
- Forzar cambio en el próximo inicio de sesión
- Soporte para contraseñas personalizadas

## Logs y Monitoreo

El sistema genera logs detallados en `C:\Logs\AD_UserManagement\` por defecto:
- Timestamp de todas las operaciones
- Errores y advertencias detallados
- Seguimiento del progreso por usuario

## Requisitos del Sistema

- Windows Server 2019 o superior
- PowerShell 5.1 o superior
- Módulo ActiveDirectory de Windows
- Permisos de administrador de dominio
- Conectividad con los controladores de dominio

## Seguridad y Mejores Prácticas

1. **Siempre ejecutar primero en modo WhatIf** para validar cambios
2. **Revisar logs** después de cada ejecución
3. **Hacer backup** antes de operaciones masivas
4. **Validar datos CSV** antes de procesar
5. **Usar cuentas de servicio** con permisos mínimos necesarios

## Mantenimiento

### Añadir Nueva UO
Las UOs se detectan automáticamente. Si necesitas forzar la detección:

```powershell
Import-Module ".\Modules\UOManager.psm1"
Initialize-UOManager
Find-NewOUs
```

### Añadir Nuevos Campos al CSV
Modifica los módulos correspondientes para procesar los nuevos campos.

### Personalizar Generación de SamAccountName
Edita la función `Generate-SamAccountName` en `NormalizedUserCreation.psm1`.

## Resolución de Problemas

### Error: "Usuario ya existe"
- Verifica que el SamAccountName no esté en uso
- Para traslados, usa el tipo correcto (TRASLADO en lugar de NORMALIZADA)

### Error: "UO no encontrada"
- Verifica que la UO esté correctamente escrita
- Ejecuta `Get-AvailableUOs` para ver UOs disponibles

### Error: "Grupo no encontrado"
- Verifica que los grupos existan en el dominio
- Revisa permisos para consultar grupos

## Ejemplo de Uso Completo

1. Preparar archivo CSV con los datos de usuarios
2. Ejecutar en modo de prueba:
   ```powershell
   .\AD_UserManagement.ps1 -CSVFile ".\MisUsuarios.csv" -WhatIf
   ```
3. Revisar salida y logs
4. Ejecutar en modo real:
   ```powershell
   .\AD_UserManagement.ps1 -CSVFile ".\MisUsuarios.csv"
   ```
5. Verificar resultados en los logs

## Soporte

Para problemas o mejoras, contactar con el equipo del CAU (Centro de Atención a Usuarios).

---

# 🆕 NUEVAS FUNCIONALIDADES - VERSIÓN 2.0

## 🔐 Gestión Automática de Contraseñas

### Contraseña Estándar Automática
- **Formato**: `Justicia + MM + AA`
- **Ejemplo actual**: `Justicia0825` (agosto 2025)
- **Actualización**: Se actualiza automáticamente según la fecha del sistema
- **Uso**: Si no se especifica contraseña en el CSV, se usará la estándar

### Funciones del Módulo PasswordManager
```powershell
# Ver contraseña estándar actual
Get-StandardPassword

# Establecer contraseña estándar
Set-UserStandardPassword -Identity "usuario123"

# Establecer contraseña personalizada
Set-UserCustomPassword -Identity "usuario123" -Password "MiPass123!" -ForceChange

# Verificar complejidad
Test-PasswordComplexity -Password "MiPassword123!"
```

## 🔍 Herramienta de Búsqueda Interactiva

### UserSearchTool.ps1
Nueva herramienta independiente para búsqueda y gestión manual de usuarios:

```powershell
# Ejecutar herramienta
.\UserSearchTool.ps1
```

### Características de Búsqueda
- **Búsqueda flexible**: Por nombre, apellidos, email, teléfono, oficina, descripción
- **Interfaz amigable**: Menús paso a paso
- **Selección visual**: Lista numerada con iconos de estado
- **Manejo de errores**: Opciones para refinar la búsqueda si no hay resultados

### Iconos de Estado
- ✅ **[ACTIVO]**: Usuario habilitado
- 🔒 **[DESHABILITADO]**: Cuenta deshabilitada
- ⚠️ **[BLOQUEADO]**: Cuenta bloqueada
- ❓ **[DESCONOCIDO]**: Estado indeterminado

## 🛠️ Opciones de Gestión de Usuarios

Después de seleccionar un usuario, se pueden realizar estas acciones:

1. **Cambiar contraseña (estándar)**: Aplica Justicia0825
2. **Habilitar usuario**: Activa la cuenta
3. **Deshabilitar usuario**: Desactiva la cuenta con confirmación
4. **Desbloquear usuario**: Libera cuentas bloqueadas
5. **Ver grupos del usuario**: Lista completa de membresías
6. **Cambiar contraseña (personalizada)**: Con validación de complejidad
7. **Ver información de contraseña**: Estado y fechas de expiración

## 📊 Información Detallada del Usuario

La herramienta muestra:
- **Información personal**: Nombre, email, teléfono, oficina
- **Estado de cuenta**: Activo/Deshabilitado/Bloqueado
- **Fechas importantes**: Último acceso, creación, modificación
- **Contraseña**: Fecha del último cambio y días transcurridos
- **Membresías**: Todos los grupos del usuario

## 🔄 Integración con Sistema Existente

### Cambios en Módulos Existentes
- **NormalizedUserCreation**: Usa el nuevo sistema de contraseñas
- **UserTransfer**: Integrado con PasswordManager
- **UserSearch**: Expandido con funcionalidad interactiva
- **AD_UserManagement**: Incluye el nuevo módulo PasswordManager

### Compatibilidad
- **100% compatible** con archivos CSV existentes
- **Mejora automática** de contraseñas sin configuración adicional
- **Funcionalidad adicional** sin afectar scripts existentes

## 📝 Ejemplos Prácticos

### Escenario 1: Búsqueda Rápida
```
1. Ejecutar: .\UserSearchTool.ps1
2. Introducir: Solo el nombre "Juan"
3. Seleccionar: Usuario de la lista
4. Acción: Cambiar contraseña estándar
5. Resultado: Contraseña Justicia0825 aplicada
```

### Escenario 2: Gestión Completa
```
1. Búsqueda: Por email parcial "@justicia"
2. Selección: Usuario bloqueado
3. Acciones:
   - Desbloquear usuario
   - Cambiar contraseña
   - Verificar grupos
4. Resultado: Usuario operativo
```

### Escenario 3: Procesamiento Masivo Mejorado
```
1. CSV: Dejar campo Password vacío
2. Ejecución: .\AD_UserManagement.ps1 -CSVFile usuarios.csv
3. Resultado: Todos los usuarios con Justicia0825 automáticamente
```