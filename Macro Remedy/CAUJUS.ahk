#SingleInstance, Force
SendMode Input
SetWorkingDir, %A_ScriptDir%


/*
Añadir clase screen que solo ejecute las macros en Remedy.

    SetTitleMatchMode, 2
    WinActivate, ahk_class ArFrame


*/


/*
                     Rutas ejemplo Alba

C:\Users\Operador\AppData\Roaming\AR System\HOME\ARCmds\Alba.ps1
C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\Alba.ps1
*/


/*
                                ESC emergencia
*/

Esc::Reload
Return


/*
                            Proyecto Alba CAU JUSTICIA
Alba es un script que permite modificar los datos de la macro Remedy, permitiendo
gestionar de una manera eficaz la gestión de llamadas.
*/

#1::
    Run, PowerShell.exe -ExecutionPolicy Bypass -File "C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\Alba.ps1",, Hide
    SetTitleMatchMode, 2
    WinActivate, ahk_class ArFrame
    Send, ^i 
    Send, {TAB 2}{End}{Enter}
Return

/*
                        Transfer @driano

            Macro para transferir llamadas de @driano.
*/

#2::
MsgBox, 4,, ¿Tiene telefono en campo Remedy? 
IfMsgBox, Yes
{
    SetTitleMatchMode, 2
    WinActivate, ahk_class ArFrame
    Send, {TAB}{Space}{TAB 22}{TAB}{TAB 2}{TAB}{Right}{TAB 2}NUEVO ADRIANO{TAB}Se recibe llamada relacionada con {@}driano. Se comprueba que no esta relacionado con puesto de trabajo. Se realiza transfer de llamada para su gesti{ó}n.{TAB 6}{Down}{TAB 34}NUEVO ADRIANO{TAB 3}Se realiza transfer de llamada a CA {@}driano para su gesti{ó}n. Se cierra ticket.^{enter}{Enter}
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}Se recibe llamada relacionada con {@}driano. Se comprueba que no esta relacionado con puesto de trabajo. Se realiza transfer de llamada para su gesti{ó}n. Se cierra ticket.{Tab}{Enter}
    Return
}
IfMsgBox, No
{
    SetTitleMatchMode, 2
    WinActivate, ahk_class ArFrame
    InputBox, phone, Telefono, (Telefono del usuario)
    Send, {TAB}{Space}{TAB 3}
    Send, %phone%
    Send, {TAB 23}{Right}{TAB 2}NUEVO ADRIANO{TAB}Se recibe llamada relacionada con {@}driano. Se comprueba que no esta relacionado con puesto de trabajo. Se realiza transfer de llamada para su gesti{ó}n.{TAB 6}{Down}{TAB 34}NUEVO ADRIANO{TAB 3}Se realiza transfer de llamada a CA {@}driano para su gesti{ó}n. Se cierra ticket.^{enter}{Enter}
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}Se recibe llamada relacionada con {@}driano. Se comprueba que no esta relacionado con puesto de trabajo. Se realiza transfer de llamada para su gesti{ó}n. Se cierra ticket.{Tab}{Enter}
    Return
}

/*
                  Cambio contraseña equipo

*/

#3::
InputBox, pass, Password, (Nueva password)
MsgBox, 4,, ¿Tiene telefono en campo Remedy? 
IfMsgBox, Yes
{
SetTitleMatchMode, 2
WinActivate, ahk_class ArFrame
Send, {TAB}{Space}{TAB}
Send, %pass%
Send, {TAB 25}{Right}{TAB 2}GESTION USUARIOS{TAB}
Send, AD . Usuario no recuerda su contrase{U+00F1}a
Send, {TAB}
Send, CONTRASE{ASC 165}AS
Send, {TAB 2}
Send, Se cambia contrase{U+00F1}a del usuario{TAB 2}-
Send, ^{enter}{Enter}
Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}
Send, Se modifica la contrase{U+00F1}a campo Remedy
Send, {Tab}{Enter}
Return
}
IfMsgBox, No
{
    SetTitleMatchMode, 2
    WinActivate, ahk_class ArFrame
    InputBox, phone, Telefono, (Telefono del usuario)
    Send, {TAB}{Space}{TAB}
    Send, %pass%
    Send, {TAB 2}
    Send, %phone%
    Send, {TAB 23}{Right}{TAB 2}GESTION USUARIOS{TAB}
    Send, AD . Usuario no recuerda su contrase{U+00F1}a
    Send, {TAB}
    Send, CONTRASE{ASC 165}AS
    Send, {TAB 2}
    Send, Se cambia contrase{U+00F1}a del usuario{TAB 2}-
    Send, ^{enter}{Enter}
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}
    Send, Se modifica la contrase{U+00F1}a campo Remedy
    Send, {Tab}{Enter}
Return
}

/*
            Cambio contraseña correo 

*/

