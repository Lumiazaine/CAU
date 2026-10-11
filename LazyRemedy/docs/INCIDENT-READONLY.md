# Incidente COM: lectura explícita

```console
remedy-terminal incident --id 7654321 --com-config example-user-config.json
```

**Todos los valores de este ejemplo son sintéticos**; no son metadatos utilizables.
Guarda la configuración real fuera de Git, con permisos sólo para su propietario.
No incluyas contraseñas, tokens ni datos de otros usuarios. No hay configuración
implícita: `enabled` y `read_only` deben ser booleanos `true` por aprobación expresa.
El ejemplo queda deshabilitado deliberadamente.

```json
{
  "enabled": false,
  "read_only": true,
  "expected_host": "SYN-HOST",
  "expected_user": "SYN\\tester",
  "expected_session_id": 7,
  "client_executable": "C:\\Synthetic\\aruser.exe",
  "typelib_guid": "{12345678-1234-1234-1234-123456789ABC}",
  "server": "SYN-SERVER",
  "form": "SYN:Incident",
  "expected_auth_user": "synthetic.tester",
  "incident_field": {
    "id": 900001, "label": "Synthetic incident", "prefix": "SYN", "digits": 10
  },
  "approved_incident_ids": ["7654321"],
  "allow_all_incidents": false,
  "fields": [{"id": 900002, "label": "Synthetic summary"}]
}
```

`typelib_guid` debe contener el GUID aprobado y comprobado para
`GetActiveObject`, no un ProgID ni un GUID deducido. IDs y etiquetas deben proceder
de metadatos confirmados. `prefix` y `digits` definen la representación canónica
(sólo en este ejemplo, `SYN0007654321`); no se infiere un patrón universal.
Los IDs solicitados son cadenas ASCII numéricas sin espacios ni ceros iniciales,
dentro del límite `digits` del contrato. La clave opcional `allow_all_incidents`
admite **solo booleanos JSON**: ausente o `false` conserva la autorización exacta
en `approved_incident_ids`; `true`, tras autorización expresa, permite consultar
cualquier ID válido por ese contrato, incluso fuera de esa lista. La lista sigue
siendo obligatoria, no vacía y válida por compatibilidad; no acepta comodines ni
se sustituye por una enumeración de todas las incidencias. Para la primera
validación, autoriza únicamente un incidente. Este permiso local no autentica al
usuario ni amplía las ACL corporativas del SDK/servidor. Se consulta una única
incidencia por igualdad exacta, no consultas arbitrarias ni barridos masivos.
No se admiten claves desconocidas ni duplicadas,
IDs de campo de tipo texto/bool, etiquetas duplicadas o etiquetas conocidas de
credenciales, incluso si aparecen en la lista permitida. La denegación cubre
variantes Unicode y con separadores conservando etiquetas y valores originales.
No inspecciona texto libre ni garantiza que una descripción no contenga datos
sensibles.

Cada campo de `fields` admite únicamente `id` y `label`, o esas dos claves más
`"reader": "diary_history"`. Sin `reader` se conserva la lectura escalar de
`field.Value`; no hay inferencia automática por etiqueta o tipo. El único valor
permitido para `reader` es `diary_history`; `value` no es un valor de configuración.
El campo de identidad no admite `reader`, ni puede reutilizarse como diario.
Un ejemplo sintético de campo opcional es:

```json
{"id": 900003, "label": "Diario sintético", "reader": "diary_history"}
```

Tras comprobar su etiqueta exacta, este lector usa **solo**
`field.GetDiaryHistoryList(0)`: exige un `tuple` exacto de `str` exactos (sin
objetos COM, listas, diccionarios ni subclases), máximo 10.000 entradas y 1 MiB
UTF-8 en total, incluidos los separadores. Comprueba los límites antes de unir
las entradas con `\n\n`; una tupla vacía produce `""`. No lee ni escribe `Value`
para ese campo. La denegación de etiquetas de credenciales sigue activa; el
texto libre del diario no se filtra por palabras de negocio. Un error descarta
la ficha y cierra todos los formularios propios; el JSON no admite NaN/Infinity.

Requiere Windows y pywin32 ya disponibles, una GUI existente y visible, sesión
interactiva positiva y coincidencias de host, usuario, sesión, SID, logon y ruta
local del único `aruser.exe` de esa sesión. Rechaza SSH y Session 0. Sólo adjunta
un objeto existente mediante `GetActiveObject` → `QueryInterface(IID_IDispatch)`
→ `Dispatch(idispatch)`; no inicia clientes ni aporta credenciales.

Abre formularios ocultos propios: búsqueda por igualdad de FIELDID numérico,
`Count == 1`, `Item(1)`, comprobación del ID devuelto, carga en visualización y
lectura por ID/etiqueta exactos. Cierra sólo esos formularios en `finally`, también
ante errores; no hace Submit, Modify, RunMacro, Logout ni setters. JSON en stdout
incluye `requested_incident_id`, `canonical_id`, `mode: live-com-readonly`,
`source: live`, `values` y `writes_enabled: false`. Los errores devuelven código 2
y un código fijo en stderr, nunca el mensaje original del proveedor.

**Límite de validación:** los tests offline usan datos y COM inyectados; no prueban
Windows real. La API ROT utilizada no expone el PID del objeto COM: la comprobación
de proceso único/SID/logon y de usuario autenticado no constituye una atestación
directa COM→PID ni elimina carreras con el cierre del cliente. La validación
Windows/COM real y la revisión independiente siguen siendo requisitos antes de
instalar/publicar. `health`, MCP y las órdenes legacy conservan su contrato previo.
