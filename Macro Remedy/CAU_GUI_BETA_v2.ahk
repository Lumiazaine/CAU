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
;
; NOTA SOBRE LOS "catch as excepcionN": los 17 catch tienen NOMBRES DISTINTOS a
; proposito. Con todos ellos llamados "err" (que es lo que hacia el v1), v2
; avisa 17 veces "This local variable has the same name as a global variable":
; para el motor, 17 locales con el mismo nombre se pisan entre si, y el aviso es
; MODAL, con lo que la macro arranca y se queda parada. Comprobado en Wine con
; AHK v2.0.28. El numero permite seguir el catch en el log de WriteError.
; =============================================================================

#SingleInstance Force
; #NoEnv no se traslada: la directiva se elimino en v2, donde las variables de
; entorno nunca se cargan como globales (hay que usar EnvGet, o los prefijos
; $Env / _Env). Dejarla puesta hace que v2 rechace el script entero con
; "This line does not contain a recognized action" y la macro no arranca.
; #MaxHotkeysPerInterval y #HotkeyInterval tambien eran directivas de v1: en v2
; son variables incorporadas (A_*) que se asignan. Van mas abajo, con el resto
; de ajustes, porque una asignacion no puede ir en la zona de directivas.
; #Persistent no existe en v2: los scripts son persistentes por defecto.

; --- Ajustes de rendimiento (identicos a v1) ---
; #MaxHotkeysPerInterval y #HotkeyInterval eran directivas de v1; en v2 son
; variables incorporadas (A_*) que se asignan, y por eso van aqui y no en la
; zona de directivas de arriba.
; Valores absurdos a proposito: la macro dispara decenas de hotkeys seguidas al
; technician y cualquier umbral reasonable haria saltar el aviso de "demasiados
; hotkeys". En v1 esto se hacia con directivas; en v2 se hace asi.
A_MaxHotkeysPerInterval := 99000000
A_HotkeyInterval := 99000000

; #KeyHistory 0 (v1) -> KeyHistory 0 (v2): la directiva paso a ser la llamada a
; la funcion, que toma el maximo de eventos. El 0 desactiva el historial igual
; que en v1 (en v2 el valor por defecto es 40).
KeyHistory(0)

; OJO: todo este bloque necesita parentesis. Es la diferencia entre la sintaxis
; de comando de v1 (SetBatchLines "-1") y la llamada a funcion de v2
; (SetBatchLines("-1")). Sin ellos, v2 no ve una llamada, ve una variable global
; sin usar, y saca el aviso "This global variable appears to never be assigned
; a value", que en un script sin compilar sale en un dialogo modal y deja la
; macro PARADA esperando a que alguien pulse Aceptar.
DetectHiddenWindows(True)
ListLines(False)
ProcessSetPriority("A")
; SetBatchLines se ha ELIMINADO en v2: los scripts ya se ejecutan a velocidad
; maxima por defecto, que es justo lo que hacia SetBatchLines "-1" en v1.
; Dejar la llamada puesta hace que v2 la trate como una variable global sin
; usar y saque el aviso "This global variable appears to never be assigned a
; value". Ese aviso, en un script sin compilar, es un dialogo MODAL: la macro
; arranca y se queda parada esperando a que alguien pulse Aceptar.
SetKeyDelay(-1, -1)
SetMouseDelay(-1)
SetDefaultMouseSpeed(0)
SetWinDelay(-1)
SetControlDelay(-1)
SendMode("Input")        ; metodo Input: NO cambiar a Event sin rehacer el analisis
; v1 pasaba un "Int*" de salida a MyCurrentTimerResolution. Esa variable no se
; usaba en ninguna parte del script (ni v1 ni aqui), asi que solo servia para
; disparar el aviso de "variable global sin asignar", que en v2 es un dialogo
; modal que deja la macro parada. La llamada se conserva porque lo que importa
; es el efecto: subir la resolucion del temporizador del sistema para que los
; Send() con SetKeyDelay -1 no pierdan pulsaciones. El codigo de retorno es
; STATUS_SUCCESS (0) en exito, que no hacia falta guardar.
if (!DllCall("ntdll\ZwSetTimerResolution", "UInt", 5000, "Int", 1))
    WriteError("No se pudo subir la resolución del temporizador (ZwSetTimerResolution)")
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
; Es un Map(), no un objeto plano. En v2 un objeto plano NO admite acceso por
; indice: escribir Mapa["clave"] da en tiempo de ejecucion
;   "This value of type Object has no property named __Item"
; y el script se para. Map() es la estructura de diccionario de v2 y ademas
; trae .Has(clave) para preguntar por una clave sin disparar el error.
; Las claves de este si podrian ser identificadores ("AccionPlantilla1"), pero
; la tabla M de abajo no, asi que los dos usan la misma forma.
DiccionarioCorreos := Map(
    "AccionPlantilla1", "NIG_captura",
    "AccionPlantilla2", "Captura",
    "AccionPlantilla3", "Formulario",
    "AccionPlantilla4", "Formulario_GDU",
    "AccionPlantilla5", "Info_solventada",
    "AccionPlantilla6", "Problema_General",
    "AccionPlantilla7", "Resolucion_tlt",
    "AccionPlantilla8", "Mantenimiento",
)

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

