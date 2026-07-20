# Manual de Usuario

Cambio de contraseña automatizado para **Directorio Corporativo** y **Temis** (Escritorio Judicial).

---

## Instalacion (una sola vez)

Abre PowerShell y pega esto:

```powershell
iex (irm https://raw.githubusercontent.com/Lumiazaine/CAU/refs/heads/main/instalar.ps1)
```

Esto configura:

- **ExecutionPolicy** en Unrestricted
- **Perfil** con las funciones `temis` y `ldap`
- Al abrir la terminal arranca en tu carpeta de usuario

Despues de la instalacion, **cierra y abre PowerShell** de nuevo.

---

## Uso diario

Una vez instalado, solo escribes:

```powershell
# Cambiar contraseña en Directorio Correo (Sirhus)
ldap mangeles.mas

# Cambiar contraseña en Directorio Correo (Interno .ius)
ldap usuario.ius

# Cambiar contraseña en Temis
temis 45601168

# Simulacion (no hace cambios reales)
ldap mangeles.mas -WhatIf
temis 45601168 -WhatIf
```

No necesitas URLs ni nada mas. Los comandos `temis` y `ldap` ya estan disponibles.

---

## Directorio Correo

Cambia la contraseña en el Directorio Corporativo de la Junta de Andalucia.

### Primera ejecucion

Te pedira **usuario administrador** y **contraseña**. Se guardan en `%USERPROFILE%\.env` para no volver a pedirlas.

### Contraseña por defecto

`Justicia.` + mes+año (ej. `Justicia.0726`). **Importante:** lleva punto despues de `Justicia`.

### Parametros

| Parametro | Descripcion |
|-----------|-------------|
| `-TargetUser` | Nombre de usuario (obligatorio) |
| `-NewPassword` | Contraseña personalizada (opcional) |
| `-Interno` | Forzar modo Interno (para cuentas `.ius`) |
| `-WhatIf` | Solo simulacion, no hace cambios |

---

## Temis

Anula la contraseña en Temis y establece una nueva. Usa tu certificado digital de la Junta de Andalucia.

Requiere tener un **certificado digital** instalado en el almacen personal de Windows (el del DNI de la Junta).

### Contraseña por defecto

`Justicia` + mes+año (ej. `Justicia0726`). **Sin punto** entre medias.

### Parametros

| Parametro | Descripcion |
|-----------|-------------|
| `-TemisUser` | DNI del usuario (obligatorio, formato `12345678X`) |
| `-NewPassword` | Contraseña personalizada (opcional) |
| `-WhatIf` | Solo simulacion, no hace cambios |

---

## Modo WhatIf (simulacion)

Usa `-WhatIf` para hacer una simulacion: inicia sesion, busca al usuario, pero **no realiza el cambio**. Sirve para comprobar que todo funciona antes de ejecutar el cambio real.

---

## Ejecucion sin instalar (alternativa)

Si no quieres instalar nada, puedes ejecutar los scripts directamente:

```powershell
# Directorio Correo
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/Lumiazaine/CAU/refs/heads/main/Directorio%20correo/cambiar_password_correo.ps1"))) -TargetUser "mangeles.mas"

# Temis
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/Lumiazaine/CAU/refs/heads/main/Temis/cambiar_password_temis.ps1"))) -TemisUser "45601168"
```

---

## Resolucion de problemas

| Problema | Causa probable |
|----------|---------------|
| "No se puede acceder a los servidores" | No estas conectado a la VPN de Justicia |
| "No se encontro ningun certificado" (Temis) | No tienes el certificado digital instalado |
| "Credenciales incorrectas" (Correo) | Usuario o contraseña de administrador erroneos |
| "temis" / "ldap" no se reconoce | Cerrar y abrir PowerShell de nuevo, o ejecutar `. $PROFILE` |
| "Token" / "formulario" errors | La web ha cambiado (notificar al administrador) |

Los logs se guardan en `cambiar_password_correo.log` y `cambiar_password_temis.log` en tu carpeta de usuario.

---

## Notas importantes

- **Temis** necesita VPN activa (conexion a Escritorio Judicial y Temis)
- **Correo** necesita VPN activa (conexion a directorio.juntadeandalucia.es)
- La contraseña por defecto sigue el patron `Justicia` + MMYY (con punto en Correo, sin punto en Temis)
- Las credenciales de administrador del Correo se guardan en `%USERPROFILE%\.env`
- Temis usa tu certificado digital, no necesita credenciales
