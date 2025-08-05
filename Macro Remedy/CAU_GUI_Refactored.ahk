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

; =============================================================================
; CONFIGURACIÓN GLOBAL Y CONSTANTES
; =============================================================================
class Config {
    static VERSION := "1.0.0"
    static REPO_URL := "https://api.github.com/repos/JUST3EXT/CAU/releases/latest"
    static TEMP_FILE := A_Temp "\CAU_GUI.exe"
    static LOCAL_FILE := A_ScriptFullPath
    static DNI_LETTERS := "TRWAGMYFPDXBNJZSQVHLCKE"
    static REMEDY_EXE := "aruser.exe"
    static AR_FRAME_CLASS := "ArFrame"
    static ALBA_SCRIPT_PATH := "C:\ProgramData\Application Data\AR SYSTEM\home\Alba.ps1"
}

; =============================================================================
; CLASE PARA MANEJO DE LOGS
; =============================================================================
class Logger {
    static LogFilePath := ""
    
    static Init() {
        FormatTime, LogFileName,, MMMMyyyy
        StringReplace, LogFileName, LogFileName, %A_Space%, _, All
        this.LogFilePath := A_MyDocuments "\log_" LogFileName ".txt"
    }
    
    static Write(action) {
        if (!this.LogFilePath) {
            this.Init()
        }
        ComputerName := A_ComputerName
        FormatTime, DateTime,, yyyy-MM-dd HH:mm:ss
        FileAppend, %DateTime% - %ComputerName% - %action%`n, %this.LogFilePath%
        FileSetAttrib, +H, %this.LogFilePath%
    }
    
    static WriteError(errorMessage) {
        if (!this.LogFilePath) {
            this.Init()
        }
        ComputerName := A_ComputerName
        FormatTime, DateTime,, yyyy-MM-dd HH:mm:ss
        FileAppend, %DateTime% - %ComputerName% - *** ERROR %errorMessage% ***`n, %this.LogFilePath%
        FileSetAttrib, +H, %this.LogFilePath%
    }
}

; =============================================================================
; CLASE PARA VALIDACIÓN Y UTILIDADES
; =============================================================================
class Utils {
    static CalculateDNILetter(dniNumber) {
        if (dniNumber = "" || !RegExMatch(dniNumber, "^\d{1,8}$")) {
            return ""
        }
        index := Mod(dniNumber, 23)
        return SubStr(Config.DNI_LETTERS, index + 1, 1)
    }
    
    static IsRemedyRunning() {
        IfWinExist, ahk_exe %Config.REMEDY_EXE%
        {
            return true
        }
        else
        {
            MsgBox, Error, el programa Remedy no se encuentra abierto.
            Logger.Write("Error, el programa Remedy no se encuentra abierto")
            return false
        }
    }
    
    static ActivateRemedyWindow() {
        try {
            SetTitleMatchMode, 2
            WinActivate, ahk_class %Config.AR_FRAME_CLASS%
            Logger.Write("Activó la ventana ArFrame")
        } catch e {
            Logger.WriteError("Activando ventana ArFrame: " . e.Message)
        }
    }
}

; =============================================================================
; CLASE PARA ACTUALIZACIONES
; =============================================================================
class Updater {
    static GetLatestReleaseVersion() {
        HttpObj := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        HttpObj.Open("GET", Config.REPO_URL, false)
        HttpObj.SetRequestHeader("User-Agent", "AutoHotkey Script")
        HttpObj.Send()
        response := HttpObj.ResponseText
        version := ""
        if RegExMatch(response, """tag_name"":""v?(\d+\.\d+\.\d+)""", match)
            version := match1
        return version
    }
    
    static DownloadLatestVersion() {
        latestVersion := this.GetLatestReleaseVersion()
        if (latestVersion = "") {
            return false
        }
        downloadUrl := "https://github.com/JUST3EXT/CAU/releases/download/v" latestVersion "/CAU_GUI.exe"
        UrlDownloadToFile, %downloadUrl%, %Config.TEMP_FILE%
        return FileExist(Config.TEMP_FILE)
    }
    
    static RunUpdateScript() {
        updateScript =
        (
            Sleep, 2000
            Loop {
                FileMove, %Config.TEMP_FILE%, %Config.LOCAL_FILE%, 1
                if (ErrorLevel = 0)
                    break
                Sleep, 500
            }
            Run, %Config.LOCAL_FILE%
            ExitApp
        )
        FileDelete, %A_Temp%\UpdateScript.ahk
        FileAppend, %updateScript%, %A_Temp%\UpdateScript.ahk
        Run, %A_Temp%\UpdateScript.ahk
    }
    