; M es un Map(), no un objeto plano. En v2 un objeto plano NO admite acceso por
; indice: "M["nombre"]" da en ejecucion
;   "This value of type Object has no property named __Item"
; y el script se para al arrancar. Map() es el diccionario de v2.
;
; Por que 46 lineas y no un literal: las claves de un literal de objeto en v2
; tienen que ser identificadores desnudos (GDU: 24). Las entrecomilladas
; ("GDU": 24) son de v1 y v2 las rechaza con "Invalid property name in object
; literal". Casi todos los nombres de macro tienen espacios, acentos o
; parentesis, asi que la tabla no se puede escribir como literal.
;
; El ORDEN de estas lineas es el orden alfabetico del listado de ARCmds, que es
; como los presenta el formulario Alba. El numero de la derecha NO es un id: es
; la distancia desde el final de la lista (n = 45 - posicion). Ver seccion 2 de
; AUDIT_BETA.md.
M := Map()
M["Abbypdf"] := 45
M["Adpas"] := 44
M["Adriano"] := 43
M["Agenda de señalamientos"] := 42
M["Arconte password"] := 41
M["ArconteSala"] := 40
M["Aumento espacio correo"] := 39
M["Certificado digital"] := 38
M["Error relación de confianza"] := 37
M["Contraseñas"] := 36
M["Correo password (micuenta)"] := 35
M["Correo password (procedimiento)"] := 34
M["Disco duro"] := 33
M["Dragon Speaking"] := 32
M["Edoc"] := 31
M["Emparejamiento ISL"] := 30
M["Escritorio judicial"] := 29
M["Expediente digital"] := 28
M["Formaciones"] := 27
M["Equipo no enciende"] := 26
M["Ganes"] := 25
M["GDU"] := 24
M["GM"] := 23
M["Hermes"] := 22
M["Internet libre"] := 21
M["Intervención video"] := 20
M["ISL Apagado"] := 19
M["Jara"] := 18
M["Lector tarjeta"] := 17
M["Lexnet"] := 16
M["Monitor"] := 15
M["Multiconferencia"] := 14
M["@Driano"] := 13
M["Orfila"] := 12
M["PIN tarjeta"] := 11
M["Servicio no CEIURIS"] := 10
M["PortafirmasNG"] := 9
M["Ratón"] := 8
M["Equipo sin red"] := 7
M["Siraj2"] := 6
M["Software"] := 5
M["Suministros"] := 4
M["Teclado"] := 3
M["Teléfono"] := 2
M["Temis"] := 1
M["Connexion"] := 0

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
    ; .Has() y no .HasOwnProp(): M es un Map(), y Map no tiene HasOwnProp.
    ; Ademas .Has() no crea la clave, que es justo lo que se quiere: preguntar
    ; por una macro inexistente no debe modificar la tabla.
    if !M.Has(nombre) {
        WriteError("Macro '" . nombre . "' no esta en la tabla de indices")
        MsgBox("La macro '" . nombre . "' no existe en la tabla de índices.`n"
            . "Añádela al objeto M (línea ~95) con su posición en ARCmds.",
            "Lazybird", "Iconx")
        return -1
    }
    return M[nombre]
}

