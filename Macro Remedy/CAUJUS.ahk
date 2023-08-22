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

Alba(num)
{
    RunWait, powershell.exe -ExecutionPolicy Bypass -File "C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\Alba.ps1",, Hide
    screen()
    Send, ^i 
    Send, {TAB 2}{Down %num%}{Enter}
    Send, {TAB 22}
    Return
}

;CIERRE USUARIO
#1::
    RunWait, powershell.exe -ExecutionPolicy Bypass -File "C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\Alba.ps1",, Hide
    screen()
    Send, ^i 
    Send, {TAB 2}{End}{Enter}
    Send, {TAB 22}
Return
;@Driano
#2::
    Alba(24)
Return
;AD
#3::
    Alba(19)
    clipboard := "Se reestablece contraseña y se deja en campo Remedy, conforme. Se cierra ticket."
Return
;Correo
#4::
    Alba(21)
    clipboard := "El usuario realiza el cambio de contraseña desde micuenta.juntadeandalucia.es, Conforme."
Return
;PNJ
#5::
    Alba(25)
    clipboard := "Se recibe llamada relacionada con servicio no relacionado con el CEIURIS. Se comprueba que no esta relacionado con puesto de trabajo. Se comunica numero del servicio correspondiente. Se cierra ticket."
Return
;Adriano
#6::
    Alba(20)
Return
;Tarjeta
#7::
    Alba(26)
Return

#8::

Return

#9::
Send, {F3}{Enter}{Tab 5}
Return

#0::Reload
Return


XButton1::
Return

XButton2::
screen()
Send, #+s
Return
