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
FileRead, Cierrepass, C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\Cierres\Cierrepass.txt

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

;Log inicialización del programa
Try {
    WriteLog("Ejecutando aplicación")
} catch e {
    WriteError("Error ejecutando la aplicación: " . e.Message)
}
Gui, 1:Font,, Segoe UI

;Bloque 1 solicitudes.
Gui, 1:Add, Text, x144 y16 w98 h19, SOLICITUDES
Gui, 1:Add, Button, x40 y40 w136 h46 gButton4, GDU
Gui, 1:Add, Button, x176 y40 w136 h46 gButton3, Aumento espacio correo
Gui, 1:Add, Button, x40 y88 w136 h46 gButton16, Intervención video
Gui, 1:Add, Button, x176 y88 w136 h46 gButton24, Formaciones
Gui, 1:Add, Button, x40 y136 w136 h46 gButton1, Internet libre
Gui, 1:Add, Button, x176 y136 w136 h46gButton2, Multiconferencia

; Bloque 2 cierres.
Gui, 1:Add, Text, x464 y16 w67 h18, CIERRES
Gui, 1:Add, Button, x344 y40 w136 h46 gButton23, Contraseñas
Gui, 1:Add, Button, x480 y40 w136 h46 gButton7, Software
Gui, 1:Add, Button, x344 y88 w136 h46 gButton6, Certificado digital
Gui, 1:Add, Button, x480 y88 w136 h46 gButton8, PIN tarjeta
Gui, 1:Add, Button, x344 y136 w136 h46 gButton9, Servicio no CEIURIS
Gui, 1:Add, Button, x480 y136 w136 h46 gButton5, Emparejamiento ISL

;Bloque 3 DP.
Gui, 1:Add, Text, x840 y16 w25 h17, DP
Gui, 1:Add, Button, x640 y40 w136 h46 gButton15, Disco duro
Gui, 1:Add, Button, x776 y40 w136 h46 gButton12, GM
Gui, 1:Add, Button, x912 y40 w136 h46 gButton11, Equipo sin red
Gui, 1:Add, Button, x640 y88 w136 h46 gButton22, ISL Apagado
Gui, 1:Add, Button, x776 y88 w136 h46 gButton14, Equipo no enciende
Gui, 1:Add, Button, x912 y88 w136 h46 gButton10, Lector tarjeta
Gui, 1:Add, Button, x640 y136 w136 h46 gButton21, Ratón
Gui, 1:Add, Button, x776 y136 w136 h46 gButton17, Monitor
Gui, 1:Add, Button, x912 y136 w136 h46 gButton13, Teléfono
Gui, 1:Add, Button, x776 y184 w136 h46 gButton18, Teclado

;Bloque 4 DNI

Gui, 1:Add, Text, x136 y272 w33 h21, DNI
Gui, 1:Add, Edit, x176 y264 w188 h26 gUpdateLetter vdni, %dni%
Gui, 1:Add, Edit, vDNILetter x368 y264 w20 h26 +ReadOnly

;Bloque 5 Teléfono

Gui, 1:Add, Text, x392 y272 w76 h21, TELÉFONO
Gui, 1:Add, Edit, x448 y264 w188 h26 vtelf, %telf%

;Bloque 6 Búsqueda incidencias

Gui, 1:Add, Text, x648 y272 w23 h21, IN
Gui, 1:Add, Edit, x664 y264 w188 h26 vInci, %Inci%
Gui, 1:Add, Button, x872 y264 w80 h23 gButton25, Buscar

; Mostrar la ventana 1
Gui, 1:Show, w1083 h332, Lazybird

; GUI Macro plantillas correos
Gui, 2:Add, Button, x56 y32 w136 h46 gAccionPlantilla, NIG y captura
Gui, 2:Add, Button, x56 y80 w136 h46 gAccionPlantilla, Captura
Gui, 2:Add, Button, x56 y128 w136 h46 gAccionPlantilla, Formulario
Gui, 2:Add, Button, x56 y176 w136 h46 gAccionPlantilla, Formulario GDU
Gui, 2:Add, Button, x192 y32 w136 h46 gAccionPlantilla, Info solventada
Gui, 2:Add, Button, x192 y80 w136 h46 gAccionPlantilla, Problema general
Gui, 2:Add, Button, x192 y128 w136 h46 gAccionPlantilla, Resolución TLT
Gui, 2:Add, Button, x192 y176 w136 h46 gAccionPlantilla, Mantenimiento
Gui, 2:Add, Radio, x16 y248 w120 h23 vRadioContacto +Checked, Primer contacto
Gui, 2:Add, Radio, x144 y248 w120 h23, Segundo contacto
Gui, 2:Add, Radio, x272 y248 w120 h23, Tercer contacto

Return 

#Space::
    WriteLog("Abriendo GUI de Plantillas")
    Gui, 2:Show, w389 h286, Plantillas correos
Return

AccionPlantilla:
    MsgBox, Pulsaste %A_GuiControl%
    Gui, 2:Hide
Return

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
        BlockInput, On ; Bloquea el teclado y el ratón
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
        DllCall("SetThreadExecutionState", "UInt", 0x80000003)
        } 
    } catch e {
        WriteError("Equipo activo " . e.Message)
    }
Return

; Función auxiliar para ejecutar macros Alba con cierre automático
ExecuteAlbaMacroWithClose(num, description, closureText := "") {
    global Cierrepass
    if (closureText = "")
        closureText := Cierrepass
    
    ExecuteAlbaMacro(num, description)
    cierre(closureText)
    WriteLog("Cierre automático ejecutado para: " . description)
}

Button1:
    ExecuteAlbaMacro(12, "Internet libre")
    Return
Button2:
    ExecuteAlbaMacro(8, "Multiconferencia")
    Return
Button3:
    ExecuteAlbaMacro(21, "Aumento espacio correo")
    Return
Button4:
    ExecuteAlbaMacro(14, "GDU")
    Return
Button5:
    ExecuteAlbaMacro(17, "Emparejamiento ISL")
    Return
Button6:
    ExecuteAlbaMacro(21, "Certificado digital")
    Return
Button7:
    ExecuteAlbaMacro(4, "Software")
    Return
Button8:
    ExecuteAlbaMacro(7, "PIN tarjeta")
    Return
Button9:
    ExecuteAlbaMacro(0, "Servicio no CEIURIS")
    Return
Button10:
    ExecuteAlbaMacro(10, "Lector tarjeta")
    Return
Button11:
    ExecuteAlbaMacro(5, "Equipo sin red")
    Return
Button12:
    ExecuteAlbaMacro(13, "GM")
    Return
Button13:
    ExecuteAlbaMacro(2, "Teléfono")
    Return
Button14:
    ExecuteAlbaMacro(23, "Equipo no enciende")
    Return
Button15:
    ExecuteAlbaMacro(18, "Disco duro")
    Return
Button16:
    ExecuteAlbaMacro(24, "Intervención video")
    Return
Button17:
    ExecuteAlbaMacro(9, "Monitor")
    Return
Button18:
    ExecuteAlbaMacro(3, "Teclado")
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
Button25: ;Botón Buscar
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

;Shortcuts con cierres

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
            Send, ^{Enter}{Enter}
        } catch e {
            WriteError("Error en iteración " . A_Index . ": " . e.Message)
        }
        Sleep 1000  ; Puedes ajustar el tiempo de espera si es necesario
    }
    MsgBox, % "Se ha completado correctamente " . repeatCount . " veces."
    return
/*
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