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

Menu ActualizacionesMenu, Add, Comprobar actualizaciones, update
Menu MenuMenu, Add, Actualizaciones, :ActualizacionesMenu
Menu MenuMenu, Add, Acerca de, AcercadeMenu
Gui Menu, MenuMenu

Gui Add, Edit, x109 y639 w188 h26
Gui Add, Edit, x411 y638 w188 h26
Gui Add, Text, x1219 y17 w25 h17, DP
Gui Add, Text, x798 y368 w84 h19, MINISTERIO
Gui Add, Text, x288 y20 w95 h20, INCIDENCIAS
Gui Add, Text, x289 y376 w98 h19, SOLICITUDES
Gui Add, Text, x797 y18 w67 h18, CIERRES
Gui Add, Text, x68 y644 w33 h21, DNI
Gui Add, Text, x327 y645 w76 h21, TELÉFONO
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
Gui Add, Button, x832 y199 w183 h68 gButton33, Transfer @Driano
Gui Add, Button, x432 y478 w183 h68 gButton34, Intervención video
Gui Add, Button, x1235 y267 w183 h68 gButton35, Monitor
Gui Add, Button, x1236 y410 w183 h68 gButton36, Teclado
Gui Add, Button, x1236 y338 w183 h68 gButton37, Ratón
Gui Add, Button, x1233 y127 w183 h68 gButton38, ISL Apagado
Gui Add, Button, x1045 y339 w183 h68 gButton39, Error relación de confianza
Gui Add, Button, x642 y56 w183 h68 gButton40, Contraseñas
Gui Add, Button, x244 y549 w183 h68 gButton41, Formaciones


Gui Show, w1456 h704, Gestor de incidencias
Return

;Variables 

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
    Send, {TAB 2}{End}{Up %num%}{Enter}
    Send, {TAB 22}
    GuiControlGet,vDni
    ControlGetText, textvar, %vDni%
    Send, %textvar% 
    Send, {Tab}{Enter}
    Send, {Tab 3} 
    Send, +{Left 90}{BackSpace}
    Return
}

update:
Return

AcercadeMenu:
MsgBox, 0,,Versión 1.0 `nYG5DcmVhZG8gcG9yIERhdmlkIPCfjJlgbkRlZGljYWRvIGEgbGFzIHBlcnNvbmFzIHF1ZSBtZSBoYW4gYW5pbWFkbyB5IGFwb3lhZG8gY2FkYSBkw61hLg==
Return

;Lógica botones

Button1:
    Alba(39)
Return

Button2:
    Alba(27)
Return

Button3:
    Alba(36)
Return

Button4:
    Alba(8)
Return

Button5:
    Alba(38)
Return

Button6:
    Alba(26)
Return

Button7:
    Alba(21)
Return

Button8:
    Alba(17)
Return

Button9:
    Alba(0)
Return

Button10:
    Alba(4)
Return

Button11:
    Alba(20)
Return

Button12:
    Alba(13)
Return

Button13:
    Alba(30)
Return

Button14:
    Alba(35)
Return

Button15:
    Alba(41)
Return

Button16:
    Alba(23)
Return

Button17:
    Alba(11)
Return

Button18:
    Alba(15)
Return

Button19:
    Alba(5)
Return

Button20:
    Alba(28)
Return

Button21:
    Alba(34)
Return

Button22:
    Alba(0)
Return

Button23:
    Alba(10)
Return

Button24:
    Alba(9)
Return

Button25:
    Alba(16)
Return

Button26:
    Alba(6)
Return

Button27:
    Alba(22)
Return

Button28:
    Alba(2)
Return

Button29:
    Alba(24)
Return

Button30:
    Alba(25)
Return

Button31:
    Alba(31)
Return

Button32:
    Alba(29)
Return

Button33:
    Alba(12)
Return

Button34:
    Alba(19)
Return

Button35:
    Alba(14)
Return

Button36:
    Alba(3)
Return

Button37:
    Alba(7)
Return

Button38:
    Alba(18)
Return

Button39:
    Alba(0)
Return

Button40:
    Alba(33)
Return

Button41:
    Alba(0)
Return

#1::
    Alba(0)
Return

#2::
    Alba(40)
Return

#3::
    Alba(32)
Return

#4::
    Alba(37)
Return

#5::
    Alba(1)
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

GuiEscape:
GuiClose:
    ExitApp
