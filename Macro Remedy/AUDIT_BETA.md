# Auditoría — `CAU_GUI - BETA.ahk`

**Fecha:** 2026-09-29 · **Alcance:** la macro de producción (GUI "Lazybird", 607 líneas) contra el
resto de `Macro Remedy/` y contra la copia commiteada.

> **Estado de veracidad:** todo lo que sigue está comprobado leyendo el código, salvo lo marcado
> **[SIN VERIFICAR]**, que requiere la carpeta `ARCmds` del servidor AR System (no disponible en este
> entorno). No se ha ejecutado la macro: no hay Windows ni Remedy aquí.

---

## 1. Qué hace realmente

La macro no habla con Remedy por API ni por COM. Es **teclado sintético sobre el formulario Oracle
(`ArFrame`)**. Todo el flujo son secuencias de `{Tab N}` y `{Up N}` sobre una ventana que no controla.

```
Click botón  →  ExecuteAlbaMacro(num, etiqueta)
                    ├─ CheckRemedy()        ¿existe aruser.exe?
                    ├─ Alba(num)            BlockInput On → Send ^i → {Tab 2}{End}{Up num}{Enter}{Tab 22}
                    ├─ Send dni {Tab}{Enter}
                    ├─ Send {Tab 3} → +{Left 90}{BackSpace} → telf
                    └─ limpia los campos de la GUI
```

### 1.1 `Alba(num)` NO es lo que su nombre indica

`Alba(num)` (línea 127) **no ejecuta `Alba.ps1`**. Verificado: cero `RunWait` o `powershell` en el
archivo. Su único cuerpo relevante es:

```ahk
Send, ^i
Send, {TAB 2}{End}{Up %num%}{Enter}
Send, {TAB 22}
```

Es decir, `num` es **un índice posicional contado desde la última fila** de la lista de macros del
formulario Alba, no un identificador. Tres consecuencias:

- Si alguien inserta, borra o reordena una macro en ARCmds, **todos los botones se desplazan en
  silencio**. No hay validación ni log del nombre real ejecutado, solo `"...con parámetro " . num`.
- `{Tab 22}` asume una posición fija del cursor en el formulario. Un campo añadido o reordenado en
  Remedy rompe **todos** los botones a la vez, no solo uno.
- El nombre `Alba` invita a pensar que hay una relación con `Alba.ps1`. **La relación se eliminó**: ver §3.

**Recomendación:** renombrar a `SeleccionarMacro(n)` / `EjecutarMacro(n)`. Es un cambio puramente
cosmético que elimina la mayor fuente de confusión del archivo.

### 1.2 Inventario de la GUI

| GUI | Contenido |
|-----|-----------|
| 1 — "Lazybird" | 22 botones de macro (SOLICITUDES / CIERRES / DP) + campos DNI, DNI+letra, Teléfono, IN + botón Buscar |
| 2 — "Plantillas correos" | 8 botones de plantilla + 3 radios (Primer/Segundo/Tercer contacto). Se abre con `Win+Espacio` |

---

## 2. La tabla de índices — RESUELTA contra los `.arq`

> **Corrección de las dos pasadas anteriores.** Las dos primeras versiones de esta sección-dam el listado deducido de
> `Core/ButtonManager.ahk` (44 filas). El ARCmds real tiene **46 macros** y
> `ButtonManager` se equivocaba en 8. Ver §2.6.

### 2.1 De dónde sale el índice

`ARCmds/ARCmds/` contiene 64 ficheros `.arq`:

- **46 `ZZZ*.arq`** — las macros de la GUI. El prefijo `ZZZ` es el truco clásico
  para forzar que aparezcan juntas y en orden al final del listado.
- **18 `x*.arq`** — las que `Alba.ps1` excluye a propósito (son las de gestión
  depea/incidencias, no de la GUI de técnico).

El nombre visible de cada macro está en la **línea 1** del `.arq`, codificada en
**Windows-1252** (`ñ` = byte `0xF1`). Ejemplo de `ZZZContr.arq`:

```
ZZZContraseña
Set-schema: 101_INCIDENCIAS^M10.241.130.25^M
```

El formulario Alba las lista **en orden alfabético** y `SeleccionarMacro(n)` sube
desde la última fila con `{TAB 2}{End}{Up n}{Enter}`. Por tanto:

```
n = 45 − posición alfabética        (posición 0 = la primera, la "A")
```

Dos detalles que costaron tres pasadas de auditoría:

- **La comparación es alfabética, no por byte.** Ordenar por byte da
  `ZZZISLApagado` antes que `ZZZInternetlibre` (porque `S` < `n`), pero
  `ButtonManager` los coloca al revés, que es lo correcto alfabéticamente.
- **Son 46 filas, no 45.** `ZZZCorre.arq` y `ZZZCorreoPassword.arq` se llaman
  ambos `ZZZCorreoPassword` pero son macros distintas (1331 y 1577 bytes, con
  texto diferente). Cuentar 45 desplaza todo lo de arriba una posición.

### 2.2 El listado real (46 filas)

