# Guía del Sistema AD_ADMIN - Gestión Completa de Usuarios

## Descripción General

El sistema AD_ADMIN es una suite completa de herramientas para la gestión de usuarios en Active Directory, diseñado específicamente para entornos multi-dominio del sistema de justicia. Incluye funcionalidades para traslados, búsquedas, creación de usuarios y gestión de contraseñas.

## Estructura del Sistema

### Scripts Principales

#### 1. **AD_UserManagement.ps1**
**Funcionalidad**: Script principal para gestión completa de usuarios
**Uso**: 
```powershell
.\AD_UserManagement.ps1 -CSVFile "usuarios.csv" [-WhatIf]
```

**Características**:
- Procesamiento de altas normalizadas, traslados y compaginaciones
- Modo WhatIf para pruebas seguras
- Logging detallado automático
- Detección automática de tipos de operación
- Corrección automática de caracteres especiales

#### 2. **MultiDomainUserSearch.ps1** 
**Funcionalidad**: Herramienta de búsqueda avanzada en múltiples dominios
**Uso**:
```powershell
.\MultiDomainUserSearch.ps1 [-Domain "almeria"] [-SearchAllDomains]
```

**Características**:
- Búsqueda en todos los dominios del bosque
- Interfaz interactiva para selección de usuarios
- Gestión completa de usuarios (habilitar, deshabilitar, cambiar contraseña)
- Visualización de grupos y permisos
- Manejo seguro de propiedades de AD

#### 3. **TestSystemComponents.ps1**
**Funcionalidad**: Suite completa de pruebas del sistema
**Uso**:
```powershell
.\TestSystemComponents.ps1 [-TestModule "All|SamAccountName|Password|CSV|Search"] [-WhatIf]
```

**Características**:
- Prueba todos los módulos y funcionalidades
- Validación de conectividad a dominios
- Verificación de permisos y funciones
- Informes detallados de estado

#### 4. **TestModules.ps1** y **TestTransferSystem.ps1**
**Funcionalidad**: Scripts de prueba específicos mantenidos por compatibilidad
**Uso**: Para pruebas específicas de componentes individuales

### Módulos del Sistema

#### **Módulos Core**

1. **DomainStructureManager.psm1**
   - Gestión de estructura de dominios y bosques
   - Detección automática de dominios disponibles
   - Mapeo de provincias y localidades

2. **UserSearch.psm1**
   - Búsquedas avanzadas de usuarios
   - Criterios múltiples (nombre, email, oficina, descripción)
   - Interfaz interactiva para selección

3. **MultiDomainSearch.psm1**
   - Búsqueda simultánea en múltiples dominios
   - Agregación y consolidación de resultados
   - Manejo seguro de propiedades de colecciones AD

#### **Módulos de Gestión**

4. **SamAccountNameGenerator.psm1**
   - Generación automática de nombres de usuario
   - Múltiples estrategias de generación
   - Verificación de unicidad en todos los dominios

5. **PasswordManager.psm1**
   - Gestión de contraseñas estándar y personalizadas
   - Validación de complejidad
   - Políticas de expiración y cambio forzoso

6. **TransferManager.psm1**
   - Lógica de traslados entre dominios
   - Detección automática de tipo de traslado
   - Preservación de datos y grupos

#### **Módulos de Soporte**

7. **CSVValidation.psm1**
   - Validación de estructura y contenido de archivos CSV
   - Verificación de campos obligatorios por tipo de alta
   - Normalización de datos de entrada

8. **UOManager.psm1**
   - Gestión de Unidades Organizativas
   - Mapeo automático de oficinas a UOs
   - Sistema de puntuación para coincidencias

9. **UserTemplateManager.psm1**
   - Búsqueda y gestión de usuarios plantilla
   - Copia de grupos y permisos
   - Selección interactiva cuando es necesaria

10. **UserTransfer.psm1** y **NormalizedUserCreation.psm1**
    - Funcionalidades específicas para tipos de operación
    - Manejo de casos especiales y excepciones

## Tipos de Operaciones

### 1. Alta Normalizada
**Cuándo se usa**: Creación de nuevos usuarios
**Proceso**:
- Generación automática de SamAccountName
- Asignación de contraseña estándar (Justicia+MM+YY)
- Búsqueda automática de UO por oficina
- Copia de grupos de usuario plantilla

