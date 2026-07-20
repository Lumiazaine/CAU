# Proyecto_HD — Dashboard y gestión de incidencias Helpdesk

**Sistema de análisis y gestión de incidencias del CAU (Junta de Andalucía, Justicia).**

## Componentes

| Componente | Tecnología | Función |
|------------|-----------|---------|
| `dashboard_incidencias.html` | HTML + JS + Chart.js | Dashboard web para analizar CSV de incidencias |
| `docs/AHK_integration_roadmap.md` | Documentación | Hoja de ruta para futura integración con AutoHotkey |
| (futuro) `HD_Gestion.ahk` | AutoHotkey v2 | Automatización de macros en Remedy según tipo de incidencia |

## Cómo usar el dashboard

1. Abre `dashboard_incidencias.html` en cualquier navegador moderno.
2. Arrastra el archivo CSV de incidencias al recuadro superior.
3. El dashboard analiza automáticamente:
   - **Tendencia temporal** (incidencias/día, NUEVO ADRIANO, urgentes)
   - **Bloques críticos** (INCOA, Firma, Itineración, Impresoras, etc.)
   - **Palabras y bigramas más frecuentes** en las descripciones
   - **Distribución por cargo y provincia**
   - **Tabla interactiva** con filtros, ordenación, paginación y exportación

## Formato CSV esperado

El dashboard detecta columnas automáticamente por nombre aproximado:

| Columna buscada | Nombres aceptados |
|----------------|-------------------|
| ID | `ID`, `ID Incidencia` |
| Descripción | `Descripción del Incidente`, `descripcion`, `desc` |
| Fecha | `Fecha Creación`, `fecha`, `date` |
| Clase/Categoría | `Clase`, `clase`, `category` |
| Cargo/Rol | `Cargo`, `cargo`, `role` |
| Provincia | `Provincia`, `provincia`, `prov` |
| Diario | `Diario`, `diario` |

Sin dependencias externas (excepto Chart.js vía CDN). Funciona offline tras la primera carga.

## Arquitectura futura (AHK)

Ver `docs/AHK_integration_roadmap.md` para el plan de integración con AutoHotkey.

El objetivo es que desde el dashboard se pueda pulsar "Gestionar" sobre una incidencia y disparar automáticamente la macro correspondiente en Remedy (vía AutoHotkey), incluyendo el cierre del ticket con la plantilla adecuada.

## Ver también

- `CAU/AGENTS.md` — configuración global del repo
- `CAU/Macro Remedy/CAU_GUI - BETA.ahk` — referencia del sistema de macros Alba
