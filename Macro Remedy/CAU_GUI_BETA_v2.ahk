#Requires AutoHotkey v2.0
; =============================================================================
; CAU_GUI_BETA_v2.ahk - Gestor de Incidencias CAU "Lazybird" (puerto a AHK v2)
; =============================================================================
; Port de "CAU_GUI - BETA.ahk" (v1, version en produccion).
; Ver AUDIT_BETA.md para el inventario de indices y los bugs detectados.
;
; REGLA DE ORO: la macro no habla con Remedy por API. Es teclado sintetico sobre
; el formulario Oracle (ArFrame). Cualquier cambio en la secuencia de {Tab N}
; rompe la macro en manos del tecnico. Las coordenadas, los atajos, el {Tab 22}
; y el BlockInput se conservan EXACTAMENTE.
;
; Los numeros de macro (n) NO se han tocado: son indices posicionales contados
; desde el final del formulario Alba. Ver AUDIT_BETA.md seccion 2.
; =============================================================================

#SingleInstance Force
#NoEnv
#MaxHotkeysPerInterval 99000000
#HotkeyInterval 99000000
#KeyHistory 0
; #Persistent no existe en v2: los scripts son persistentes por defecto.

; --- Ajustes de rendimiento (identicos a v1) ---
DetectHiddenWindows True
ListLines False
ProcessSetPriority("A")
SetBatchLines "-1"
SetKeyDelay -1, -1
SetMouseDelay -1
SetDefaultMouseSpeed 0
SetWinDelay -1
SetControlDelay -1
SendMode "Input"        ; metodo Input: NO cambiar a Event sin rehacer el analisis
DllCall("ntdll\ZwSetTimerResolution", "Int", 5000, "Int", 1, "Int*", MyCurrentTimerResolution)
SetWorkingDir A_ScriptDir

