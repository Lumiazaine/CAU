# Referencia: Procedimientos de Alta (Wiki SSDJ)

> Extraido de la wiki `extranet.chap.junta-andalucia.es/dokuwiki/!ssdj`
> Fecha: 2026-07-16
> Fuente: `pag_procedimientos_generales:gesti`, `pag_apli:alta_ad`, `pag_apli:adriano:alta`, y otras paginas de alta

---

## 1. Perfiles de Usuario

### Tipo A: Personal del Ministerio / Directores / Jefes de Servicio / Forenses IML
- Jueces (CGPJ), Fiscales, Forenses IML
- Historicamente cuentas `.IUS` (antes Admin. Central, ahora Junta de Andalucia)
- Forenses tienen **dos cuentas de correo**: una en **IUS** y otra en **JUS** (Sirhus)

### Tipo B: Personal Judicial Funcionario Junta de Andalucia (excluidos forenses)
- Usuarios registrados en **SIRHUS**
- Auxiliares judiciales, gestores procesales, tramitadores, administrativos de fiscalias/IMLs

### Tipo C: Personal Judicial NO funcionario NI Tipo A
- Empresas externas, psicologos SAVA, educadores equipos tecnicos menores, Policia Judicial, GC Judiciales

### Tipo D: Personal Informatica Delegaciones Territoriales
- Funcionarios de Informatica Judicial (DGIJS)

### Tipo E: Personal Externo Empresas de Apoyo SSJJ y DDPP
- Encomiendas (CAU, Sistemas, CRIP), contratos (NttData/SACOEP), desarrollo (Indra-Soltel, Fujitsu)

### Tipo F: Otro Personal
- Secretarios coordinadores provinciales, otros accesos especificos

---

## 2. Tipos de Alta

### Alta Normalizada
Usuario que accede **por primera vez** al sistema de Justicia de Andalucia.

**Ejemplos:**
- Usuario que aprueba oposiciones y accede a su primer puesto
- Usuario que trabajaba en otra CCAA y se traslada a Andalucia (si no es concurso de traslado)

### Alta Traslado
Usuario se traslada de un OOJJ a **otro dentro de Andalucia**. Baja en origen + alta en destino.

**Ejemplos:**
- Interino que cesa en un organo y toma posesion en otro
- Comisiones de servicio

### Alta Compaginada
Usuario compagina su trabajo en el OOJJ titular con otro OOJJ **sin perder acceso en origen**.

**Ejemplos:**
- Sustituciones por vacaciones o bajas
- Usuarios que necesitan acceso a varios OOJJ simultaneamente
- Audiencias y TSJ (Salas/Secciones)

### Otros Casos
- **Concurso de traslado**: usuarios aprobados en concursos periodicos del ministerio
- **Inspectores judiciales**: inspectores CGPJ en auditorias
- **Creacion nuevo OOJJ**: plantilla de organo recien creado
- **Jueces en practicas**: magistrados en practicas

---

## 3. Flujo General de Alta (Remedy)

### 3.1 Solicitud
**Vias:**
- Correo electronico: `csu.ius@juntadeandalucia.es`
- Gestor de Incidencias del Escritorio Judicial (funcionarios)
- Creacion directa de ticket en Remedy (externos)

**Documentacion requerida:**
- Formulario oficial firmado y sellado por el responsable
- Formularios especificos adicionales para accesos especiales

### 3.2 Ticket Remedy

| Campo | Valor |
|-------|-------|
| Clase | GESTION USUARIOS |
| Tipo | ALTA NORMALIZADA (u otro segun caso) |
| Prioridad | NORMAL |
| Origen | TELEFONO / FAX / E-MAIL |
| Clasificacion | PETICION |
| Categoria | PERSONAL JUDICIAL |

**Pestana USUARIO:**
- Provincia / Localidad / Unidad Funcional
- Cargo: seleccionar del desplegable
- Nombre y apellidos: en **MAYUSCULAS**
- Usuario Temis: **DNI sin letra**
- Correo: dejar en blanco (alta normalizada) / correo del usuario (traslado)
- Telefono: numero de contacto valido

