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

; Variables globales
global repoUrl, downloadUrl, localFile, logFilePath, tempFile
dni:=""
telf:= ""
letters := "TRWAGMYFPDXBNJZSQVHLCKE"

; Función para calcular letra dni
CalculateDNILetter(dniNumber) {
    global letters
    if (dniNumber = "" || !RegExMatch(dniNumber, "^\d{1,8}$")) {
        return ""
    }
    index := Mod(dniNumber, 23)
    return SubStr(letters, index + 1, 1)
}

; Función para registrar logs
WriteLog(action) {
    ComputerName := A_ComputerName
    FormatTime, DateTime,, yyyy-MM-dd HH:mm:ss
    FormatTime, LogFileName,, MMMMyyyy
    StringReplace, LogFileName, LogFileName, %A_Space%, _, All
    LogFilePath := A_MyDocuments "\log_" LogFileName ".txt"
    FileAppend, %DateTime% - %ComputerName% - %action%`n, %LogFilePath%
    FileSetAttrib, +H, %LogFilePath%
}

; Función para registrar erores
WriteError(errorMessage) {
    ComputerName := A_ComputerName
    FormatTime, DateTime,, yyyy-MM-dd HH:mm:ss
    FormatTime, LogFileName,, MMMMyyyy
    StringReplace, LogFileName, LogFileName, %A_Space%, _, All
    LogFilePath := A_MyDocuments "\log_" LogFileName ".txt"
    FileAppend, %DateTime% - %ComputerName% - *** ERROR %errorMessage% ***`n, %LogFilePath%
    FileSetAttrib, +H, %LogFilePath%
}

; Versión actual del script (usar el mismo formato que en GitHub)
currentVersion := "1.0.0"

; URL del repositorio de GitHub (último release)
repoUrl := "https://api.github.com/repos/JUST3EXT/CAU/releases/latest"

; Rutas de archivos
tempFile := A_Temp "\CAU_GUI.exe"
localFile := A_ScriptFullPath
logFile := A_ScriptDir "\update_log.txt"

; Configuración inicial
#NoEnv
SetBatchLines, -1
FileEncoding, UTF-8

; Obtener última versión desde GitHub
GetLatestReleaseVersion() {
    global repoUrl
    try {
        HttpObj := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        HttpObj.Open("GET", repoUrl, false)
        HttpObj.SetRequestHeader("User-Agent", "CAU-Updater/1.0")
        HttpObj.Send()
        
        if (HttpObj.Status != 200) {
            throw Exception("HTTP Error: " HttpObj.Status)
        }
        
        response := HttpObj.ResponseText
        if RegExMatch(response, """tag_name"":""(v?[\d.]+)""", match) {
            return match1
        }
        return ""
    }
    catch e {
        WriteError("Falló la obtención de versión: " e.Message)
        return ""
    }
}

; Descargar última versión
DownloadLatestVersion() {
    global tempFile
    try {
        latestVersion := GetLatestReleaseVersion()
        if !latestVersion {
            return false
        }
        
        downloadUrl := "https://github.com/JUST3EXT/CAU/releases/download/" latestVersion "/CAU_GUI.exe"
        WriteLog("Iniciando descarga desde: " downloadUrl)
        
        HttpObj := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        HttpObj.Open("GET", downloadUrl, false)
        HttpObj.SetRequestHeader("User-Agent", "CAU-Updater/1.0")
        HttpObj.Send()
        
        if (HttpObj.Status != 200) {
            throw Exception("Error en descarga: HTTP " HttpObj.Status)
        }
        
        ; Guardar archivo binario correctamente
        adoStream := ComObjCreate("ADODB.Stream")
        adoStream.Type := 1 ; Tipo binario
        adoStream.Open()
        adoStream.Write(HttpObj.ResponseBody)
        adoStream.SaveToFile(tempFile, 2)
        adoStream.Close()
        
        return FileExist(tempFile)
    }
    catch e {
        WriteError("Falló la descarga: " e.Message)
        return false
    }
}

; Ejecutar script de actualización
RunUpdateScript() {
    global localFile, tempFile
    updateScript =
    (
        #NoEnv
        SetBatchLines, -1
        SetTitleMatchMode, 2
        
        tries := 0
        Loop {
            FileMove, %tempFile%, %localFile%, 1
            if !ErrorLevel
                break
            if (tries++ >= 10) {
                MsgBox, 16, Error, No se pudo reemplazar el archivo!
                ExitApp
            }
            Sleep, 1000
        }
        Run, "%localFile%"
        ExitApp
    )
    
    scriptPath := A_Temp "\CAU_Updater.ahk"
    FileDelete, %scriptPath%
    FileAppend, %updateScript%, %scriptPath%
    Run, "%scriptPath%",, Hide
}