| n | Fichero | Nombre visible | | n | Fichero | Nombre visible |
|---|---|---|---|---|---|---|
| 45 | ZZZAbbyp | ZZZAbbyp | | 22 | ZZZHerme | ZZZHermes |
| 44 | ZZZAdpas | ZZZAdpas | | 21 | ZZZInter | ZZZInternetlibre |
| 43 | ZZZAdria | ZZZAdria | | 20 | ZZZIn001 | ZZZIntervencionvideo |
| 42 | ZZZAgend | ZZZAgenda | | 19 | ZZZISLAp | ZZZISLApagado |
| 41 | ZZZAr001 | ZZZArcontepassword | | 18 | ZZZJara | ZZZJara |
| 40 | ZZZArcon | ZZZArconteSala | | 17 | ZZZLecto | ZZZLectortarjeta |
| 39 | ZZZAumen | ZZZAumentoAlmacenamientoCorreo | | 16 | ZZZLexne | ZZZLexne |
| 38 | ZZZCerti | ZZZCertificadoDigital | | 15 | ZZZMonit | ZZZMonitor |
| 37 | ZZZConfi | ZZZConfianzaEquipo | | 14 | ZZZMulti | ZZZMulticonferencia |
| 36 | ZZZContr | ZZZContraseña | | 13 | ZZZNuevo | ZZZNuevoAdriano |
| 35 | ZZZCorre | ZZZCorreoPassword | | 12 | ZZZOrfil | ZZZOrfila |
| 34 | ZZZCorreoPassword | ZZZCorreoPassword | | 11 | ZZZPinTa | ZZZPinTarjeta |
| 33 | ZZZDisco | ZZZDiscoduro | | 10 | ZZZPnj | ZZZPnj |
| 32 | ZZZDrago | ZZZDragonSpeaking | | 9 | ZZZPorta | ZZZPortafirmasNG |
| 31 | ZZZEdoc | ZZZEdoc | | 8 | ZZZRaton | ZZZRaton |
| 30 | ZZZEmpar | ZZZEmparejamientoISL | | 7 | ZZZRedEq | ZZZRedEquipo |
| 29 | ZZZEscri | ZZZEscritorioJudicial | | 6 | ZZZSiraj | ZZZSiraj2 |
| 28 | ZZZExped | ZZZExpedienteDigital | | 5 | ZZZSoftw | ZZZSoftware |
| 27 | ZZZForma | ZZZFormacion | | 4 | ZZZSumin | ZZZSuministros |
| 26 | ZZZFuent | ZZZFuentealimentacion | | 3 | ZZZTecla | ZZZTeclado |
| 25 | ZZZGanes | ZZZGanes | | 2 | ZZZTelef | ZZZTelefono |
| 24 | ZZZGdu | ZZZGdu | | 1 | ZZZTemis | ZZZTemis |
| 23 | ZZZGm | ZZZGm.arq | | 0 | ZZZZConn | ZZZZConnie |

Las etiquetas amigables de la tabla `M` del port salen de aquí. Las que no se
pueden adivinar con seguridad van con el nombre del fichero: `ArconteSala`,
`Correo password`, `Adpas`, `Connexion`, `Temis`.

### 2.3 El BETA asigna el mismo índice a dos macros distintas

Esto prueba que los números del BETA estaban mal **sin necesidad del listado**:
dos macros diferentes no pueden ocupar la misma fila.

| Índice | (handler, etiqueta) | | (handler, etiqueta) |
|---|---|---|---|
| 5 | `Button11` Equipo sin red | | `Button22` ISL Apagado |
| 10 | `Button10` Lector tarjeta | | `Button24` Formaciones |
| 21 | `Button3` Aumento espacio correo | | `Button6` Certificado digital |

El v1 **no puede ser correcto bajo ninguna interpretación del listado**.

### 2.4 Por qué están mal: el listado fue creciendo

La corrección no es un error aleatorio, es **desfase acumulado**. Comparando el
número del v1 con el real, el desfase es 0 al fondo de la lista y crece hacia
arriba:

| n real | 2 | 3 | 5 | 6 | 7 | 11 | 14 | 15 | 17 | 21 | 23 | 24 | 33 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| v1 | 2 | 3 | 4 | 6 | 5 | 7 | 8 | 9 | 10 | 12 | 13 | 14 | 18 |
| Δ | 0 | 0 | +1 | −1 | +2 | +4 | +6 | +6 | +7 | +9 | +10 | +10 | +15 |

Es la firma de **macros añadidas en la parte alta del alfabeto** sin actualizar
los números escritos a mano. Por eso los 4 handlers que el v1 acertaba son
`Teléfono` (2), `Teclado` (3) — abajo del todo, sin nada por encima — y los dos
*muertos* `Siraj2` (6) y `Emparejamiento ISL` (30).

Y por encima del desfase hay **4 handlers mal cableados de origen**, con Δ
imposible (negativo o disproportionado):

| Handler | Etiqueta GUI | v1 | Real | Δ | Qué ejecuta en realidad el v1 |
|---|---|---|---|---|---|
| `Button21` | Ratón | 37 | **8** | −29 | nada ("Contraseñas" según §2.5) |
| `Button16` | Intervención video | 24 | **20** | −4 | "Intervención video" sí, pero desfasado |
| `Button23` | Contraseñas | 11 | **36** | +25 | "Lector tarjeta" |
| `Button24` | Formaciones | 10 | **27** | +17 | "Lector tarjeta" |

### 2.5 Remapeo: qué hacer con cada botón

22 de los 24 handlers apuntaban a una fila equivocada.

| Handler | Etiqueta GUI | v1 | **Real** | Δ | Handler | Etiqueta GUI | v1 | **Real** | Δ |
|---|---|---|---|---|---|---|---|---|---|
| `Button1` | Internet libre | 12 | **21** | +9 | `Button13` | Teléfono | 2 | **2** | = |
| `Button2` | Multiconferencia | 8 | **14** | +6 | `Button14` | Equipo no enciende | 23 | **26** | +3 |
| `Button3` | Aumento espacio correo | 21 | **39** | +18 | `Button15` | Disco duro | 18 | **33** | +15 |
| `Button4` | GDU | 14 | **24** | +10 | `Button16` | Intervención video | 24 | **20** | −4 |
| `Button5` | Emparejamiento ISL | 17 | **30** | +13 | `Button17` | Monitor | 9 | **15** | +6 |
| `Button6` | Certificado digital | 21 | **38** | +17 | `Button18` | Teclado | 3 | **3** | = |
| `Button7` | Software | 4 | **5** | +1 | `Button19` | Siraj2 *(muerto)* | 6 | **6** | = |
| `Button8` | PIN tarjeta | 7 | **11** | +4 | `Button20` | Emparejamiento ISL *(muerto)* | 30 | **30** | = |
| `Button9` | Servicio no CEIURIS | 0 | **10** | +10 | `Button21` | Ratón | 37 | **8** | −29 |
| `Button10` | Lector tarjeta | 10 | **17** | +7 | `Button22` | ISL Apagado | 5 | **19** | +14 |
| `Button11` | Equipo sin red | 5 | **7** | +2 | `Button23` | Contraseñas | 11 | **36** | +25 |
| `Button12` | GM | 13 | **23** | +10 | `Button24` | Formaciones | 10 | **27** | +17 |

