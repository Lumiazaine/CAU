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

Gui Add, Edit, x224 y592 w150 h26 vDni,
Gui Add, Edit, x224 y632 w150 h26 vtelf,
Gui Add, Text, x1208 y48 w119 h25, CONTRASEÑAS
Gui Add, Text, x984 y48 w48 h29, DP
Gui Add, Text, x1224 y360 w153 h31, TRANSFER
Gui Add, Text, x680 y280 w67 h29, CAU
Gui Add, Text, x656 y48 w106 h29, MINISTERIO
Gui Add, Text, x280 y48 w150 h29, INCIDENCIAS
Gui Add, Text, x272 y368 w150 h29, SOLICITUDES
Gui Add, Text, x672 y432 w62 h29, CIERRES
Gui Add, Text, x176 y592 w43 h29, DNI
Gui Add, Text, x984 y512 w150 h29, Teléfonos
Gui Add, Text, x936 y552 w169 h29, MINISTERIO - 913 859 800
Gui Add, Text, x936 y576 w133 h29, PNJ - 918 382 680
Gui Add, Text, x128 y632 w88 h31, TELÉFONO
Gui Add, Button, x88 y88 w146 h54 gButton1, Adriano
Gui Add, Button, x88 y152 w146 h54 gButton2, Escritorio judicial
Gui Add, Button, x400 y88 w146 h54 gButton3, Arconte
Gui Add, Button, x400 y216 w146 h54 gButton4, PortafirmasNG
Gui Add, Button, x248 y88 w146 h54 gButton5, Agenda de señalamientos
Gui Add, Button, x248 y152 w146 h54 gButton6, Expediente digital
Gui Add, Button, x400 y152 w146 h54 gButton7, Hermes
Gui Add, Button, x88 y216 w146 h54 gButton8, Jara
Gui Add, Button, x248 y216 w146 h54 gButton9, Quenda // Cita previa
Gui Add, Button, x88 y280 w146 h54 gButton10, Suministros
Gui Add, Button, x240 y456 w146 h54 gButton11, Internet libre
Gui Add, Button, x88 y512 w146 h54 gButton12, Multiconferencia
Gui Add, Button, x392 y400 w146 h54 gButton13, Dragon Speaking
Gui Add, Button, x240 y400 w146 h54 gButton14, Aumento espacio correo
Gui Add, Button, x88 y400 w146 h54 gButton15, Abbypdf
Gui Add, Button, x88 y456 w146 h54 gButton16, GDU
Gui Add, Button, x624 y144 w146 h54 gButton17, Orfila
Gui Add, Button, x624 y88 w146 h54 gButton18, Lexnet
Gui Add, Button, x624 y200 w146 h54 gButton19, Siraj2
Gui Add, Button, x624 y360 w146 h54 gButton20, Emparejamiento ISL
Gui Add, Button, x624 y304 w146 h54 gButton21, Certificado digital
Gui Add, Button, x624 y592 w146 h54 gButton22, Software
Gui Add, Button, x624 y464 w146 h54 gButton23, PIN tarjeta
Gui Add, Button, x624 y528 w146 h54 gButton24, Servicio no CEIURIS
Gui Add, Button, x1000 y152 w146 h54 gButton25, Lector tarjeta
Gui Add, Button, x848 y216 w146 h54 gButton26, Equipo sin red
Gui Add, Button, x1000 y88 w146 h54 gButton27, GM
Gui Add, Button, x920 y408 w146 h54 gButton28, Teléfono
Gui Add, Button, x848 y344 w146 h54 gButton29, Ganes
Gui Add, Button, x848 y280 w146 h54 gButton30, Equipo no enciende
Gui Add, Button, x848 y88 w146 h54 gButton31, Disco duro
Gui Add, Button, x848 y152 w146 h54 gButton32, Edoc Fortuny
Gui Add, Button, x1184 y152 w146 h54 gButton33, AD
Gui Add, Button, x1184 y216 w146 h54 gButton34, Correo
Gui Add, Button, x1184 y280 w146 h54 gButton35, Temis
Gui Add, Button, x1184 y88 w146 h54 gButton36, Arconte
Gui Add, Button, x1184 y392 w146 h54 gButton37, @Driano
Gui Add, Button, x392 y456 w146 h54 gButton38, Intervención video
Gui Add, Button, x1000 y216 w146 h54 gButton39, Monitor
Gui Add, Button, x1000 y344 w146 h54 gButton40, Teclado
Gui Add, Button, x1000 y280 w146 h54 gButton41, Ratón
Gui Show, w1385 h687, CAU
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
    Return
}

;Lógica botones

Button1:
    Alba(40)
Return

Button2:
    Alba(28)
Return

Button3:
    Alba(37)
Return

Button4:
    Alba(12)
Return

Button5:
    Alba(39)
Return

Button6:
    Alba(27)
Return

Button7:
    Alba(23)
Return

Button8:
    Alba(19)
Return

Button9:
    Alba(10)
Return

Button10:
    Alba(5)
Return

Button11:
    Alba(22)
Return

Button12:
    Alba(16)
Return

Button13:
    Alba(32)
Return

Button14:
    Alba(38)
Return

Button15:
    Alba(42)
Return

Button16:
    Alba(25)
Return

Button17:
    Alba(14)
Return

Button18:
    Alba(18)
Return

Button19:
    Alba(7)
Return

Button20:
    Alba(30)
Return

Button21:
    Alba(35)
Return

Button22:
    Alba(6)
Return

Button23:
    Alba(11)
Return

Button24:
    Alba(13)
Return

Button25:
    Alba(4)
Return

Button26:
    Alba(8)
Return

Button27:
    Alba(24)
Return

Button28:
    Alba(2)
Return

Button29:
    Alba(26)
Return

Button30:
    Alba(29)
Return

Button31:
    Alba(33)
Return

Button32:
    Alba(31)
Return

Button33:
    Alba(41)
Return

Button34:
    Alba(34)
Return

Button35:
    Alba(1)
Return

Button36:
    Alba(36)
Return

Button37:
    Alba(15)
Return

Button38:
    Alba(21)
Return

Button39:
    Alba(17)
Return

Button40:
    Alba(3)
Return

Button41:
    Alba(9)
Return

#1::
Alba(0)
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
