# Gestor de Incidencias CAU - Versión Refactorizada 2.0.0

## 📋 Descripción

Sistema automatizado para gestión de incidencias en Remedy con interfaz gráfica mejorada, desarrollado específicamente para el Centro de Atención de Usuarios (CAU) del sistema judicial.

## ✨ Características Principales

### 🔧 Funcionalidades Core
- **Gestión automatizada** de incidencias en Remedy
- **Cálculo automático** de letra de DNI español
- **Interfaz gráfica intuitiva** con categorización de botones
- **42 tipos de incidencias** predefinidas organizadas por categorías
- **Búsqueda rápida** de incidencias existentes
- **Modo AFK** para mantener sesión activa

### 🏗️ Arquitectura Mejorada
- **Arquitectura orientada a objetos** con separación de responsabilidades
- **Patrón Singleton** para gestión de instancias
- **Configuración centralizada** y modular
- **Sistema de logging avanzado** con niveles configurables
- **Manejo robusto de errores** con recuperación automática
- **Actualización automática** desde GitHub

### 🎯 Mejoras de Rendimiento
- **Optimización de AutoHotkey** para máximo rendimiento
- **Timer de alta precisión** para operaciones críticas
- **Carga asíncrona** de actualizaciones
- **Gestión eficiente de memoria**

## 📁 Estructura del Proyecto

```
CAU_GUI_Refactored/
├── CAU_GUI_Refactored.ahk          # Archivo principal
├── README.md                       # Documentación
│
├── Config/
│   └── AppConfig.ahk               # Configuración centralizada
│
├── Utils/
│   ├── Logger.ahk                  # Sistema de logging
│   └── DNIValidator.ahk            # Validación y cálculo de DNI
│
├── Core/
│   ├── ButtonManager.ahk           # Gestión de botones y acciones
│   ├── UpdateManager.ahk           # Sistema de actualización
│   └── CAUApplication.ahk          # Clase principal de aplicación
│
└── Assets/ (opcional)
    └── icon.ico                    # Icono de la aplicación
```

## 🚀 Instalación

### Requisitos Previos
- Windows 10/11
- AutoHotkey v1.1.33+ 
- Remedy (aruser.exe) instalado
- PowerShell habilitado
- Acceso a internet para actualizaciones

### Instalación Manual
1. Descargar todos los archivos manteniendo la estructura de carpetas
2. Asegurar que Remedy esté instalado y funcional
3. Verificar que el script de Alba esté en la ruta configurada
4. Ejecutar `CAU_GUI_Refactored.ahk`

### Compilación (Opcional)
```bash
# Usando Ahk2Exe
Ahk2Exe.exe /in CAU_GUI_Refactored.ahk /out CAU_GUI.exe /icon Assets\icon.ico
```

## 🎮 Uso

### Inicio Rápido
1. **Abrir Remedy** antes de usar la aplicación
2. **Ejecutar CAU_GUI_Refactored.ahk**
3. **Completar campos**: DNI (se calcula la letra automáticamente) y Teléfono
4. **Hacer clic** en el botón correspondiente a la incidencia
5. Los datos se procesan automáticamente en Remedy

### Categorías de Incidencias

#### 📱 INCIDENCIAS
- Adriano, Escritorio judicial, Arconte
- Agenda de señalamientos, Expediente digital
- Hermes, Jara, Quenda/Cita previa
- @Driano, Contraseñas, etc.

#### 📋 SOLICITUDES  
- PortafirmasNG, Suministros, Internet libre
- Multiconferencia, Dragon Speaking
- Aumento espacio correo, Abbypdf, GDU
- Intervención video, Formaciones

#### ✅ CIERRES
- Orfila, Lexnet, Siraj2
- Software, PIN tarjeta

#### 🏛️ MINISTERIO
- Sistemas específicos del ministerio