**Ejemplo CSV**:
```csv
TipoAlta;Nombre;Apellidos;Email;Telefono;Oficina;Descripcion;AD
NORMALIZADA;María;González López;;12345678A;Juzgado de Primera Instancia Nº 3 de Sevilla;Gestión Procesal;
```

### 2. Traslado
**Cuándo se usa**: Movimiento de usuarios existentes
**Proceso**:
- Búsqueda del usuario por campo AD o Email
- Detección automática de dominio origen y destino
- **Mismo dominio**: Mover usuario, limpiar y copiar grupos
- **Entre dominios**: Crear nuevo usuario, mantener el original

**Ejemplo CSV**:
```csv
TipoAlta;Nombre;Apellidos;Email;Telefono;Oficina;Descripcion;AD
TRASLADO;Juan;Pérez Martín;juan.perez@juntadeandalucia.es;98765432B;Juzgado de Primera Instancia Nº 1 de Granada;Auxilio Judicial;jperez
```

### 3. Compaginación
**Cuándo se usa**: Añadir funciones adicionales sin eliminar las existentes
**Proceso**:
- Búsqueda del usuario existente
- Adición de grupos sin eliminar los actuales
- Actualización de propiedades si es necesario

## Mejoras y Características Nuevas

### **Corrección de Caracteres Especiales**
- **Problema resuelto**: Caracteres como "ñ", "º" aparecían como "�"
- **Solución**: Función `Normalize-Text` que convierte automáticamente caracteres problemáticos
- **Aplicado a**: Nombres de oficina, descripciones, campos de texto

### **Búsqueda de Usuario Plantilla Mejorada**
- **Problema resuelto**: Fallos en coincidencia de descripciones con tildes
- **Solución**: Normalización previa de descripciones antes de comparar
- **Mapeos añadidos**: "Gestión Procesal" ↔ "gestion", incluyendo variantes con/sin tildes

### **Selección Inteligente de UO**
- **Problema resuelto**: Selección incorrecta entre UOs similares (ej: Primera Instancia vs Instrucción)
- **Solución**: Sistema de puntuación que prioriza coincidencias específicas
- **Ejemplo**: "Primera Instancia" recibe bonus de +20 puntos vs "Instrucción" con +2 puntos

### **Manejo Robusto de Propiedades AD**
- **Problema resuelto**: Errores al mostrar propiedades tipo `ADPropertyValueCollection`
- **Solución**: Función `Get-SafePropertyValue` que maneja colecciones de manera segura
- **Aplicado a**: Todas las visualizaciones de propiedades de usuario

## Arquitectura Modular

### **Ventajas del Sistema Modular**
1. **Mantenibilidad**: Cada funcionalidad en su propio módulo
2. **Reutilización**: Módulos compartidos entre scripts
3. **Escalabilidad**: Fácil añadir nuevas funcionalidades
4. **Pruebas**: Cada módulo se puede probar independientemente

### **Imports Automáticos**
Los módulos importan automáticamente sus dependencias:
```powershell
Import-Module "$PSScriptRoot\DomainStructureManager.psm1" -Force
Import-Module "$PSScriptRoot\UserSearch.psm1" -Force
```

### **Funciones Exportadas**
Cada módulo exporta solo las funciones públicas necesarias:
```powershell
Export-ModuleMember -Function @(
    'Search-UsersInAllDomains',
    'Show-MultiDomainSearchResults', 
    'Start-MultiDomainUserSearch'
)
```

## Formato del CSV

### Estructura Requerida
```csv
TipoAlta;Nombre;Apellidos;Email;Telefono;Oficina;Descripcion;AD
```

### Campos Obligatorios por Tipo

#### **NORMALIZADA**
- ✅ TipoAlta, Nombre, Apellidos, Oficina, Descripcion
- ❌ AD (debe estar vacío)
- 🔸 Email (opcional), Telefono (opcional)

#### **TRASLADO**
- ✅ TipoAlta, Nombre, Apellidos, Oficina, Descripcion
- ✅ AD O Email (al menos uno para localizar usuario)
- 🔸 Telefono (opcional)

