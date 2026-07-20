# Guía del Sistema de Traslados de Usuarios

## Descripción General

El sistema de traslados permite mover usuarios entre diferentes ubicaciones/dominios en Active Directory, manteniendo o copiando sus perfiles según sea necesario.

## Tipos de Traslado

### 1. Traslado Dentro del Mismo Dominio
- **Cuándo se aplica**: Cuando el usuario se traslada dentro de la misma provincia
- **Proceso**: Se mueve el usuario existente, se limpian sus grupos actuales y se copian los grupos del usuario plantilla
- **Ventajas**: Mantiene el historial del usuario

### 2. Traslado Entre Dominios (Copia)
- **Cuándo se aplica**: Cuando el usuario se traslada a una provincia diferente
- **Proceso**: Se crea un nuevo usuario copiando datos del original y la plantilla
- **Características**: Nuevo SamAccountName, contraseña estándar (Justicia+MM+YY)

## Flujo del Proceso

### Paso 1: Búsqueda del Usuario Existente
El sistema busca al usuario por su dirección de email en todos los dominios disponibles.

### Paso 2: Detección de Provincia
- **Origen**: Se extrae de la estructura del dominio (ej: malaga.justicia.junta-andalucia.es → málaga)
- **Destino**: Se determina por la oficina especificada en el CSV

### Paso 3: Búsqueda de Usuario Plantilla
El sistema busca un usuario plantilla con las siguientes prioridades:

1. **Coincidencia exacta**: Misma descripción (Tramitador, Auxilio, LAJ, etc.)
2. **Coincidencia por oficina**: Usuario con descripción similar en la oficina destino
3. **Selección interactiva**: Si no hay coincidencias, muestra usuarios con descripciones diferentes para selección manual

### Paso 4: Aplicación del Traslado
Según el tipo de traslado detectado:

#### Mismo Dominio:
- Limpia membresías de grupos actuales
- Copia grupos del usuario plantilla
- Actualiza propiedades (nombre, teléfono, oficina, etc.)
- Mantiene contraseña actual

#### Entre Dominios:
- Crea nuevo usuario en dominio destino
- Copia propiedades del usuario original y plantilla
- Asigna contraseña estándar (Justicia+MM+YY)
- Copia grupos del usuario plantilla

## Descripcionces de Usuario Soportadas

El sistema reconoce las siguientes descripciones y sus variantes:

- **Tramitador**: Tramitador, Tramitadora, Gestión procesal, Procesal
- **Auxilio**: Auxilio, Auxilio judicial, Auxiliar, Auxiliar judicial  
- **LAJ**: LAJ, Letrado de la administración, Letrado, Administración de Justicia
- **Letrado de la Administración de justicia**: LAJ, Letrado, Letrado de la administración
- **Juez**: Juez, Jueza, Magistrado, Magistrada

## Formato del CSV

```csv
TipoAlta;Nombre;Apellidos;Email;Telefono;Oficina;Descripcion;AD
TRASLADO;Juan;García López;juan.garcia@juntadeandalucia.es;12345678A;Sevilla Centro;Tramitador;jgarcia
NORMALIZADA;María Luisa;Martín García;;55667788E;Almería Sur;Letrado;
COMPAGINADA;José Antonio;Ruiz Pérez;josea.ruiz@juntadeandalucia.es;99887766F;Huelva Centro;Magistrado;jaruiz
```

### Campos del CSV:

#### Campos Obligatorios:
- **TipoAlta**: NORMALIZADA, TRASLADO o COMPAGINADA (obligatorio)
- **Nombre**: Nombre del usuario (obligatorio)
- **Apellidos**: Apellidos del usuario (obligatorio)
- **Oficina**: Oficina/juzgado de destino (obligatorio, usado para determinar UO y provincia)
- **Descripcion**: Puesto del usuario - LAJ, Letrado, Juez, Magistrado, Auxilio, Gestor, Tramitador (obligatorio)

#### Campos Opcionales/Condicionales:
- **Email**: Dirección de correo (opcional para NORMALIZADA, requerido para TRASLADO/COMPAGINADA si no hay AD)
- **Telefono**: DNI del usuario (se almacena en campo teléfono de AD)
- **AD**: SamAccountName del usuario existente (requerido para TRASLADO/COMPAGINADA si no hay Email, vacío para NORMALIZADA)

### Validaciones Específicas por Tipo:

#### NORMALIZADA:
- Campo AD debe estar vacío (se generará automáticamente)
- Email es opcional (para casos sin cuenta de correo)
- Se generará SamAccountName según reglas específicas

#### TRASLADO:
- Debe tener Email O campo AD para localizar usuario existente
- Se buscará primero por AD, luego por Email
- Eliminará grupos anteriores y copiará los del destino