**Pestana INCIDENTE - Descripcion:**
```
ALTA NORMALIZADA 12345678X
Destino: Organo correspondiente
```

**Diario:**
- "Pendiente de formulario" (si procede)
- Todas las actuaciones realizadas

### 3.3 Asignacion
1. Inicialmente: **Nivel 1 / Centro de Servicio al Usuario**
2. Desde Nivel 1: se asigna a los **grupos tecnicos responsables** segun actividad
3. Completadas las actividades: se reasigna a Nivel 1 para **verificacion final**

### 3.4 Equipos y Actividades

| Equipo | Actividad |
|--------|-----------|
| **CAU** | Creacion/modificacion de cuentas AD, TEMIS, Correo, ISL. Gestion completa alta funcionarios |
| **Sistemas GTSW** | Alta/modificacion usuarios AD (perfiles tecnicos). Asignacion VPN y maquina salto |
| **DT/CRIP** | Carga de perfil y configuracion del equipo (solo funcionarios) |

### 3.5 Cierre
- **Alta completa**: cerrar ticket con "Alta finalizada"
- **Alta parcial** (pendiente correo/Nexo): marcar Solucionada y pasar siguiente paso
- CAU informa al usuario de la finalizacion

---

## 4. Alta en Active Directory (AD)

### 4.1 Nomenclatura de Usuario
- **Formato**: inicial del nombre + primer apellido completo
- **Todo MAYUSCULAS**
- **Sin preposiciones** (ej: "del" en "Maria del Carmen" se ignora)
- **Nombres compuestos**: iniciales de cada nombre (ej: "Maria del Carmen" → `MC`)
- **Apellidos compuestos**: primera palabra del apellido

**Si el usuario ya existe:**
1. Anadir letras del segundo apellido hasta que sea unico
2. Si se agotan letras del segundo apellido, anadir letras del nombre de pila
3. Si todo falla, anadir contador numerico

### 4.2 Copia desde Plantilla
1. Ir a la carpeta del OOJJ correspondiente
2. Localizar usuario con **mismo cargo**
3. Boton derecho → "Copiar"
4. Rellenar: Nombre, Apellidos, Nombre inicio sesion (SAM)
5. Contrasena: estandar (`JusticiaMMYY`)
6. Marcar "El usuario debe cambiar la contrasena en el siguiente inicio de sesion"

### 4.3 Creacion Manual
Si no hay plantilla en la carpeta destino:
- Boton derecho → Nuevo → Usuario
- Rellenar **todas** las pestanas manualmente

### 4.4 Campos Obligatorios del Perfil

**Pestana General:**
- Descripcion: Cargo (Magistrado/a, Juez/a, LAJ, Fiscal, Auxilio Judicial, Tramitacion, Gestion, Medico Forense, Psicologo/a)
- Oficina: Unidad funcional resumida (ej: "Instruccion 1", "SCNE", "IML", "TSJ Sala de lo Social")
- Telefono: **DNI** (formato: 12345678L)
- Correo: correo corporativo

**Pestana Direccion:**
- Ciudad: localidad
- Estado/Provincia: provincia

**Pestana Cuenta:**
- Dominio `@justicia.junta-andalucia.es`

**Pestana Organizacion:**
- Puesto: cargo
- Departamento: unidad funcional resumida

**Pestana Miembros de:**
- Copiar grupos de seguridad de usuario plantilla del mismo cargo en el mismo OOJJ

### 4.5 Traslado en AD

**Misma provincia:**
- Mover perfil a carpeta del OOJJ destino
- Actualizar pestanas del perfil
- Resetear contrasena

**Distinta provincia:**
- Eliminar perfil en origen
- Crear nuevo usuario en destino (mismo SAM si es posible)

### 4.6 Alta Compaginada en AD