; Log de inicializacion.
; Va en una funcion, y no suelto en la seccion auto-ejecucion, por dos razones
; de v2:
;   - la seccion auto-ejecucion termina en cuanto aparece una funcion, asi que
;     el codigo que hay despues no se ejecuta salvo que se llame explicitamente.
;     Por eso la llamada esta junto a guiMain.Show(), no aqui.
;   - un "catch as X" a ese nivel crea una GLOBAL "excepcion1", que luego
;     choca con la local de cualquier otro sitio que use el mismo nombre.
logInicio() {
    try {
        WriteLog("Ejecutando aplicación")
    } catch as excepcion1 {
        WriteError("Error ejecutando la aplicación: " . excepcion1.Message)
    }
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
    ; IfWinExist era una FUNCION en v1. En v2 no existe: la sustituye
    ; WinExist(), que devuelve el HWND (0 si no la encuentra) y sirve igual en un
    ; if. Dejar IfWinExist puesto hace que v2 la trate como una variable y avise.
    if WinExist("ahk_exe aruser.exe")
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
    } catch as excepcion2 {
        WriteError("Activando ventana ArFrame: " . excepcion2.Message)
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
    } catch as excepcion3 {
        WriteError("Seleccionando macro " . num . ": " . excepcion3.Message)
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
        leerCampos()

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
        dni := ""
        telf := ""
        ctlDni.Text := ""
        ctlTelf.Text := ""

        WriteLog("Finalizado: " . description . " [DNI: " . dni . ", Telf: " . telf . "]")
    } catch as excepcion4 {
        WriteError("Error en macro " . description . " (índice " . num . "): " . excepcion4.Message)
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
    } catch as excepcion5 {
        WriteError("Error en el cierre: " . excepcion5.Message)
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
; En v1 las dos ventanas se numeraban ("Gui, 1:" y "Gui, 2:"). En v2 no existe
; esa numeracion: cada ventana es un objeto Gui. La traduccion mecanica
; Gui("1:Add", ...) COMPILA pero revienta en la primera llamada ("Too many
; parameters passed to function"), asi que no se podia dejar como estaba.
; Lo mismo con la opcion gButtonN: no existe en v2 y los botones quedarian
; muertos sin OnEvent. Ver AUDIT_BETA.md seccion 8.
;
; Ojo con el orden: en v2 la seccion auto-ejecucion termina en cuanto aparece
; una funcion o un hotkey. Por eso Boton() y leerCampos() estan mas abajo, con
; el resto de funciones, y NO aqui.
guiMain := Gui()
guiPlantillas := Gui()

; v1 era "Gui, 1:Font,, Segoe UI". El metodo se llama SetFont, no Font, y el
; primer parametro son las OPCIONES (s14, cRed, ...), no el nombre de la fuente:
; SetFont("Segoe UI") falla con "Invalid option". Con el hueco delante se deja
; vacio, que es el equivalente de los dos comas del v1.
guiMain.SetFont(, "Segoe UI")

; --- Bloque 1: SOLICITUDES ---
guiMain.Add("Text", "x144 y16 w98 h19", "SOLICITUDES")
Boton(guiMain, Button4, "x40 y40 w136 h46", "GDU")
Boton(guiMain, Button3, "x176 y40 w136 h46", "Aumento espacio correo")
Boton(guiMain, Button16, "x40 y88 w136 h46", "Intervención video")
Boton(guiMain, Button24, "x176 y88 w136 h46", "Formaciones")
Boton(guiMain, Button1, "x40 y136 w136 h46", "Internet libre")
Boton(guiMain, Button2, "x176 y136 w136 h46", "Multiconferencia")

; --- Bloque 2: CIERRES ---
guiMain.Add("Text", "x464 y16 w67 h18", "CIERRES")
Boton(guiMain, Button23, "x344 y40 w136 h46", "Contraseñas")
Boton(guiMain, Button7, "x480 y40 w136 h46", "Software")
Boton(guiMain, Button6, "x344 y88 w136 h46", "Certificado digital")
Boton(guiMain, Button8, "x480 y88 w136 h46", "PIN tarjeta")
Boton(guiMain, Button9, "x344 y136 w136 h46", "Servicio no CEIURIS")
Boton(guiMain, Button5, "x480 y136 w136 h46", "Emparejamiento ISL")

; --- Bloque 3: DP ---
guiMain.Add("Text", "x840 y16 w25 h17", "DP")
Boton(guiMain, Button15, "x640 y40 w136 h46", "Disco duro")
Boton(guiMain, Button12, "x776 y40 w136 h46", "GM")
Boton(guiMain, Button11, "x912 y40 w136 h46", "Equipo sin red")
Boton(guiMain, Button22, "x640 y88 w136 h46", "ISL Apagado")
Boton(guiMain, Button14, "x776 y88 w136 h46", "Equipo no enciende")
Boton(guiMain, Button10, "x912 y88 w136 h46", "Lector tarjeta")
Boton(guiMain, Button21, "x640 y136 w136 h46", "Ratón")
Boton(guiMain, Button17, "x776 y136 w136 h46", "Monitor")
Boton(guiMain, Button13, "x912 y136 w136 h46", "Teléfono")
Boton(guiMain, Button18, "x776 y184 w136 h46", "Teclado")

; --- Bloque 4: DNI ---
; Los cuatro Edit se guardan en variables: en v2 no existen las variables de
; control de v1, asi que hay que leer y escribir el control directamente.
guiMain.Add("Text", "x136 y272 w33 h21", "DNI")
ctlDni := guiMain.Add("Edit", "x176 y264 w188 h26", dni)
ctlDni.OnEvent("Change", UpdateLetter)
ctlDNILetter := guiMain.Add("Edit", "x368 y264 w20 h26 +ReadOnly", "")

; --- Bloque 5: Teléfono ---
guiMain.Add("Text", "x392 y272 w76 h21", "TELÉFONO")
ctlTelf := guiMain.Add("Edit", "x448 y264 w188 h26", telf)

; --- Bloque 6: Búsqueda de incidencias ---
guiMain.Add("Text", "x648 y272 w23 h21", "IN")
ctlInci := guiMain.Add("Edit", "x664 y264 w188 h26", Inci)
Boton(guiMain, Button25, "x872 y264 w80 h23", "Buscar")

; v1 cerraba la aplicacion con las etiquetas GuiEscape / GuiClose. En v2 eso son
; eventos de la ventana, no hotkeys (GuiEscape:: no es un hotkey valido), asi que
; se enganchan aqui. Solo a la ventana principal: en v2 no hay forma de
; replicar "una etiqueta para todas las ventanas" sin numeracion, y colgar la
; aplicacion al cerrar el formulario de plantillas no es lo que se quiere.
; Ver AUDIT_BETA.md seccion 7 (pregunta abierta para los tecnicos).
guiMain.OnEvent("Close", SalirApp)
guiMain.OnEvent("Escape", SalirApp)

; El log de arranque va aqui, no antes: logInicio() esta definida mas abajo, y
; llamarla antes de llegar a la seccion de funciones es lo que v2 no permite
; (la seccion auto-ejecucion termina en la primera definicion de funcion).
; El orden respecto a la ventana es el mismo que en v1: log y luego pintar.
logInicio()

; v1 era "Gui, 1:Show, w1083 h332, Lazybird". En v2 Show() SOLO acepta el tamano:
; el titulo va en la propiedad .Title. Ponerlo como segundo argumento da "Too
; many parameters passed to function".
guiMain.Title := "Lazybird"
guiMain.Show("w1083 h332")

; =============================================================================
; GUI 2 - Plantillas de correo
; =============================================================================

Boton(guiPlantillas, AccionPlantilla1, "x56 y32 w136 h46", "NIG y captura")
Boton(guiPlantillas, AccionPlantilla2, "x56 y80 w136 h46", "Captura")
Boton(guiPlantillas, AccionPlantilla3, "x56 y128 w136 h46", "Formulario")
Boton(guiPlantillas, AccionPlantilla4, "x56 y176 w136 h46", "Formulario GDU")
Boton(guiPlantillas, AccionPlantilla5, "x192 y32 w136 h46", "Info solventada")
Boton(guiPlantillas, AccionPlantilla6, "x192 y80 w136 h46", "Problema general")
Boton(guiPlantillas, AccionPlantilla7, "x192 y128 w136 h46", "Resolución TLT")
Boton(guiPlantillas, AccionPlantilla8, "x192 y176 w136 h46", "Mantenimiento")
; v1 agrupaba los tres Radio con vRadioContacto (solo el primero lleva el
; nombre). En v2 se lee .Value de cada uno.
ctlContacto1 := guiPlantillas.Add("Radio", "x16 y248 w120 h23 +Checked", "Primer contacto")
ctlContacto2 := guiPlantillas.Add("Radio", "x144 y248 w120 h23", "Segundo contacto")
ctlContacto3 := guiPlantillas.Add("Radio", "x272 y248 w120 h23", "Tercer contacto")

; =============================================================================
; Atajos y handlers
; =============================================================================

#Space::{
    WriteLog("Abriendo GUI de Plantillas")
    ; v1 era "Gui, 2:Show, w389 h286, Plantillas correos". El titulo va en .Title,
    ; no como segundo argumento de Show(). Ver la nota de guiMain.Show mas arriba.
    guiPlantillas.Title := "Plantillas correos"
    guiPlantillas.Show("w389 h286")
    return
}

; --- Envío de plantillas de correo ---
; En v1 las ocho AccionPlantillaN eran etiquetas apiladas que compartian cuerpo
; y se distinguian por A_ThisLabel. En v2 un manejador de OnEvent tiene que ser
; una funcion, asi que hay ocho funciones finitas que delegan en una comun.
; El nombre se pasa como cadena para poder seguir usando DiccionarioCorreos tal
; cual estaba (sus claves son "AccionPlantilla1".."AccionPlantilla8").
AccionPlantilla1(*) => plantillaEnviada("AccionPlantilla1")
AccionPlantilla2(*) => plantillaEnviada("AccionPlantilla2")
AccionPlantilla3(*) => plantillaEnviada("AccionPlantilla3")
AccionPlantilla4(*) => plantillaEnviada("AccionPlantilla4")
AccionPlantilla5(*) => plantillaEnviada("AccionPlantilla5")
AccionPlantilla6(*) => plantillaEnviada("AccionPlantilla6")
AccionPlantilla7(*) => plantillaEnviada("AccionPlantilla7")
AccionPlantilla8(*) => plantillaEnviada("AccionPlantilla8")

; En v1 este flujo no estaba dentro de try/catch: si faltaba un .txt saltaba un
; error de AHK sin log y con el formulario a medias (bug #15). Ahora se captura.
plantillaEnviada(nombre) {
    try {
        ; en v2 no hay variables de control: el Radio se lee con .Value
        RadioContacto := ctlContacto1.Value ? "1" : (ctlContacto2.Value ? "2" : "3")

        RutaContacto := RutaContactos . "\" . RadioContacto . "contacto.txt"
        TextoContacto := LeerPlantilla(RutaContacto)
        if (TextoContacto = "") {
            MsgBox("No se encontró la plantilla de contacto:" . "`n" . RutaContacto, "Lazybird", "Iconx")
            return
        }

        NombreCorreo := DiccionarioCorreos[nombre]
        TextoCorreo := LeerPlantilla(RutaCorreos . "\" . NombreCorreo . ".txt")
        if (TextoCorreo = "") {
            MsgBox("No se encontró la plantilla de correo:" . "`n"
                . RutaCorreos . "\" . NombreCorreo . ".txt", "Lazybird", "Iconx")
            return
        }
        TextoCorreo := StrReplace(TextoCorreo, "`r`n", "`n")

        screen()
        ; SendRaw no existe en v2: lo sustituye SendText(), que es su equivalente
        ; exacto (envia el texto literal, sin interpretar {} como teclas). Las
        ; plantillas contienen llaves y corchetes, asi que la diferencia se ve.
        ; OJO: NO cambiar SendText por Send, que interpretaria {Enter} y compañía.
        Send("{Tab 24}{Up}{Tab}{Enter}{Tab 3}^+{Up}^v{Tab}{Down 2}{Tab 4}^+{Up}")
        Sleep 150
        SendText(TextoContacto)
        Send("^{Enter}{Enter}")
        Sleep 150
        Send("{Tab 10}{Enter}")
        SendText(TextoCorreo)
        Send("^{Enter}")
        Send("{Tab 2}{Enter}{Tab}{Enter}")
        Send("^{Enter}{Enter}")
        Sleep 100
        Send("{Enter}{Tab 2}{Enter}")
        guiPlantillas.Hide()
        WriteLog("Envió la plantilla " . NombreCorreo . " (" . RadioContacto . ")")
    } catch as excepcion6 {
        WriteError("Error en la plantilla " . nombre . ": " . excepcion6.Message)
        MsgBox("Error al enviar la plantilla:" . "`n" . excepcion6.Message, "Lazybird", "Iconx")
    }
}

; --- Letra del DNI ---
; v1 la enganchaba con gUpdateLetter al Edit del DNI. En v2 es OnEvent("Change").
; OJO: este manejador estaba conectado en la construccion de la GUI y hay que
; mantenerlo en el mismo sitio, con la misma semantica (se recalcula en cada
; pulsacion, que es lo que hacia v1).
UpdateLetter(*) {
    global dni             ; sin global, se escribe una local y la global sigue vacia
    try {
        dni := ctlDni.Text
        DNILetter := CalculateDNILetter(dni)
        ctlDNILetter.Text := DNILetter
        WriteLog("Actualizó la letra del DNI")
    } catch as excepcion7 {
        WriteError("Actualizando letra del DNI: " . excepcion7.Message)
    }
}

; Cierre de la aplicacion. Sustituye a las etiquetas GuiEscape / GuiClose de v1,
; que en v2 no existen como hotkeys. Ver la nota de OnEvent mas arriba.
SalirApp(*) {
    WriteLog("Cerró la aplicación")
    ExitApp()
}

; Crea un boton y lo engancha a su manejador. En v1 era la opcion "gButtonN" de
; la cadena de opciones, que en v2 no existe: sin esto los 25 botones se
; dibujarian pero no harian nada al pulsarlos.
;
; La local NO se llama "boton". En v2 los nombres distinguen mayusculas, pero AHK
; sigue avisando "This local variable has the same name as a global variable"
; cuando una local coincide con el nombre de una funcion global, aunque solo
; cambien en las mayusculas: "boton" dentro de Boton() dispara el aviso. Y el
; aviso es MODAL, asi que la macro se queda parada al arrancar. Comprobado con un
; caso minimo de 4 lineas.
Boton(ventana, manejador, opciones, texto) {
    ctlBoton := ventana.Add("Button", opciones, texto)
    ctlBoton.OnEvent("Click", manejador)
    return ctlBoton
}

; Lee los tres campos editables. En v1 esto lo hacia "Gui, Submit, NoHide",
; que rellenaba las variables de control; en v2 no existen esas variables y
; Submit no hace nada por si solo, hay que leer cada control.
leerCampos() {
    global dni, telf, Inci
    dni := ctlDni.Text
    telf := ctlTelf.Text
    Inci := ctlInci.Text
}

; =============================================================================
; Handlers de los botones de la GUI 1
; =============================================================================
; Los handlers NO llevan numero: piden el indice por nombre a EjecutarMacro(),
; que lo busca en la tabla M del principio del script. Asi es imposible que dos
; macros distintas compartan indice, que es lo que pasaba en v1.
; Ver AUDIT_BETA.md seccion 2.
Button1(*) {
    ExecuteAlbaMacro(EjecutarMacro("Internet libre"), "Internet libre")
}
Button2(*) {
    ExecuteAlbaMacro(EjecutarMacro("Multiconferencia"), "Multiconferencia")
}
Button3(*) {
    ExecuteAlbaMacro(EjecutarMacro("Aumento espacio correo"), "Aumento espacio correo")
}
Button4(*) {
    ExecuteAlbaMacro(EjecutarMacro("GDU"), "GDU")
}
Button5(*) {
    ExecuteAlbaMacro(EjecutarMacro("Emparejamiento ISL"), "Emparejamiento ISL")
}
Button6(*) {
    ExecuteAlbaMacro(EjecutarMacro("Certificado digital"), "Certificado digital")
}
Button7(*) {
    ExecuteAlbaMacro(EjecutarMacro("Software"), "Software")
}
Button8(*) {
    ExecuteAlbaMacro(EjecutarMacro("PIN tarjeta"), "PIN tarjeta")
}
Button9(*) {
    ExecuteAlbaMacro(EjecutarMacro("Servicio no CEIURIS"), "Servicio no CEIURIS")
}
Button10(*) {
    ExecuteAlbaMacro(EjecutarMacro("Lector tarjeta"), "Lector tarjeta")
}
Button11(*) {
    ExecuteAlbaMacro(EjecutarMacro("Equipo sin red"), "Equipo sin red")
}
Button12(*) {
    ExecuteAlbaMacro(EjecutarMacro("GM"), "GM")
}
Button13(*) {
    ExecuteAlbaMacro(EjecutarMacro("Teléfono"), "Teléfono")
}
Button14(*) {
    ExecuteAlbaMacro(EjecutarMacro("Equipo no enciende"), "Equipo no enciende")
}
Button15(*) {
    ExecuteAlbaMacro(EjecutarMacro("Disco duro"), "Disco duro")
}
Button16(*) {
    ExecuteAlbaMacro(EjecutarMacro("Intervención video"), "Intervención video")
}
Button17(*) {
    ExecuteAlbaMacro(EjecutarMacro("Monitor"), "Monitor")
}
Button18(*) {
    ExecuteAlbaMacro(EjecutarMacro("Teclado"), "Teclado")
}

; Código muerto en v1 (ningún botón los invoca, bug #6). Se conservan por si
; algun día se usan. Sus indices ya coincidian con el listado.
Button19(*) {
    ExecuteAlbaMacro(EjecutarMacro("Siraj2"), "Siraj2")
}
Button20(*) {
    ExecuteAlbaMacro(EjecutarMacro("Emparejamiento ISL"), "Emparejamiento ISL")
}

Button21(*) {
    ExecuteAlbaMacro(EjecutarMacro("Ratón"), "Ratón")
}
Button22(*) {
    ExecuteAlbaMacro(EjecutarMacro("ISL Apagado"), "ISL Apagado")
}
Button23(*) {
    ExecuteAlbaMacro(EjecutarMacro("Contraseñas"), "Contraseñas")
}
Button24(*) {
    ExecuteAlbaMacro(EjecutarMacro("Formaciones"), "Formaciones")
}

; Buscar: el índice 0 es intencionado, solo enfoca el formulario antes de buscar.
; global Inci es obligatorio: sin el, v2 crea una variable LOCAL con ese nombre,
; distinta de la global que rellena leerCampos(), y la busqueda saldria siempre
; vacia sin dar ningun error.
Button25(*) {
    global Inci
    if (!CheckRemedy())
        return
    try {
        leerCampos()
        SeleccionarMacro(ULTIMA_FILA)
        Send("{F3}{Enter}{Tab 5}")
        Send(Inci)
        Send("^{Enter}")
        ctlInci.Text := ""
        WriteLog("Pulsó el botón Buscar con Inci: " . Inci)
    } catch as excepcion8 {
        WriteError("Pulsando el botón Buscar: " . excepcion8.Message)
    }
}

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
#1::{
    ExecuteAlbaMacro(ULTIMA_FILA, "Combinación #1 (Macro Base)")
    return
}

#2::{
    ExecuteAlbaMacroWithClose(43, "Combinación #2 (Cierre Estándar)")
    return
}

#3::{
    ExecuteAlbaMacro(34, "Combinación #3 (Cierre Estándar)")
    return
}

#4::{
    ExecuteAlbaMacro(40, "Combinación #4 (Cierre Estándar)")
    return
}

#5::{
    ExecuteAlbaMacro(1, "Combinación #5 (Cierre Estándar)")
    return
}

