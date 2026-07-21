# LAZYDIRECTORY v1.0

App de terminal para gestionar usuarios del **Directorio Corporativo** (correo electrónico) de la Junta de Andalucía.

## Requisitos

- PowerShell 5.1+
- Acceso a `https://directorio.juntadeandalucia.es`
- Credenciales de administrador del Directorio

## Uso

```powershell
.\lazydirectory\lazydirectory.ps1
```

### Menú principal

| Opción | Descripción |
|--------|-------------|
| 1. Conectar a Directorio | Inicia sesión con credenciales de admin |
| 2. Buscar usuario | Busca por UID, DNI, email, nombre, edificio, servicio |
| 3. Ver perfil | Muestra atributos LDAP completos del usuario |
| 4. Cambiar contraseña | Establece nueva contraseña |
| 0. Salir | Cierra la aplicación |

### Campos de búsqueda

| # | Campo | Descripción |
|---|-------|-------------|
| 1 | Identificador | uid del usuario |
| 2 | DNI | Documento nacional de identidad |
| 3 | Correo electrónico | Dirección de email |
| 4 | Nombre y/o Apellidos | Nombre completo (cn) |
| 5 | Tipo de Usuario | Tipo de cuenta |
| 6 | Edificio | Edificio del usuario |
| 7 | Servicio | Servicio al que pertenece |

### Tipo de búsqueda

- Empezando por (default)
- Igual a
- Terminando en
- Conteniendo a

### Perfil de usuario

El perfil muestra datos agrupados en:

- **Datos personales**: UID, DN, nombre, apellidos, email
- **Contacto**: teléfono, móvil, fax, dirección, CP, ciudad, provincia
- **Puesto**: cargo, departamento, organismo, centro gestor/destino, edificio, servicio
- **Cuenta**: uidNumber, gidNumber, cuotas, home directory
- Opción **Ver campos raw**: Muestra todos los campos LDAP del formulario

### Comandos rápidos

- `s usuario` — Busca un UID desde cualquier pantalla

### Ramas LDAP

- **SIRHUS (jus)** — Usuarios externos del ámbito Justicia
- **Internos (ius)** — Usuarios con correo @ius

### Credenciales

Se guardan en `$env:USERPROFILE\.env` tras el primer inicio de sesión.

## Archivos

```
lazydirectory/
├── lazydirectory.ps1    # App principal
├── debug/               # HTML de depuración
└── README.md
```