`Button9` pasa de `0` a `10`: en el v1 `{End}{Up 0}{Enter}` seleccionaba la última
fila (**Connexion**), no era un no-op.

### 2.6 `ButtonManager.ahk`: acertaba 32 de 40

Su transcripción del listado es **casi** correcta, pero no la fuente: le faltan
6 filas. Al no contar el segundo `ZZZCorreoPassword`, todo lo que está por encima
de la fila 35 va **+1** desplazado:

| Etiqueta | ButtonManager | Real | | Etiqueta | ButtonManager | Real |
|---|---|---|---|---|---|---|
| Abbypdf | 44 | **45** | | Contraseñas | 35 | **36** |
| Agenda de señalamientos | 41 | **42** | | Error relación de confianza | 36 | **37** |
| Adriano | 42 | **43** | | Aumento espacio correo | 38 | **39** |
| Arconte | 39 | **41** | | Certificado digital | 37 | **38** |

Las 34 filas de la zona baja (0-33) coinciden **exactamente**, y ahí está casi
toda la GUI. Por eso las dos primeras pasadas de esta auditoría —que tomaron
`ButtonManager` como referencia— salían con 3 números buenos de diferencia en 3
botones. La tabla `M` del port está generada desde los `.arq`, no desde ahí.

### 2.7 Atajos

| Atajo | Índice v1 | Qué hay en esa fila | ¿Fiable? |
|---|---|---|---|
| `#1` | 0 | `Connexion` (última fila) | el desfase en la fila 0 es 0, así que **sí** |
| `#2`, `F14` | 43 | `Adriano` | con el desfase acumulado tocaría ~59: fuera de rango. **Roto** |
| `#3`, `F15` | 34 | `Correo password (procedimiento)` | idem, **roto** |
| `#4`, `F16` | 40 | `ArconteSala` | idem, **roto** |
| `#5`, `F17` | 1 | `Temis` | desfase 0 en la fila 1: **sí** |
| `#6` | 42 | `Adriano` | ver §4 |
| `#9`, `F18`, `F12`, `F19`, `Buscar` | 0 | `Connexion` | ver la nota de `ULTIMA_FILA` |
| `F20` | 30 | `Emparejamiento ISL` | **sí**, el desfase en la fila 30 es 0 |

No hay forma de saber qué macro **querían** `#2/F14`, `#3/F15` y `#4/F16`: sus
números ya Apuntaban fuera de rango antes del desfase. Se dejan como estaban y
el port anota a qué fila caen ahora.

### 2.8 16 macros del listado que la GUI no expone

Adpas, Arconte password, ArconteSala, Correo password ×2, Temis, Connexion,
Abbypdf, Adriano, Agenda de señalamientos, Dragon Speaking, Edoc,
Escritorio judicial, Expediente digital, Ganes, Hermes, Jara, Lexnet, Orfila,
@Driano, PortafirmasNG, Suministros. Están en la tabla `M` listas para añadir
botón.

## 3. Alba ya no se usa para la fecha/hora — confirmado

`Macro Remedy/Alba.ps1` recorre los `.arq` de `%APPDATA%\AR System\HOME\ARCmds` y sustituye el valor
de los campos `1010000200=` y `1010000150=` por el literal `$DATE$ $TIME$` (variables nativas de AR
System, que se resuelven en tiempo de ejecución).

- El regex es `[^\x01]*`; el `\x01` (byte `0x01`, confirmado con `od`) es el separador de campo real
  de los `.arq`. Sustituye desde el ID de campo hasta el siguiente separador.
- Lee y escribe con `-Encoding Default` (Windows-1252). **Nunca re-guardar un `.arq` como UTF-8**: los
  acentos de las plantillas se corrompen.
- Excluye 18 ficheros (x0x1xxxM.arq … x7xxxGES.arq). Esas macros conservan la fecha literal antigua.

**Estado de la adopción:**

| | ¿Lanza `Alba.ps1`? | ¿Navega con `{End}{Up n}`? |
|---|---|---|
| `CAU_GUI - BETA.ahk` (producción) | **No** | Sí |
| `Core/ButtonManager.ahk` (v2, nunca desplegado) | **Sí** (`RunWait`, `AppConfig.ALBA_SCRIPT_PATH`) | Sí |

La v2 es el diseño **antiguo**: ejecutaba el script de fechas en cada click *y* navegaba. El BETA ya
aplicó el cambio (nada de `Alba.ps1`) pero conservó el nombre de la función. La decepción: `AppConfig.ahk:39`
apunta a `C:\ProgramData\Application Data\AR SYSTEM\home\Alba.ps1`, una ruta que **no existe** — el
script real vive en `%APPDATA%\AR System\HOME\ARCmds`. La v2 está rota en ese punto.

---

## 4. git ≠ producción

La copia commiteada es **posterior** a la que se ejecuta en los equipos. Diff en el bloque `#6::`
("¿Cuántas veces repetir?"):

| Aspecto | Producción | `git` (main) |
|---|---|---|
| Validación de entero | **ausente** | `if repeatCount is not integer` |
| Aviso durante el bucle | `MsgBox` (pausa y bloquea) | `ToolTip` (no pausa) |
| Macro repetida | **`Alba(42)`** | **`Alba(0)`** |
| `MsgBox` de salida | sin flags ni título | `64, Completado,` |
| `Sleep` | `Sleep 1000` | `Sleep, 1000` |

**Impacto:**

1. **`Alba(42)` vs `Alba(0)` es un cambio de comportamiento, no de estilo.** `{Up 0}` deja el cursor en
   la última fila; `{Up 42}` sube 42. La tecla de repetir hace algo distinto en cada versión. `42` no
   aparece en ningún botón de la GUI.
2. En producción **`#6` no valida que la entrada sea un entero**. Con texto no numérico,
   `Loop %repeatCount%` se comporta de forma indefinida.
