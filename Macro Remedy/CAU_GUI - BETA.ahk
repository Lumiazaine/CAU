#SingleInstance Force
#NoEnv
#MaxHotkeysPerInterval 99000000
#HotkeyInterval 99000000
#KeyHistory 0
#Persistent
DetectHiddenWindows, On
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
; Variables globales
global repoUrl, downloadUrl, localFile, logFilePath, tempFile
dni:=""
telf:= ""
letters := "TRWAGMYFPDXBNJZSQVHLCKE"
FileRead, Cierrepass, C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\Cierrepass.txt

; Función para calcular letra dni
CalculateDNILetter(dniNumber) {
    global letters
    if (dniNumber = "" || !RegExMatch(dniNumber, "^\d{1,8}$")) {
        return ""
    }
    index := Mod(dniNumber, 23)
    return SubStr(letters, index + 1, 1)
}

; Función para obtener la ruta del log
GetLogPath() {
    FormatTime, LogFileName,, MMMMyyyy
    StringReplace, LogFileName, LogFileName, %A_Space%, _, All
    return A_MyDocuments "\log_" LogFileName ".txt"
}

; Función para registrar logs
WriteLog(action) {
    global currentVersion
    LogFilePath := GetLogPath()
    FormatTime, DateTime,, yyyy-MM-dd HH:mm:ss
    FileAppend, %DateTime% - %A_ComputerName% - %A_UserName% - [v%currentVersion%] - %action%`n, %LogFilePath%
    FileSetAttrib, +H, %LogFilePath%
}

; Función para registrar errores
WriteError(errorMessage) {
    global currentVersion
    LogFilePath := GetLogPath()
    FormatTime, DateTime,, yyyy-MM-dd HH:mm:ss
    FileAppend, %DateTime% - %A_ComputerName% - %A_UserName% - [v%currentVersion%] - *** ERROR: %errorMessage% ***`n, %LogFilePath%
    FileSetAttrib, +H, %LogFilePath%
}

; Versión actual del script (usar el mismo formato que se espera en GitHub)
currentVersion := "1.0.0"

; URL del repositorio de GitHub (último release)
repoUrl := "https://api.github.com/repos/JUST3EXT/CAU/releases/latest"

; Ruta temporal para el archivo descargado
tempFile := A_Temp "\CAU_GUI.exe"

; Ruta del archivo actual (se asume que es un ejecutable compilado)
localFile := A_ScriptFullPath


; Función para obtener la última versión desde GitHub
GetLatestReleaseVersion() {
    global repoUrl
    HttpObj := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    HttpObj.Open("GET", repoUrl, false)
    HttpObj.SetRequestHeader("User-Agent", "AutoHotkey Script")
    HttpObj.Send()
    response := HttpObj.ResponseText
    version := ""
    ; Se permite opcionalmente la "v" en el tag
    if RegExMatch(response, """tag_name"":""v?(\d+\.\d+\.\d+)""", match)
        version := match1
    return version
}

; Función para descargar la última versión del ejecutable
DownloadLatestVersion() {
    global tempFile
    latestVersion := GetLatestReleaseVersion()
    if (latestVersion = "") {
        return false
    }
    downloadUrl := "https://github.com/JUST3EXT/CAU/releases/download/v" latestVersion "/CAU_GUI.exe"
    UrlDownloadToFile, %downloadUrl%, %tempFile%
    return FileExist(tempFile)
}

; Función para ejecutar el script de actualización (script auxiliar temporal)
RunUpdateScript() {
    global localFile, tempFile
    updateScript =
    (
        Sleep, 2000
        ; Intentar mover el archivo en un bucle hasta que sea posible
        Loop {
            FileMove, %tempFile%, %localFile%, 1
            if (ErrorLevel = 0)
                break
            Sleep, 500
        }
        Run, %localFile%
        ExitApp
    )
    ; Guardar y ejecutar el script auxiliar
    FileDelete, %A_Temp%\UpdateScript.ahk  ; Borrar si existe uno anterior
    FileAppend, %updateScript%, %A_Temp%\UpdateScript.ahk
    Run, %A_Temp%\UpdateScript.ahk
}