#### 💻 DP (Dispositivos Periféricos)
- Lector tarjeta, Equipo sin red, GM
- Teléfono, Ganes, Equipo no enciende
- Disco duro, Monitor, Teclado, Ratón
- ISL Apagado, Error relación de confianza

### Hotkeys Disponibles

| Tecla | Función |
|-------|---------|
| `Win+1` | Quenda/Cita previa |
| `Win+2` | PortafirmasNG |
| `Win+3` | Expediente digital |
| `Win+4` | Contraseñas |
| `Win+5` | Edoc Fortuny |
| `Win+6` | Repetir incidencias (solicita cantidad) |
| `Win+7` | Activar/Desactivar modo AFK |
| `Win+9` | Búsqueda rápida |
| `Win+0` | Recargar aplicación |
| `F12-F20` | Funciones especializadas |
| `XButton1` | Acceder menú Alt de Remedy |
| `XButton2` | Captura de pantalla |

## ⚙️ Configuración

### Archivo de Configuración (`Config/AppConfig.ahk`)
```autohotkey
class AppConfig {
    static VERSION := "2.0.0"
    static REPO_URL := "https://api.github.com/repos/JUST3EXT/CAU/releases/latest"
    static GUI_WIDTH := 1456
    static GUI_HEIGHT := 704
    static LOG_ENABLED := true
    static AFK_TIMER_INTERVAL := 60000
    // ... más configuraciones
}
```

### Personalización
- **Cambiar versión**: Modificar `AppConfig.VERSION`
- **Ajustar GUI**: Modificar `GUI_WIDTH` y `GUI_HEIGHT`
- **Configurar logging**: Cambiar `LOG_ENABLED`
- **Intervalos de timer**: Ajustar `AFK_TIMER_INTERVAL`

## 📊 Sistema de Logging

### Niveles de Log
- **DEBUG**: Información detallada para desarrollo
- **INFO**: Información general de operaciones
- **WARNING**: Advertencias que no impiden funcionamiento
- **ERROR**: Errores que afectan funcionalidad
- **CRITICAL**: Errores críticos que pueden cerrar la app

### Ubicación de Logs
```
%USERPROFILE%\Documents\log_[MES][AÑO].txt
```

Ejemplo: `log_enero2025.txt`

### Ejemplo de Entrada de Log
```
2025-01-15 14:30:25 - COMPUTER01 - [INFO] Gestor de incidencias CAU v2.0.0 iniciado
2025-01-15 14:30:26 - COMPUTER01 - [DEBUG] [PERFORMANCE] Carga módulos: 150ms
2025-01-15 14:30:30 - COMPUTER01 - [INFO] [LEGACY] Ejecutó macro alba 12345678Zy654321987
```

## 🔄 Sistema de Actualización

### Características
- **Verificación automática** al inicio
- **Descarga desde GitHub** Releases
- **Instalación automática** con backup
- **Versionado semántico** (major.minor.patch)
- **Reinicio automático** después de actualización

### Proceso de Actualización
1. Verificar versión remota vs local
2. Mostrar prompt al usuario
3. Descargar nueva versión
4. Crear backup del archivo actual  
5. Reemplazar archivo y reiniciar

## 🛠️ Desarrollo

### Estructura de Clases

#### `CAUApplication`
Clase principal que coordina toda la aplicación:
```autohotkey
class CAUApplication {
    static GetInstance()        // Singleton
    Start()                    // Inicializar app
    CreateGUI()               // Crear interfaz
    HandleButtonClick()       // Manejar clicks
    HandleAFKMode()          // Gestionar modo AFK
}
```

#### `ButtonManager` 
Gestiona botones y sus acciones:
```autohotkey
class ButtonManager {
    ExecuteButtonAction()     // Ejecutar acción de botón
    ExecuteAlbaScript()      // Ejecutar script Alba
    CheckRemedy()           // Verificar Remedy abierto
}
```

#### `UpdateManager`
Sistema de actualización:
```autohotkey
class UpdateManager {
    CheckForUpdates()        // Verificar actualizaciones
    DownloadLatestVersion() // Descargar versión
    PerformUpdate()         // Realizar actualización
}
```