; Comprobar actualizaciones
CheckForUpdates() {
    global currentVersion
    WriteLog("Iniciando verificación de actualizaciones...")
    WriteLog("Versión actual: " currentVersion)
    
    latestVersion := GetLatestReleaseVersion()
    if !latestVersion {
        return
    }
    
    WriteLog("Última versión disponible: " latestVersion)
    
    if (latestVersion != currentVersion) {
        MsgBox, 68, Actualización Disponible, Nueva versión %latestVersion% disponible.`n¿Deseas actualizar ahora?
        IfMsgBox, Yes
        {
            if DownloadLatestVersion() {
                WriteLog("Actualización descargada exitosamente")
                MsgBox, 64, Éxito, Actualización completada. La aplicación se reiniciará.
                RunUpdateScript()
                ExitApp
            }
        }
    } else {
        WriteLog("Ya tienes la última versión instalada")
    }
}

; Punto de entrada principal
CheckForUpdates()

; Tu código principal continuaría aquí
MsgBox, 64, Bienvenido, Aplicación cargada correctamente (Versión %currentVersion%)
return

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

Alba(num)
{
     if (!CheckRemedy())
    {
        return
    }
    try {
        BlockInput, On ; Bloquea el teclado y el ratón
        RunWait, powershell.exe -ExecutionPolicy Bypass -File "C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\Alba.ps1",, Hide
        screen()
        Send, ^i
        Send, {TAB 2}{End}{Up %num%}{Enter}
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
#1::
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
    try {
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
            WriteLog("Ejecutó la combinación #2 con DNI y teléfono")
    } catch e {
        WriteError("Ejecutando combinación #2: " . e.Message)
    }
#3::
     if (!CheckRemedy())
    {
        return
    }
    try {
    Alba(34)
    Gui, Submit, NoHide
    Send, %dni%
    Send, {Tab}{Enter}
    Send, {Tab 3}
    Send, +{Left 90}{BackSpace}
    Send, %telf%
    GuiControl, , dni
    GuiControl, , telf
            WriteLog("Ejecutó la combinación #3 con DNI y teléfono")
    } catch e {
        WriteError("Ejecutando combinación #3: " . e.Message)
    } 
    Return
#4::
     if (!CheckRemedy())
    {
        return
    }
    try {
    Alba(40)
    Gui, Submit, NoHide
    Send, %dni%
    Send, {Tab}{Enter}
    Send, {Tab 3}
    Send, +{Left 90}{BackSpace}
    Send, %telf%
    GuiControl, , dni
    GuiControl, , telf
            WriteLog("Ejecutó la combinación #4 con DNI y teléfono")
    } catch e {
        WriteError("Ejecutando combinación #4: " . e.Message)
    }
    Return
#5::
     if (!CheckRemedy())
    {
        return
    }
    try {
    Alba(1)
    Gui, Submit, NoHide
    Send, %dni%
    Send, {Tab}{Enter}
    Send, {Tab 3}
    Send, +{Left 90}{BackSpace}
    Send, %telf%
    GuiControl, , dni
    GuiControl, , telf
            WriteLog("Ejecutó la combinación #1 con DNI y teléfono")
    } catch e {
        WriteError("Ejecutando combinación #1: " . e.Message)
    }
    Return
#7:: ; AFK mode
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
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
     if (!CheckRemedy())
    {
        return
    }
    try{
        screen()
        Send, {Alt}a
        Send, {Down 9}{Right}{Enter}
          WriteLog("Se utilizó botón " . XButton1)
    } catch e {
        WriteError("Se utilizó botón " . XButton1 . e.Message)
    }
        Return
XButton2::
    Send, #+s
    Return
F13::
     if (!CheckRemedy())
    {
        return
    }
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
        WriteLog("Se utilizó macro F13")
    } catch e {
        WriteError("Se utilizó macro F13" . e.Message)
    }
    Return
F14::
     if (!CheckRemedy())
    {
        return
    }
    try{
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
        WriteLog("Ejecutó macro F14")
    } catch e {
        WriteError("Ejecutó macro F14: " . e.Message)
    }
    Return
F15::
     if (!CheckRemedy())
    {
        return
    }
    try{
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
        WriteLog("Ejecutó macro F15")
    } catch e {
        WriteError("Ejecutó macro F15: " . e.Message)
    }
    Return
F16::
     if (!CheckRemedy())
    {
        return
    }
    try{
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
        WriteLog("Ejecutó macro F16")
    } catch e {
        WriteError("Ejecutó macro F16: " . e.Message)
    }
    Return
F17::
     if (!CheckRemedy())
    {
        return
    }
    try{
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
        WriteLog("Ejecutó macro F17")
    } catch e {
        WriteError("Ejecutó macro F17: " . e.Message)
    }
    Return
F18::
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
    WriteLog("Ejecutó macro F18")
    } catch e {
        WriteError("Ejecutó macro F18: " . e.Message)
    }
    Return
F12::
     if (!CheckRemedy())
    {
        return
    }
    try{
    Alba(0)
    Send, {F3}{Enter}{Tab 5}
    Gui, Submit, NoHide
    Send, %Inci%
    Send, ^{Enter}
    GuiControl, , Inci
    WriteLog("Ejecutó macro F12")
    } catch e {
        WriteError("Ejecutó macro F12: " . e.Message)
    }
    Return
F19::
     if (!CheckRemedy())
    {
        return
    }
    Try {
    Alba(0)
    Send, {F3}{Enter}{Tab 5}
    Gui, Submit, NoHide
    Send, %Inci%
    Send, ^{Enter}
    GuiControl, , Inci
    WriteLog("Se ejecutó macro F19")
    } catch e {
        WriteError("Se ejecutó macro F19 :" . e.Message)
    }
    Return
F20::
     if (!CheckRemedy())
    {
        return
    }
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
    cierre("Se empareja equipo correctamente y se indica contrase{U+00F1}a ISL se cierra ticket.")
    WriteLog("Se ejecuta macro F20")
    } catch e {
        WriteError("Se ejecuta macro F20: " . e.Message)
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