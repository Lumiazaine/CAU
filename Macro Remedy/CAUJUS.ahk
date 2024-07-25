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

dni := ""
telf := ""
letters := "TRWAGMYFPDXBNJZSQVHLCKE"

CalculateDNILetter(dniNumber) {
    global letters
    if (dniNumber = "" || !RegExMatch(dniNumber, "^\d{1,8}$")) {
        return ""
    }
    index := Mod(dniNumber, 23)
    return SubStr(letters, index + 1, 1)
}

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
    Gui, Submit, NoHide
    DNILetter := CalculateDNILetter(DNI)
    GuiControl,, DNILetter, %DNILetter%
    Return

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
    Return
}

cierre(closetext)
{
    Sleep, 800
    Send, ^{enter}{Enter}
    Sleep, 800
    SendInput, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
    SendInput, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}closetext{Tab}{Enter}
}

#0::Reload
Return

#1::
    Alba(0)
    Gui, Submit, NoHide
    Send, %DNI%
    Send, {Tab}{Enter}
    Send, {Tab 3}
    Send, +{Left 90}{BackSpace}
    Send, %telf%
    GuiControl, , DNI
    GuiControl, , telf
    Return

Button1:
    Alba(0)
    Send, {F3}{Enter}{Tab 5}
    Gui, Submit, NoHide
    Send, %Inci%
    Send, ^{Enter}
    GuiControl, , Inci
    Return

GuiEscape:
GuiClose:
ExitApp
