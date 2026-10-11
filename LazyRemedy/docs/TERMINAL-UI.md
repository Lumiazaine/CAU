# Remedy en terminal: interfaz visual de solo lectura

La interfaz usa Textual y llama al adaptador existente `read_incident`. No es una
pantalla JSON ni un sustituto de la aplicación autenticada. La lectura en vivo
requiere Windows, el cliente Remedy ya abierto en la sesión interactiva propia y
una política privada válida. La TUI no abre ni autentica el cliente.

## Instalación y arranque

Desde la carpeta del paquete:

```console
python -m pip install ".[ui]"
remedy-terminal ui --com-config politica-privada.json
remedy-terminal ui --com-config politica-privada.json --journal-csv exportacion-privada.csv --id 123
```

Los nombres de archivos y el ID `123` son ejemplos sintéticos. No publique la
política, la exportación ni tickets reales. El extra opcional fija
`textual==6.12.0`; no modifica las dependencias del CLI JSON ni del servidor MCP.
Sin ese extra, `ui` devuelve `ui_dependencies_missing`. `ui --help` funciona sin
importar Textual. El arranque de `ui` no ejecuta `build_application`.

Se recomienda Windows Terminal, con ratón habilitado, un mínimo de **100×30**
columnas/filas y, para más espacio, **160×45**. La lista y la ficha se muestran
lado a lado; las tablas y los campos largos admiten desplazamiento. La tabla
puede desplazarse horizontalmente para ver zona horaria y advertencias.

## Controles

- **Ctrl+F:** enfocar la búsqueda por ID numérico ASCII exacto.
- **Enter** en la búsqueda o **Consultar:** solicitar la ficha autorizada.
- **Ratón / flechas** en la tabla: preparar el ID de la fila. Enter en una fila
  o seleccionarla con el ratón solicita detalles por el adaptador protegido.
- **Anterior / Siguiente:** recorrer páginas de 100 filas.
- **Filtrar exportación solo por ID:** filtro literal de subcadena en el listado
  importado. No busca por descripción, no consulta Remedy y no amplía permisos.
- **Resumen / Descripción / Cierre / Diario:** campos de solo lectura. Tab cambia
  el control enfocado; flechas y ratón permiten navegar por pestañas/listado.
- **F1:** ayuda; **Esc:** cerrar ayuda; **Ctrl+Q:** salir.

No se recortan espacios ni se corrigen ceros iniciales en la búsqueda. `0123`,
` 123`, números Unicode, IDs canónicos introducidos manualmente y valores fuera
del contrato numérico se rechazan. Los IDs canónicos del CSV se conservan en la
tabla; su conversión a ID numérico al seleccionar una fila exige coincidencia
exacta con el prefijo y la longitud de la política privada. Esa conversión de
un ID canónico verificado no es una reparación del texto introducido por el
usuario. La autorización se comprueba de nuevo al consultar mediante el mismo
helper que usa el backend. `allow_all_incidents: true` en una política válida
permite cualquier ID válido por el contrato; ausente o `false` conserva la lista
exacta de IDs aprobados. No admite comodines, consultas libres ni lectura masiva.
La cabecera, la procedencia y el estado de una ficha recibida indican
**TODAS las incidencias (política local)** cuando corresponde. Este aviso describe
solo el permiso local: no prueba una sesión autenticada ni acceso a todas las
incidencias en las ACL corporativas. Sin política válida indica **sin verificar**.

## Exportación local (opcional)

`--journal-csv` importa **solo un listado**, nunca una ficha en vivo ni el texto
del diario de un ticket. La pantalla lo identifica permanentemente como
**NO EN VIVO**, muestra el recuento exacto y la fecha de modificación del archivo
en UTC. Esta fecha es procedencia del archivo, no una garantía de la hora de
exportación ni de actualidad de los datos. Las fechas de apertura de las filas
se conservan como texto; la zona horaria se muestra sin inferirla ni convertirla.

Formato obligatorio: UTF-8 con BOM, separador `;`, cabecera exacta en este orden:

```text
ID incidencia;Fecha apertura;Zona horaria;Advertencia
123;2026-01-02 10:00:00;UTC;
SYN0000000456;02/01/2026 11:00:00;UTC;Ejemplo sintético
```