#### **COMPAGINADA**
- ✅ TipoAlta, Nombre, Apellidos, Oficina, Descripcion
- ✅ AD O Email (al menos uno para localizar usuario)
- 🔸 Telefono (opcional)

### Validaciones Automáticas
- **Estructura**: Verificación de columnas requeridas
- **Contenido**: Validación de campos según tipo de alta
- **Consistencia**: Verificación de coherencia entre campos
- **Caracteres**: Normalización automática de caracteres especiales

## Generación de SamAccountName

### Estrategias de Generación
1. **Estrategia Principal**: Iniciales nombre + primer apellido
   - "Juan García López" → "jgarcia"
   - "María Luisa Rodríguez" → "mlrodriguez"

2. **Estrategia Secundaria**: Añadir letras del segundo apellido
   - Si "jgarcia" existe → "jgarcial", "jgarcialopez"

3. **Estrategia Terciaria**: Nombre completo + iniciales apellidos
   - "Juan García López" → "juang", "juangl"

4. **Fallback**: Numeración secuencial
   - "jgarcia1", "jgarcia2", etc.

### Características
- **Verificación Global**: Comprueba unicidad en TODOS los dominios
- **Longitud Máxima**: 20 caracteres
- **Caracteres Permitidos**: Solo letras y números
- **Normalización**: Eliminación automática de acentos

## Contraseñas Estándar

### Formato Actual
- **Patrón**: Justicia + MM + YY
- **Ejemplo**: Justicia0825 (Agosto 2025)
- **Política**: Cambio obligatorio en primer inicio
- **Actualización**: Automática según fecha del sistema

### Validación de Complejidad
- **Longitud mínima**: 8 caracteres
- **Requisitos**: Mayúsculas, minúsculas, números, símbolos
- **Verificación**: Automática antes de asignar contraseñas personalizadas

## Mapeo de Provincias y Dominios

```
Almería   → almeria.justicia.junta-andalucia.es
Cádiz     → cadiz.justicia.junta-andalucia.es  
Córdoba   → cordoba.justicia.junta-andalucia.es
Granada   → granada.justicia.junta-andalucia.es
Huelva    → huelva.justicia.junta-andalucia.es
Jaén      → jaen.justicia.junta-andalucia.es
Málaga    → malaga.justicia.junta-andalucia.es
Sevilla   → sevilla.justicia.junta-andalucia.es
```

### Detección Automática
- **Por oficina**: Extracción automática de provincia del nombre de oficina
- **Flexibilidad**: Maneja variaciones como "Almería", "almeria", "ALMERIA"
- **Fallback**: Dominio principal si no se detecta provincia específica

## Logging y Monitoreo

### Archivos de Log Automáticos
- **Ubicación**: `C:\Logs\AD_UserManagement\`
- **Formato**: `AD_UserManagement_YYYYMMDD_HHMMSS.log`
- **Contenido**: Timestamp, nivel, mensaje detallado
- **Rotación**: Automática por ejecución

### Niveles de Log
- **INFO**: Operaciones normales
- **WARNING**: Situaciones que requieren atención
- **ERROR**: Errores que impiden operaciones
- **DEBUG**: Información detallada para diagnóstico

### CSV de Resultados

#### **Sistema Dual de Archivos CSV**
El sistema ahora genera dos tipos de archivos CSV:

1. **CSV de Ejecución Individual**
   - **Ubicación**: Mismo directorio que el CSV de entrada
   - **Formato**: `[archivo_original]_resultados_YYYYMMDD_HHMMSS.csv`
   - **Contenido**: Solo los resultados de la ejecución actual
   - **Uso**: Para revisar resultados específicos de una operación

2. **CSV Acumulativo Histórico** ⭐ **NUEVO**
   - **Ubicación**: `AD_ADMIN_Historial_Completo_Altas.csv`
   - **Formato**: Archivo único que nunca se sobrescribe
   - **Contenido**: **TODOS** los resultados históricos de todas las ejecuciones
   - **Uso**: Control total y auditoría completa de todas las altas realizadas

#### **Campos Adicionales en CSV Histórico**
- **FechaProceso**: Timestamp exacto de procesamiento
- **ProcesoId**: Identificador único del proceso de ejecución  
- **ArchivoOrigen**: Nombre del CSV original procesado
- **VersionSistema**: Versión del sistema AD_ADMIN utilizado
- **UsuarioEjecucion**: Usuario que ejecutó el proceso
- **ServidorEjecucion**: Servidor donde se ejecutó

#### **Control de Duplicados**
- Automático: El sistema evita duplicar registros idénticos
- Criterios: Nombre + Apellidos + AD + TipoAlta + Estado + ArchivoOrigen
- Los duplicados se omiten automáticamente con mensaje en log

## Casos de Uso Comunes

### **Ejecución Básica**
```powershell
# Modo prueba (recomendado primero)
.\AD_UserManagement.ps1 -CSVFile "nuevos_usuarios.csv" -WhatIf