### Añadir Nueva Funcionalidad

#### 1. Nuevo Botón
Modificar `ButtonManager.ahk`:
```autohotkey
this.buttonConfigs["Button43"] := {
    name: "Nueva Función", 
    albaParam: 45, 
    category: "INCIDENCIAS",
    description: "Descripción de la nueva función"
}
```

#### 2. Nuevo Hotkey
Modificar `CAUApplication.ahk`:
```autohotkey
Hotkey, F21, HandleF21
// ...
HandleF21:
    CAUApplication.GetInstance().HandleButtonClick("Button43")
return
```

#### 3. Nueva Configuración
Modificar `AppConfig.ahk`:
```autohotkey
static NEW_SETTING := "valor_por_defecto"
```

## 🐛 Solución de Problemas

### Problemas Comunes

#### Error: "Remedy no se encuentra abierto"
- **Causa**: Remedy no está ejecutándose
- **Solución**: Abrir Remedy antes de usar la aplicación
- **Verificación**: Buscar proceso `aruser.exe` en Task Manager

#### Error: "No se pudo verificar actualizaciones"
- **Causa**: Sin conexión a internet o GitHub no accesible
- **Solución**: Verificar conectividad, usar VPN si es necesario
- **Alternativa**: Deshabilitar verificación automática

#### GUI no se muestra correctamente
- **Causa**: Resolución de pantalla incompatible
- **Solución**: Ajustar `GUI_WIDTH` y `GUI_HEIGHT` en `AppConfig.ahk`
- **Alternativa**: Usar modo ventana en lugar de pantalla completa

#### Script de Alba no funciona
- **Causa**: Ruta incorrecta o permisos insuficientes
- **Solución**: Verificar `ALBA_SCRIPT_PATH` en configuración
- **Verificación**: Ejecutar PowerShell como administrador

### Logging para Debug
Para resolver problemas, activar logging detallado:
```autohotkey
Logger.GetInstance().SetLevel(Logger.LEVEL_DEBUG)
```

## 📈 Changelog

### v2.0.0 (2025-01-15)
- ✅ Refactorización completa a arquitectura orientada a objetos
- ✅ Sistema de logging avanzado con niveles
- ✅ Mejoras en sistema de actualización automática
- ✅ Validación mejorada de DNI
- ✅ Configuración modular y centralizada
- ✅ Documentación técnica completa
- ✅ Optimización de rendimiento
- ✅ Mejoras en UX y accesibilidad

### v1.0.0 (Original)
- Funcionalidad básica de gestión de incidencias
- GUI básica con botones
- Integración con Remedy
- Cálculo básico de DNI
- Sistema de actualización básico

## 📄 Licencia

Este software es de uso interno para el Centro de Atención de Usuarios (CAU) del sistema judicial. Todos los derechos reservados.

## 👥 Contribución

Para contribuir al proyecto:

1. **Fork** el repositorio
2. **Crear branch** para nuevas características (`git checkout -b feature/AmazingFeature`)
3. **Commit** cambios (`git commit -m 'Add some AmazingFeature'`)
4. **Push** al branch (`git push origin feature/AmazingFeature`)
5. **Abrir Pull Request**

### Estándares de Código
- Usar comentarios descriptivos en español
- Seguir convenciones de nomenclatura AutoHotkey
- Documentar todas las funciones públicas
- Incluir manejo de errores apropiado
- Escribir logs informativos para operaciones importantes

## 📞 Soporte

Para soporte técnico:
- **Logs**: Revisar `%USERPROFILE%\Documents\log_*.txt`
- **Issues**: GitHub Issues del repositorio
- **Documentación**: Este README.md
- **Contacto**: CAU Team

---

**Desarrollado con ❤️ por el equipo CAU para mejorar la eficiencia en la gestión de incidencias del sistema judicial.**