El prefijo `SYN` es sintético. Las fechas deben ser válidas y usar
`AAAA-MM-DD HH:MM:SS` o `DD/MM/AAAA HH:MM:SS`. La ordenación es descendente por
fecha/hora civil de apertura, con desempate descendente por parte numérica del
ID y texto del ID. El importador valida **todas** las filas antes de aceptar la
exportación; una fila incorrecta descarta el archivo entero, sin lista parcial.

Límites cerrados: 64 MiB, 100.000 filas; longitudes máximas de los cuatro campos:
61, 35, 128 y 1.024 caracteres. IDs únicos, sin reparación ni normalización.
La carga y ordenación inicial se realizan fuera del hilo de interfaz. Aunque el
archivo tenga 90.000 filas, solo se renderizan 100 por página. Un archivo con
cabecera y sin filas es una exportación vacía válida; un archivo vacío sin
cabecera, UTF-8 inválido, esquema distinto, fecha imposible, ID duplicado o
exceso de límites se rechaza con un mensaje humano sin rutas privadas.

## Garantías y límites de seguridad

- La cabecera **SOLO LECTURA** permanece visible. No hay campos editables de
  ticket, operaciones de escritura, exportación de fichas ni registro de su
  texto. Los únicos inputs son búsqueda y filtro local.
- La política existente decide qué IDs y campos se permiten. Incluir una fila
  en el CSV **no** autoriza su lectura. Una denegación sigue siendo denegación.
- No se llama a operaciones SDK mutables ni se modifica la política. Se usa
  únicamente el adaptador existente y sus consultas/formularios propios de
  Query y Display. MCP y `health` mantienen su comportamiento previo.
- Cada consulta limpia la ficha anterior antes de empezar; cualquier fallo
  deja la ficha vacía con **Sin incidencia cargada.** en sus cuatro paneles, igual
  que al arrancar. **No incluido…** solo aparece tras una respuesta válida, en
  los grupos que realmente no contienen campos. Mientras se lee, búsqueda y
  botón quedan deshabilitados.
  La ayuda sigue respondiendo. Las lecturas están serializadas y una respuesta
  obsoleta o con ID cambiado se descarta.
- El worker Windows inicializa COM en su propio hilo con `CoInitialize` y lo
  libera con `CoUninitialize`. Solo devuelve un diccionario de escalares,
  nunca referencias COM.
- Antes de presentar una respuesta se comprueban `source=live`,
  `mode=live-com-readonly`, `writes_enabled=false`, ID solicitado y coincidencia
  canónica exacta con la política. No existe fallback de datos ficticios ni de
  detalles procedentes del CSV.
- IDs, etiquetas y valores se muestran como texto plano, sin interpretar markup
  Rich. Se eliminan secuencias de escape/control y caracteres de formato bidi
  para que no controlen el terminal. El resto del texto no se normaliza.
- El Diario se muestra solo si está incluido en los campos que devuelve el
  adaptador autorizado. Si no lo está, la pestaña lo indica explícitamente;
  no se simula ni se obtiene de la exportación del listado.
  El lector opcional `reader: diary_history` usa el getter formal
  `GetDiaryHistoryList(0)` tras validar la etiqueta exacta. Convierte solo una
  tupla de cadenas exactas en texto separado por líneas en blanco, con límites
  de 10.000 entradas y 1 MiB UTF-8, incluidos separadores; vacío produce texto
  vacío. Sin esa opción se mantiene el getter escalar `Value`. No escribe campos
  ni evita la denegación de etiquetas de credenciales.
- Los errores de pantalla no muestran trazas, rutas privadas ni mensajes crudos
  del backend. No hay operaciones de AD, VPN, UOs ni otras aplicaciones.

## Verificación automatizada

```console
python -m pip install ".[ui,test]"
python -m pytest tests/test_tui*.py
python -m pytest tests/test_all_readonly.py
python -m pytest tests
```

Las pruebas de UI usan el Pilot de Textual con teclado y ratón a 100×30 y
160×45, datos exclusivamente sintéticos, importación de 90.000 filas,
paginación/filtro, limpieza tras fallos, denegación, controles/markup, guardas de
fuente/identidad y la inicialización COM mediante una interfaz de prueba. También
se ejerce el adaptador real con un contrato COM sintético y se verifica su
rechazo seguro en Linux. Las pruebas específicamente Textual se omiten si falta
el extra; las del CLI y del importador siguen ejecutándose.

Estas pruebas offline **no** demuestran acceso corporativo autenticado ni
compatibilidad visual con una sesión Windows concreta. La revisión y la lectura
autorizada en Windows deben verificarse por separado antes de desplegar.