; Repetir la acción N veces.
; NOTA (bug abierto): produccion usa el índice 42; la copia de git usa 0.
; Aquí se mantiene 42 porque es el comportamiento que ven los técnicos.
; Además se incorpora la validación de entero y el ToolTip de git, que son
; mejoras de UX y no alteran la secuencia de teclas.
; Los flags numéricos de MsgBox en v1 (16, 48, 64) son máscaras de BOTÓN, no
; iconos: 16=Ignore, 48=Ignore+Yes, 64=No. Casi seguro se querían iconos.
#6::{
    if (!CheckRemedy())
        return

    ; InputBox cambia de DOS maneras en v2, y las dos importan:
    ;
    ; 1) Devuelve un OBJETO, no una cadena. El texto va en .Value y el motivo de
    ;    cierre en .Result ("OK" / "Cancel" / "Timeout"). En v1 era
    ;    "InputBox, salida" y el motivo se leia con ErrorLevel.
    ; 2) El ORDEN de parametros es otro. v1 era
    ;       InputBox, salida, Titulo, Prompt, Default, H, W
    ;    y v2 es
    ;       InputBox(Prompt, Title, Options, Default)
    ;    con el tamano dentro de Options como "w150 h300". La llamada de v1
    ;    (..., , 300, 150) era H=300 W=150, asi que aqui va "w150 h300".
    ;    Ademas v2 no admite huecos: en v1 los parametros vacios se dejaban en
    ;    blanco y aqui eso da "Too many parameters passed to function".
    ib := InputBox("¿Cuántas veces deseas repetir la acción?", "Repeticiones", "w150 h300")
    if (ib.Result != "OK") {
        MsgBox("Cancelado por el usuario.", "Cancelado", "Icon!")
        return
    }
    repeatCount := ib.Value

    ; v1 comparaba el texto crudo con un entero y aceptaba "3" con espacios.
    ; Trim() es el equivalente explicito; sin el, " 3 " pasaria a IsInteger()
    ; como falso y el tecnico veria "numero invalido" con un numero valido.
    repeatCount := Trim(repeatCount)

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
        } catch as excepcion9 {
            WriteError("Error en iteración " . A_Index . ": " . excepcion9.Message)
        }
        Sleep 1000
    }

    ToolTip()
    MsgBox("Se ha completado correctamente " . repeatCount . " veces.", "Completado", "Icon2")
    return
}