; Función para comprobar y actualizar el script
CheckForUpdates() {
    global currentVersion
    latestVersion := GetLatestReleaseVersion()
    WriteLog("Comprobando actualizaciones... Versión actual: " currentVersion)
    if (latestVersion != "" && latestVersion != currentVersion) {
        WriteLog("Nueva versión disponible: " latestVersion)
        ; Preguntar al usuario si desea actualizar (puedes quitar el prompt si prefieres la actualización silenciosa)
        MsgBox, 4,, Hay una nueva versión disponible: %latestVersion%`n¿Deseas actualizar el script?
        IfMsgBox, Yes
        {
            if (DownloadLatestVersion()) {
                WriteLog("Script actualizado correctamente a la versión " latestVersion)
                MsgBox, Script actualizado correctamente. Se reiniciará ahora.
                RunUpdateScript()
                ExitApp
            } else {
                WriteError("*** ERROR *** Error al descargar la nueva versión.")
                MsgBox, Error al descargar la nueva versión.
            }
        }
    } else {
        WriteLog("No se encontraron nuevas actualizaciones.")
    }
}

; Comprobar actualizaciones al iniciar el script
CheckForUpdates()

;Log inicialización del programa

Try {
    WriteLog("Ejecutando aplicación")
} catch e {
    WriteError("Error ejecutando la aplicación: " . e.Message)
}

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
Gui Add, Button, x49 y57 w183 h68 gButton1, Adriano
Gui Add, Button, x49 y137 w183 h68 gButton2, Escritorio judicial
Gui Add, Button, x431 y56 w183 h68 gButton3, Arconte
Gui Add, Button, x50 y285 w183 h68 gButton4, PortafirmasNG
Gui Add, Button, x241 y56 w183 h68 gButton5, Agenda de señalamientos
Gui Add, Button, x241 y136 w183 h68 gButton6, Expediente digital
Gui Add, Button, x50 y212 w183 h68 gButton7, Hermes
Gui Add, Button, x240 y210 w183 h68 gButton8, Jara
Gui Add, Button, x432 y209 w183 h68 gButton9, Quenda // Cita previa
Gui Add, Button, x240 y284 w183 h68 gButton10, Suministros
Gui Add, Button, x242 y478 w183 h68 gButton11, Internet libre
Gui Add, Button, x52 y548 w183 h68 gButton12, Multiconferencia
Gui Add, Button, x432 y408 w183 h68 gButton13, Dragon Speaking
Gui Add, Button, x242 y408 w183 h68 gButton14, Aumento espacio correo
Gui Add, Button, x52 y408 w183 h68 gButton15, Abbypdf
Gui Add, Button, x52 y478 w183 h68 gButton16, GDU
Gui Add, Button, x741 y476 w183 h68 gButton17, Orfila
Gui Add, Button, x740 y406 w183 h68 gButton18, Lexnet
Gui Add, Button, x742 y547 w183 h68 gButton19, Siraj2
Gui Add, Button, x431 y134 w183 h68 gButton20, Emparejamiento ISL
Gui Add, Button, x642 y127 w183 h68 gButton21, Certificado digital
Gui Add, Button, x831 y57 w183 h68 gButton22, Software
Gui Add, Button, x831 y128 w183 h68 gButton23, PIN tarjeta
Gui Add, Button, x643 y199 w183 h68 gButton24, Servicio no CEIURIS
Gui Add, Button, x1234 y198 w183 h68 gButton25, Lector tarjeta
Gui Add, Button, x1045 y197 w183 h68 gButton26, Equipo sin red
Gui Add, Button, x1233 y57 w183 h68 gButton27, GM
Gui Add, Button, x1137 y483 w183 h68 gButton28, Teléfono
Gui Add, Button, x1046 y410 w183 h68 gButton29, Ganes
Gui Add, Button, x1045 y268 w183 h68 gButton30, Equipo no enciende
Gui Add, Button, x1045 y57 w183 h68 gButton31, Disco duro
Gui Add, Button, x1045 y127 w183 h68 gButton32, Edoc Fortuny
Gui Add, Button, x832 y199 w183 h68 gButton33, @Driano
Gui Add, Button, x432 y478 w183 h68 gButton34, Intervención video
Gui Add, Button, x1235 y267 w183 h68 gButton35, Monitor
Gui Add, Button, x1236 y410 w183 h68 gButton36, Teclado
Gui Add, Button, x1236 y338 w183 h68 gButton37, Ratón
Gui Add, Button, x1233 y127 w183 h68 gButton38, ISL Apagado
Gui Add, Button, x1045 y339 w183 h68 gButton39, Error relación de confianza
Gui Add, Button, x642 y56 w183 h68 gButton40, Contraseñas
Gui Add, Button, x244 y549 w183 h68 gButton41, Formaciones
Gui Add, Button, x1050 y635 w80 h23 gButton42, Buscar
Gui, Add, Checkbox, vModoSeguro x1200 y635 w80 h23, Modo Seguro
Gui Show, w1456 h704, Gestor de incidencias

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

screen()
{
    try {
        SetTitleMatchMode, 2
        WinActivate, ahk_class ArFrame
        WriteLog("Activó la ventana ArFrame")
    } catch e {
        WriteError("Activando ventana ArFrame: " . e.Message)
    }
    Return
}

; Función auxiliar para ejecutar macros Alba estándar con log integrado
ExecuteAlbaMacro(num, description) {
    global dni, telf
    if (!CheckRemedy())
        return
    
    try {
        WriteLog("Iniciando macro: " . description . " (Alba " . num . ")")
        Alba(num)
        Gui, Submit, NoHide
        
        ; Introducir datos en Remedy
        if (dni != "") {
            Send, %dni%{Tab}{Enter}
            Sleep, 200
        }
        
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        
        if (telf != "") {
            Send, %telf%
        }
        
        ; Limpiar campos en la GUI
        GuiControl,, dni
        GuiControl,, telf
        
        WriteLog("Finalizado: " . description . " [DNI: " . dni . ", Telf: " . telf . "]")
    } catch e {
        WriteError("Error en macro " . description . " (Alba " . num . "): " . e.Message)
    }
}

Alba(num) {
    if (!CheckRemedy())
    {
        return
    }
    
    try {
        ; --- Rutas de script ---
        psScriptPath := "C:\Alba.ps1"
        psWorkDir  := "C:\"
        
        ; --- COMPROBACIÓN DE ARCHIVO ---
        ; Comprueba si el archivo NO existe
        If !FileExist(psScriptPath)
        {
            MsgBox, 48, Error de Script, No se pudo encontrar el archivo de PowerShell en la ruta:%n%n%psScriptPath%
            Return ; Aborta la macro si no se encuentra el archivo
        }
        BlockInput, On ; Bloquea el teclado y el ratón
        psComando := "& '" . psScriptPath . "'"
        RunWait, powershell.exe -NoProfile -ExecutionPolicy Bypass -Command %psComando%, %psWorkDir%, Hide
        screen()
        Send, ^i
        Sleep, 300 
        Send, {TAB 2}{End}{Up %num%}{Enter}
        Sleep, 300 
        Send, {TAB 22}
        WriteLog("Ejecutó la macro Alba con parámetro " . num)
        
    } catch e {
        WriteError("Ejecutando macro Alba: " . e.Message)
    }
    finally
    {
        BlockInput, Off ; Desbloquea el teclado y el ratón
    }
    Return
}

;Función para realizar el proceso de cierre de una incidencia, recibe como parámetro el texto a introducir en el campo de cierre

cierre(closetext)
{
    try {
        Sleep, 800
        Send, ^{enter}{Enter}
        Sleep, 800
        SendInput, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
        SendInput, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}%closetext%{Tab}{Enter}
        
        WriteLog("Cierre ejecutado con texto: " . closetext)
    } catch e {
        WriteError("Cierre ejecutado con texto: " . e.Message)
    }
}

KeepActive:
    Try {
        if (IsActive)
        {
            MouseGetPos, xpos, ypos
            MouseMove, %xpos%, %ypos%, 0
            Send, {Shift}
            WriteLog("Se movió mouse")
            Return
        } 
    } catch e {
        WriteError("Se movió mouse " . e.Message)
    }

Button1:
    ExecuteAlbaMacro(42, "Adriano")
    Return
Button2:
    ExecuteAlbaMacro(29, "Escritorio judicial")
    Return
Button3:
    ExecuteAlbaMacro(39, "Arconte")
    Return
Button4:
    ExecuteAlbaMacro(9, "PortafirmasNG")
    Return
Button5:
    ExecuteAlbaMacro(41, "Agenda de señalamientos")
    Return
Button6:
    ExecuteAlbaMacro(28, "Expediente digital")
    Return
Button7:
    ExecuteAlbaMacro(22, "Hermes")
    Return
Button8:
    ExecuteAlbaMacro(18, "Jara")
    Return
Button9:
    ExecuteAlbaMacro(0, "Quenda // Cita previa")
    Return
Button10:
    ExecuteAlbaMacro(4, "Suministros")
    Return
Button11:
    ExecuteAlbaMacro(21, "Internet libre")
    Return
Button12:
    ExecuteAlbaMacro(14, "Multiconferencia")
    Return
Button13:
    ExecuteAlbaMacro(32, "Dragon Speaking")
    Return
Button14:
    ExecuteAlbaMacro(38, "Aumento espacio correo")
    Return
Button15:
    ExecuteAlbaMacro(44, "Abbypdf")
    Return
Button16:
    if (!CheckRemedy())
        return
    try {
        Alba(24)
        Gui, Submit, NoHide
        Send, %dni%{Tab}{Enter}{Tab 3}+{Left 90}{BackSpace}%telf%
        if (dni != "" && DNILetter != "") {
            Clipboard := dni . DNILetter
        }
        GuiControl,, dni
        GuiControl,, telf
        WriteLog("Ejecutó macro GDU (Alba 24) - DNI en portapapeles: " . (dni . DNILetter))
    } catch e {
        WriteError("Error en macro GDU (Alba 24): " . e.Message)
    }
    Return
Button17:
    ExecuteAlbaMacro(12, "Orfila")
    Return
Button18:
    ExecuteAlbaMacro(16, "Lexnet")
    Return
Button19:
    ExecuteAlbaMacro(6, "Siraj2")
    Return
Button20:
    ExecuteAlbaMacro(30, "Emparejamiento ISL")
    Return
Button21:
    ExecuteAlbaMacro(37, "Certificado digital")
    Return
Button22:
    ExecuteAlbaMacro(5, "Software")
    Return
Button23:
    ExecuteAlbaMacro(11, "PIN tarjeta")
    Return
Button24:
    ExecuteAlbaMacro(10, "Servicio no CEIURIS")
    Return
Button25:
    ExecuteAlbaMacro(17, "Lector tarjeta")
    Return
Button26:
    ExecuteAlbaMacro(7, "Equipo sin red")
    Return
Button27:
    ExecuteAlbaMacro(23, "GM")
    Return
Button28:
    ExecuteAlbaMacro(2, "Teléfono")
    Return
Button29:
    ExecuteAlbaMacro(25, "Ganes")
    Return
Button30:
    ExecuteAlbaMacro(26, "Equipo no enciende")
    Return
Button31:
    ExecuteAlbaMacro(33, "Disco duro")
    Return
Button32:
    ExecuteAlbaMacro(31, "Edoc Fortuny")
    Return
Button33:
    ExecuteAlbaMacro(13, "@Driano")
    Return
Button34:
    ExecuteAlbaMacro(20, "Intervención video")
    Return
Button35:
    ExecuteAlbaMacro(15, "Monitor")
    Return
Button36:
    ExecuteAlbaMacro(3, "Teclado")
    Return
Button37:
    ExecuteAlbaMacro(8, "Ratón")
    Return
Button38:
    ExecuteAlbaMacro(19, "ISL Apagado")
    Return
Button39:
    ExecuteAlbaMacro(36, "Error relación de confianza")
    Return
Button40:
    ExecuteAlbaMacro(35, "Contraseñas")
    Return
Button41:
    ExecuteAlbaMacro(27, "Formaciones")
    Return
Button42:
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
; Función auxiliar para ejecutar macros Alba con cierre automático
ExecuteAlbaMacroWithClose(num, description, closureText := "") {
    global Cierrepass
    if (closureText = "")
        closureText := Cierrepass
    
    ExecuteAlbaMacro(num, description)
    cierre(closureText)
    WriteLog("Cierre automático ejecutado para: " . description)
}

#1::
    ExecuteAlbaMacro(0, "Combinación #1 (Macro Base)")
    Return
#2::
    ExecuteAlbaMacroWithClose(43, "Combinación #2 (Cierre Estándar)")
    Return
#3::
    ExecuteAlbaMacro(34, "Combinación #3 (Cierre Estándar)")
    Return
#4::
    ExecuteAlbaMacro(40, "Combinación #4 (Cierre Estándar)")
    Return
#5::
    ExecuteAlbaMacro(1, "Combinación #5 (Cierre Estándar)")
    Return
; Macro para repetir incidencias el número que se desee 
#6::
    if (!CheckRemedy()) {
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

    Loop %repeatCount%
    {
        try {
            Alba(42)
            Sleep, 1500
            MsgBox, 64, Estado de Macro, Macro ejecuntandose %A_Index% de %repeatCount% no tocar.,1
            WriteLog("Macro repeticion (Iteración: " . A_Index . ")")
            Send, {Enter}
            Send, {Tab 36}{Enter}{Enter}
            Sleep, 1000
            FileRead, Correo, C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\correo.txt
            A_Clipboard := Correo
            Send, {Enter}
            Send, ^v
            Send, {Tab}{Enter}{Enter}
            Sleep, 1000
            Send, {Tab 15}{Right 2}
            cierre("Se notifica por correo tras acoplamiento completado. Se procede al cierre de las incidencias a petición del procedimiento.")
            Sleep, 1500
        } catch e {
            WriteError("Error en iteración " . A_Index . ": " . e.Message)
        }
        Sleep 1000  ; Puedes ajustar el tiempo de espera si es necesario
    }
    MsgBox, % "Se ha completado correctamente " . repeatCount . " veces."
    return
/*
                                ACOPLAMIENTO FASE NUMO
                            Importante para cierre de mantenimiento AD TEMIS

try {
Alba(42)
Sleep, 1500
MsgBox, 64, Estado de Macro, Macro ejecuntandose %A_Index% de %repeatCount% no tocar.,1
WriteLog("Macro repeticion (Iteración: " . A_Index . ")")
Send, {Enter}
Send, {Tab 36}{Enter}{Enter}
Sleep, 1000
FileRead, Correo, C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\correo.txt
A_Clipboard := Correo
Send, {Enter}
Send, ^v
Send, {Tab}{Enter}{Enter}
Sleep, 1000
Send, {Tab 15}{Right 2}
cierre("Se notifica por correo tras acoplamiento completado. Se procede al cierre de las incidencias a petición del procedimiento.")
Sleep, 1500

*/



    /*
    Individual corregido
    Send, {Enter}
    Send, {Tab 36}{Enter}{Enter}
    Sleep, 1000
    FileRead, Correo, C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\correo.txt
    A_Clipboard := Correo
    Send, {Enter}
    Send, ^v
    Send, {Tab}{Enter}{Enter}
    Sleep, 1000
    Send, {Tab 15}{Right 2}
    cierre("Se notifica por correo tras acoplamiento completado. Se procede al cierre de las incidencias a petición del procedimiento.")
    return
    */


#7:: ; AFK mode
    if (!CheckRemedy())
        return
    try {
        Toggle := !Toggle
        if (Toggle) {
            SetTimer, KeepActive, 60000
            IsActive := true
            MsgBox, 64, Gestor, Modo AFK activado.
            WriteLog("Modo AFK ACTIVADO")
        } else {
            SetTimer, KeepActive, Off
            IsActive := false
            MsgBox, 64, Gestor, Modo AFK desactivado.
            WriteLog("Modo AFK DESACTIVADO")
        }
    } catch e {
        WriteError("Cambiando modo AFK: " . e.Message)
    }
    Return

    Return

;; Macro llamadas automáticas openscape
#8::
    try {
        WriteLog("Iniciando marcación automática OpenScape")
        Send, {End}^+{Up}^{c}
        WinShow, ahk_class WindowsForms10.Window.8.app.0.25bb5ff_r8_ad1
        WinRestore, ahk_class WindowsForms10.Window.8.app.0.25bb5ff_r8_ad1
        WinActivate, ahk_class WindowsForms10.Window.8.app.0.25bb5ff_r8_ad1
        WinWaitActive, ahk_class WindowsForms10.Window.8.app.0.25bb5ff_r8_ad1
        Sleep, 1000
        Send, {Alt down}{Alt up}10^v{Enter}
        Sleep, 3000
        Send, {Alt down}{Alt up}4
        Sleep, 12000
        Send, {Alt down}{Alt up}3
        WriteLog("Finalizada marcación OpenScape")
    } catch e {
        WriteError("Error en marcación OpenScape: " . e.Message)
    }
    Return

#9::
    if (!CheckRemedy())
        return
    try {
        Gui, Submit, NoHide
        Alba(0)
        Send, {F3}{Enter}{Tab 5}%Inci%^{Enter}
        GuiControl,, Inci
        WriteLog("Ejecutó búsqueda rápida (#9) con IN: " . Inci)
    } catch e {
        WriteError("Error en búsqueda rápida #9: " . e.Message)
    }
    Return

#0::
    WriteLog("Solicitando recarga del script (Reload)")
    Reload
    Return

XButton1::
    if (!CheckRemedy())
        return
    try {
        screen()
        Send, {Alt}a{Down 9}{Right}{Enter}
        WriteLog("Ejecutó macro rápida de menú con XButton1")
    } catch e {
        WriteError("Error en XButton1: " . e.Message)
    }
    Return

XButton2::
    WriteLog("Ejecutó captura de pantalla (Win+Shift+S) con XButton2")
    Send, #+s
    Return
/*
Button42:
    if (!CheckRemedy())
        return
    try {
        Gui, Submit, NoHide
        Alba(0)
        Send, {F3}{Enter}{Tab 5}%Inci%^{Enter}
        GuiControl,, Inci
        WriteLog("Pulsó el botón Buscar con IN: " . Inci)
    } catch e {
        WriteError("Pulsando botón Buscar: " . e.Message)
    }
    Return
    ExecuteAlbaMacro(0, "Macro F13")
    Return
*/

F14::
    ExecuteAlbaMacroWithClose(43, "Macro F14")
    Return
F15::
    ExecuteAlbaMacroWithClose(34, "Macro F15")
    Return
F16::
    ExecuteAlbaMacroWithClose(40, "Macro F16")
    Return
F17::
    ExecuteAlbaMacroWithClose(1, "Macro F17")
    Return
F18::
    if (!CheckRemedy())
        return
    try {
        Send, ^c
        Alba(0)
        Send, {F3}{Enter}{Tab 5}^v^{Enter}
        WriteLog("Ejecutó búsqueda F18 con texto del portapapeles")
    } catch e {
        WriteError("Error en búsqueda F18: " . e.Message)
    }
    Return
F12::
F19::
    if (!CheckRemedy())
        return
    try {
        Gui, Submit, NoHide
        Alba(0)
        Send, {F3}{Enter}{Tab 5}%Inci%^{Enter}
        GuiControl,, Inci
        WriteLog("Ejecutó búsqueda (F12/F19) con IN: " . Inci)
    } catch e {
        WriteError("Error en búsqueda F12/F19: " . e.Message)
    }
    Return
F20::
    ExecuteAlbaMacroWithClose(30, "Macro F20 (Emparejamiento)", "Se empareja equipo correctamente y se indica contraseña ISL se cierra ticket.")
    Return

GuiEscape:
GuiClose:
    try {
        WriteLog("Cerró la aplicación")
        ExitApp
    } catch e {
        WriteError("Cerrando la aplicación: " . e.Message)
    }