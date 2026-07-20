# Temis - Cambio de Contrasena

## Descripcion

Automatiza el cambio de contrasena en **Temis** (Escritorio Judicial de la Junta de Andalucia).
Usa autenticacion por certificado digital para acceder a Escritorio Judicial, redirige via Lanzadera
a Temis, anula la contrasena del usuario y establece una nueva.

## Requisitos

- PowerShell 5.1+
- Certificado digital de la Junta de Andalucia instalado en `Cert:\CurrentUser\My`
- Conexion a `escritoriojudicial.justicia.junta-andalucia.es` y `temis.justicia.junta-andalucia.es`
- Windows 7/10 corporativo (entorno Junta de Andalucia)

## Uso

```powershell
.\Temis\cambiar_password_temis.ps1 -TemisUser "12345678X" -WhatIf
.\Temis\cambiar_password_temis.ps1 -TemisUser "12345678X"
```

### Parametros

| Parametro | Obligatorio | Descripcion |
|-----------|-------------|-------------|
| `-TemisUser` | Si | DNI del usuario (formato `12345678X`) |
| `-NewPassword` | No | Nueva contrasena (default: `Justicia` + MMYY) |
| `-WhatIf` | No | Simula sin cambios reales |
| `-ShowBrowser` | No | Muestra ventana del navegador durante la ejecucion |

### Password por defecto

`Justicia` + MMYY (ej. `Justicia0726` para Julio 2026).

## Flujo Tecnico

```
 1. Verifica conectividad a los servidores
 2. Obtiene certificado digital (auto-detecta DNI en Subject)
 3. GET Inicio.do + GET AccesoCertificado.do + POST CallAuthenticationServlet
      -> Sesion autenticada en Escritorio Judicial
 4. GET Lanzadera.do?id=2
      -> SSO hacia Temis con ticket
 5. POST UsuarioConsulta.do (accion=buscar_dos)
      -> Busca por DNI (si formato 8 digitos + letra) o por usuario
      -> Extrae codigoUsuario del HTML
 6. POST UsuarioConsulta.do (accion=modificarDos)
      -> Abre la ficha del usuario
      -> Extrae todos los campos con Extract-FormFields
 7. POST UsuarioGuardarModificar.do (accion=anular, cambiarIdPassword=3)
      -> Anula la contrasena en Temis
 8. POST RealizarModificarPassword.do
      -> Establece la nueva contrasena desde Escritorio Judicial
```

### Detalle de campos del formulario (paso 7)

`Extract-FormFields` parsea el HTML de la ficha y extrae todos los
`<input>`, `<select>` y `<textarea>` del formulario `UsuarioGuardarModificar`.
Luego sobreescribe:
- `accion` = `anular`
- `usuario` = DNI del usuario
- `cambiarIdPassword` = `3`

## Archivos

```
Temis/
├── cambiar_password_temis.ps1    # Script principal (281 lineas)
├── cambiar_password_temis.log    # Log de ejecuciones
├── debug/                        # HTML de depuracion de cada paso
└── README.md
```

### Debug

Cada ejecucion guarda en `debug/`:
- `11_ResultadoAnular.html`     # Respuesta de Temis tras anular
- `12_ResultadoEscritorio.html` # Respuesta de Escritorio Judicial

## Logging

- Consola coloreada con niveles: INFO (cyan), OK (verde), WARN (amarillo), ERROR (rojo)
- Archivo `cambiar_password_temis.log` en el mismo directorio (formato `yyyy-MM-dd [HH:mm:ss] [LEVEL] mensaje`)
- Contador de errores al final del proceso

## Notas para futuros mantenedores

### Flujo HAR descubierto via analisis de trafico

El flujo real no usa Internet Explorer COM ni WebBrowser. Se descubrio
capturando peticiones HTTP con las herramientas de desarrollador del navegador
(F12) y exportando a formato HAR.

### Certificado digital

El script busca automáticamente un certificado con DNI (8 dígitos + letra) en
el Subject del almacén personal, priorizando el no caducado más reciente.
Si no encuentra ninguno con DNI, usa el primer certificado válido disponible.
No requiere modificación al cambiar de titular.

### Lanzadera

La URL `Lanzadera.do?id=2` es el SSO hacia Temis. El `id=2` corresponde a la
aplicacion Temis dentro de Escritorio Judicial. Si la URL cambia, actualizar
`$script:ESC_URL` + `/Lanzadera.do?id=2` donde se invoca (linea 144).

### Temis URL

Actualmente usa `http://temis.justicia.junta-andalucia.es/Temis` (HTTP).
Si migran a HTTPS, actualizar `$script:TEMIS_URL` en la linea 13.