; Modo AFK: evita que el equipo entre en suspensión.
; global Toggle / IsActive es OBLIGATORIO. Sin el, v2 crea una LOCAL con ese
; nombre dentro del hotkey, que arranca vacia en cada pulsacion: Toggle valdria
; false, el "si" nunca se cumpliria y el modo AFK no se podria ni activar.
#7::{
    global Toggle, IsActive
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
    } catch as excepcion10 {
        WriteError("Cambiando modo AFK: " . excepcion10.Message)
    }
    return
}

; En v1 IsActive se leia sin declarar (bug #5). Aqui se inicializa arriba.
; OJO: esto es una ETIQUETA (destino de SetTimer), no un hotkey. Las etiquetas se
; declaran igual que en v1 y NO llevan llaves.
KeepActive:
    try {
        if (IsActive)
            DllCall("SetThreadExecutionState", "UInt", 0x80000003)
    } catch as excepcion11 {
        WriteError("Error manteniendo el equipo activo: " . excepcion11.Message)
    }
    return

; Marcación automática en OpenScape.
#8::{
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
    } catch as excepcion12 {
        WriteError("Error en marcación OpenScape: " . excepcion12.Message)
    }
    return
}

#9::{
    global Inci          ; sin global, v2 lee una local vacia (ver Button25)
    if (!CheckRemedy())
        return
    try {
        leerCampos()
        SeleccionarMacro(ULTIMA_FILA)
        Send("{F3}{Enter}{Tab 5}" . Inci . "^{Enter}")
        ctlInci.Text := ""
        WriteLog("Ejecutó búsqueda rápida (#9) con IN: " . Inci)
    } catch as excepcion13 {
        WriteError("Error en búsqueda rápida #9: " . excepcion13.Message)
    }
    return
}