3. El `ToolTip` de git es una mejora real (no interrumpe la secuencia de tecleo) que **nunca llegó a los
   equipos**. Hay trabajo hecho en el repo que no está desplegado.
4. El resto del archivo es idéntico en ambas versiones.

**Acción recomendada:** decidir cuál de las dos es la buena para `#6` y desplegar. El port a v2 (§6)
mantiene el comportamiento de producción (`42`) e incorpora las mejoras de git, que son de UX y no
alteran la secuencia de teclas.

---

## 5. Bugs verificados

| # | Línea | Severidad | Problema |
|---|---|---|---|
| 1 | 24, 26-27 | **Alta** | Dos perfiles de usuario hardcodeados conviviendo: `C:\Users\CAU.LAP\...` (Cierrepass) y `C:\Users\david\...` (Contactos/Correos). En cualquier otra máquina falla. Debería ser `%APPDATA%\AR System\HOME\ARCmds\...` y `%USERPROFILE%` |
| 2 | todo | **Alta** | Híbrido v1/v2: `Gui, N:Add` y `Send,` son v1; `global` (líneas 20, 41, 58, 67, 95, 170) y `StrReplace` (263) son **v2**. No es un archivo válido de ninguna de las dos versiones. Ver §7 |
| 3 | 20 | Baja | `global repoUrl, downloadUrl, localFile, tempFile` declara 4 variables que **no se usan en todo el archivo**. Resto de una migración v2 abandonada |
| 4 | 58, 67 | Media | `global currentVersion` y la variable nunca se asignan → todos los logs salen con `[v]` vacío. Impide saber qué versión generó cada línea |
| 5 | 307, 472, 477 | Media | `IsActive` se lee en `KeepActive` (307) pero solo se asigna dentro de `#7` (472/477). Si el temporizador dispara antes de activar el modo AFK, lee una variable inexistente |
| 6 | 371, 374 | Baja | `Button19` y `Button20` no tienen ningún botón que los invoque. Código muerto (Siraj2 y Emparejamiento ISL) |
| 7 | 341 | Media | `Button9` ("Servicio no CEIURIS") llama `Alba(0)` → `{End}{Up 0}{Enter}` = seleccionar y **ejecutar** la última fila, que es `ZZZZConnie` (Connexion). No era un no-op: ejecutaba otra macro. La real es la 10 (§2.5). Corregido en el port |
| 8 | 366-386 | **Alta** | 4 de 22 botones ejecutan una macro cuyo texto no corresponde a su etiqueta: "Ratón"→37, "Contraseñas"→11, "ISL Apagado"→5, "Formaciones"→10. **Resuelto** contra los `.arq` (§2.5): 8, 36, 19, 27 |
| 9 | 323, 332 | Media | `Button3` ("Aumento espacio correo") y `Button6` ("Certificado digital") comparten `Alba(21)`. No pueden ser la misma macro. **Resuelto**: 39 y 38. Tras la corrección **ningún handler comparte índice**, y eso ya no puede volver a pasar (§6) |
| 10 | 299 | Baja | `MsgBox, Error, ...` — el primer parámetro de `MsgBox` es una máscara **numérica de botones**, y `Error` no es un valor válido. Lo mismo en 428, 435, 439, 462, 473, 478, donde `16`/`48`/`64` son botones (16=Ignore, 48=Ignore+Yes, 64=No), no iconos: casi con seguridad se querían iconos de aviso |
| 11 | 52 | Baja | `StringReplace ... %A_Space%, _, All` existe **solo** para fabricar el nombre del log. El nombre resultante es `log_septiembre2026.txt` (mes pegado al año, sin espacio) |
| 12 | 13 | Baja | BOM UTF-8 al inicio del archivo. AHK v1.1 lo tolera; si se pierde al editar, AHK interpreta mal la primera directiva |
| 13 | 154-166 | Media | `cierre()` no tiene `BlockInput`, al contrario que `Alba()`. Secuencia de ~30 teclas sobre Oracle Forms sin protección: cualquier interferencia deja el formulario a medias y el técnico sin salida limpia |
| 14 | 251-278 | Media | El handler de las 8 plantillas de correo **no está dentro de `try`/`catch`**. Si falta un `.txt` de plantilla, salta un error de AHK sin log y con los campos a medias |
| 15 | 341, 366-386 | **Crítica** | **22 de los 24 handlers apuntan a una fila equivocada** (§2.5). Es el bug de más impacto: el técnico pulsa "Contraseñas" y se ejecuta "Lector tarjeta", sin aviso. Causa raíz: los números se escribieron en cada handler en vez de estar en una tabla, y el listado fue creciendo sin actualizarlos (desfase acumulado, §2.4) |

---

## 6. Port a AHK v2

Ver `CAU_GUI_BETA_v2.ahk`. **La lista completa de lo que hubo que cambiar, y de los fallos que solo
aparecieron al ejecutarlo, está en el §10. Esta sección es el criterio; el §10 es la evidencia.**

Criterios aplicados:

- **Sintaxis v2 real, no renombrados cosméticos.** Cada cambio está verificado contra el intérprete
  de v2 (2.0.28), no de memoria. Varios eran comandos en v1 y en v2 no existen:
  `IfWinExist` → `WinExist`, `SendRaw` → `SendText`, `SetTitleMatchMode` → sigue existiendo pero como
  función, `InputBox` cambia de firma y de tipo de retorno. El §10 los lista uno a uno.
- **Preservación estricta del comportamiento**: mismas coordenadas, mismos atajos, misma secuencia
  `{Tab 22}`, mismo `BlockInput`, y `SendText` para las plantillas, que es el equivalente exacto de
  `SendRaw` (el texto puede contener `{}` y no debe interpretarse como teclas).
- **`SendInput` → `SendEvent`**: el original usa `SendInput` a propósito en `cierre()` (envío por
  eventos, no por inyección de Input). En v2 `Send` usa el método Input, así que preservar esto exige
  `SendEvent()` explícito.