# Ejecución real
.\AD_UserManagement.ps1 -CSVFile "nuevos_usuarios.csv"
```

### **Búsqueda de Usuarios**
```powershell
# Búsqueda interactiva
.\MultiDomainUserSearch.ps1

# Búsqueda en dominio específico
.\MultiDomainUserSearch.ps1 -Domain "sevilla"

# Búsqueda en todos los dominios
.\MultiDomainUserSearch.ps1 -SearchAllDomains
```

### **Pruebas del Sistema**
```powershell
# Prueba completa
.\TestSystemComponents.ps1

# Prueba específica
.\TestSystemComponents.ps1 -TestModule "Search"

# Modo WhatIf
.\TestSystemComponents.ps1 -WhatIf
```

## Solución de Problemas

### **Errores Comunes**

#### "No se encontró el módulo"
- **Causa**: Estructura de directorios incorrecta
- **Solución**: Verificar que todos los archivos .psm1 están en `Modules\`

#### "Usuario no encontrado por email"
- **Causa**: Email incorrecto o usuario no existe
- **Solución**: Verificar email en AD, probar con campo AD

#### "Error de permisos"
- **Causa**: Cuenta sin permisos suficientes
- **Solución**: Ejecutar con cuenta de administrador de dominio

#### "Caracteres extraños en campos"
- **Causa**: Problema de codificación (RESUELTO en nueva versión)
- **Solución**: Automática con función `Normalize-Text`

### **Diagnóstico Avanzado**

#### Verificar Estado de Módulos
```powershell
.\TestSystemComponents.ps1 -TestModule "Modules"
```

#### Verificar Conectividad Dominios
```powershell
.\TestSystemComponents.ps1 -TestModule "Search"
```

#### Log Detallado
- Revisar `C:\Logs\AD_UserManagement\` para logs detallados
- Buscar mensajes ERROR y WARNING específicos

## Desarrollo y Extensión

### **Añadir Nuevas Funcionalidades**
1. Crear nuevo módulo en `Modules\`
2. Implementar funciones con `Export-ModuleMember`
3. Importar en script principal si es necesario
4. Añadir pruebas en `TestSystemComponents.ps1`

### **Modificar Comportamientos**
1. Localizar módulo responsable
2. Editar función específica
3. Probar con `TestSystemComponents.ps1`
4. Actualizar documentación

### **Buenas Prácticas**
- ✅ Usar módulos para funcionalidad reutilizable
- ✅ Implementar logging detallado
- ✅ Incluir validaciones y manejo de errores
- ✅ Documentar cambios en esta guía
- ✅ Probar en modo WhatIf primero

## Historial de Versiones

### **Versión Actual (2025-08-20)**
- ✅ Corrección completa de caracteres especiales
- ✅ Mejora en búsqueda de usuario plantilla  
- ✅ Sistema de puntuación para selección de UO
- ✅ Manejo robusto de propiedades AD
- ✅ Refactorización modular completa
- ✅ Script de pruebas unificado
- ✅ Herramienta búsqueda multi-dominio mejorada

### **Cambios Principales**
1. **Arquitectura**: De scripts monolíticos a sistema modular
2. **Robustez**: Manejo de errores y casos especiales mejorado  
3. **Usabilidad**: Interfaces más intuitivas y feedback claro
4. **Mantenibilidad**: Código organizado y documentado
5. **Funcionalidad**: Nuevas capacidades de búsqueda y gestión

---

**Última actualización**: 2025-08-20  
**Versión del sistema**: 2.0.0 (Modular)  
**Compatibilidad**: PowerShell 5.1+, Windows Server 2016+, Active Directory módulo requerido