; --- Version: la variable se usaba en los logs pero nunca se asignaba (bug #4) ---
currentVersion := "BETA-v2"

; --- Estado ---
dni := ""
telf := ""
Inci := ""
Toggle := false
IsActive := false
letters := "TRWAGMYFPDXBNJZSQVHLCKE"

; --- Rutas: se eliminan los perfiles hardcodeados C:\Users\CAU.LAP y
;     C:\Users\david (bug #1). Ahora se derivan del entorno. ---
RutaARCmds := A_AppData "\AR System\HOME\ARCmds"
RutaPlantillas := RutaARCmds "\Plantillas"
RutaContactos := RutaPlantillas "\Contactos"
RutaCorreos := RutaPlantillas "\Correos"
RutaCierres := RutaPlantillas "\Cierres"

; Cierre por defecto. En v1 la lectura era incondicional al arrancar: si el
; fichero faltaba, la macro no cargaba. Ahora degrada con aviso.
Cierrepass := LeerPlantilla(RutaCierres "\Cierrepass.txt")
if (Cierrepass = "")
    MsgBox("No se encontró la plantilla de cierre en:" . "`n" . RutaCierres . "\Cierrepass.txt"
        . "`n`n" . "Los cierres automáticos quedarán sin texto por defecto.", "Lazybird", "Iconx")

; --- Diccionario: boton de GUI 2 -> fichero de plantilla de correo ---
DiccionarioCorreos := {
    AccionPlantilla1: "NIG_captura",
    AccionPlantilla2: "Captura",
    AccionPlantilla3: "Formulario",
    AccionPlantilla4: "Formulario_GDU",
    AccionPlantilla5: "Info_solventada",
    AccionPlantilla6: "Problema_General",
    AccionPlantilla7: "Resolucion_tlt",
    AccionPlantilla8: "Mantenimiento",
}

; =============================================================================
; INDICE DE MACROS - LISTADO REAL DE ARCmds (46 macros, filas 0..45)
; =============================================================================
; El formulario Alba lista las macros en orden alfabetico y SeleccionarMacro()
; sube desde la ultima fila: {TAB 2}{End}{Up n}{Enter}. Por tanto
;
;     n = 45 - posicion alfabetica        (posicion 0 = la primera, la "A")
;
; Verificado contra los 46 ficheros .arq de ARCmds/ARCmds. El prefijo "ZZZ" del
; nombre visible es lo que fuerza ese orden alfabetico.
;
; ESTA TABLA SUSTITUYE A LOS NUMEROS MAGOS EN LINEA. Es el unico sitio donde hay
; que tocar cuando se anade, borra o renombra una macro en ARCmds.
;
; En el v1 los numeros venian escritos en cada handler. Eso permitio que tres
; filas tuvieran DOS macros distintas:
;     5  <- "Equipo sin red" y "ISL Apagado"
;     10 <- "Lector tarjeta" y "Formaciones"
;     21 <- "Aumento espacio correo" y "Certificado digital"
; 22 de los 24 handlers apuntaban a la fila equivocada. Ver AUDIT_BETA.md seccion 2.
;
; ALTA: los indices se corrigen por NOMBRE. Si el listado de ARCmds de un equipo
; no coincide con el de arriba, cambia aqui el numero, no en los handlers.
; =============================================================================

M := {
    "Abbypdf":                         45,
    "Adpas":                           44,
    "Adriano":                         43,
    "Agenda de señalamientos":         42,
    "Arconte password":                41,
    "ArconteSala":                     40,
    "Aumento espacio correo":          39,
    "Certificado digital":             38,
    "Error relación de confianza":     37,
    "Contraseñas":                     36,
    "Correo password (micuenta)":      35,
    "Correo password (procedimiento)": 34,
    "Disco duro":                      33,
    "Dragon Speaking":                 32,
    "Edoc":                            31,
    "Emparejamiento ISL":              30,
    "Escritorio judicial":             29,
    "Expediente digital":              28,
    "Formaciones":                     27,
    "Equipo no enciende":              26,
    "Ganes":                           25,
    "GDU":                             24,
    "GM":                              23,
    "Hermes":                          22,
    "Internet libre":                  21,
    "Intervención video":              20,
    "ISL Apagado":                     19,
    "Jara":                            18,
    "Lector tarjeta":                  17,
    "Lexnet":                          16,
    "Monitor":                         15,
    "Multiconferencia":                14,
    "@Driano":                         13,
    "Orfila":                          12,
    "PIN tarjeta":                     11,
    "Servicio no CEIURIS":             10,
    "PortafirmasNG":                   9,
    "Ratón":                           8,
    "Equipo sin red":                  7,
    "Siraj2":                          6,
    "Software":                        5,
    "Suministros":                     4,
    "Teclado":                         3,
    "Teléfono":                        2,
    "Temis":                           1,
    "Connexion":                       0,
}

; Fila 0 = ULTIMA del listado = "ZZZZConnie" (Connexion). El v1 la usaba como si
; fuera "sin macro", pero {End}{Up 0}{Enter} SI selecciona esa fila y la ejecuta.
; Se conserva el 0 porque asi funcionaba; el nombre correcto es "ultima".
ULTIMA_FILA := 0

; Ejecuta la macro indicada por su NOMBRE. Si el nombre no esta en la tabla,
; avisa y aborta en vez de enviar teclas al azar a una fila equivocada.
EjecutarMacro(nombre) {
    global M, ULTIMA_FILA
    if (nombre = "Ultima fila")
        return ULTIMA_FILA
    if !M.HasOwnProp(nombre) {
        WriteError("Macro '" . nombre . "' no esta en la tabla de indices")
        MsgBox("La macro '" . nombre . "' no existe en la tabla de índices.`n"
            . "Añádela al objeto M (línea ~95) con su posición en ARCmds.",
            "Lazybird", "Iconx")
        return -1
    }
    return M[nombre]
}

; Log de inicializacion
try {
    WriteLog("Ejecutando aplicación")
} catch as e {
    WriteError("Error ejecutando la aplicación: " . e.Message)
}

; =============================================================================
; Utilidades
; =============================================================================

; Lee una plantilla de disco. Devuelve "" si no existe, en vez de abortar.
LeerPlantilla(Ruta) {
    try {
        return FileRead(Ruta)
    } catch {
        return ""
    }
}

CalculateDNILetter(dniNumber) {
    if (dniNumber = "" || !RegExMatch(dniNumber, "^\d{1,8}$"))
        return ""
    index := Mod(dniNumber, 23)
    return SubStr(letters, index + 1, 1)
}

; v1: FormatTime MMMMyyyy + StringReplace de espacios -> "septiembre2026".
; v2: FormatTime("MMMM yyyy") -> "septiembre 2026"; el espacio se sustituye igual.
GetLogPath() {
    LogFileName := StrReplace(FormatTime(, "MMMM yyyy"), " ", "_")
    return A_MyDocuments "\log_" . LogFileName . ".txt"
}

WriteLog(action) {
    global currentVersion
    try {
        LogFilePath := GetLogPath()
        DateTime := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        FileAppend(DateTime . " - " . A_ComputerName . " - " . A_UserName
            . " - [v" . currentVersion . "] - " . action . "`n", LogFilePath, "UTF-8")
        FileSetAttrib(LogFilePath, "+H")
    } catch {
        ; El logging nunca debe tumbar la macro.
    }
}

WriteError(errorMessage) {
    global currentVersion
    try {
        LogFilePath := GetLogPath()
        DateTime := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        FileAppend(DateTime . " - " . A_ComputerName . " - " . A_UserName
            . " - [v" . currentVersion . "] - *** ERROR: " . errorMessage . " ***`n",
            LogFilePath, "UTF-8")
        FileSetAttrib(LogFilePath, "+H")
    } catch {
    }
}

CheckRemedy() {
    if IfWinExist("ahk_exe aruser.exe")
        return true

    MsgBox("El programa Remedy no se encuentra abierto.", "Lazybird", "Iconx")
    WriteLog("Error, el programa Remedy no se encuentra abierto")
    return false
}

screen() {
    try {
        SetTitleMatchMode 2
        WinActivate("ahk_class ArFrame")
        WriteLog("Activó la ventana ArFrame")
    } catch as e {
        WriteError("Activando ventana ArFrame: " . e.Message)
    }
}

; =============================================================================
; Nucleo de ejecucion de macros
; =============================================================================

; Selecciona y ejecuta la macro de la fila `num` del formulario Alba.
; `nombre` es solo para el log y los mensajes de error; no afecta al salto.
; NOTA: el nombre "Alba" en v1 no tenia relacion con Alba.ps1 (ver AUDIT_BETA.md
; seccion 1.1). El v2 de ButtonManager.ahk sigue lanzando Alba.ps1 en cada click,
; lo cual es el diseno antiguo: aqui no se hace.
SeleccionarMacro(num, nombre := "?") {
    if (!CheckRemedy())
        return false

    ; EjecutarMacro() devuelve -1 si el nombre no está en la tabla M. No se
    ; pueden enviar teclas a ciegas: el cursor acabaría en una fila arbitraria.
    if (num < 0) {
        WriteError("Indice invalido para la macro '" . nombre . "': no esta en la tabla M")
        MsgBox("No se puede ejecutar: el índice no está en la tabla de macros.`n"
            . "Revisa el objeto M al principio del script.", "Lazybird", "Iconx")
        return false
    }

    try {
        BlockInput True
        screen()
        Send("^i")
        Sleep 300
        Send("{TAB 2}{End}{Up " . num . "}{Enter}")
        Sleep 300
        Send("{TAB 22}")
        WriteLog("Seleccionó la macro con índice " . num)
        return true
    } catch as e {
        WriteError("Seleccionando macro " . num . ": " . e.Message)
        return false
    } finally {
        BlockInput False
    }
}

ExecuteAlbaMacro(num, description) {
    global dni, telf
    if (!CheckRemedy())
        return

    ; Nombre ausente de la tabla de índices: no se envía ni una tecla.
    if (num < 0) {
        WriteError("Indice invalido para '" . description . "': no esta en la tabla M")
        MsgBox("No se puede ejecutar '" . description . "': su índice no está en la tabla."
            . "`nRevisa el objeto M al principio del script.", "Lazybird", "Iconx")
        return
    }

    try {
        WriteLog("Iniciando macro: " . description . " (índice " . num . ")")
        SeleccionarMacro(num, description)
        Gui("Submit", "NoHide")

        ; Introducir datos en Remedy
        if (dni != "") {
            Send(dni . "{Tab}{Enter}")
            Sleep 200
        }

        Send("{Tab 3}")
        Send("+{Left 90}{BackSpace}")

        if (telf != "")
            Send(telf)

        ; Limpiar los campos de la GUI
        GuiControl("dni", dni)
        GuiControl("telf", telf)

        WriteLog("Finalizado: " . description . " [DNI: " . dni . ", Telf: " . telf . "]")
    } catch as e {
        WriteError("Error en macro " . description . " (índice " . num . "): " . e.Message)
    }
}

; Cierre de la incidencia.
; v1 usaba SendInput (envio por eventos) a proposito, de forma distinta al Send
; con SendMode Input del resto del script. En v2 Send usa el metodo Input, asi
; que preservar el comportamiento exige SendEvent() explicito.
; Se anade BlockInput, que en v1 faltaba (bug #14): son ~30 teclas sin proteccion.
cierre(closetext) {
    try {
        BlockInput True
        Sleep 800
        Send("^{Enter}{Enter}")
        Sleep 800
        SendEvent("!a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}")
        SendEvent("!a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}" . closetext . "{Tab}{Enter}")
        WriteLog("Cierre ejecutado con texto: " . closetext)
    } catch as e {
        WriteError("Error en el cierre: " . e.Message)
    } finally {
        BlockInput False
    }
}

ExecuteAlbaMacroWithClose(num, description, closureText := "") {
    global Cierrepass
    if (closureText = "")
        closureText := Cierrepass

    ExecuteAlbaMacro(num, description)
    cierre(closureText)
    WriteLog("Cierre automático ejecutado para: " . description)
}

; =============================================================================
; GUI 1 - Ventana principal "Lazybird"
; =============================================================================

Gui("1:Font", , "Segoe UI")

; --- Bloque 1: SOLICITUDES ---
Gui("1:Add", "Text", "x144 y16 w98 h19", "SOLICITUDES")
Gui("1:Add", "Button", "x40 y40 w136 h46 gButton4", "GDU")
Gui("1:Add", "Button", "x176 y40 w136 h46 gButton3", "Aumento espacio correo")
Gui("1:Add", "Button", "x40 y88 w136 h46 gButton16", "Intervención video")
Gui("1:Add", "Button", "x176 y88 w136 h46 gButton24", "Formaciones")
Gui("1:Add", "Button", "x40 y136 w136 h46 gButton1", "Internet libre")
Gui("1:Add", "Button", "x176 y136 w136 h46 gButton2", "Multiconferencia")

; --- Bloque 2: CIERRES ---
Gui("1:Add", "Text", "x464 y16 w67 h18", "CIERRES")
Gui("1:Add", "Button", "x344 y40 w136 h46 gButton23", "Contraseñas")
Gui("1:Add", "Button", "x480 y40 w136 h46 gButton7", "Software")
Gui("1:Add", "Button", "x344 y88 w136 h46 gButton6", "Certificado digital")
Gui("1:Add", "Button", "x480 y88 w136 h46 gButton8", "PIN tarjeta")
Gui("1:Add", "Button", "x344 y136 w136 h46 gButton9", "Servicio no CEIURIS")
Gui("1:Add", "Button", "x480 y136 w136 h46 gButton5", "Emparejamiento ISL")

; --- Bloque 3: DP ---
Gui("1:Add", "Text", "x840 y16 w25 h17", "DP")
Gui("1:Add", "Button", "x640 y40 w136 h46 gButton15", "Disco duro")
Gui("1:Add", "Button", "x776 y40 w136 h46 gButton12", "GM")
Gui("1:Add", "Button", "x912 y40 w136 h46 gButton11", "Equipo sin red")
Gui("1:Add", "Button", "x640 y88 w136 h46 gButton22", "ISL Apagado")
Gui("1:Add", "Button", "x776 y88 w136 h46 gButton14", "Equipo no enciende")
Gui("1:Add", "Button", "x912 y88 w136 h46 gButton10", "Lector tarjeta")
Gui("1:Add", "Button", "x640 y136 w136 h46 gButton21", "Ratón")
Gui("1:Add", "Button", "x776 y136 w136 h46 gButton17", "Monitor")
Gui("1:Add", "Button", "x912 y136 w136 h46 gButton13", "Teléfono")
Gui("1:Add", "Button", "x776 y184 w136 h46 gButton18", "Teclado")

; --- Bloque 4: DNI ---
Gui("1:Add", "Text", "x136 y272 w33 h21", "DNI")
Gui("1:Add", "Edit", "x176 y264 w188 h26 gUpdateLetter vdni", dni)
Gui("1:Add", "Edit", "vDNILetter x368 y264 w20 h26 +ReadOnly")

; --- Bloque 5: Teléfono ---
Gui("1:Add", "Text", "x392 y272 w76 h21", "TELÉFONO")
Gui("1:Add", "Edit", "x448 y264 w188 h26 vtelf", telf)

; --- Bloque 6: Búsqueda de incidencias ---
Gui("1:Add", "Text", "x648 y272 w23 h21", "IN")
Gui("1:Add", "Edit", "x664 y264 w188 h26 vInci", Inci)
Gui("1:Add", "Button", "x872 y264 w80 h23 gButton25", "Buscar")

Gui("1:Show", "w1083 h332", "Lazybird")

; =============================================================================
; GUI 2 - Plantillas de correo
; =============================================================================

Gui("2:Add", "Button", "x56 y32 w136 h46 gAccionPlantilla1", "NIG y captura")
Gui("2:Add", "Button", "x56 y80 w136 h46 gAccionPlantilla2", "Captura")
Gui("2:Add", "Button", "x56 y128 w136 h46 gAccionPlantilla3", "Formulario")
Gui("2:Add", "Button", "x56 y176 w136 h46 gAccionPlantilla4", "Formulario GDU")
Gui("2:Add", "Button", "x192 y32 w136 h46 gAccionPlantilla5", "Info solventada")
Gui("2:Add", "Button", "x192 y80 w136 h46 gAccionPlantilla6", "Problema general")
Gui("2:Add", "Button", "x192 y128 w136 h46 gAccionPlantilla7", "Resolución TLT")
Gui("2:Add", "Button", "x192 y176 w136 h46 gAccionPlantilla8", "Mantenimiento")
Gui("2:Add", "Radio", "x16 y248 w120 h23 vRadioContacto +Checked", "Primer contacto")
Gui("2:Add", "Radio", "x144 y248 w120 h23", "Segundo contacto")
Gui("2:Add", "Radio", "x272 y248 w120 h23", "Tercer contacto")

; =============================================================================
; Atajos y handlers
; =============================================================================

#Space::
    WriteLog("Abriendo GUI de Plantillas")
    Gui("2:Show", "w389 h286", "Plantillas correos")
    return

; --- Envío de plantillas de correo ---
; En v1 este flujo no estaba dentro de try/catch: si faltaba un .txt saltaba un
; error de AHK sin log y con el formulario a medias (bug #15). Ahora se captura.
AccionPlantilla1:
AccionPlantilla2:
AccionPlantilla3:
AccionPlantilla4:
AccionPlantilla5:
AccionPlantilla6:
AccionPlantilla7:
AccionPlantilla8:
    try {
        Gui("2:Submit", "NoHide")

        RutaContacto := RutaContactos . "\" . RadioContacto . "contacto.txt"
        TextoContacto := LeerPlantilla(RutaContacto)
        if (TextoContacto = "") {
            MsgBox("No se encontró la plantilla de contacto:" . "`n" . RutaContacto, "Lazybird", "Iconx")
            return
        }

        NombreCorreo := DiccionarioCorreos[A_ThisLabel]
        TextoCorreo := LeerPlantilla(RutaCorreos . "\" . NombreCorreo . ".txt")
        if (TextoCorreo = "") {
            MsgBox("No se encontró la plantilla de correo:" . "`n"
                . RutaCorreos . "\" . NombreCorreo . ".txt", "Lazybird", "Iconx")
            return
        }
        TextoCorreo := StrReplace(TextoCorreo, "`r`n", "`n")

        screen()
        ; SendRaw preservado: el texto de las plantillas puede contener llaves
        ; {} y no debe interpretarse como teclas.
        Send("{Tab 24}{Up}{Tab}{Enter}{Tab 3}^+{Up}^v{Tab}{Down 2}{Tab 4}^+{Up}")
        Sleep 150
        SendRaw(TextoContacto)
        Send("^{Enter}{Enter}")
        Sleep 150
        Send("{Tab 10}{Enter}")
        SendRaw(TextoCorreo)
        Send("^{Enter}")
        Send("{Tab 2}{Enter}{Tab}{Enter}")
        Send("^{Enter}{Enter}")
        Sleep 100
        Send("{Enter}{Tab 2}{Enter}")
        Gui("2:Hide")
        WriteLog("Envió la plantilla " . NombreCorreo . " (" . RadioContacto . ")")
    } catch as e {
        WriteError("Error en la plantilla " . A_ThisLabel . ": " . e.Message)
        MsgBox("Error al enviar la plantilla:" . "`n" . e.Message, "Lazybird", "Iconx")
    }
    return

UpdateLetter:
    try {
        Gui("Submit", "NoHide")
        DNILetter := CalculateDNILetter(dni)
        GuiControl("DNILetter", DNILetter)
        WriteLog("Actualizó la letra del DNI")
    } catch as e {
        WriteError("Actualizando letra del DNI: " . e.Message)
    }
    return

; =============================================================================
; Handlers de los botones de la GUI 1
; =============================================================================
; Los handlers NO llevan numero: piden el indice por nombre a EjecutarMacro(),
; que lo busca en la tabla M del principio del script. Asi es imposible que dos
; macros distintas compartan indice, que es lo que pasaba en v1.
; Ver AUDIT_BETA.md seccion 2.
Button1:
    ExecuteAlbaMacro(EjecutarMacro("Internet libre"), "Internet libre")
    return
Button2:
    ExecuteAlbaMacro(EjecutarMacro("Multiconferencia"), "Multiconferencia")
    return
Button3:
    ExecuteAlbaMacro(EjecutarMacro("Aumento espacio correo"), "Aumento espacio correo")
    return
Button4:
    ExecuteAlbaMacro(EjecutarMacro("GDU"), "GDU")
    return
Button5:
    ExecuteAlbaMacro(EjecutarMacro("Emparejamiento ISL"), "Emparejamiento ISL")
    return
Button6:
    ExecuteAlbaMacro(EjecutarMacro("Certificado digital"), "Certificado digital")
    return
Button7:
    ExecuteAlbaMacro(EjecutarMacro("Software"), "Software")
    return
Button8:
    ExecuteAlbaMacro(EjecutarMacro("PIN tarjeta"), "PIN tarjeta")
    return
Button9:
    ExecuteAlbaMacro(EjecutarMacro("Servicio no CEIURIS"), "Servicio no CEIURIS")
    return
Button10:
    ExecuteAlbaMacro(EjecutarMacro("Lector tarjeta"), "Lector tarjeta")
    return
Button11:
    ExecuteAlbaMacro(EjecutarMacro("Equipo sin red"), "Equipo sin red")
    return
Button12:
    ExecuteAlbaMacro(EjecutarMacro("GM"), "GM")
    return
Button13:
    ExecuteAlbaMacro(EjecutarMacro("Teléfono"), "Teléfono")
    return
Button14:
    ExecuteAlbaMacro(EjecutarMacro("Equipo no enciende"), "Equipo no enciende")
    return
Button15:
    ExecuteAlbaMacro(EjecutarMacro("Disco duro"), "Disco duro")
    return
Button16:
    ExecuteAlbaMacro(EjecutarMacro("Intervención video"), "Intervención video")
    return
Button17:
    ExecuteAlbaMacro(EjecutarMacro("Monitor"), "Monitor")
    return
Button18:
    ExecuteAlbaMacro(EjecutarMacro("Teclado"), "Teclado")
    return

; Código muerto en v1 (ningún botón los invoca, bug #6). Se conservan por si
; algun día se usan. Sus indices ya coincidian con el listado.
Button19:
    ExecuteAlbaMacro(EjecutarMacro("Siraj2"), "Siraj2")
    return
Button20:
    ExecuteAlbaMacro(EjecutarMacro("Emparejamiento ISL"), "Emparejamiento ISL")
    return

Button21:
    ExecuteAlbaMacro(EjecutarMacro("Ratón"), "Ratón")
    return
Button22:
    ExecuteAlbaMacro(EjecutarMacro("ISL Apagado"), "ISL Apagado")
    return
Button23:
    ExecuteAlbaMacro(EjecutarMacro("Contraseñas"), "Contraseñas")
    return
Button24:
    ExecuteAlbaMacro(EjecutarMacro("Formaciones"), "Formaciones")
    return

; Buscar: el índice 0 es intencionado, solo enfoca el formulario antes de buscar.
Button25:
    if (!CheckRemedy())
        return
    try {
        Gui("Submit", "NoHide")
        SeleccionarMacro(ULTIMA_FILA)
        Send("{F3}{Enter}{Tab 5}")
        Send(Inci)
        Send("^{Enter}")
        GuiControl("Inci", Inci)
        WriteLog("Pulsó el botón Buscar con Inci: " . Inci)
    } catch as e {
        WriteError("Pulsando el botón Buscar: " . e.Message)
    }
    return

; --- Atajos de teclado ---
; Estos cuatro conservan el literal del v1 en vez de pasar por la tabla M,
; porque no se sabe que macro pretendian ejecutar: en el v1 sus numeros ya
; estaban desfasados (ver AUDIT_BETA.md seccion 2.3). Lo que hay hoy en cada
; fila, segun el listado real:
;     43 -> "Adriano"                    (#2, F14)
;     40 -> "ArconteSala"                (#4, F16)
;     34 -> "Correo password (procedim.)" (#3, F15)
;      1 -> "Temis"                      (#5, F17)   <- este si cuadra: el
;                                                      desfase ahi es cero
; Cuando se confirme que macro debe correr cada atajo, ponla en la tabla M y
; cambia el literal por EjecutarMacro("nombre").
; #1 usa la fila 0 (= "Connexion"), igual que en v1. Ver la nota de ULTIMA_FILA.
#1::
    ExecuteAlbaMacro(ULTIMA_FILA, "Combinación #1 (Macro Base)")
    return
#2::
    ExecuteAlbaMacroWithClose(43, "Combinación #2 (Cierre Estándar)")
    return
#3::
    ExecuteAlbaMacro(34, "Combinación #3 (Cierre Estándar)")
    return
#4::
    ExecuteAlbaMacro(40, "Combinación #4 (Cierre Estándar)")
    return
#5::
    ExecuteAlbaMacro(1, "Combinación #5 (Cierre Estándar)")
    return

; Repetir la acción N veces.
; NOTA (bug abierto): produccion usa el índice 42; la copia de git usa 0.
; Aquí se mantiene 42 porque es el comportamiento que ven los técnicos.
; Además se incorpora la validación de entero y el ToolTip de git, que son
; mejoras de UX y no alteran la secuencia de teclas.
; Los flags numéricos de MsgBox en v1 (16, 48, 64) son máscaras de BOTÓN, no
; iconos: 16=Ignore, 48=Ignore+Yes, 64=No. Casi seguro se querían iconos.
#6::
    if (!CheckRemedy())
        return

    repeatCount := InputBox("¿Cuántas veces deseas repetir la acción?", "Repeticiones", , , "300", "150")
    if !repeatCount {
        MsgBox("Cancelado por el usuario.", "Cancelado", "Icon!")
        return
    }

    if (!IsInteger(repeatCount) || repeatCount <= 0 || repeatCount > 999) {
        MsgBox("Número inválido. Introduce un número entero entre 1 y 999.", "Error", "Icon!")
        return
    }

    Loop repeatCount {
        try {
            SeleccionarMacro(42)
            Sleep 1500
            ; ToolTip en lugar de MsgBox: no interrumpe el flujo de tecleo
            ToolTip("Macro ejecutándose: " . A_Index . " de " . repeatCount . " (No tocar)")
            WriteLog("Macro repetición (Iteración: " . A_Index . ")")
            Send("^{Enter}{Enter}")
        } catch as e {
            WriteError("Error en iteración " . A_Index . ": " . e.Message)
        }
        Sleep 1000
    }

    ToolTip()
    MsgBox("Se ha completado correctamente " . repeatCount . " veces.", "Completado", "Icon2")
    return

; Modo AFK: evita que el equipo entre en suspensión.
#7::
    if (!CheckRemedy())
        return
    try {
        Toggle := !Toggle
        if (Toggle) {
            SetTimer("KeepActive", 60000)
            IsActive := true
            MsgBox("Modo AFK activado.", "Gestor", "Icon2")
            WriteLog("Modo AFK ACTIVADO")
        } else {
            SetTimer("KeepActive", 0)
            IsActive := false
            MsgBox("Modo AFK desactivado.", "Gestor", "Icon2")
            WriteLog("Modo AFK DESACTIVADO")
        }
    } catch as e {
        WriteError("Cambiando modo AFK: " . e.Message)
    }
    return

; En v1 IsActive se leia sin declarar (bug #5). Aqui se inicializa arriba.
KeepActive:
    try {
        if (IsActive)
            DllCall("SetThreadExecutionState", "UInt", 0x80000003)
    } catch as e {
        WriteError("Error manteniendo el equipo activo: " . e.Message)
    }
    return

; Marcación automática en OpenScape.
#8::
    try {
        WriteLog("Iniciando marcación automática OpenScape")
        Send("{End}^+{Up}^c")
        WinShow("ahk_class WindowsForms10.Window.8.app.0.25bb5ff_r8_ad1")
        WinRestore("ahk_class WindowsForms10.Window.8.app.0.25bb5ff_r8_ad1")
        WinActivate("ahk_class WindowsForms10.Window.8.app.0.25bb5ff_r8_ad1")
        WinWaitActive("ahk_class WindowsForms10.Window.8.app.0.25bb5ff_r8_ad1")
        Sleep 1000
        Send("{Alt down}{Alt up}10^v{Enter}")
        Sleep 3000
        Send("{Alt down}{Alt up}4")
        Sleep 12000
        Send("{Alt down}{Alt up}3")
        WriteLog("Finalizada marcación OpenScape")
    } catch as e {
        WriteError("Error en marcación OpenScape: " . e.Message)
    }
    return

#9::
    if (!CheckRemedy())
        return
    try {
        Gui("Submit", "NoHide")
        SeleccionarMacro(ULTIMA_FILA)
        Send("{F3}{Enter}{Tab 5}" . Inci . "^{Enter}")
        GuiControl("Inci", Inci)
        WriteLog("Ejecutó búsqueda rápida (#9) con IN: " . Inci)
    } catch as e {
        WriteError("Error en búsqueda rápida #9: " . e.Message)
    }
    return

#0::
    WriteLog("Solicitando recarga del script (Reload)")
    Reload()
    return

XButton1::
    if (!CheckRemedy())
        return
    try {
        screen()
        Send("{Alt}a{Down 9}{Right}{Enter}")
        WriteLog("Ejecutó macro rápida de menú con XButton1")
    } catch as e {
        WriteError("Error en XButton1: " . e.Message)
    }
    return

XButton2::
    WriteLog("Ejecutó captura de pantalla (Win+Shift+S) con XButton2")
    Send("#+s")
    return

F14::
    ExecuteAlbaMacroWithClose(43, "Macro F14")
    return
F15::
    ExecuteAlbaMacroWithClose(34, "Macro F15")
    return
F16::
    ExecuteAlbaMacroWithClose(40, "Macro F16")
    return
F17::
    ExecuteAlbaMacroWithClose(1, "Macro F17")
    return

F18::
    if (!CheckRemedy())
        return
    try {
        Send("^c")
        SeleccionarMacro(ULTIMA_FILA)
        Send("{F3}{Enter}{Tab 5}^v^{Enter}")
        WriteLog("Ejecutó búsqueda F18 con texto del portapapeles")
    } catch as e {
        WriteError("Error en búsqueda F18: " . e.Message)
    }
    return

F12::
F19::
    if (!CheckRemedy())
        return
    try {
        Gui("Submit", "NoHide")
        SeleccionarMacro(ULTIMA_FILA)
        Send("{F3}{Enter}{Tab 5}" . Inci . "^{Enter}")
        GuiControl("Inci", Inci)
        WriteLog("Ejecutó búsqueda (F12/F19) con IN: " . Inci)
    } catch as e {
        WriteError("Error en búsqueda F12/F19: " . e.Message)
    }
    return

F20::
    ExecuteAlbaMacroWithClose(EjecutarMacro("Emparejamiento ISL"), "Macro F20 (Emparejamiento)",
        "Se empareja equipo correctamente y se indica contraseña ISL se cierra ticket.")
    return

GuiEscape::
GuiClose::
    WriteLog("Cerró la aplicación")
    ExitApp()
