#SingleInstance Force
#NoEnv
#MaxHotkeysPerInterval 99000000
#HotkeyInterval 99000000
#KeyHistory 0
#Persistent
ListLines Off
Process, Priority,, A
SetBatchLines, -1
SetKeyDelay, -1, -1
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
SetWinDelay, -1
SetControlDelay, -1
SendMode Input
DllCall("ntdll\ZwSetTimerResolution", "Int", 5000, "Int", 1, "Int*", MyCurrentTimerResolution)
SetWorkingDir, %A_ScriptDir%

; Variables globales
global dni
global telf
global Inci
global DNILetter
global buttons
global IsActive
global Toggle

; Inicializar variables globales
dni =
telf =
Inci =
DNILetter =
buttons =
IsActive = 0
Toggle = 0

; =============================================================================
; CONFIGURACIÓN GLOBAL Y CONSTANTES
; =============================================================================
Config_VERSION = 1.0.0
Config_REPO_URL = https://api.github.com/repos/JUST3EXT/CAU/releases/latest
Config_TEMP_FILE = %A_Temp%\CAU_GUI.exe
Config_LOCAL_FILE = %A_ScriptFullPath%
Config_DNI_LETTERS = TRWAGMYFPDXBNJZSQVHLCKE
Config_REMEDY_EXE = aruser.exe
Config_AR_FRAME_CLASS = ArFrame
Config_ALBA_SCRIPT_PATH = C:\ProgramData\Application Data\AR SYSTEM\home\Alba.ps1

; =============================================================================
; FUNCIONES PARA MANEJO DE LOGS
; =============================================================================
Logger_LogFilePath =

Logger_Init() {
    global Logger_LogFilePath
    FormatTime, LogFileName,, MMMMyyyy
    StringReplace, LogFileName, LogFileName, %A_Space%, _, All
    Logger_LogFilePath = %A_MyDocuments%\log_%LogFileName%.txt
}

Logger_Write(action) {
    global Logger_LogFilePath
    if (!Logger_LogFilePath) {
        Logger_Init()
    }
    ComputerName := A_ComputerName
    FormatTime, DateTime,, yyyy-MM-dd HH:mm:ss
    FileAppend, %DateTime% - %ComputerName% - %action%`n, %Logger_LogFilePath%
    FileSetAttrib, +H, %Logger_LogFilePath%
}

Logger_WriteError(errorMessage) {
    global Logger_LogFilePath
    if (!Logger_LogFilePath) {
        Logger_Init()
    }
    ComputerName := A_ComputerName
    FormatTime, DateTime,, yyyy-MM-dd HH:mm:ss
    FileAppend, %DateTime% - %ComputerName% - *** ERROR %errorMessage% ***`n, %Logger_LogFilePath%
    FileSetAttrib, +H, %Logger_LogFilePath%
}

; =============================================================================
; FUNCIONES PARA VALIDACIÓN Y UTILIDADES
; =============================================================================
Utils_CalculateDNILetter(dniNumber) {
    global Config_DNI_LETTERS
    if (dniNumber = "" || !RegExMatch(dniNumber, "^\d{1,8}$")) {
        return ""
    }
    index := Mod(dniNumber, 23)
    return SubStr(Config_DNI_LETTERS, index + 1, 1)
}

Utils_IsRemedyRunning() {
    global Config_REMEDY_EXE
    IfWinExist, ahk_exe %Config_REMEDY_EXE%
    {
        return true
    }
    else
    {
        MsgBox, Error, el programa Remedy no se encuentra abierto.
        Logger_Write("Error, el programa Remedy no se encuentra abierto")
        return false
    }
}

Utils_ActivateRemedyWindow() {
    global Config_AR_FRAME_CLASS
    SetTitleMatchMode, 2
    WinActivate, ahk_class %Config_AR_FRAME_CLASS%
    Logger_Write("Activó la ventana ArFrame")
}

; =============================================================================
; FUNCIONES PARA ACTUALIZACIONES
; =============================================================================
Updater_GetLatestReleaseVersion() {
    global Config_REPO_URL
    HttpObj := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    HttpObj.Open("GET", Config_REPO_URL, false)
    HttpObj.SetRequestHeader("User-Agent", "AutoHotkey Script")
    HttpObj.Send()
    response := HttpObj.ResponseText
    version =
    if RegExMatch(response, """tag_name"":""v?(\d+\.\d+\.\d+)""", match)
        version := match1
    return version
}

