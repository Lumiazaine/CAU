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
dni:=""
telf:= ""
letters := "TRWAGMYFPDXBNJZSQVHLCKE"

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
    } catch e {
        WriteError("Actualizando letra del DNI: " . e.Message)
    }
    Return

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

Alba(num)
{
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

cierre(closetext)
{
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
    try{
        Alba(42)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button2:
    try{
        Alba(29)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button3:
    try{
        Alba(39)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button4:
    try{
        Alba(9)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button5:
    try{
        Alba(41)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button6:
    try{
        Alba(28)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button7:
    try{
        Alba(22)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button8:
    try{
        Alba(18)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button9:
    try{
        Alba(0)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button10:
    try{
        Alba(4)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button11:
    try{
        Alba(21)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button12:
    try{
        Alba(14)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button13:
    try{
        Alba(32)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button14:
    try{
        Alba(38)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button15:
    try{
        Alba(44)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button16:
    Alba(24)
    Gui, Submit, NoHide
    Send, %dni%
    Send, {Tab}{Enter}
    Send, {Tab 3}
    Send, +{Left 90}{BackSpace}
    Send, %telf%
    if (dni != "" && DNILetter != "") {
        Clipboard := dni . DNILetter
    }
    GuiControl, , dni
    GuiControl, , telf
    Return
Button17:
    try{
        Alba(12)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button18:
    try{
        Alba(16)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button19:
    try{
        Alba(6)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button20:
    try{
        Alba(30)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button21:
    try{
        Alba(37)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button22:
    try{
        Alba(5)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button23:
    try{
        Alba(11)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button24:
    try{
        Alba(10)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button25:
    try{
        Alba(17)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button26:
    try{
        Alba(7)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button27:
    try{
        Alba(23)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button28:
    try{
        Alba(2)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button29:
    try{
        Alba(25)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button30:
    try{
        Alba(26)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button31:
    try{
        Alba(33)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button32:
    try{
        Alba(31)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button33:
    try{
        Alba(13)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button34:
    try{
        Alba(20)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button35:
    try{
        Alba(15)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button36:
    try{
        Alba(3)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button37:
    try{
        Alba(8)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button38:
    try{
        Alba(19)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button39:
    try{
        Alba(36)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button40:
    try{
        Alba(35)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button41:
    try{
        Alba(27)
        Gui, Submit, NoHide
        Send, %dni%
        Send, {Tab}{Enter}
        Send, {Tab 3}
        Send, +{Left 90}{BackSpace}
        Send, %telf%
        GuiControl, , dni
        GuiControl, , telf
        WriteLog("Ejecutó macro alba " .dni "y" .telf)
    } catch e {
        WriteError("Error ejecutando macro " . .e.Message)
    }
    Return
Button42:
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
#2::
    Alba(43)
    Gui, Submit, NoHide
    Send, %dni%
    Send, {Tab}{Enter}
    Send, {Tab 3}
    Send, +{Left 90}{BackSpace}
    Send, %telf%
    GuiControl, , dni
    GuiControl, , telf
    cierre("Se cambia contrase{U+00F1}a de AD.")
    Return
#3::
    Alba(34)
    Gui, Submit, NoHide
    Send, %dni%
    Send, {Tab}{Enter}
    Send, {Tab 3}
    Send, +{Left 90}{BackSpace}
    Send, %telf%
    GuiControl, , dni
    GuiControl, , telfsi 
    Return
#4::
    Alba(40)
    Gui, Submit, NoHide
    Send, %dni%
    Send, {Tab}{Enter}
    Send, {Tab 3}
    Send, +{Left 90}{BackSpace}
    Send, %telf%
    GuiControl, , dni
    GuiControl, , telf
    Return
#5::
    Alba(1)
    Gui, Submit, NoHide
    Send, %dni%
    Send, {Tab}{Enter}
    Send, {Tab 3}
    Send, +{Left 90}{BackSpace}
    Send, %telf%
    GuiControl, , dni
    GuiControl, , telf
    Return
#7:: ; AFK mode
try{
    SetTimer, KeepActive, 60000 
        Toggle := !Toggle
        if (Toggle)
        {
            SetTimer, KeepActive, On
            IsActive := true
            MsgBox, 64, Modo AFK activado.
            WriteLog("Activó modo afk")
        }
        else
        {
            SetTimer, KeepActive, Off
            IsActive := false
            MsgBox, 64, Modo AFK desactivado.
            WriteLog("Desactivó modo afk")
        }} catch e {
            WriteError("Error ejecutando modo afk " . e.Message)
        }

    Return
#9::
    Alba(0)
    Send, {F3}{Enter}{Tab 5}
    Gui, Submit, NoHide
    Send, %Inci%
    Send, ^{Enter}
    GuiControl, , Inci
    Return
#0::Reload
    try {
        WriteLog("Recargó el script")
    } catch e {
        WriteError("Recargando el script: " . e.Message)
    }
Return

XButton1::
    Send, !a{Down 9}{Right}{Enter}
    Return
XButton2::
    screen()
    Send, #+s
    Return
F13::
    Alba(0)
    Gui, Submit, NoHide
    Send, %dni%
    Send, {Tab}{Enter}
    Send, {Tab 3}
    Send, +{Left 90}{BackSpace}
    Send, %telf%
    GuiControl, , dni
    GuiControl, , telf
    Return
F14::
    Alba(43)
    Gui, Submit, NoHide
    Send, %dni%
    Send, {Tab}{Enter}
    Send, {Tab 3}
    Send, +{Left 90}{BackSpace}
    Send, %telf%
    GuiControl, , dni
    GuiControl, , telf
    cierre("Se cambia contrase{U+00F1}a de AD.")
    Return
F15::
    Alba(34)
    Gui, Submit, NoHide
    Send, %dni%
    Send, {Tab}{Enter}
    Send, {Tab 3}
    Send, +{Left 90}{BackSpace}
    Send, %telf%
    GuiControl, , dni
    GuiControl, , telf
    cierre("Se cambia contrase{U+00F1}a de correo.")
    Return
F16::
    Alba(40)
    Gui, Submit, NoHide
    Send, %dni%
    Send, {Tab}{Enter}
    Send, {Tab 3}
    Send, +{Left 90}{BackSpace}
    Send, %telf%
    GuiControl, , dni
    GuiControl, , telf
    cierre("Se cambia contrase{U+00F1}a de Aurea.")
    Return
F17::
    Alba(1)
    Gui, Submit, NoHide
    Send, %dni%
    Send, {Tab}{Enter}
    Send, {Tab 3}
    Send, +{Left 90}{BackSpace}
    Send, %telf%
    GuiControl, , dni
    GuiControl, , telf
    cierre("Se cambia contrase{U+00F1}a Temis.")
    Return
F18::
    Send, ^c
    Alba(0)
    Send, {F3}{Enter}{Tab 5}
    Gui, Submit, NoHide
    Send, ^v
    Send, ^{Enter}
    Return
F12::
    Alba(0)
    Send, {F3}{Enter}{Tab 5}
    Gui, Submit, NoHide
    Send, %Inci%
    Send, ^{Enter}
    GuiControl, , Inci
    Return
F19::
    Alba(0)
    Send, {F3}{Enter}{Tab 5}
    Gui, Submit, NoHide
    Send, %Inci%
    Send, ^{Enter}
    GuiControl, , Inci
    Return
F20::
    Alba(30)
    Gui, Submit, NoHide
    Send, %dni%
    Send, {Tab}{Enter}
    Send, {Tab 3}
    Send, +{Left 90}{BackSpace}
    Send, %telf%
    GuiControl, , dni
    GuiControl, , telf
    cierre("Se empareja equipo correctamente y se indica contrase{U+00F1}a ISL se cierra ticket.")
    Return

GuiEscape:
GuiClose:
    try {
        WriteLog("Cerró la aplicación")
        ExitApp
    } catch e {
        WriteError("Cerrando la aplicación: " . e.Message)
    }