**Usuario multi-organo:**
- Mantiene perfil en carpeta OOJJ titular
- Anadir grupos de seguridad del OOJJ destino (copiados de plantilla en ese OOJJ)

**Usuario alternativo:**
- Crear perfil nuevo (mismo proceso que alta normalizada)

---

## 5. Alta en Temis

Se accede a **Mantemis** desde el Escritorio Virtual:
1. `Mantemis` → apartado "Usuarios"
2. Anadir DNI del usuario (o buscar por nombre/apellido)
3. Marcar casilla izquierda del usuario → "Modificar"
4. Pulsar "**Otros puestos**" → "Nuevo"
5. Elegir: organo, cargo, cuerpo
6. Solo dar **fecha de alta** (no fecha de baja)
7. Si es primer puesto: asignar roles para Adriano
8. Sincronizar para que el cambio se vea en Adriano

**Info util:** Si el nombre tiene tilde, ponerla en el filtro o no encuentra.

---

## 6. Alta en Correo Corporativo (Directorio)

Se gestiona via `https://directorio.juntadeandalucia.es`

**Dos tipos de cuentas:**
- **Sirhus** (`o=jus`): personal funcionario Tipo B
- **Internos/IUS** (`o=ius`): personal Tipo A, forenses, historicas

El alta en correo se hace tras crear el usuario en AD.

**Tecnicamente requiere:**
1. Login en Directorio Corporativo
2. Seleccionar rama LDAP (`jus` o `ius`)
3. Buscar/crear usuario
4. Establecer contrasena (`Justicia.MMYY` para Sirhus, formato con punto)
5. Forzar cambio en primer login

---

## 7. Alta en Adriano

Se realiza **a traves de Temis** (sincronizacion nocturna Temis → Adriano):
1. Alta en Temis (paso 5)
2. Sincronizacion automatica nocturna
3. Si se necesita rapido: abrir peticion a Servicios/DevOps

**Aplicaciones segun cargo:**

| Cargo | Aplicaciones |
|-------|--------------|
| Juez/Magistrado/LAJ/Fiscal | AD, Temis, Adriano, Arconte/Aurea, VPN/ISL |
| Gestor/Tramitador procesal | AD, Temis, Adriano |
| Auxilio judicial | AD, Temis, Adriano, Arconte, NEXO |
| Juzgado Paz/Oficina Municipal | Temis, Correo (solo funcionario) |
| Resto perfiles | AD, Temis |
| Registro Civil | AD, Temis |
| Personal externo | AD, Temis, VPN, JIRA, Remedy, HGP, listas correo |

---

## 8. Altas en Otras Aplicaciones

### Hermes
- El usuario debe estar primero en **Temis** (sincronizacion nocturna Temis → Hermes)
- Si es personal externo: creacion manual en `HERMES > ADMINISTRACION > USUARIOS > NUEVO`

### JARA
- Se accede desde `Mantenimiento Temis` → Aplicaciones → JARA (codigo **600**)
- Seleccionar perfil segun categoria → "Asignar"
- Tipo de asignacion: **Usuario**
- Buscar usuario → "Asignar"

### PortafirmasNG
- `Mantenimiento Temis` → Aplicaciones → PortafirmasNG
- Perfil: **Acceso** → "Asignar"
- Tipo: **Usuario**
- Buscar usuario → "Asignar"

### ISL (Escritorio Remoto)
- Se solicita como aplicacion no estandar
- Gestionado por CAU

### VPN / Circuito / Portatil
- Solo en Altas Normalizadas o si no dispone previamente
- Gestionado por Sistemas GTSW

---

## 9. Tickets Relacionados (post-Alta)

### Carga de Perfil
Nuevo ticket con los mismos datos del usuario:

| Campo | Valor |
|-------|-------|
| Origen | TELEFONO |
| Clase | PUESTO DE TRABAJO |
| Tipo | SOFTWARE |
| Categoria | PERFIL USUARIO |

