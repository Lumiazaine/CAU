#SingleInstance Force
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
DllCall("ntdll\ZwSetTimerResolution","Int",5000,"Int",1,"Int*",MyCurrentTimerResolution)
SetWorkingDir, %A_ScriptDir%

screen()
{
    SetTitleMatchMode, 2
    WinActivate, ahk_class ArFrame
    Return
}

tlf()
{
    SetTitleMatchMode, 2
    WinActivate, ahk_class ArFrame
    InputBox, phone, Telefono, (indica el telefono del usuario)
    SendInput, {TAB 3}
    Send, +{Left 90}{BackSpace}
    SendInput, %phone%
}

password()
{   
    SetTitleMatchMode, 2
    WinActivate, ahk_class ArFrame
    InputBox, pass, Password, (Nueva password)
    SendInput, {TAB 36}%pass%
    Return
}

cierre(closetext)
{
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}%closetext%{Tab}{Enter}
}

select()
{
    Send, +{Left 90}{BackSpace}
}

#1::
    RunWait, powershell.exe -ExecutionPolicy Bypass -File "C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\Alba.ps1",, Hide
    screen()
    Send, ^i 
    Send, {TAB 2}{End}{Enter}
    Send, {TAB 22}
Return

#2::
    tlf()
    screen()
    Send, {TAB 20}{Right}{TAB 9}{Down}{TAB 31}NUEVO ADRIANO{TAB}{@}DRIANO - Se recibe llamada relacionada con {@}driano. Se comprueba que no esta relacionado con puesto de trabajo. Se realiza transfer de llamada para su gesti{ASC 162}n.{TAB 2}Se realiza transfer de llamada a CA {@}driano para su gesti{ASC 162}n. Se cierra ticket.^{enter}{Enter}
    cierre("Se recibe llamada relacionada con {@}driano. Se comprueba que no esta relacionado con puesto de trabajo. Se realiza transfer de llamada para su gesti{ASC 162}n. Se cierra ticket.")
Return

#3::
    tlf()
    password()
    screen()
    InputBox, PRO,,,
    Send {Tab 25}{Right}{Tab 9}{Down 2}{Tab 34}GESTION USUARIOS{Tab}%PRO% - Solicita el reseteo de la contrase{U+00F1}a{Tab}CONTRASE{ASC 165}AS{Tab 2}Se restablece contrase{U+00F1}a y se deja en el campo remedy. Resolvemos{TAB 2}-^{enter}{Enter}
    cierre("Se restablece contrase{U+00F1}a y se deja en el campo remedy. Resolvemos")
Return

#4::
    tlf()
    password()
    Send {Tab 25}{Right}{Tab 9}{Down 2}{Tab 34}GESTION USUARIOS{Tab}CORREO - Usuario no recuerda su contrase{U+00F1}a{Tab}CONTRASE{ASC 165}AS{Tab 2}el usuario realiza el cambio de contrase{U+00F1}a desde micuenta.juntadeandalucia.es{TAB 2}-^{enter}{Enter}
    cierre("el usuario realiza el cambio de contraseña desde micuenta.juntadeandalucia.es, Conforme.")
Return

#5::
    tlf()
    Send, {TAB 23}{Right}{TAB 2}COMUNICACIONES{TAB}PNJ - Se recibe llamada relacionada con servicio no relacionado con el CEIURIS. Se comprueba que no esta relacionado con puesto de trabajo. Se comunica n{ASC 163}mero del servicio correspondiente{TAB 6}{Down}{TAB 34}COMUNICACIONES{TAB 3}Se recibe llamada relacionada con servicio no relacionado con el CEIURIS. Se comprueba que no esta relacionado con puesto de trabajo. Se comunica n{ASC 163}mero del servicio correspondiente^{enter}{Enter}
    cierre("Se recibe llamada relacionada con servicio no relacionado con el CEIURIS. Se comprueba que no esta relacionado con puesto de trabajo. Se comunica numero del servicio correspondiente. Se cierra ticket.")
Return

#6::
    tlf()
    screen()
    Send, {TAB 23}{Right}{TAB 2}PUESTO DE TRABAJO{TAB}
    InputBox, DDI,Motivo del incidente,,
    screen()
    Send, %DDI%{TAB}SOFTWARE{TAB 2}
    InputBox, DIA,Diario,,
    screen()
    Send, %DIA%{TAB 2}-
    Send, ^{enter}{Enter}
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}%DIA%{Tab}{Enter}
Return

#7::
Send, {F3}{Enter}{Tab 5}
Return

#8::

Return

#9::

Return

   
#0::Reload
Return
 
XButton2::
Send, #{PrintScreen}
Return