#4::
InputBox, pass, Password, (Nueva password)
MsgBox, 4,, ¿Tiene telefono en campo Remedy? 
IfMsgBox, Yes
{
SetTitleMatchMode, 2
WinActivate, ahk_class ArFrame
Send, {TAB}{Space}{TAB}
Send, %pass%
Send, {TAB 25}{Right}{TAB 2}GESTION USUARIOS{TAB}
Send, Correo . Usuario no recuerda su contrase{U+00F1}a
Send, {TAB}
Send, CONTRASE{ASC 165}AS
Send, {TAB 2}
Send, Se cambia contrase{U+00F1}a del usuario{TAB 2}-
Send, ^{enter}{Enter}
Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}
Send, Se modifica la contrase{U+00F1}a campo Remedy
Send, {Tab}{Enter}
Return
}
IfMsgBox, No
{
    SetTitleMatchMode, 2
    WinActivate, ahk_class ArFrame
    InputBox, phone, Telefono, (Telefono del usuario)
    Send, {TAB}{Space}{TAB}
    Send, %pass%
    Send, {TAB 2}
    Send, %phone%
    Send, {TAB 23}{Right}{TAB 2}GESTION USUARIOS{TAB}
    Send, Correo . Usuario no recuerda su contrase{U+00F1}a
    Send, {TAB}
    Send, CONTRASE{ASC 165}AS
    Send, {TAB 2}
    Send, Se cambia contrase{U+00F1}a del usuario{TAB 2}-
    Send, ^{enter}{Enter}
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}
    Send, Se modifica la contrase{U+00F1}a campo Remedy
    Send, {Tab}{Enter}
Return
}

/*

             Transfer Ministerio u otros servicios. (Cambio a)

*/

#5::
MsgBox, 4,, ¿Tiene telefono en campo Remedy? 
IfMsgBox, Yes
{
SetTitleMatchMode, 2
WinActivate, ahk_class ArFrame
Send, {TAB}{Space}{TAB 22}{TAB}{TAB 2}{TAB}{Right}{TAB 2}COMUNICACIONES{TAB}Se recibe llamada relacionada con servicio no relacionado con el CEIURIS. Se comprueba que no esta relacionado con puesto de trabajo. Se comunica n{ú}mero del servicio correspondiente{TAB 6}{Down}{TAB 34}COMUNICACIONES{TAB 3}Se recibe llamada relacionada con servicio no relacionado con el CEIURIS. Se comprueba que no esta relacionado con puesto de trabajo. Se comunica n{ú}mero del servicio correspondiente^{enter}{Enter}
Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}Se recibe llamada relacionada con servicio no relacionado con el CEIURIS. Se comprueba que no esta relacionado con puesto de trabajo. Se comunica n{ú}mero del servicio correspondiente. Se cierra ticket.{Tab}{Enter}
Return
}
IfMsgBox, No
{
    SetTitleMatchMode, 2
    WinActivate, ahk_class ArFrame
    InputBox, phone, Telefono, (Telefono del usuario)
    Send, {TAB}{Space}{TAB 3}
    Send, %phone%
    Send, {TAB 23}{Right}{TAB 2}COMUNICACIONES{TAB}Se recibe llamada relacionada con servicio no relacionado con el CEIURIS. Se comprueba que no esta relacionado con puesto de trabajo. Se comunica n{ú}mero del servicio correspondiente{TAB 6}{Down}{TAB 34}COMUNICACIONES{TAB 3}Se recibe llamada relacionada con servicio no relacionado con el CEIURIS. Se comprueba que no esta relacionado con puesto de trabajo. Se comunica n{ú}mero del servicio correspondiente^{enter}{Enter}
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}Se recibe llamada relacionada con servicio no relacionado con el CEIURIS. Se comprueba que no esta relacionado con puesto de trabajo. Se comunica n{ú}mero del servicio correspondiente. Se cierra ticket.{Tab}{Enter}
Return
}


/*

                                                            Incidencia equipo
*/


#6::
MsgBox, 4,, ¿Tiene telefono en campo Remedy? 
IfMsgBox, Yes
{
SetTitleMatchMode, 2
WinActivate, ahk_class ArFrame
Send, {TAB}{Space}{TAB 22}{TAB}{TAB 2}{TAB}{Right}{TAB 2}COMUNICACIONES{TAB}Se recibe llamada relacionada con problemas con el equipo{TAB 6}{Down}{TAB 34}COMUNICACIONES{TAB 3}Se recibe llamada relacionada con problemas con el equipo^{enter}{Enter}
Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}Se recibe llamada relacionada con problemas con el equipo. Se solventa y se cierra ticket.{Tab}{Enter}
Return
}
IfMsgBox, No
{
    SetTitleMatchMode, 2
    WinActivate, ahk_class ArFrame
    InputBox, phone, Telefono, (Telefono del usuario)
    Send, {TAB}{Space}{TAB 3}
    Send, %phone%
    Send, {TAB 23}{Right}{TAB 2}COMUNICACIONES{TAB}Se recibe llamada relacionada con problemas con el equipo{TAB 6}{Down}{TAB 34}COMUNICACIONES{TAB 3}Se recibe llamada relacionada con problemas con el equipo^{enter}{Enter}
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}Se recibe llamada relacionada con problemas con el equipo. Se solventa y se cierra ticket.{Tab}{Enter}
Return
}

