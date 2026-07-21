# LAZYTEMIS v1.0

App de terminal para gestionar usuarios en **Temis** (Escritorio Judicial de la Junta de Andalucia).

## Requisitos

- PowerShell 5.1+
- Certificado digital de la Junta de Andalucia instalado
- Conexion VPN a la red de Justicia

## Uso

```powershell
.\lazytemis\lazytemis.ps1
```

### Menu principal

| Opcion | Descripcion |
|--------|-------------|
| 1. Conectar a Temis | Inicia sesion con certificado digital |
| 2. Buscar usuario | Busca por DNI, nombre, apellidos o cargo |
| 3. Ver perfil | Muestra los datos del usuario seleccionado |
| 4. Cambiar contrasena | Anula la contrasena en Temis y establece nueva |
| 5. Listar por organismo | Explora usuarios por partido judicial/organismo |
| 0. Salir | Cierra la aplicacion |

### Comandos rapidos

- `s 12345678X` — Busca un DNI desde cualquier pantalla

## Que se puede hacer

Version inicial con las operaciones documentadas en el HAR de Temis:

- [x] Autenticacion con certificado
- [x] Busqueda de usuarios (DNI, nombre, apellidos, cargo)
- [x] Visualizacion de perfil completo
- [x] Cambio de contrasena (anular + establecer)
- [x] Listado por organismo/partido judicial
- [ ] Alta de nuevos usuarios (pendiente HAR)
- [ ] Baja/desactivacion (pendiente HAR)
- [ ] Gestion de incidencias (pendiente HAR)

## Archivos

```
lazytemis/
├── lazytemis.ps1    # App principal
├── debug/           # HTML de depuracion
└── README.md
```