**Descripcion:**
```
Se solicita cargar el perfil.
Alta tramitada en IN000000XXXXX
AD: [usuario]
TEMIS: [usuario]
[...]
```

Asignar a **Delegacion Provincial correspondiente**.

### Peticion de Portatil
- Asignar a Delegacion Provincial
- Para traslados interprovinciales

### Peticion de Formacion
- Asignar a **Servicios/Formacion**
- Tipificacion: Soporte Formativo / Adriano / Incorporacion Personal

---

## 10. Casos Especiales

### Alta por Concurso de Traslado
- Verificar que el usuario aparece en el listado facilitado por servicios centrales
- Si aparece: NO necesita formulario, indicar "Alta por concurso de traslado" en descripcion
- Si NO aparece: tramitacion normal con formulario

### Alta de Inspectores Judiciales
- 2 semanas de antelacion recomendada
- Un inspector como LAJ, otro como MAG
- Formulario firmado obligatorio
- En AD: cargo "Inspector CGPJ (LAJ/MAG)"
- En Temis: perfil como sustituto, linea en "otros puestos"
- Baja automatica al finalizar inspeccion

### Alta en Capacitacion (Adriano CAP)
- Perfiles genericos: profesor, alumno1..alumno20
- Mas de 20 alumnos: solicitar perfiles extra a Servicios/DevOps
- CAU asigna a Sistemas/GTSR → Servicios/DevOps
- Importante: comunicar fecha fin del curso para reseteo

### Alta de Personal Externo SSDJ
- El responsable/jefe de proyecto envia datos a Coordinacion OT
- Coordinacion OT registra en checklist: `\\iusnas05\SIJ\10. Proyectos en curso\...`
- Categorizacion: Categoria operacional 1 = "Solicitud de acceso", Categoria 2 = "Alta", Producto 2 = "Personal externo"

**Info imprescindible:**
- Nombre, DNI, correo, empresa
- Unidad funcional destino, perfil solicitado
- Perfil AD/LDAP de referencia
- Direccion MAC (si trabajo en oficinas Consejeria)
- Rutas exactas carpetas IUSNAS05 e impresoras
- Formularios firmados (AD/LDAP, Adriano)

---

## 11. Herramientas por Perfiles (Externos)

| Servicio | Herramienta | Quien da alta |
|----------|-------------|---------------|
| Todos | AD | Sistemas |
| Todos | Maquina salto | Sistemas |
| Todos | Escritorio Judicial | CAU |
| Todos | TEMIS | CAU |
| Todos | LDAP (ficheros/consigna) | CAU |
| Todos | VPN | CAU |
| CAU | Directorio Corporativo (Correo) | CAU |
| CAU | ISL | CAU |
| CAU | Hermes | CAU |
| CAU | Arconte/Aurea | SSVV |
| Runtime | Adriano | Runtime |
| Runtime | Remedy / Jira | Runtime |
| OT | Jira | OT |
| OT | Alfresco | OT |

---

## 12. Formularios Necesarios

Disponibles en Portal de Capacitacion:
`https://capacitacion.justicia.junta-andalucia.es/course/section.php?id=261`

**Formularios para tecnicos:**
- Acceso a Adriano
- Acceso a CORPUS
- Acceso a Nueva Sede
- Acceso a BMC Helix
- **Alta, Baja o Modificacion de personal externo**
- Solicitud de VPN

---

## 13. Notas Importantes

1. **Contacto siempre por telefono** durante el alta (el usuario no tiene correo activo hasta que se completa)
2. **Fecha de asignacion en Remedy** no debe superar **10 minutos** desde apertura
3. **Todas las actuaciones** deben reflejarse en el campo Diario
4. **Orden recomendado** de altas: AD → TEMIS → Correo → Adriano → Arconte → NEXO
5. **Contrasena estandar**: `Justicia` + MM + YY (AD/Temis) o `Justicia.` + MM + YY (Correo Sirhus)
6. **Forzar cambio de contrasena** en primer inicio de sesion