#0::{
    WriteLog("Solicitando recarga del script (Reload)")
    Reload()
    return
}

XButton1::{
    if (!CheckRemedy())
        return
    try {
        screen()
        Send("{Alt}a{Down 9}{Right}{Enter}")
        WriteLog("Ejecutó macro rápida de menú con XButton1")
    } catch as excepcion14 {
        WriteError("Error en XButton1: " . excepcion14.Message)
    }
    return
}

XButton2::{
    WriteLog("Ejecutó captura de pantalla (Win+Shift+S) con XButton2")
    Send("#+s")
    return
}

F14::{
    ExecuteAlbaMacroWithClose(43, "Macro F14")
    return
}

F15::{
    ExecuteAlbaMacroWithClose(34, "Macro F15")
    return
}

F16::{
    ExecuteAlbaMacroWithClose(40, "Macro F16")
    return
}

F17::{
    ExecuteAlbaMacroWithClose(1, "Macro F17")
    return
}

F18::{
    if (!CheckRemedy())
        return
    try {
        Send("^c")
        SeleccionarMacro(ULTIMA_FILA)
        Send("{F3}{Enter}{Tab 5}^v^{Enter}")
        WriteLog("Ejecutó búsqueda F18 con texto del portapapeles")
    } catch as excepcion15 {
        WriteError("Error en búsqueda F18: " . excepcion15.Message)
    }
    return
}