- **Corregido en el port:** rutas por `%APPDATA%`/`%USERPROFILE%` (#1), `currentVersion` e `IsActive`
  declarados (#4, #5), `MsgBox` con iconos válidos (#10), `BlockInput` también en `cierre()` (#13),
  `try/catch` en las plantillas (#14), validación de entero y `ToolTip` en `#6` (de git).
- **Números de macro corregidos** contra los `.arq` reales (§2.2) y **reestructurados**: los 25 handlers
  ya no llevan número, piden el índice por nombre a `EjecutarMacro("nombre")`, que lo busca en el `Map`
  `M` del principio del script. Así es estructuralmente imposible que dos macros compartan índice
  (bug #15), que es exactamente como se coló el error.
- **`SIN_MACRO` era falso y se ha eliminado.** El v1 usaba `Alba(0)` creyendo que era "sin macro", pero
  la fila 0 es `ZZZZConnie` (Connexion): `{End}{Up 0}{Enter}` la selecciona y la ejecuta. El port lo
  llama `ULTIMA_FILA` y conserva el `0` para no cambiar el comportamiento (§2.7).
- **Guardas añadidas:** si un nombre no está en `M`, `EjecutarMacro` devuelve `-1` y `ExecuteAlbaMacro`
  aborta con `MsgBox` **sin enviar ninguna tecla**. Antes, un nombre mal escrito mandaba el cursor a una
  fila arbitraria del formulario.

> **Los `global` NO desaparecen.** Una primera versión de esta sección afirmaba que los seis `global`
> del v1 sobraban. Es al revés: en v2 el ámbito de función es local **por defecto**, así que sin
> `global` un hotkey que asigna `Toggle := !Toggle` se crea una local nueva en cada pulsación y el
> estado se pierde al salir. Faltan cuatro (§10, fallo 7).

---

## 7. Preguntas abiertas

*Respuesta del usuario al ejecutar el validador en su equipo:* las corridas de
`verificar_indices.ps1` en Windows (PowerShell 5.1, copia actual del repositorio) devuelven
**"Todo correcto"** con la tabla M del port y la lectura se decide por **UTF-8, formato tabla M**,
46 entradas, 46 `.arq`, sin huecos ni duplicados y `0` como última fila (`ZZZZConnie`). El caso
que provocaba *1 entrada de 46* con el nombre en blanco queda identificado y blindado en el script.

1. **¿Con qué intérprete se ejecuta en producción?** El archivo mezcla sintaxis v1 y v2 (bug #2), así
   que no es válido en ninguna. `global dni, telf` (línea 95) está dentro de `ExecuteAlbaMacro`, que se
   ejecuta en **cada click**. Si fuese v2 puro, `Gui, 1:Add` (líneas 181-231) no existiría; si fuese v1
   puro, ese `global` daría error. Se resuelve mirando el intérprete configurado en el equipo.
2. **¿Qué macro deben correr `#2/F14`, `#3/F15` y `#4/F16`?** Sus números (43, 34, 40) apuntaban fuera
   de rango incluso antes del desfase. Hoy caen en `Adriano`, `Correo password` y `ArconteSala` (§2.7).
3. **`#6`: ¿índice 42 o la fila 0?** 42 = `Adriano`, que no encaja con "repetir la acción". En git es
   `Alba(0)`. El port mantiene 42.
4. **¿`Buscar` / `F12` / `F19` deben ejecutar `Connexion`?** `{End}{Up 0}{Enter}` sí selecciona y ejecuta
   la última fila. En el v1 se tomaba como "solo enfocar".
5. **¿Las 4 filas de arriba del listado** (`ZZZAbbyp`, `ZZZAdpas`, `ZZZArcontepassword`,
   `ZZZArconteSala`) **son de uso real del CAU o Discarded?** No las referencia ningún botón. Si se
   borran, todos los números vuelven a bajar.
6. **Orden alfabético exacto.** La deducción asume *case-insensitive* por el nombre visible, con
   desempate por fichero. Solo afecta a 4 posiciones (`Arconte password`/`ArconteSala` y
   `Internet libre`/`Intervención video`) y ninguna la usa un botón. Se resuelve contando en el
   formulario.



7. **`GuiEscape` / `GuiClose`: ¿cerraban la aplicación entera o solo la ventana principal?** En v2 esas
   etiquetas no existen y se han sustituido por `.OnEvent("Close"/"Escape")` **en la ventana
   principal únicamente**. No se ha podido confirmar la semántica de v1 porque no se ha conseguido el
   intérprete de v1 (todas las URL de descarga dan 404 o 0 bytes). Si en v1 cerrar el formulario de
   plantillas salía de la aplicación y aquí no, es un cambio de comportamiento que hay que decidir.
8. **Los `MsgBox` con 16, 48 y 64, ¿querían iconos o botones?** Son máscaras de botón (§2.3), no
   iconos. El port los ha puesto como iconos, que es casi con toda seguridad la intención, pero es
   una interpretación y cambia lo que ve el técnico.

Para resolver 2-6 basta abrir el formulario Alba en un equipo con Remedy y contar. `verificar_indices.ps1` (§9)
automatiza la parte estática. La 7 y la 8 no se pueden automatizar: son de intención, no de
texto, y necesitan que conteste alguien de los técnicos.

---

## 8. `ButtonManager.ahk`: la fuente de verdad, pero con 6 filas de menos

En la primera pasada se descartó por contradecir al BETA en 15 de 22 botones. Era un error de
criterio: **las contradicciones eran del BETA**, no suyas (§2.3). Pero tampoco era la fuente: el
ARCmds real va a los `.arq` (§2.1).

Lo que aporta `ButtonManager.ahk` es la **transcripción** del listado, y es buena en su mayor parte
(32/40 exactos, y las 34 filas bajas clavadas). Sus defectos:

- **Le faltan 6 macros**: `Adpas`, `ArconteSala`, los dos `Correo password`, `Temis` y `Connexion`.
  La de `Connexion` es la que más daño hace, porque desaparece la fila 0 y todo lo de arriba va +1.
- Asigna `"Arconte"` a `ZZZAr001` (`ZZZArcontepassword`) cuando el nombre visible sugiere
  `ZZZArconteSala`. Las dos filas están, pero repartidas: 39 en su tabla, 40 y 41 en la real.
- `ExecuteAlbaScript()` (línea 228) sigue lanzando `Alba.ps1` en cada click: es el diseño antiguo que
  el BETA ya había abandonado (§3).
- `AppConfig.ALBA_SCRIPT_PATH` (línea 39) apunta a
  `C:\ProgramData\Application Data\AR System\home\Alba.ps1`, ruta que no existe. El ARCmds real
  vive en `%APPDATA%\AR System\HOME\ARCmds`.

**Conclusión operativa:** la tabla `M` de `CAU_GUI_BETA_v2.ahk` se genera desde los `.arq` de
`ARCmds/ARCmds/`, no desde `ButtonManager.ahk`. Este último queda como *proveedor de etiquetas
amigables* de 39 de las 46 macros.

---

## 9. `verificar_indices.ps1`

Contrasta la tabla `M` contra los `.arq` reales. **Solo lectura**: no modifica nada.

```powershell
cd "Macro Remedy"
.\verificar_indices.ps1
.\verificar_indices.ps1 -Tabla "Core\ButtonManager.ahk"   # ver cómo de buena es su transcripción
.\verificar_indices.ps1 -SoloLectura                      # sin ARCmds: solo coherencia interna
```

Busca el ARCmds en este orden: `-ARCmds`, `.\ARCmds\ARCmds` (la copia del repo) y
`%APPDATA%\AR System\HOME\ARCmds` (el del equipo). Sale con código 1 si algo falla, así que sirve
en un script.

 Hace tres cosas:

1. **Coherencia de la tabla** — ningún índice en dos macros, ningún nombre repetido, sin huecos.
2. **Número de macros** — si ARCmds tiene más o menos `.arq` de los que la tabla asume, dice
   cuántos y avisa de que **todo está desplazado**.
3. **Fila a fila** — imprime el listado real con su índice y marca las macros que la tabla no
   conoce.

La lectura del nombre es la del §2.1: byte a byte hasta el `\n` en Windows-1252, orden alfabético
sin distinguir mayúsculas, desempate por nombre de fichero.

### Tres bugs del validador, todos encontrados por ejecutarlo de verdad

**1. El "1 de 46" no era un parser roto: era un `$null`.** En un equipo con Windows PowerShell 5.1
la salida era:

```
1. Coherencia interna de la tabla
  1 macros con nombre
  [FALLO]  Solo 1 entradas leidas de                          . Es una lectura fallida, no una tabla corta.
```

El nombre de fichero sale **en blanco**, y eso es la pista: `@($null)` tiene `.Count` = 1 y se
interpola como cadena vacía. Lo que llegaba al comparador no era una tabla de una entrada, era un
`$null` suelto. Rehecha la lectura línea a línea, sin anclar `$` y sin depender del modo multilínea,
el resultado siguió siendo 1: el fallo no estaba en el patrón.

**2. `$tabla` y `$Tabla` eran la misma variable.** PowerShell no distingue mayúsculas, así que el
array de índices y el parámetro con la ruta del fichero eran una y la misma. Al asignar el array se
perdía la ruta, el diagnóstico recibía una ruta vacía y `ReadAllBytes` terminaba con *"La ruta de
acceso no tiene un formato válido"*, que era el error que veía el usuario. El array pasa a llamarse
`$tablaM`.

**3. `@($lista).Count` lanza si la lista es de objetos.** Envolver un `System.Collections.Generic.List[object]`
en `@()` falla con *"Argument types do not match"* **aunque tenga elementos**. Con 46 entradas no
hay nada que ganar con una lista, así que el validador usa arrays de PowerShell.

**Cómo queda la lectura.** En vez de seguir buscando la causa exacta del `$null`, que depende de la
versión de PowerShell y no se ha podido reproducir, la lectura se hace a prueba de él: se leen
bytes, se proban **tres decodificaciones** (UTF-8, Windows-1252, UTF-16) contra **dos formatos de
tabla** (`"nombre": N` del port v2 y `Map("name", "X", "albaParam", N)` de `ButtonManager.ahk`), y
se queda con la que más entradas saca. El script imprime las seis pruebas, así que si algo va mal
se ve cuál era la buena y por qué las otras no.

Comprobado con PowerShell 7.6.6 sobre el repo y sobre ficheros construidos a propósito: LF, CRLF,
CR puro, UTF-8 con BOM, Windows-1252, tabuladores y espacio duro dan **46 entradas y "Todo
correcto"**; un fichero UTF-16 también se lee (46, por la decodificación alternativa); uno vacío, uno
con basura y una ruta inexistente fallan con un mensaje claro y código 1; y una tabla con un índice
duplicado se detecta con el desfase que provoca. **El código de salida es 0 cuando todo cuadra.**

El diagnóstico de lectura fallida se mantiene y ahora no puede lanzar: indica codificado, recuento
de bytes, CR, LF y NUL, cuántas líneas parecen entradas de tabla, cuántas encajan y dónde está la
línea `M :=`.

### `.gitattributes`: los `.arq` no se dejan a git

El repositorio no tenía `.gitattributes`, y con el `core.autocrlf=true` que trae Git por defecto al
instalarlo en Windows hay un riesgo real: git podría convertir los finales de línea de
`ARCmds/**/*.arq`, que son Windows-1252 con CRLF y llevan el separador de campo `0x01`. Si los toca,
**las macros de producción dejan de funcionar y la tabla de índices pasa a describir un listado que
ya no es el real**.

Se añaden `*.arq -text` y `*.arr -text` (binario: cero conversión en ninguna dirección). Comprobado
que los blobs ya commiteados tienen los CRLF intactos, así que la regla no provoca ningún cambio
espurio. **Deliberadamente no se fijan reglas `eol=lf` para el código fuente**: con medio repo en
CRLF legadose, un `--renormalize` reescribe de golpe `Bateria de pruebas/`, `Otras herramientas/` y
`superbateria_test.ps1`, que están fuera de alcance.

---

## 10. El port a v2, fallado por ejecución

Esta sección existe porque **compilar no es arrancar**. El port llegó a compilar sin un solo error y
aún así estaba roto de diez maneras distintas, y ninguna se veía sin ejecutarlo.

### Cómo se ha verificado

El banco de pruebas es **Wine + Xvfb**, no una VM de Windows. La razón es el coste: un ciclo de
corrección en una VM de Proxmox es de horas (arrancar, instalar AutoHotkey, copiar el fichero,
arrancar, cerrar), y aquí son unos 40 segundos. Un `.ahk` no usa nada que Wine no sepa emular
(mensajes de Windows, GUI, `DllCall` a `ntdll`), así que las diferencias entre el banco y un equipo
real están en la resolución del formulario Oracle y en el `{Tab}` de Remedy, no en la lógica.

Interprete: **AutoHotkey v2.0.28**. Todo lo de esta sección está comprobado con ese binario, no con
la documentación ni de memoria.

El resultado final del port:

```
0 errores de compilación
0 avisos de #Warn
ventana "Lazybird" presente, 1083x332, los 23 botones con su texto
clic en "GDU" -> llega a CheckRemedy()   (verificado por captura)
```

### Los 10 fallos

**1. `Gui("1:Add", …)` está muerto al nacer.** La traducción mecánica de `Gui, 1:Add, Text, …` da
`Gui("1:Add", "Text", …)`, que **compila sin quejarse** y revienta en la primera llamada con *"Too
many parameters passed to function"*. En v2 no hay ventanas numeradas: cada una es un objeto `Gui()`.
Lo mismo con la opción `gButtonN` de las cadenas de opciones, que en v2 no existe y se traduce por
`.OnEvent("Click", …)`.

> Consecuencia: los 25 botones se dibujaban y **no hacían nada al pulsarlos**. Un port que solo se
> compila y se mira compilar habría dado este por bueno.

**2. Las 25 etiquetas `ButtonN:` no son manejadores.** `Boton(guiMain, Button4, …)` evalúa `Button4`
como expresión, y una etiqueta no es un valor. Se han convertido en funciones `ButtonN(*) { … }`. El `*` es
obligatorio: `OnEvent` pasa dos argumentos y una función de un solo parámetro falla. Con etiquetas,
AHK avisaba 25 veces *"This global variable appears to never be assigned a value"*.

**3. `M` y `DiccionarioCorreos` no admitían acceso por índice.** Eran objetos planos. En v2,
`objeto["clave"]` no busca una propiedad: busca una propiedad llamada `__Item`, y da en ejecución

```
This value of type "Object" has no property named "__Item".
```

lo que **para el script en el arranque**, antes de pintar nada. Los dos son ahora `Map()`, que es el
diccionario de v2, y `.Has()` sustituye a `.HasOwnProp()` (que `Map` no tiene).

Relacionado: las claves de un literal de objeto en v2 tienen que ser **identificadores desnudos**
(`GDU: 24`). Las entrecomilladas (`"GDU": 24`) son de v1 y se rechazan. Como casi todos los nombres
de macro tienen espacios o acentos, la tabla no se puede escribir como literal: son 46 asignaciones.

**4. `Font` no es un método de `Gui`, y el título no va en `Show()`.**

| v1 | v2 (correcto) | Qué pasaba si se hacía mal |
|---|---|---|
| `Gui, 1:Font,, Segoe UI` | `guiMain.SetFont(, "Segoe UI")` | *Invalid option* — el 1.º parámetro son las opciones (`s14`, `cRed`), no la fuente |
| `Gui, 1:Show, w1083 h332, Lazybird` | `guiMain.Title := "Lazybird"` + `Show("w1083 h332")` | *Too many parameters* — `Show` solo acepta el tamaño |

**5. Comandos de v1 que en v2 no existen o cambian de firma.**

| v1 | v2 | Nota |
|---|---|---|
| `IfWinExist("…")` | `WinExist("…")` | v2 lo trata como variable y avisa |
| `SendRaw(texto)` | `SendText(texto)` | Equivalente **exacto**: no interpreta `{}`. **No** sustituir por `Send`, que sí lo interpretaría |
| `SetBatchLines` | — | **Eliminada.** Los scripts corren a máxima velocidad por defecto. Se dejó la llamada como está, y v2 la trata como global suelta y saca un diálogo **modal** que congela la macro |
| `InputBox, salida, título, prompt, , 300, 150` | `ib := InputBox(prompt, título, "w150 h300")` → `ib.Value` / `ib.Result` | Cambia el **orden** (v1: `H, W`; v2: dentro de `Options`) y **devuelve un objeto**, no una cadena. Los huecos no se permiten |

Lo de `SetBatchLines` es la más traicionera de la lista: quitar la llamada no cambia el
comportamiento, **dejarla** congela la macro en un diálogo.

**6. Los 17 `catch as err` se pisaban entre sí.** Renombrados a `catch as excepcion1…17`, los 17
avisos desaparecieron. El caso mínimo son cuatro líneas:

```ahk
Boton(v) {
    boton := v          ; ← "boton" dentro de "Boton" dispara el aviso
    return boton
}
Boton(1)
```

*This local variable has the same name as a global variable* — con el aviso **modal**, es decir la
macro arranca y se queda parada. Un técnico vería una macro que no responde y sin pista. Nótese que
v2 **sí** distingue mayúsculas: el choque no es de nombre, es de que la local se llama igual que la
función global. Nombres únicos (`excepcionN`, `ctlBoton`) lo resuelven.

**7. Faltaban cuatro `global`.** En v2 el ámbito de función es local por defecto, así que asignar sin
`global` dentro de un hotkey crea una local que **arranca vacía en cada pulsación**:

| Variable | Función | Sin `global` |
|---|---|---|
| `Inci` | `Button25` | Busca siempre una incidencia vacía, sin error |
| `Toggle`, `IsActive` | `#7` | El modo AFK no se puede ni activar: `Toggle` siempre vale `false` |
| `dni` | `UpdateLetter` | La global sigue vacía para el resto del script |

**8. `MyCurrentTimerResolution` era un parámetro de salida sin usar.** `DllCall` con un destino que
nunca se lee no falla, pero el port comprobaba la **variable** en vez del **código de retorno**. Ahora
comprueba el retorno y escribe al log.

**9. `A_MaxHotkeysPerInterval` / `A_HotkeyInterval` no son directivas.** Eran `#MaxHotkeysPerInterval`
y `#HotkeyInterval` en v1; en v2 son variables incorporadas que se asignan, y por eso van en el cuerpo
y no en la zona de directivas. `#NoEnv` se eliminó y `#Persistent` no existe: los scripts ya son
persistentes.

**10. `SetTimer("KeepActive", …)` no crea el temporizador.** Este no lo había visto nadie — ni yo en
la primera pasada — porque **compila sin error ni aviso** y solo falla al ejecutar:

```
Parameter #1 of SetTimer requires an Object, but received a String.
```

En v2 `SetTimer` exige el **objeto función**, no el nombre entre comillas. Y como la llamada está
dentro del `try` del hotkey `#7`, la excepción se come sola y acaba en el log. El técnico pulsaba
`#7`, veía *"Modo AFK activado"*, y el equipo **se suspendía igual**: el temporizador, que era lo
único que impedía la suspensión, nunca se había creado.

Dos arreglos, los dos obligatorios:

| v1 / forma rota | v2 | Por qué |
|---|---|---|
| `SetTimer("KeepActive", 60000)` | `SetTimer(KeepActive, 60000)` | objeto función, no cadena |
| `KeepActive:` (etiqueta) | `KeepActive() { … }` (función) | `SetTimer` no acepta etiquetas en v2 |

Medido sobre el port real, no sobre un ejemplo: 6 disparos del temporizador en la ventana activa con
la forma buena, **0** con la de cadena, en la misma prueba y la misma copia.

La forma buena, entera:

```ahk
KeepActive() {
    global IsActive                    ; sin esto, IsActive es una local vacía
    try {
        if (IsActive)
            DllCall("SetThreadExecutionState", "UInt", 0x80000003)
    } catch as excepcion11 {
        WriteError("Error manteniendo el equipo activo: " . excepcion11.Message)
    }
}
```

Sin el `global` el bug se enmascara: el temporizador sí existiría, pero `IsActive` sería una local
vacía en cada disparo y la `DllCall` no se ejecutaría nunca. Los dos fallos juntos dan exactamente
el síntoma del bug 7 —el modo AFK no hace nada— por dos causas distintas, y por eso conviene
comprobarlos por separado.

`verificar-port.py` (§5) avisa de las dos formas: cadena en `SetTimer`, y destino que sea etiqueta o
no exista. Probado en negativo con tres copias rotas a propósito; las tres se detectan.

> **Nota sobre la prueba end-to-end del modo AFK:** para ejercitarlo de verdad no vale pulsar `#7`
> desde fuera con `Send()`. Bajo Wine el `Send()` sintético no llega a los hotkeys del propio script,
> así que la hotkey no se dispara y la prueba pasa sin comprobar nada — da falso negativo. Lo que
> funciona es copiar el *cuerpo* del hotkey (las tres líneas de `Toggle`/`SetTimer`/`IsActive`) en un
> temporizador de prueba dentro del propio port. Es lo que se hizo aquí.
>
> Otra trampa del mismo test: en una copia instrumentada, el `MsgBox` de *"No se encontró la plantilla
> de cierre"* (línea 104 del port) detiene el auto-execute en Wine, donde `Cierrepass.txt` no existe.
> El port arranca, dibuja la ventana y se queda parado **antes** de llegar a `guiMain.Show()`; sin
> `xvfb` no se ve ningún síntoma y parece que el script no hace nada. Hay que falsear esa rama para
> instrumentar.

### Lo que NO se ha podido cerrar

- **`GuiEscape` / `GuiClose`.** El v1 cerraba la aplicación con esas dos etiquetas. En v2 no existen
  como hotkeys (`GuiEscape::` no es un hotkey válido), así que se han enganchado a la ventana principal
  con `.OnEvent("Close"/"Escape")`. **Sin cerrar la cuestión**: no se ha podido conseguir el intérprete
  de v1 para confirmar si en v1 afectaban a **las dos** ventanas o solo a la principal, y en v2 no hay
  forma de replicar "una etiqueta para todas las ventanas" sin la numeración que ya no existe. Si en
  v1 cerrar el formulario de plantillas salía de la aplicación y aquí no, es un cambio de
  comportamiento. **Pregunta para los técnicos** (§7).
- **Los números 16, 48 y 64 de los `MsgBox` del v1** son máscaras de botón, no iconos (§2.3). El port
  los ha puesto como iconos, que es casi con toda seguridad la intención, pero es una interpretación.

### Verificación automática

`verificar-port.py` comprueba lo que es textual, que es justamente lo que decide si el técnico pulsa
"GDU" y le sale la macro de GDU:

1. el listado real de los `.arq` tiene 46 macros y los índices son 0..45 sin huecos ni repetidos;
2. la tabla `M` tiene 46 entradas y la *k*-ésima tiene el índice `45 − k`;
3. los 25 handlers piden su macro por nombre, y todo nombre existe en la tabla;
4. ningún handler escribe un número de macro a mano;
5. todo botón cableado tiene su función, y existe `OnEvent("Click")`;
6. `SetTimer` no recibe cadenas y su destino es una función que existe (modo AFK, bug 10).

> **La comparación de nombres es POSICIONAL, no literal, y hay un motivo.** El nombre visible de la
> macro en el formulario (línea 1 del `.arq`) **no es** la etiqueta del botón. La macro
> `ZZZFuentealimentacion` es la que el técnico tiene en el botón **"Equipo no enciende"** — si no
> enciende el equipo, la causa es la fuente — y `ZZZRedEquipo` es la de **"Equipo sin red"**. Comparar
> los nombres en abstracto daría 46 avisos falsos. Lo que define el índice es la posición alfabética.

Comprobado en positivo y, sobre todo, **en negativo**: contra copias con un índice movido (`GDU`
24→25), con un `ExecuteAlbaMacro(14, "GDU")` a mano y con el `OnEvent` eliminado, falla las tres con un
mensaje que señala el sitio exacto. Un validador que solo dice "OK" no vale para nada.