    static CheckForUpdates() {
        latestVersion := this.GetLatestReleaseVersion()
        Logger.Write("Comprobando actualizaciones... Versión actual: " Config.VERSION)
        if (latestVersion != "" && latestVersion != Config.VERSION) {
            Logger.Write("Nueva versión disponible: " latestVersion)
            MsgBox, 4,, Hay una nueva versión disponible: %latestVersion%`n¿Deseas actualizar el script?
            IfMsgBox, Yes
            {
                if (this.DownloadLatestVersion()) {
                    Logger.Write("Script actualizado correctamente a la versión " latestVersion)
                    MsgBox, Script actualizado correctamente. Se reiniciará ahora.
                    this.RunUpdateScript()
                    ExitApp
                } else {
                    Logger.WriteError("Error al descargar la nueva versión.")
                    MsgBox, Error al descargar la nueva versión.
                }
            }
        } else {
            Logger.Write("No se encontraron nuevas actualizaciones.")
        }
    }
}

; =============================================================================
; CLASE PARA MACROS
; =============================================================================
class MacroManager {
    static ExecuteAlba(num) {
        if (!Utils.IsRemedyRunning()) {
            return
        }
        try {
            BlockInput, On
            RunWait, powershell.exe -ExecutionPolicy Bypass -File "%Config.ALBA_SCRIPT_PATH%",, Hide
            Utils.ActivateRemedyWindow()
            Send, ^i
            Send, {TAB 2}{End}{Up %num%}{Enter}
            Send, {TAB 22}
            Logger.Write("Ejecutó la macro Alba con parámetro " . num)
        } catch e {
            Logger.WriteError("Ejecutando macro Alba: " . e.Message)
        } finally {
            BlockInput, Off
        }
    }
    
    static ExecuteCierre(closetext) {
        try {
            Sleep, 800
            Send, ^{enter}{Enter}
            Sleep, 800
            SendInput, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
            SendInput, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}%closetext%{Tab}{Enter}
            Logger.Write("Cierre ejecutado con texto: " . closetext)
        } catch e {
            Logger.WriteError("Cierre ejecutado con texto: " . e.Message)
        }
    }
    
    static ExecuteStandardMacro(albaNumber, dni, telf, closeText := "") {
        if (!Utils.IsRemedyRunning()) {
            return
        }
        try {
            this.ExecuteAlba(albaNumber)
            Gui, Submit, NoHide
            Send, %dni%
            Send, {Tab}{Enter}
            Send, {Tab 3}
            Send, +{Left 90}{BackSpace}
            Send, %telf%
            GuiControl,, dni
            GuiControl,, telf
            
            if (closeText != "") {
                this.ExecuteCierre(closeText)
            }
            
            Logger.Write("Ejecutó macro alba " . dni . " y " . telf)
        } catch e {
            Logger.WriteError("Error ejecutando macro: " . e.Message)
        }
    }
    
    static ExecuteSearchMacro(inci) {
        if (!Utils.IsRemedyRunning()) {
            return
        }
        try {
            Gui, Submit, NoHide
            this.ExecuteAlba(0)
            Send, {F3}{Enter}{Tab 5}
            Send, %inci%
            Send, ^{Enter}
            GuiControl,, Inci
            Logger.Write("Pulsó el botón Buscar y ejecutó la macro Alba con Inci: " . inci)
        } catch e {
            Logger.WriteError("Pulsando botón Buscar: " . e.Message)
        }
    }
}

; =============================================================================
; CLASE PARA LA INTERFAZ DE USUARIO
; =============================================================================
class GUI {
    static Create() {
        ; Crear controles de entrada
        Gui Add, Edit, vdni x109 y639 w188 h26 gUpdateLetter, %dni%
        Gui Add, Edit, x411 y638 w188 h26 vtelf, %telf%
        Gui Add, Edit, x817 y637 w188 h26 vInci, %Inci%
        Gui, Add, Edit, vDNILetter x300 y639 w20 h26 ReadOnly
        
        ; Crear etiquetas
        Gui Add, Text, x1219 y17 w25 h17, DP
        Gui Add, Text, x798 y368 w84 h19, MINISTERIO
        Gui Add, Text, x288 y20 w95 h20, INCIDENCIAS
        Gui Add, Text, x289 y376 w98 h19, SOLICITUDES
        Gui Add, Text, x797 y18 w67 h18, CIERRES
        Gui Add, Text, x68 y644 w33 h21, DNI
        Gui Add, Text, x327 y645 w76 h21, TELÉFONO
        Gui Add, Text, x786 y646 w23 h21, IN
        
        ; Crear botones usando un array de configuración
        this.CreateButtons()
        
        ; Botones adicionales
        Gui Add, Button, x1050 y635 w80 h23 gButton42, Buscar
        Gui, Add, Checkbox, vModoSeguro x1200 y635 w80 h23, Modo Seguro
        
        Gui Show, w1456 h704, Gestor de incidencias
    }
    
    static CreateButtons() {
        ; Configuración de botones: [x, y, width, height, label, albaNumber]
        global buttons := [
            [49, 57, 183, 68, "Adriano", 42],
            [49, 137, 183, 68, "Escritorio judicial", 29],
            [431, 56, 183, 68, "Arconte", 39],
            [50, 285, 183, 68, "PortafirmasNG", 9],
            [241, 56, 183, 68, "Agenda de señalamientos", 41],
            [241, 136, 183, 68, "Expediente digital", 28],
            [50, 212, 183, 68, "Hermes", 22],
            [240, 210, 183, 68, "Jara", 18],
            [432, 209, 183, 68, "Quenda // Cita previa", 0],
            [240, 284, 183, 68, "Suministros", 4],
            [242, 478, 183, 68, "Internet libre", 21],
            [52, 548, 183, 68, "Multiconferencia", 14],
            [432, 408, 183, 68, "Dragon Speaking", 32],
            [242, 408, 183, 68, "Aumento espacio correo", 38],
            [52, 408, 183, 68, "Abbypdf", 44],
            [52, 478, 183, 68, "GDU", 24],
            [741, 476, 183, 68, "Orfila", 12],
            [740, 406, 183, 68, "Lexnet", 16],
            [742, 547, 183, 68, "Siraj2", 6],
            [431, 134, 183, 68, "Emparejamiento ISL", 30],
            [642, 127, 183, 68, "Certificado digital", 37],
            [831, 57, 183, 68, "Software", 5],
            [831, 128, 183, 68, "PIN tarjeta", 11],
            [643, 199, 183, 68, "Servicio no CEIURIS", 10],
            [1234, 198, 183, 68, "Lector tarjeta", 17],
            [1045, 197, 183, 68, "Equipo sin red", 7],
            [1233, 57, 183, 68, "GM", 23],
            [1137, 483, 183, 68, "Teléfono", 2],
            [1046, 410, 183, 68, "Ganes", 25],
            [1045, 268, 183, 68, "Equipo no enciende", 26],
            [1045, 57, 183, 68, "Disco duro", 33],
            [1045, 127, 183, 68, "Edoc Fortuny", 31],
            [832, 199, 183, 68, "@Driano", 13],
            [432, 478, 183, 68, "Intervención video", 20],
            [1235, 267, 183, 68, "Monitor", 15],
            [1236, 410, 183, 68, "Teclado", 3],
            [1236, 338, 183, 68, "Ratón", 8],
            [1233, 127, 183, 68, "ISL Apagado", 19],
            [1045, 339, 183, 68, "Error relación de confianza", 36],
            [642, 56, 183, 68, "Contraseñas", 35],
            [244, 549, 183, 68, "Formaciones", 27]
        ]
        
        for index, button in buttons {
            Gui Add, Button, x%button[1]% y%button[2]% w%button[3]% h%button[4]% gButton%index%, %button[5]%
        }
    }
}

; =============================================================================
; MANEJADORES DE EVENTOS
; =============================================================================
UpdateLetter:
    try {
        Gui, Submit, NoHide
        DNILetter := Utils.CalculateDNILetter(DNI)
        GuiControl,, DNILetter, %DNILetter%
        Logger.Write("Actualizó la letra del DNI")
    } catch e {
        Logger.WriteError("Actualizando letra del DNI: " . e.Message)
    }
    Return

; Generar manejadores de botones dinámicamente
Loop, 41 {
    Button%A_Index%:
        MacroManager.ExecuteStandardMacro(buttons[A_Index][6], dni, telf)
        Return
}

Button42:
    MacroManager.ExecuteSearchMacro(Inci)
    Return

; =============================================================================
; HOTKEYS
; =============================================================================
#1:: MacroManager.ExecuteStandardMacro(0, dni, telf)
#2:: MacroManager.ExecuteStandardMacro(43, dni, telf, "Se cambia contraseña de AD.")
#3:: MacroManager.ExecuteStandardMacro(34, dni, telf)
#4:: MacroManager.ExecuteStandardMacro(40, dni, telf)
#5:: MacroManager.ExecuteStandardMacro(1, dni, telf)

#6::
    if (!Utils.IsRemedyRunning()) {
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
        try {
            MacroManager.ExecuteAlba(42)
            Send ^{Enter}{Enter}
            Logger.Write("Ejecutó la combinación #6 (Iteración: " . A_Index . ")")
        } catch e {
            Logger.WriteError("Error en iteración " . A_Index . ": " . e.Message)
        }
        Sleep 100
    }
    MsgBox, % "Se ha completado correctamente " . repeatCount . " iteraciones."
    return

#7::
    if (!Utils.IsRemedyRunning()) {
        return
    }
    try {
        static Toggle := false
        Toggle := !Toggle
        if (Toggle) {
            SetTimer, KeepActive, On
            IsActive := true
            MsgBox, 64, Modo AFK activado.
            Logger.Write("Activó modo afk")
        } else {
            SetTimer, KeepActive, Off
            IsActive := false
            MsgBox, 64, Modo AFK desactivado.
            Logger.Write("Desactivó modo afk")
        }
    } catch e {
        Logger.WriteError("Error ejecutando modo afk: " . e.Message)
    }
    Return

#9:: MacroManager.ExecuteSearchMacro(Inci)
#0:: Reload

XButton1::
    if (!Utils.IsRemedyRunning()) {
        return
    }
    try {
        Utils.ActivateRemedyWindow()
        Send, {Alt}a
        Send, {Down 9}{Right}{Enter}
        Logger.Write("Se utilizó botón XButton1")
    } catch e {
        Logger.WriteError("Se utilizó botón XButton1: " . e.Message)
    }
    Return

XButton2:: Send, #+s

F13:: MacroManager.ExecuteStandardMacro(0, dni, telf)
F14:: MacroManager.ExecuteStandardMacro(43, dni, telf, "Se cambia contraseña de AD.")
F15:: MacroManager.ExecuteStandardMacro(34, dni, telf, "Se cambia contraseña de correo.")
F16:: MacroManager.ExecuteStandardMacro(40, dni, telf, "Se cambia contraseña de Aurea.")
F17:: MacroManager.ExecuteStandardMacro(1, dni, telf, "Se cambia contraseña Temis.")
F18::
    if (!Utils.IsRemedyRunning()) {
        return
    }
    try {
        Send, ^c
        MacroManager.ExecuteAlba(0)
        Send, {F3}{Enter}{Tab 5}
        Gui, Submit, NoHide
        Send, ^v
        Send, ^{Enter}
        Logger.Write("Ejecutó macro F18")
    } catch e {
        Logger.WriteError("Ejecutó macro F18: " . e.Message)
    }
    Return

F12:: MacroManager.ExecuteSearchMacro(Inci)
F19:: MacroManager.ExecuteSearchMacro(Inci)
F20:: MacroManager.ExecuteStandardMacro(30, dni, telf, "Se empareja equipo correctamente y se indica contraseña ISL se cierra ticket.")

; =============================================================================
; FUNCIONES AUXILIARES
; =============================================================================
KeepActive:
    Try {
        if (IsActive) {
            MouseGetPos, xpos, ypos
            MouseMove, %xpos%, %ypos%, 0
            Send, {Shift}
            Logger.Write("Se movió mouse")
            Return
        } 
    } catch e {
        Logger.WriteError("Se movió mouse: " . e.Message)
    }

GuiEscape:
GuiClose:
    try {
        Logger.Write("Cerró la aplicación")
        ExitApp
    } catch e {
        Logger.WriteError("Cerrando la aplicación: " . e.Message)
    }

; =============================================================================
; INICIALIZACIÓN
; =============================================================================
Logger.Init()
Logger.Write("Ejecutando aplicación")
Updater.CheckForUpdates()
GUI.Create() 