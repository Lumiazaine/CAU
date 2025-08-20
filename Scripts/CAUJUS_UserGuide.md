# Guía Práctica del Usuario - CAU IT Support Utility

## 🚀 Inicio Rápido

### ¿Qué es la Utilidad CAU?
La Utilidad CAU es una herramienta de soporte técnico que te ayuda a resolver problemas comunes en tu equipo de trabajo de forma rápida y sencilla.

### ¿Cuándo usarla?
- Tu equipo va lento
- Problemas con certificados digitales
- Instalación de software corporativo
- Problemas de impresión
- Diagnósticos de red

## 📋 Antes de Empezar

### ✅ Requisitos Previos
1. **Credenciales**: Ten a mano tu usuario de dominio (@JUSTICIA)
2. **Permisos**: Necesitas ser administrador local del equipo
3. **Red**: Conexión estable a la red corporativa
4. **Tiempo**: Reserve 15-30 minutos según la operación

### 🔧 Versiones Disponibles

| Versión | Archivo | Recomendado para |
|---------|---------|------------------|
| **Básica** | `CAUJUS_refactored.bat` | Windows 7/8, equipos antiguos |
| **Avanzada** | `CAUJUS.ps1` | Windows 10/11, equipos modernos |

## 🎯 Guías de Uso por Escenarios

### Escenario 1: "Mi equipo va muy lento"

**Problema**: El equipo tarda mucho en abrir programas, navegar es lento, etc.

**Solución: Optimización del Sistema**

#### Pasos a seguir:

1. **Ejecutar la utilidad**:
   ```cmd
   # Versión básica
   Clic derecho en CAUJUS_refactored.bat → "Ejecutar como administrador"
   
   # Versión avanzada  
   Clic derecho en PowerShell → "Ejecutar como administrador"
   .\CAUJUS.ps1
   ```

2. **Introducir credenciales**:
   ```
   introduce tu AD: miusuario
   ```

3. **Seleccionar opción 1**:
   ```
   ==========================================
                      CAU
         IT Support Utility v3.0
   ==========================================
   
   Sistema: PC001, Usuario: miusuario, IP: 192.168.1.100
   
   1. Batería pruebas (OPTIMIZACIÓN) ← SELECCIONAR ESTA
   2. Cambiar password correo
   ...
   
   Escoge una opción: 1
   ```

4. **Proceso automático**:
   - ✅ Cierra navegadores
   - ✅ Limpia cachés
   - ✅ Optimiza registro
   - ✅ Elimina archivos temporales
   - ✅ Actualiza políticas

5. **Decisión final**:
   ```
   Reiniciar equipo (s/n): s
   ```

**⏱️ Tiempo estimado**: 10-15 minutos
**🔄 Frecuencia recomendada**: Semanal o cuando notes lentitud

---

### Escenario 2: "Necesito instalar/renovar mi certificado digital"

**Problema**: Certificado expirado, nuevo certificado, problemas de firma

**Solución: Gestión de Certificados**

#### Pasos para RENOVAR certificado:

1. **Acceder al menú certificados**:
   ```
   Opción principal: 5. Certificado digital
   ```

2. **Preparar el navegador**:
   ```
   ==========================================
              Certificado digital
   ==========================================
   
   1. Configuración previa (Silenciosa) ← EJECUTAR PRIMERO
   2. Configuración previa (Manual)
   3. Solicitar certificado digital
   4. Renovar certificado digital ← DESPUÉS ESTA
   5. Descargar certificado digital
   6. Inicio
   
   Escoge una opción: 1
   ```

3. **Renovar certificado**:
   ```
   Escoge una opción: 4
   ```
   - Se abre automáticamente la página de renovación FNMT
   - Sigue el proceso en el navegador

#### Pasos para NUEVO certificado:

1. **Configurar navegador** (opción 1)
2. **Solicitar** (opción 3)
3. **Esperar activación** (24-48h)
4. **Descargar** (opción 5)

**📱 Importante**: Ten a mano tu DNI/NIE y el móvil para recibir SMS

---

### Escenario 3: "La impresora no funciona"

**Problema**: Documentos no salen, cola bloqueada, error de impresión

**Solución: Reset del Sistema de Impresión**

#### Pasos:

1. **Seleccionar opción de impresión**:
   ```
   Opción principal: 3. Reiniciar cola impresión
   ```

2. **Proceso automático**:
   - ✅ Para el servicio de impresión
   - ✅ Limpia trabajos pendientes
   - ✅ Reinicia el servicio

3. **Verificar funcionamiento**:
   - Intenta imprimir un documento de prueba
   - Si persiste, contacta con soporte

**⏱️ Tiempo estimado**: 2-3 minutos

---

### Escenario 4: "Necesito instalar Chrome/LibreOffice/AutoFirma"

**Problema**: Software corporativo no instalado o versión incorrecta

**Solución: Instalación desde Repositorio Corporativo**

#### Pasos:

1. **Acceder a utilidades**:
   ```
   Opción principal: 7. Utilidades
   ```

2. **Seleccionar software**:
   ```
   ==========================================
                 Utilidades
   ==========================================
   
   2. Instalar Chrome 109 ← Para navegador corporativo
   6. Instalar Autofirmas ← Para firma digital
   7. Instalar Libreoffice ← Para ofimática
   ```

3. **Instalación automática**:
   - Descarga desde repositorio corporativo
   - Instalación silenciosa
   - Configuración básica

**🔒 Ventaja**: Garantiza versiones corporativas y licencias válidas

---

### Escenario 5: "Problemas de red/conexión"

**Problema**: Internet lento, no puedo acceder a recursos, IP incorrecta

