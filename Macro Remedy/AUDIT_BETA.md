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

Ver `CAU_GUI_BETA_v2.ahk`. Criterios aplicados:

- **Sintaxis v2 real**, no renombrados cosméticos: `Gui("1:Add", …)`, `Send("…")`, `FileRead()`,
  `IfWinExist()`, `Loop N`, `StrReplace()`, `InputBox(Prompt, Title, …)`, `IsInteger()`. Los 6
  `global` desaparecen (en v2 el ámbito de función es local y las globales lo son por defecto).
- **Preservación estricta del comportamiento**: mismas coordenadas, mismos atajos, misma secuencia
  `{Tab 22}`, mismo `BlockInput`, mismo `SendRaw` para las plantillas (el texto puede contener `{}` y
  no debe interpretarse).
- **`SendInput` → `SendEvent`**: el original usa `SendInput` a propósito en `cierre()` (envío por
  eventos, no por inyección de Input). En v2 `Send` usa el método Input, así que preservar esto exige
  `SendEvent()` explícito.
- **Corregido en el port:** rutas por `%APPDATA%`/`%USERPROFILE%` (#1), `currentVersion` e `IsActive`
  declarados (#4, #5), `MsgBox` con iconos válidos (#10), `BlockInput` también en `cierre()` (#13),
  `try/catch` en las plantillas (#14), validación de entero y `ToolTip` en `#6` (de git).
- **Números de macro corregidos** contra los `.arq` reales (§2.2) y **reestructurados**: los 24 handlers
  ya no llevan número, piden el índice por nombre a `EjecutarMacro("nombre")`, que lo busca en el objeto
  `M` del principio del script. Así es estructuralmente imposible que dos macros compartan índice
  (bug #15), que es exactamente como se coló el error.
- **`SIN_MACRO` era falso y se ha eliminado.** El v1 usaba `Alba(0)` creyendo que era "sin macro", pero
  la fila 0 es `ZZZZConnie` (Connexion): `{End}{Up 0}{Enter}` la selecciona y la ejecuta. El port lo
  llama `ULTIMA_FILA` y conserva el `0` para no cambiar el comportamiento (§2.7).
- **Guardas añadidas:** si un nombre no está en `M`, `EjecutarMacro` devuelve `-1` y `ExecuteAlbaMacro`
  aborta con `MsgBox` **sin enviar ninguna tecla**. Antes, un nombre mal escrito mandaba el cursor a una
  fila arbitraria del formulario.

---

## 7. Preguntas abiertas

1. **¿Con qué intérprete se ejecuta en producción?** El archivo mezcla sintaxis v1 y v2 (bug #2), así
   que no es válido en ninguna. `global dni, telf` (línea 95) está dentro de `ExecuteAlbaMacro`, que se
   ejecuta en **cada click**. Si fuese v2 puro, `Gui, 1:Add` (líneas 181-231) no existiría; si fuese v1
   puro, ese `global` daría error. Se resuelve mirando el intérprete configurado en el equipo.
2. **¿Qué macro deben correr `#2/F14`, `#3/F15` y `#4/F16`?** Sus números (43, 34, 40) apuntaban fuera
   de rango incluso antes del desfase. Hoy caen en `Adriano`, `Correo password` y `ArconteSala` (§2.7).
3. **`#6`: ¿índice 42 o la fila 0?** 42 = `Adriano`, que no encaja con "repetir la acción". En git es
   `Alba(0)`. El port mantiene 42.
4. **¿`Buscar` / `F12` / `F19` deben ejecutar `Connexion`?** `{End}{Up 0}{Enter}` sí selecciona y ejecuta
   la última fila. En el v1 setomaba como "solo enfocar".
5. **¿Las 4 filas de arriba del listado** (`ZZZAbbyp`, `ZZZAdpas`, `ZZZArcontepassword`,
   `ZZZArconteSala`) **son de uso real del CAU o Discarded?** No las referencia ningún botón. Si se
   borran, todos los números vuelven a bajar.
6. **Orden alfabético exacto.** La deducción asume *case-insensitive* por el nombre visible, con
   desempate por fichero. Solo afecta a 4 posiciones (`Arconte password`/`ArconteSala` y
   `Internet libre`/`Intervención video`) y ninguna la usa un botón. Se resuelve contando en el
   formulario.

Para resolver 2-6 basta abrir el formulario Alba en un equipo con Remedy y contar. `verificar_indices.ps1`
(§9) automatiza la parte estática.

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

> **Bug encontrado al ejecutarlo en un equipo real (30/09/2026).** La primera versión leía la tabla
> con un único regex multilínea sobre el fichero entero y devolvía **1 entrada de 46**. El script
> concluía que faltaban 45 macros en ARCmds y señalaba la tabla como desviada, cuando lo único roto
> era el parser. La causa exacta no queda confirmada —la diferencia está en cómo el motor .NET
> interpreta `(?m)` junto con `$`—, así que la lectura se reescribió para no depender de eso: se leen
> bytes, se normalizan los finales de línea y se analiza **línea a línea sin anclar `$`**. Además,
> un recuento inferior a 10 entradas se trata como **fallo de lectura**, no como tabla corta, y se
> imprime un diagnóstico con bytes, recuento de CR y de LF, y las primeras líneas no vacías.
>
> Sigue sin poder ejecutarse en el entorno donde se escribió (no hay PowerShell en Linux). La lógica
> está replicada en Python y validada contra los `.arq` reales en las dos variantes de finales de
> línea: 46 entradas, correspondencia 1:1, sin huecos ni duplicados. Aun así conviene confirmarlo en
> un equipo con Remedy.

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
