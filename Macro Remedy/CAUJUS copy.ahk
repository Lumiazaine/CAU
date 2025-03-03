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

; --- Configuración inicial ---
repoUrl    := "https://api.github.com/repos/JUST3EXT/CAU/releases/latest"
localFile  := A_ScriptFullPath
tempFile   := A_Temp "\CAUJUS.exe"    ; Ruta temporal para el ejecutable descargado
currentVersion := "1.0"               ; Versión actual del script

; --- Función para obtener la última versión desde GitHub ---
GetLatestReleaseVersion() {
    global repoUrl
    HttpObj := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    HttpObj.Open("GET", repoUrl)
    HttpObj.SetRequestHeader("User-Agent", "AutoHotkey Script")
    HttpObj.Send()
    response := HttpObj.ResponseText
    version := ""
    ; Se utiliza una variable auxiliar 'm' para capturar el primer grupo (X.Y.Z)
    if RegExMatch(response, """tag_name"":""v(\d+\.\d+\.\d+)""", m)
        version := m1
    return version
}

; --- Función para descargar la última versión del ejecutable ---
DownloadLatestVersion() {
    global tempFile
    latestVersion := GetLatestReleaseVersion()
    ; Se construye la URL de descarga usando la versión obtenida
    downloadUrl := "https://github.com/JUST3EXT/CAU/releases/download/v" latestVersion "/CAUJUS.exe"
    UrlDownloadToFile, %downloadUrl%, %tempFile%
    return FileExist(tempFile)
}

; --- Función para verificar y actualizar el script ---
CheckForUpdates() {
    global currentVersion
    latestVersion := GetLatestReleaseVersion()
    ; Se asume que WriteLog y WriteError están definidas en otra parte
    WriteLog("Comprobando actualizaciones... Versión actual: " currentVersion)
    if (latestVersion != "" && latestVersion != currentVersion) {
        WriteLog("Nueva versión disponible: " latestVersion)
        MsgBox, Hay una nueva versión disponible: %latestVersion%`nActualizando el script...
        if (DownloadLatestVersion()) {
            WriteLog("Script actualizado correctamente a la versión " latestVersion)
            MsgBox, Script actualizado correctamente. Se reiniciará ahora.
            RunUpdateScript()
            ExitApp
        } else {
            WriteError("*** ERROR *** Error al descargar la nueva versión.")
            MsgBox, Error al descargar la nueva versión.
        }
    } else {
        WriteLog("No se encontraron nuevas actualizaciones.")
    }
}

; --- Función para ejecutar el script de actualización ---
RunUpdateScript() {
    global localFile, tempFile
    ; Se crea un script auxiliar en el directorio temporal
    updateScript =
    (
    Sleep, 2000
    ; Espera a que el proceso actual se cierre utilizando A_PID
    Process, WaitClose, %A_PID%
    ; Mueve el archivo descargado al lugar del script actual
    FileMove, %tempFile%, %localFile%, 1
    ; Ejecuta el script actualizado
    Run, %localFile%
    ExitApp
    )
    FileAppend, %updateScript%, %A_Temp%\UpdateScript.ahk
    Run, %A_Temp%\UpdateScript.ahk
}

; --- Inicio de la verificación de actualizaciones ---
CheckForUpdates()


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
    } catch e {
        WriteError("Actualizando letra del DNI: " . e.Message)
    }
    Return

CheckRemedy()
{
    IfWinExist, ahk_exe aruser.exe
    {
        return true
    }
    else
    {
        MsgBox, Error, el programa Remedy no se encuentra abierto.
        WriteLog("Error, el programa Remedy no se encuentra abierto")
        return false
    }
}

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
         if (!CheckRemedy())
    {
        return
    }
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
    if (!CheckRemedy())
    {
        return
    }
    try {
        BlockInput, On
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
        finally
    {
        BlockInput, Off ; Desbloquea el teclado y el ratón
    }
    Return

;Busca incidencia por selección

F19::
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
