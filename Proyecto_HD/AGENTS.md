# Proyecto_HD — Memoria para Agentes

## Resumen del proyecto

Dashboard web de análisis de incidencias del CAU de la Junta de Andalucía (Justicia). Procesa archivos CSV exportados del sistema de tickets para detectar patrones, tendencias y bloques críticos. Futura integración con AutoHotkey para automatizar la gestión de incidencias en Remedy.

## Estructura

```
Proyecto_HD/
├── dashboard_incidencias.html   # Dashboard web (único componente ejecutable)
├── README.md                    # Documentación general
├── AGENTS.md                    # Este archivo (memoria para agentes)
├── .opencode.jsonc              # Configuración de opencode
└── docs/
    └── AHK_integration_roadmap.md  # Plan de integración con AutoHotkey
```

## Dashboard: funcionamiento interno

### Carga de datos
- El usuario arrastra un CSV → se parsea con `parseCSV()` (JS puro, sin librerías)
- **NO hay datos embebidos** — todo el analisis se calcula al vuelo
- Se guarda en `localStorage` para persistencia entre recargas
- Las columnas se detectan por nombre aproximado (fuzzy match) via `detectColumns()`

### Columnas auto-detectadas
```js
// Aliases aceptados para cada columna:
COL.id     ← ["id incidencia","id","incidencia"]
COL.desc   ← ["descripcion","descripci","desc"]
COL.fecha  ← ["fecha creacion","fecha","creacion","date"]
COL.clase  ← ["clase"]
COL.cargo  ← ["cargo"]
COL.prov   ← ["provincia","prov"]
COL.diario ← ["diario"]
```

### Análisis dinámico (todo se calcula al vuelo)
| Funcion | Que calcula | Donde se usa |
|---------|-------------|-------------|
| `computeStats()` | Totales, urgentes, afecta a todos, no puedo trabajar | Stats cards |
| `computeDailyTrends()` | Incidencias/dia (total + por clase + urgentes) | Timeline chart |
| `computeTopWords(N)` | Top N palabras por frecuencia | Words tab |
| `computeTopBigrams(N)` | Top N bigramas | Bigrams tab |
| `computeBlockCounts()` | 18 bloques definidos por keywords | Blocks tab |
| `computeCargoStats()` | Incidencias por cargo (con desglose NA) | Cargo chart |
| `computeProvStats()` | Incidencias por provincia | Province chart |
| `computeRepeated()` | Descripciones exactas repetidas | Repeated tab |

### Bloques (definidos en `BLOCK_DEFS`)
Definidos como array de objetos en el HTML (constante inline):
```js
{k:"incoa", l:"INCOA / Fallo esquema", kw:["INCOA","Fallo en el esquema","..."], color:"b-crit"}
```
18 bloques en total. Colores: critico, warning, ok, info, purple.

### Clasificacion de incidencias (mapping a macros Alba)

Definido en `MACRO_MAP` (constante inline en el HTML):

| Patron en descripcion | Macro | Label boton |
|-----------------------|-------|-------------|
| `contrase|clave|PIN` | Alba(11) | Restaurar contrasena |
| `certificado` | Alba(21) | Gestion certificado |
| `INCOA|Fallo en el esquema|error no reconocido` | Alba(?) | Gestion INCOA |
| `bloqueado|desbloqu` | Alba(?) | Desbloqueo |
| `itiner` | Alba(?) | Gestion itineracion |
| `firma` | Alba(?) | Gestion firma |
| `impresor|imprimir` | Alba(?) | Gestion impresora |
| `JARA` | Alba(?) | Gestion JARA |
| `teletrabajo` | Alba(?) | Gestion teletrabajo |
| `HERMES` | Alba(?) | Gestion Hermes |
| `alta.*usuari|dar de alta` | Alba(14) | Alta usuario (GDU) |

La funcion `classifyIncident(desc)` busca coincidencias en `MACRO_MAP` y devuelve el macro correspondiente. El boton "Gestionar" se muestra solo cuando hay una macro asignada.

## Integración con Macro Remedy

- El sistema de macros existente está en `CAU/Macro Remedy/CAU_GUI - BETA.ahk`
- Las macros son números que corresponden a entradas en el sistema Remedy (`Alba(N)`)
- El botón "Gestionar" del dashboard debe disparar un script AHK externo
- Mecanismo de comunicación propuesto: archivo de comandos (`temp\hd_cmd.txt`)

## Convenciones

- UI y documentación en ESPAÑOL
- Código JS en inglés (variables, funciones)
- Comentarios en español solo cuando sea necesario
- Sin dependencias npm/node/python — debe funcionar sin internet (tras primera carga)

## Comandos

```powershell
# Abrir dashboard
Start-Process "C:\Users\CAU\CAU\Proyecto_HD\dashboard_incidencias.html"

# Ver estructura
Get-ChildItem -Recurse "C:\Users\CAU\CAU\Proyecto_HD\"
```
