;OPTIMIZATIONS START
#NoEnv
#MaxHotkeysPerInterval 99000000
#HotkeyInterval 99000000
#KeyHistory 0
ListLines Off
Process, Priority, , A
SetBatchLines, -1
SetKeyDelay, -1, -1
SetMouseDelay, -1
SetDefaultMouseSpeed, 0
SetWinDelay, -1
SetControlDelay, -1
SendMode Input
DllCall("ntdll\ZwSetTimerResolution","Int",5000,"Int",1,"Int*",MyCurrentTimerResolution) ;setting the Windows Timer Resolution to 0.5ms, THIS IS A GLOBAL CHANGE


screen()
{
    SetTitleMatchMode, 2
    WinActivate, ahk_class ArFrame
    Return
}

tlf()
{
    MsgBox, 4,, ¿Tiene teléfono en campo Remedy?
    IfMsgBox, Yes
    {
        SetTitleMatchMode, 2
        WinActivate, ahk_class ArFrame
        Send, {TAB 4}
    }
    IfMsgBox, No
    {
        SetTitleMatchMode, 2
        WinActivate, ahk_class ArFrame
        InputBox, phone, Teléfono, (Teléfono del usuario)
        Send, {TAB 4}
        Send, %phone%
    }
    Return
}

password()
{   
    SetTitleMatchMode, 2
    WinActivate, ahk_class ArFrame
    InputBox, pass, Password, (Nueva password)
    Send, {TAB 36}%pass%
    Return
}

cierre(closetext)
{
    SendInput, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
    SendInput, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}closetext{Tab}{Enter}
}

Gui Add, Button, x56 y136 w80 h23, Correo
Gui Add, Button, x56 y168 w80 h23, PNJ
Gui Add, Button, x56 y104 w80 h23, AD
Gui Add, Button, x56 y72 w80 h23, @Driano
Gui Add, Button, x56 y200 w80 h23, Equipo
Gui Add, Button, x56 y32 w80 h23, Alba

Gui Show, w194 h264, Window
Return

ButtonAlba:
    Run, PowerShell.exe -ExecutionPolicy Bypass -File "C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\Alba.ps1",, Hide
    screen()
    SendInput, ^i 
    SendInput, {TAB 2}{End}{Enter}
    SendInput, {TAB 22}
Return

Button@Driano:
 tlf()
    screen()
    SendInput, {TAB 23}{Right}{TAB 2}NUEVO ADRIANO{TAB}Se recibe llamada relacionada con {@}driano. Se comprueba que no esta relacionado con puesto de trabajo. Se realiza transfer de llamada para su gestion.{TAB 6}{Down}{TAB 34}NUEVO ADRIANO{TAB 3}Se realiza transfer de llamada a CA {@}driano para su gestion. Se cierra ticket.^{enter}{Enter}
    cierre("Se recibe llamada relacionada con {@}driano. Se comprueba que no esta relacionado con puesto de trabajo. Se realiza transfer de llamada para su gestion. Se cierra ticket.")
Return

ButtonAD:
    tlf()
    password()
    SendInput, {Tab 25}{Right}{Tab 9}{Down 2}{Tab 34}GESTION USUARIOS{Tab}AD - Usuario no recuerda su contrase{U+00F1}a{Tab}CONTRASE{ASC 165}AS{Tab 2}Se cambia contrase{U+00F1}a del usuario{TAB 2}-^{enter}{Enter}
    cierre("Se cambia contrase{U+00F1}a de AD.")
Return

ButtonCorreo:
    tlf()
    password()
    SendInput, {Tab 25}{Right}{Tab 9}{Down 2}{Tab 34}GESTION USUARIOS{Tab}Correo - Usuario no recuerda su contrase{U+00F1}a{Tab}CONTRASE{ASC 165}AS{Tab 2}Se cambia contrase{U+00F1}a del usuario{TAB 2}-^{enter}{Enter}
    cierre("Se cambia contrase{U+00F1}a de correo.")
Return

ButtonPNJ:
    tlf()
    SendInput, {TAB 23}{Right}{TAB 2}COMUNICACIONES{TAB}Se recibe llamada relacionada con servicio no relacionado con el CIUS. Se comprueba que no esta relacionado con puesto de trabajo. Se comunica n{ú}mero del servicio correspondiente{TAB 6}{Down}{TAB 34}COMUNICACIONES{TAB 3}Se recibe llamada relacionada con servicio no relacionado con el CEIURIS. Se comprueba que no esta relacionado con puesto de trabajo. Se comunica numero del servicio correspondiente^{enter}{Enter}
    cierre("Se recibe llamada relacionada con servicio no relacionado con el CEIURIS. Se comprueba que no esta relacionado con puesto de trabajo. Se comunica numero del servicio correspondiente. Se cierra ticket.")
Return

ButtonEquipo:
    tlf()
    SendInput, {TAB 23}{Right}{TAB 2}COMUNICACIONES{TAB}Se recibe llamada relacionada con problemas con el equipo{TAB 6}{Down}{TAB 34}COMUNICACIONES{TAB 3}Se recibe llamada relacionada con problemas con el equipo^{enter}{Enter}
    cierre("Se recibe llamada relacionada con problemas con el equipo. Se solventa y se cierra ticket.")
Return

GuiEscape:
GuiClose:
    ExitApp
