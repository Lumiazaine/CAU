# Directorio Correo - Cambio de Contrasena

## Descripcion

Automatiza el cambio de contrasena de usuarios en el **Directorio Corporativo**
de la Junta de Andalucia (`directorio.juntadeandalucia.es`).
Soporta tanto cuentas **Sirhus** (externas, dominio `jus`) como **Internos**
(cuentas `.ius`, dominio `ius`).

## Requisitos

- PowerShell 5.1+
- Credenciales de administrador del Directorio (`$env:USERPROFILE\.env` o prompt manual)
- Conexion a `directorio.juntadeandalucia.es`
- Windows 7/10 corporativo (entorno Junta de Andalucia)

## Uso

```powershell
# Sirhus (dominio jus, por defecto)
.\Directorio\ correo\cambiar_password_correo.ps1 -TargetUser "mangeles.mas"
.\Directorio\ correo\cambiar_password_correo.ps1 -TargetUser "mangeles.mas" -WhatIf

# Internos (dominio ius, deteccion automatica por .ius)
.\Directorio\ correo\cambiar_password_correo.ps1 -TargetUser "usuario.ius"
.\Directorio\ correo\cambiar_password_correo.ps1 -TargetUser "usuario.ius" -WhatIf

# Forzar modo Interno manualmente
.\Directorio\ correo\cambiar_password_correo.ps1 -TargetUser "usuario" -Interno
```

### Parametros

| Parametro | Obligatorio | Descripcion |
|-----------|-------------|-------------|
| `-TargetUser` | Si | Nombre de usuario (con o sin `.ius`) |
| `-NewPassword` | No | Nueva contrasena (default: `Justicia.` + MMYY) |
| `-WhatIf` | No | Simula login sin hacer el cambio |
| `-Interno` | No | Forzar rama LDAP `ius` (para cuentas `.ius`) |

### Password por defecto

`Justicia.` + MMYY (ej. `Justicia.0726` para Julio 2026).
**ATENCION:** Lleva punto antes del mes: `Justicia.0726`, no `Justicia0726`.

### Deteccion automatica de tipo

El script detecta automaticamente si el usuario es Interno:
- Si `-TargetUser` contiene `.ius` (ej. `usuario.ius`) -> modo Interno
- Si `-TargetUser` es un nombre simple (ej. `mangeles.mas`) -> modo Sirhus
- El flag `-Interno` fuerza modo Interno aunque el nombre no contenga `.ius`

## Flujo Tecnico

```
1. GET LoginInicial
     -> Obtiene token CSRF de la pagina de login
2. POST LoginInicial (admin + password)
     -> Inicia sesion como JUST9.SANDETEL.EXT
3. POST LoginUsuario (administrarRamas)
     -> Selecciona modo de administracion de ramas LDAP
4. POST LoginUsuario (administrarRama, ramaLdap=jus|ius)
     -> Selecciona la rama LDAP segun tipo de usuario
5. GET UsuariosMain
     -> Obtiene token CSRF del panel de usuarios
6. POST UsuariosMain (accion=consulta)
     -> Busca al usuario por identificador
7. POST UsuariosMain (accion=modificacion, confirmarPassword)
     -> Si se encuentra: extrae DN del HTML
     -> Si NO se encuentra (pendiente de alta): construye DN
        manualmente con formato uid=...,o=jus|ius,...
     -> Envia la nueva contrasena
```

### Seleccion de rama LDAP

| Tipo | Rama LDAP | DN construido |
|------|-----------|---------------|
| Sirhus | `jus` | `uid={user},o=jus,o=empleados,o=juntadeandalucia,c=es` |
| Interno | `ius` | `uid={user},o=ius,o=empleados,o=juntadeandalucia,c=es` |

## Archivos

```
Directorio correo/
├── cambiar_password_correo.ps1    # Script principal
├── cambiar_password_correo.log    # Log de ejecuciones
└── README.md
```

## Logging

- Consola coloreada con niveles: INFO (cyan), OK (verde), WARN (amarillo), ERROR (rojo)
- Archivo `cambiar_password_correo.log` (formato `yyyy-MM-dd [HH:mm:ss] [LEVEL] mensaje`)
- Contador de errores al final del proceso

## Notas para futuros mantenedores

### Como se descubrio el flujo

Se capturaron las peticiones HTTP del navegador (F12 -> HAR) al realizar
manualemente el cambio de contrasena en el panel del Directorio. El HAR revelo:

1. El sistema usa un token CSRF (`tokenParametro`) en cada paso
2. El login requiere 3 pasos: login -> administrarRamas -> ramaLdap
3. La busqueda y el cambio se hacen via POST a UsuariosMain
4. Las cuentas Internos usan `ramaLdap=ius` y busqueda con `marcarInternos=SI`

### Credenciales (`.env` en perfil del usuario)

Las credenciales se cargan desde `$env:USERPROFILE\.env` con formato:
```
ADMIN_USER=usuario
ADMIN_PASS=contraseña
```

Si el archivo no existe o falta alguna variable, el script solicita
usuario y contraseña manualmente (la contraseña se oculta al escribir).

Si el login falla por credenciales incorrectas, el script reintenta
pidiendo credenciales de nuevo (hasta 3 intentos) antes de abortar.

`.env` esta incluido en `.gitignore` del repositorio. **No committear
credenciales reales a GitHub.**

### Token CSRF

Cada GET/POST devuelve un `tokenParametro` en el HTML que debe extraerse y
reenviarse en la siguiente peticion. La funcion `Extract-Token` busca el patron
`name="tokenParametro" value="..."` en el HTML de respuesta.

### Cuentas pendientes de alta

Si un usuario Sirhus esta pendiente de validar el alta, la busqueda no lo
encuentra (no aparece `name="dn"` en el HTML). En ese caso, el script construye
el DN manualmente y envia el cambio igualmente -- el servidor lo procesa aunque
el usuario no sea visible en el buscador.

### Verificar cambios en el panel

Si el HTML del Directorio cambia (nueva version del portal), pueden fallar:
- La extraccion del token CSRF
- La extraccion del DN del usuario
- La deteccion de exito (`actualiz.+correctamente|mensaje_ok`)
- Los campos del formulario de cambio de password

En ese caso, capturar un nuevo HAR y ajustar las expresiones regulares.
