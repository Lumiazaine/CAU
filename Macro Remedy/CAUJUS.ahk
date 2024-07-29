#SingleInstance Force
#NoEnv
#MaxHotkeysPerInterval 99000000
#HotkeyInterval 99000000
#KeyHistory 0
#Persistent
ListLines Off
Process, Priority, , A
SetBatchLines, -1
SetKeyDelay, -1, -1
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
SetWinDelay, -1
SetControlDelay, -1
SendMode Input
DllCall("ntdll\ZwSetTimerResolution","Int",5000,"Int",1,"Int*",MyCurrentTimerResolution)
SetWorkingDir, %A_ScriptDir%

; Variables
dni := ""
telf := ""
letters := "TRWAGMYFPDXBNJZSQVHLCKE"

; Funciones
CalculateDNILetter(dniNumber) {
    global letters
    if (dniNumber = "" || !RegExMatch(dniNumber, "^\d{1,8}$")) {
        return ""
    }
    index := Mod(dniNumber, 23)
    return SubStr(letters, index + 1, 1)
}

WriteLog(action) {
    ComputerName := A_ComputerName
    FormatTime, DateTime,, yyyy-MM-dd HH:mm:ss
    FormatTime, LogFileName,, MMMMyyyy
    StringReplace, LogFileName, LogFileName, %A_Space%, _, All
    LogFilePath := A_MyDocuments "\log_" LogFileName ".txt"
    FileAppend, %DateTime% - %ComputerName% - %action%`n, %LogFilePath%
    FileSetAttrib, +H, %LogFilePath%
}

WriteError(errorMessage) {
    ComputerName := A_ComputerName
    FormatTime, DateTime,, yyyy-MM-dd HH:mm:ss
    FormatTime, LogFileName,, MMMMyyyy
    StringReplace, LogFileName, LogFileName, %A_Space%, _, All
    LogFilePath := A_MyDocuments "\log_" LogFileName ".txt"
    FileAppend, %DateTime% - %ComputerName% - *** ERROR %errorMessage% ***`n, %LogFilePath%
    FileSetAttrib, +H, %LogFilePath%
}

Gui Add, Button, x688 y56 w80 h23 gButton1, Buscar
Gui Add, Edit, x96 y56 w120 h21 vDNI gUpdateLetter, %dni%
Gui Add, Edit, x344 y56 w120 h21 vtelf, %telf%
Gui Add, Edit, x528 y56 w120 h21 vInci, %Inci%
Gui Add, Edit, x216 y56 w31 h21 vDNILetter, ReadOnly
Gui Add, Text, x56 y56 w23 h23 +0x200, DNI
Gui Add, Text, x272 y56 w62 h23 +0x200, TELÉFONO
Gui Add, Text, x496 y56 w19 h23 +0x200, IN
Gui Show, w838 h159, Rosetta

UpdateLetter:
    try {
        Gui, Submit, NoHide
        DNILetter := CalculateDNILetter(DNI)
        GuiControl,, DNILetter, %DNILetter%
        WriteLog("Actualizó la letra del DNI")
    } catch e {
        WriteError("Actualizando letra del DNI: " . e.Message)
    }
    Return

screen() {
    try {
        SetTitleMatchMode, 2
        WinActivate, ahk_class ArFrame
        WriteLog("Activó la ventana ArFrame")
    } catch e {
        WriteError("Activando ventana ArFrame: " . e.Message)
    }
    Return
}

Alba(num) {
    try {
        RunWait, powershell.exe -ExecutionPolicy Bypass -File "C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\Alba.ps1",, Hide
        screen()
        Send, ^i
        Send, {TAB 2}{End}{Up %num%}{Enter}
        Send, {TAB 22}
        WriteLog("Ejecutó la macro Alba con parámetro " . num)
    } catch e {
        WriteError("Ejecutando macro Alba: " . e.Message)
    }
    Return
}

cierre(closetext) {
    try {
        Sleep, 800
        Send, ^{enter}{Enter}
        Sleep, 800
        SendInput, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
        SendInput, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}closetext{Tab}{Enter}
        WriteLog("Cierre ejecutado con texto: " . closetext)
    } catch e {
        WriteError("Cierre ejecutado con texto: " . e.Message)
    }
}

;Recargar programa

#0::Reload
    try {
        WriteLog("Recargó el script")
    } catch e {
        WriteError("Recargando el script: " . e.Message)
    }
Return

;Abrir ticket con DNI y Teléfono.

#1::
    try {
        Alba(0)
        Gui, Submit, NoHide
        Send, %DNI%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , DNI
        GuiControl, , telf
        WriteLog("Ejecutó la combinación #1 con DNI y teléfono")
    } catch e {
        WriteError("Ejecutando combinación #1: " . e.Message)
    }
    Return

;Busca incidencia por selección

F19::
    try {
        Send, ^c
        Alba(0)
        Send, {F3}{Enter}{Tab 5}
        Gui, Submit, NoHide
        Send, ^v
        Send, ^{Enter}
          WriteLog("Pulsó el botón Buscar y ejecutó la macro Alba con Inci: " . Inci)
    } catch e {
        WriteError("Pulsando botón Buscar: " . e.Message)
    }
    Return    

;Misma acción que el botón 1 pero con tecla

F20::
    try {
        Gui, Submit, NoHide
        Alba(0)
        Send, {F3}{Enter}{Tab 5}
        Send, %Inci%
        Send, ^{Enter}
        GuiControl, , Inci
        WriteLog("Pulsó el botón Buscar y ejecutó la macro Alba con Inci: " . Inci)
    } catch e {
        WriteError("Pulsando botón Buscar: " . e.Message)
    }
    Return

;botón de busqueda

Button1:
    try {
        Gui, Submit, NoHide
        Alba(0)
        Send, {F3}{Enter}{Tab 5}
        Send, %Inci%
        Send, ^{Enter}
        GuiControl, , Inci
        WriteLog("Pulsó el botón Buscar y ejecutó la macro Alba con Inci: " . Inci)
    } catch e {
        WriteError("Pulsando botón Buscar: " . e.Message)
    }
    Return

GuiEscape:
GuiClose:
    try {
        WriteLog("Cerró la aplicación")
        ExitApp
    } catch e {
        WriteError("Cerrando la aplicación: " . e.Message)
    }