; F12 y F19 comparten cuerpo, como en v1. En v2 NO se pueden apilar con llaves
; ("F12::F19::{" es un hotkey invalido), asi que van por separado con el mismo
; cuerpo. El texto del log se deja igual para no cambiar lo que ve el técnico.
F12::{
    global Inci          ; sin global, v2 lee una local vacia (ver Button25)
    if (!CheckRemedy())
        return
    try {
        leerCampos()
        SeleccionarMacro(ULTIMA_FILA)
        Send("{F3}{Enter}{Tab 5}" . Inci . "^{Enter}")
        ctlInci.Text := ""
        WriteLog("Ejecutó búsqueda (F12/F19) con IN: " . Inci)
    } catch as excepcion16 {
        WriteError("Error en búsqueda F12/F19: " . excepcion16.Message)
    }
    return
}

F19::{
    global Inci          ; sin global, v2 lee una local vacia (ver Button25)
    if (!CheckRemedy())
        return
    try {
        leerCampos()
        SeleccionarMacro(ULTIMA_FILA)
        Send("{F3}{Enter}{Tab 5}" . Inci . "^{Enter}")
        ctlInci.Text := ""
        WriteLog("Ejecutó búsqueda (F12/F19) con IN: " . Inci)
    } catch as excepcion17 {
        WriteError("Error en búsqueda F12/F19: " . excepcion17.Message)
    }
    return
}

F20::{
    ExecuteAlbaMacroWithClose(EjecutarMacro("Emparejamiento ISL"), "Macro F20 (Emparejamiento)",
        "Se empareja equipo correctamente y se indica contraseña ISL se cierra ticket.")
    return
}

; GuiEscape / GuiClose ya no estan aqui: eran etiquetas, no hotkeys, y en v2 no
; existen. Se han resuelto con guiMain.OnEvent("Escape"/"Close", SalirApp), mas
; arriba, al construir la ventana. SalirApp() es la funcion que hace el ExitApp.