**Solución: Diagnósticos de Red** (Solo versión PowerShell)

#### Pasos:

1. **Acceder a utilidades**:
   ```
   Opción principal: 7. Utilidades
   ```

2. **Ejecutar diagnósticos**:
   ```
   10. Network Diagnostics ← SELECCIONAR
   ```

3. **Revisar resultados**:
   ```
   ==========================================
            Network Diagnostics
   ==========================================
   
   Testing Local Network Gateway... [OK]
   Testing DNS Server... [OK]
   Testing Internet Connectivity... [FAILED] ← PROBLEMA AQUÍ
   Testing Company Domain... [OK]
   
   Network Configuration:
     Ethernet: IP: 192.168.1.100, Gateway: 192.168.1.1
   ```

4. **Soluciones comunes**:
   - Si todo [OK]: Problema específico de aplicación
   - Si Gateway [FAILED]: Problema de red local
   - Si DNS [FAILED]: Problema de resolución de nombres
   - Si Internet [FAILED]: Problema de conectividad externa

---

## 🛠️ Funciones Adicionales

### Información del Sistema
```
Opción: 8. System Information (PowerShell)
```
Muestra información detallada del equipo:
- Modelo y fabricante
- Versión de Windows
- Memoria RAM
- Último reinicio
- Certificados instalados

### Sincronización de Fecha/Hora
```
Utilidades → 8. Force Time Sync
```
Útil cuando:
- Certificados fallan por fecha incorrecta
- Problemas de autenticación
- Logs con timestamp erróneo

### Corrección de Pantalla Negra
```
Utilidades → 3. Fix Black Screen
```
Para cuando:
- Pantalla negra tras conectar/desconectar monitor
- Problemas de duplicación de pantalla
- Resolución incorrecta

## 🚨 Resolución de Problemas Comunes

### Error: "No se puede ejecutar en servidor de salto"
**Causa**: Estás en IUSSWRDPCAU02
**Solución**: Ejecuta desde tu equipo de trabajo, no desde el servidor

### Error: "Usuario AD requerido"
**Causa**: No introdujiste usuario de dominio
**Solución**: Usar formato: `miusuario` (sin @JUSTICIA)

### Error: "Repositorio no accesible"
**Causa**: Problemas de red o permisos
**Solución**: 
1. Verificar conexión VPN
2. Comprobar usuario de dominio
3. Contactar con administrador de red

### Instalación falla
**Causa**: Permisos o archivo corrupto
**Solución**:
1. Ejecutar como administrador
2. Cerrar antivirus temporalmente
3. Verificar espacio en disco

## 📊 Interpretación de Logs

### Ubicación de logs
- **Local**: `C:\Users\[usuario]\AppData\Local\Temp\CAUJUS_Logs\`
- **Red**: `\\iusnas05\SIJ\CAU-2012\logs\`

### Ejemplo de log exitoso
```
2025-08-20 10:30:15 [INFO] Session started - User: jdoe, AD: jdoe, Host: PC001
2025-08-20 10:30:20 [INFO] Main menu selection: 1
2025-08-20 10:30:25 [INFO] Starting system optimization
2025-08-20 10:35:40 [INFO] System optimization completed successfully
```

### Indicadores de problemas
```
[ERROR] Failed to access repository
[WARN] Some cache clearing operations failed
[ERROR] Elevated execution failed with code 1
```

## 📞 Cuándo Contactar Soporte

### Usa la utilidad cuando:
- ✅ Problemas de rendimiento general
- ✅ Certificados digitales estándar
- ✅ Instalaciones de software corporativo
- ✅ Problemas de impresión básicos
- ✅ Mantenimiento preventivo

### Contacta soporte cuando:
- ❌ Pantalla azul (BSOD)
- ❌ Hardware no funciona
- ❌ Problemas de dominio/autenticación
- ❌ Virus/malware
- ❌ Errores críticos del sistema
- ❌ La utilidad no soluciona el problema

## 🎓 Consejos de Uso

### ✅ Buenas Prácticas
1. **Ejecuta siempre como administrador**
2. **Cierra aplicaciones importantes antes de optimizar**
3. **Haz backup de datos críticos antes de cambios importantes**
4. **Ejecuta optimización semanalmente**
5. **Mantén actualizada la utilidad**

### ❌ Evita
1. **Interrumpir procesos de optimización**
2. **Ejecutar múltiples veces seguidas**
3. **Usar en servidores de producción**
4. **Modificar archivos de configuración sin conocimiento**

### 🔄 Mantenimiento Recomendado

| Frecuencia | Acción |
|------------|--------|
| **Diario** | Verificar que todo funciona correctamente |
| **Semanal** | Ejecutar optimización del sistema |
| **Mensual** | Verificar certificados y actualizaciones |
| **Trimestral** | Revisión completa del equipo |

## 📚 Recursos Adicionales

### Enlaces Útiles
- **Portal Empleado**: https://micuenta.juntadeandalucia.es
- **FNMT Certificados**: https://www.sede.fnmt.gob.es
- **Soporte CAU**: Ext. 1234 (horario 8:00-15:00)

### Documentación Relacionada
- Manual de Certificados Digitales Corporativos
- Guía de Configuración de Puesto de Trabajo
- Procedimientos de Backup y Restauración

### Videos Tutoriales (Intranet)
- "Cómo optimizar tu equipo de trabajo"
- "Gestión de certificados digitales paso a paso"
- "Instalación de software corporativo"

---

**📧 Feedback**: Si tienes sugerencias para mejorar esta guía, contacta con el equipo CAU

**🔄 Última actualización**: 20/08/2025

**📋 Versión de la guía**: 1.0