Updater_DownloadLatestVersion() {
    global Config_TEMP_FILE
    latestVersion := Updater_GetLatestReleaseVersion()
    if (latestVersion = "") {
        return false
    }
    downloadUrl = https://github.com/JUST3EXT/CAU/releases/download/v%latestVersion%/CAU_GUI.exe
    UrlDownloadToFile, %downloadUrl%, %Config_TEMP_FILE%
    return FileExist(Config_TEMP_FILE)
}

Updater_RunUpdateScript() {
    global Config_TEMP_FILE, Config_LOCAL_FILE
    updateScript =
    (
        Sleep, 2000
        Loop {
            FileMove, %Config_TEMP_FILE%, %Config_LOCAL_FILE%, 1
            if (ErrorLevel = 0)
                break
            Sleep, 500
        }
        Run, %Config_LOCAL_FILE%
        ExitApp
    )
    FileDelete, %A_Temp%\UpdateScript.ahk
    FileAppend, %updateScript%, %A_Temp%\UpdateScript.ahk
    Run, %A_Temp%\UpdateScript.ahk
}

Updater_CheckForUpdates() {
    global Config_VERSION
    latestVersion := Updater_GetLatestReleaseVersion()
    Logger_Write("Comprobando actualizaciones... Versión actual: " . Config_VERSION)
    if (latestVersion != "" && latestVersion != Config_VERSION) {
        Logger_Write("Nueva versión disponible: " . latestVersion)
        MsgBox, 4,, Hay una nueva versión disponible: %latestVersion%`n¿Deseas actualizar el script?
        IfMsgBox, Yes
        {
            if (Updater_DownloadLatestVersion()) {
                Logger_Write("Script actualizado correctamente a la versión " . latestVersion)
                MsgBox, Script actualizado correctamente. Se reiniciará ahora.
                Updater_RunUpdateScript()
                ExitApp
            } else {
                Logger_WriteError("Error al descargar la nueva versión.")
                MsgBox, Error al descargar la nueva versión.
            }
        }
    } else {
        Logger_Write("No se encontraron nuevas actualizaciones.")
    }
}

; =============================================================================
; FUNCIONES PARA MACROS
; =============================================================================
MacroManager_ExecuteAlba(num) {
    global Config_ALBA_SCRIPT_PATH
    if (!Utils_IsRemedyRunning()) {
        return
    }
    BlockInput, On
    RunWait, powershell.exe -ExecutionPolicy Bypass -File "%Config_ALBA_SCRIPT_PATH%",, Hide
    Utils_ActivateRemedyWindow()
    Send, ^i
    Send, {TAB 2}{End}{Up %num%}{Enter}
    Send, {TAB 22}
    Logger_Write("Ejecutó la macro Alba con parámetro " . num)
    BlockInput, Off
}

MacroManager_ExecuteCierre(closetext) {
    Sleep, 800
    Send, ^{enter}{Enter}
    Sleep, 800
    SendInput, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
    SendInput, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}%closetext%{Tab}{Enter}
    Logger_Write("Cierre ejecutado con texto: " . closetext)
}

MacroManager_ExecuteStandardMacro(albaNumber, dni, telf, closeText=""){
    if (!Utils_IsRemedyRunning()) {
        return
    }
    MacroManager_ExecuteAlba(albaNumber)
    Gui, Submit, NoHide
    Send, %dni%
    Send, {Tab}{Enter}
    Send, {Tab 3}
    Send, +{Left 90}{BackSpace}
    Send, %telf%
    GuiControl,, dni
    GuiControl,, telf
    
    if (closeText != "") {
        MacroManager_ExecuteCierre(closeText)
    }
    
    Logger_Write("Ejecutó macro alba " . dni . " y " . telf)
}

MacroManager_ExecuteSearchMacro(inci) {
    if (!Utils_IsRemedyRunning()) {
        return
    }
    Gui, Submit, NoHide
    MacroManager_ExecuteAlba(0)
    Send, {F3}{Enter}{Tab 5}
    Send, %inci%
    Send, ^{Enter}
    GuiControl,, Inci
    Logger_Write("Pulsó el botón Buscar y ejecutó la macro Alba con Inci: " . inci)
}

; =============================================================================
; FUNCIONES PARA LA INTERFAZ DE USUARIO
; =============================================================================
GUI_Create() {
    global dni, telf, Inci, DNILetter, buttons
    
    Gui Add, Edit, vdni x109 y639 w188 h26 gUpdateLetter, %dni%
    Gui Add, Edit, x411 y638 w188 h26 vtelf, %telf%
    Gui Add, Edit, x817 y637 w188 h26 vInci, %Inci%
    Gui, Add, Edit, vDNILetter x300 y639 w20 h26 ReadOnly
    
    Gui Add, Text, x1219 y17 w25 h17, DP
    Gui Add, Text, x798 y368 w84 h19, MINISTERIO
    Gui Add, Text, x288 y20 w95 h20, INCIDENCIAS
    Gui Add, Text, x289 y376 w98 h19, SOLICITUDES
    Gui Add, Text, x797 y18 w67 h18, CIERRES
    Gui Add, Text, x68 y644 w33 h21, DNI
    Gui Add, Text, x327 y645 w76 h21, TELÉFONO
    Gui Add, Text, x786 y646 w23 h21, IN
    
    GUI_CreateButtons()
    
    Gui Add, Button, x1050 y635 w80 h23 gButton42, Buscar
    Gui, Add, Checkbox, vModoSeguro x1200 y635 w80 h23, Modo Seguro
    
    Gui Show, w1456 h704, Gestor de incidencias
}

GUI_CreateButtons() {
    global buttons
    buttons_data =
(LTrim
49|57|183|68|Adriano|42
49|137|183|68|Escritorio judicial|29
431|56|183|68|Arconte|39
50|285|183|68|PortafirmasNG|9
241|56|183|68|Agenda de señalamientos|41
241|136|183|68|Expediente digital|28
50|212|183|68|Hermes|22
240|210|183|68|Jara|18
432|209|183|68|Quenda // Cita previa|0
240|284|183|68|Suministros|4
242|478|183|68|Internet libre|21
52|548|183|68|Multiconferencia|14
432|408|183|68|Dragon Speaking|32
242|408|183|68|Aumento espacio correo|38
52|408|183|68|Abbypdf|44
52|478|183|68|GDU|24
741|476|183|68|Orfila|12
740|406|183|68|Lexnet|16
742|547|183|68|Siraj2|6
431|134|183|68|Emparejamiento ISL|30
642|127|183|68|Certificado digital|37
831|57|183|68|Software|5
831|128|183|68|PIN tarjeta|11
643|199|183|68|Servicio no CEIURIS|10
1234|198|183|68|Lector tarjeta|17
1045|197|183|68|Equipo sin red|7
1233|57|183|68|GM|23
1137|483|183|68|Teléfono|2
1046|410|183|68|Ganes|25
1045|268|183|68|Equipo no enciende|26
1045|57|183|68|Disco duro|33
1045|127|183|68|Edoc Fortuny|31
832|199|183|68|@Driano|13
432|478|183|68|Intervención video|20
1235|267|183|68|Monitor|15
1236|410|183|68|Teclado|3
1236|338|183|68|Ratón|8
1233|127|183|68|ISL Apagado|19
1045|339|183|68|Error relación de confianza|36
642|56|183|68|Contraseñas|35
244|549|183|68|Formaciones|27
)
    Loop, Parse, buttons_data, `n, `r
    {
        if (A_LoopField = "")
            continue
        StringSplit, button_props, A_LoopField, |
        Gui, Add, Button, x%button_props1% y%button_props2% w%button_props3% h%button_props4% gButton%A_Index%, %button_props5%
        buttons%A_Index% := button_props6
    }
}

; =============================================================================
; MANEJADORES DE EVENTOS
; =============================================================================
UpdateLetter:
    global dni, DNILetter
    Gui, Submit, NoHide
    DNILetter := Utils_CalculateDNILetter(dni)
    GuiControl,, DNILetter, %DNILetter%
    Logger_Write("Actualizó la letra del DNI")
    Return

; Generar manejadores de botones dinámicamente
Loop, 41
{
    handler_name := "Button" . A_Index
    SetLabel(handler_name, "Button_Handler")
}

Button_Handler:
    StringTrimLeft, button_index, A_ThisLabel, 6
    global dni, telf, buttons
    alba_num := buttons%button_index%
    MacroManager_ExecuteStandardMacro(alba_num, dni, telf)
Return

SetLabel(label, p_handler) {
    global
    %label%:
    GoSub, %p_handler%
    Return
}


Button42:
    global Inci
    MacroManager_ExecuteSearchMacro(Inci)
    Return

; =============================================================================
; HOTKEYS
; =============================================================================
#1:: 
    global dni, telf
    Gui, Submit, NoHide
    MacroManager_ExecuteStandardMacro(0, dni, telf)
    Return

#2:: 
    global dni, telf
    Gui, Submit, NoHide
    MacroManager_ExecuteStandardMacro(43, dni, telf, "Se cambia contraseña de AD.")
    Return

#3:: 
    global dni, telf
    Gui, Submit, NoHide
    MacroManager_ExecuteStandardMacro(34, dni, telf, "Se cambia contraseña de correo.")
    Return

#4:: 
    global dni, telf
    Gui, Submit, NoHide
    MacroManager_ExecuteStandardMacro(40, dni, telf, "Se cambia contraseña de Aurea.")
    Return

#5:: 
    global dni, telf
    Gui, Submit, NoHide
    MacroManager_ExecuteStandardMacro(1, dni, telf, "Se cambia contraseña Temis.")
    Return

#6::
    if (!Utils_IsRemedyRunning()) {
        return
    }
    InputBox, repeatCount, Repeticiones, ¿Cuántas veces deseas repetir la acción?, , 300, 150
    if ErrorLevel {
        MsgBox, Cancelado por el usuario.
        return
    }
    if (repeatCount <= 0 || repeatCount > 999) {
        MsgBox, Número inválido. Introduce un número entre 1 y 999.
        return
    }
    Loop %repeatCount% {
        MacroManager_ExecuteAlba(42)
        Send ^{Enter}{Enter}
        Logger_Write("Ejecutó la combinación #6 (Iteración: " . A_Index . ")")
        Sleep 100
    }
    MsgBox, % "Se ha completado correctamente " . repeatCount . " iteraciones."
    return

#7::
    if (!Utils_IsRemedyRunning()) {
        return
    }
    global IsActive, Toggle
    Toggle := !Toggle
    if (Toggle) {
        SetTimer, KeepActive, 5000
        IsActive := true
        MsgBox, 64, Modo AFK activado.
        Logger_Write("Activó modo afk")
    } else {
        SetTimer, KeepActive, Off
        IsActive := false
        MsgBox, 64, Modo AFK desactivado.
        Logger_Write("Desactivó modo afk")
    }
    Return

#9:: 
    global Inci
    Gui, Submit, NoHide
    MacroManager_ExecuteSearchMacro(Inci)
    Return

#0:: Reload

XButton1::
    if (!Utils_IsRemedyRunning()) {
        return
    }
    Utils_ActivateRemedyWindow()
    Send, {Alt}a
    Send, {Down 9}{Right}{Enter}
    Logger_Write("Se utilizó botón XButton1")
    Return

XButton2:: Send, #+s

F13:: 
    global dni, telf
    Gui, Submit, NoHide
    MacroManager_ExecuteStandardMacro(0, dni, telf)
    Return

F14:: 
    global dni, telf
    Gui, Submit, NoHide
    MacroManager_ExecuteStandardMacro(43, dni, telf, "Se cambia contraseña de AD.")
    Return

F15:: 
    global dni, telf
    Gui, Submit, NoHide
    MacroManager_ExecuteStandardMacro(34, dni, telf, "Se cambia contraseña de correo.")
    Return

F16:: 
    global dni, telf
    Gui, Submit, NoHide
    MacroManager_ExecuteStandardMacro(40, dni, telf, "Se cambia contraseña de Aurea.")
    Return

F17:: 
    global dni, telf
    Gui, Submit, NoHide
    MacroManager_ExecuteStandardMacro(1, dni, telf, "Se cambia contraseña Temis.")
    Return

F18::
    if (!Utils_IsRemedyRunning()) {
        return
    }
    Send, ^c
    MacroManager_ExecuteAlba(0)
    Send, {F3}{Enter}{Tab 5}
    Gui, Submit, NoHide
    Send, ^v
    Send, ^{Enter}
    Logger_Write("Ejecutó macro F18")
    Return

F12:: 
    global Inci
    Gui, Submit, NoHide
    MacroManager_ExecuteSearchMacro(Inci)
    Return

F19:: 
    global Inci
    Gui, Submit, NoHide
    MacroManager_ExecuteSearchMacro(Inci)
    Return

F20:: 
    global dni, telf
    Gui, Submit, NoHide
    MacroManager_ExecuteStandardMacro(30, dni, telf, "Se empareja equipo correctamente y se indica contraseña ISL se cierra ticket.")
    Return

; =============================================================================
; FUNCIONES AUXILIARES
; =============================================================================
KeepActive:
    global IsActive
    if (IsActive) {
        MouseGetPos, xpos, ypos
        MouseMove, %xpos%, %ypos%, 0
        Send, {Shift}
        Logger_Write("Se movió mouse")
    }
    Return

GuiEscape:
GuiClose:
    Logger_Write("Cerró la aplicación")
    ExitApp

; =============================================================================
; INICIALIZACIÓN
; =============================================================================
Logger_Init()
Logger_Write("Ejecutando aplicación")
Updater_CheckForUpdates()
GUI_Create()
Return
