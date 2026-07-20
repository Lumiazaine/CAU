# Integración AutoHotkey — Hoja de ruta

## Objetivo

Desde el dashboard web, al hacer clic en "Gestionar" sobre una incidencia, se debe disparar automáticamente la macro correspondiente en **Remedy (AR System)** vía AutoHotkey, incluyendo el cierre del ticket con la plantilla adecuada.

## Referencia: sistema actual

El archivo `CAU/Macro Remedy/CAU_GUI - BETA.ahk` implementa:

```
ExecuteAlbaMacro(num, desc)     → Alba(N) + rellena DNI/teléfono
ExecuteAlbaMacroWithClose(...)  → Alba(N) + cierre automático
cierre(closetext)               → Cierra ticket en Remedy
Alba(num)                       → Envía teletipo N a Remedy (Ctrl+I → selecciona macro)
```

Cada botón de la GUI dispara una macro específica:

| Botón | Macro | Descripción |
|-------|-------|-------------|
| GDU | Alba(14) | Gestión de usuarios |
| Internet libre | Alba(12) | Solicitud internet libre |
| Certificado digital | Alba(21) | Gestión certificado |
| PIN tarjeta | Alba(11) | Restaurar PIN |
| Software | Alba(4) | Instalación software |
| Disco duro | Alba(18) | Avería disco |
| Equipo sin red | Alba(5) | Problema de red |

## Arquitectura propuesta

```
┌─────────────────────┐     comando/archivo     ┌──────────────────────┐
│  Dashboard web      │ ──────────────────────→ │  HD_Gestion.ahk      │
│  (dashboard_        │    "INCOA" | "FIRMA"    │  (AutoHotkey v2)     │
│   incidencias.html) │                         │                      │
└─────────────────────┘                         │  Alba(num)           │
                                                 │  cierre(texto)       │
                                                 │  WriteLog(...)       │
                                                 └──────────────────────┘
                                                           │
                                                           ↓
                                                 ┌──────────────────────┐
                                                 │  Remedy (AR System)  │
                                                 │  ahk_class ArFrame   │
                                                 └──────────────────────┘
```

### Mecanismo de comunicación (3 opciones a estudiar)

#### Opción A: Archivo de comandos (recomendada para empezar)

```
El dashboard escribe: C:\temp\hd_cmd.txt
  → Contenido: JSON con { tipo, id, dni, telf, descripcion }

HD_Gestion.ahk (bucle con FileGetTime + FileRead):
  → Lee el archivo, ejecuta la macro correspondiente
  → Borra el archivo tras procesar
```

**Ventajas**: Simple, sin IPC, fácil de depurar.
**Inconvenientes**: Sondeo (polling), posible race condition.

#### Opción B: Named pipe (NT \\.\pipe\HD_Gestion)

```
HD_Gestion.ahk crea un pipe de lectura.
El dashboard (o un script intermedio) escribe en el pipe.
```

**Ventajas**: Comunicación bidireccional, sin polling.
**Inconvenientes**: Más complejo, requiere más pruebas.

#### Opción C: Lanzamiento directo con parámetros

```
cmd /c start "" "C:\path\HD_Gestion.ahk" "INCOA" "IN0000002551923"
HD_Gestion.ahk recibe parámetros via A_Args
```

**Ventajas**: Simple, sin estado compartido.
**Inconvenientes**: Lanza un proceso nuevo cada vez, sin cola de espera.

## Pasos para la integración (futura)

1. **Analizar todas las macros disponibles** en Remedy (números 0-50) y documentar qué hace cada una.
2. **Mapear cada bloque de incidencia** a su macro Alba correspondiente (tabla en AGENTS.md).
3. **Implementar `HD_Gestion.ahk`** con:
   - Recepción de comandos (archivo, pipe, o parámetros)
   - Función `Alba(num)` copiada del script existente
   - Función `cierre(texto)` con plantillas específicas por tipo
   - Sistema de logging
4. **Añadir al dashboard** el botón "Gestionar" funcional:
   - Al hacer clic → escribe el comando
   - Feedback visual (pendiente, procesando, completado)
5. **Probar el flujo completo**: dashboard → HD_Gestion.ahk → Remedy → cierre.

## Consideraciones de seguridad

- El script AHK se ejecuta con los permisos del usuario (no requiere admin para Remedy)
- El archivo de comandos debe estar en una ruta con acceso controlado
- Validar que Remedy esté abierto (`IfWinExist, ahk_exe aruser.exe`) antes de ejecutar
- Nunca enviar datos sensibles (contraseñas, datos personales) a través del mecanismo de comunicación

## Recursos

- Código de referencia: `CAU/Macro Remedy/CAU_GUI - BETA.ahk` (593 líneas)
- Documentación AutoHotkey v2: https://www.autohotkey.com/docs/v2/
- Formato CSV de entrada: `Helpdesk_total.csv` (10 columnas, ~2000 registros/mes)