#### COMPAGINADA:
- Debe tener Email O campo AD para localizar usuario existente
- Solo añadirá grupos adicionales sin eliminar los existentes

## Cómo Usar el Sistema

### 1. Preparar el CSV
Crear archivo CSV con los datos de traslado usando el formato especificado.

### 2. Ejecutar en Modo Prueba (WhatIf)
```powershell
.\AD_UserManagement.ps1 -CSVFile "ejemplos_traslados.csv" -WhatIf
```

### 3. Revisar Logs
Verificar el archivo de log generado para confirmar que el proceso es correcto.

### 4. Ejecutar en Modo Real
```powershell
.\AD_UserManagement.ps1 -CSVFile "ejemplos_traslados.csv"
```

## Scripts de Prueba

### TestTransferSystem.ps1
Script para probar componentes individuales del sistema:
```powershell
.\TestTransferSystem.ps1 -WhatIf
```

Prueba:
- Detección de dominios
- Búsqueda por email
- Detección de provincias
- Búsqueda de plantillas
- Proceso completo de traslado

## Archivos del Sistema

### Módulos Principales:
- **TransferManager.psm1**: Lógica principal de traslados
- **DomainStructureManager.psm1**: Gestión de estructura de dominios
- **UserTemplateManager.psm1**: Búsqueda y gestión de plantillas

### Scripts:
- **AD_UserManagement.ps1**: Script principal
- **TestTransferSystem.ps1**: Pruebas del sistema
- **ejemplos_traslados.csv**: CSV de ejemplo

## Características de Seguridad

1. **Modo WhatIf por defecto**: Todas las operaciones se pueden simular primero
2. **Validación de usuarios**: Verificación de existencia antes de procesar
3. **Selección interactiva**: Control manual cuando no hay coincidencias automáticas
4. **Logging detallado**: Registro completo de todas las operaciones
5. **Manejo de errores**: Continuación del procesamiento aunque fallen casos individuales

## Generación de SamAccountName

Para altas normalizadas, el sistema genera automáticamente el SamAccountName siguiendo estas reglas:

### Estrategias de Generación:

1. **Estrategia 1**: Iniciales del nombre + primer apellido completo
   - "Juan García López" → "jgarcia"
   - "María Luisa Rodríguez" → "mlrodriguez"

2. **Estrategia 2**: Si existe, añadir letras del segundo apellido progresivamente
   - "Juan García López" → "jgarcia", "jgarcial", "jgarcialopez"

3. **Estrategia 3**: Si se agota, usar nombre completo + iniciales del apellido
   - "Juan García López" → "juang", "juangl", etc.

4. **Fallback**: Numeración secuencial
   - "jgarcia1", "jgarcia2", etc.

### Reglas Especiales:

- **Nombres compuestos**: Se usan iniciales (María Luisa → ML)
- **Limpieza de caracteres**: Se eliminan acentos y caracteres especiales
- **Longitud máxima**: 20 caracteres
- **Verificación de unicidad**: Se verifica en el dominio de destino

### Ejemplos:
```
Juan García López → jgarcia
María Luisa Rodríguez Martín → mlrodriguez  
José Antonio Fernández → jafernandez
Carmen López → clopez
```

## Contraseñas Estándar

Para usuarios nuevos creados por traslado entre dominios:
- **Formato**: Justicia + MM + YY
- **Ejemplo actual**: Justicia0825 (Agosto 2025)
- **Política**: Forzar cambio en primer inicio de sesión

## Mapeo de Provincias

El sistema mapea automáticamente:
- **Almería**: almeria.justicia.junta-andalucia.es
- **Cádiz**: cadiz.justicia.junta-andalucia.es  
- **Córdoba**: cordoba.justicia.junta-andalucia.es
- **Granada**: granada.justicia.junta-andalucia.es
- **Huelva**: huelva.justicia.junta-andalucia.es
- **Jaén**: jaen.justicia.junta-andalucia.es
- **Málaga**: malaga.justicia.junta-andalucia.es
- **Sevilla**: sevilla.justicia.junta-andalucia.es

## Solución de Problemas

### Usuario no encontrado por email
- Verificar que el email esté correcto en el CSV
- Comprobar que el usuario existe en algún dominio
- Revisar conectividad a todos los dominios

### No se encuentra usuario plantilla
- El sistema mostrará usuarios con descripciones diferentes
- Seleccionar manualmente el más apropiado
- Verificar que existan usuarios activos en el dominio destino

### Error en creación de usuario
- Verificar permisos en el dominio destino
- Comprobar que la OU destino existe
- Revisar políticas de contraseñas del dominio

### Error en copia de grupos
- Algunos grupos pueden no ser copiables (grupos del sistema)
- Verificar permisos para gestión de grupos
- Revisar logs para grupos específicos que fallan