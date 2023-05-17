#SingleInstance, Force
SendMode Input
SetWorkingDir, %A_ScriptDir%


/*
                            Plantilla función tfl 
                                    (WIP)


MsgBox, 4,, ¿Tiene telefono en campo Remedy? 
IfMsgBox, Yes
{

Return
}
IfMsgBox, No
{

Return
}

*/

/*
                                    LOGIN
::CAU::
Send, CAU09 {TAB} 
Send, c09 {Enter}  
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
/*
C:\Users\Operador\AppData\Roaming\AR System\HOME\ARCmds\Alba.ps1
C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\Alba.ps1
*/
#1::
Run powershell.exe -file "C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\Alba.ps1"
Sleep, 1000
WinActivate, [ BMC Remedy User - [Página de inicio (Buscar)]]
Send, ^i 
Send, {TAB 2}{End}{Enter}
Return

#2::
/*
                            Transfer @driano

            Macro para transferir llamadas de @driano.
*/
MsgBox, 4,, ¿Tiene telefono en campo Remedy? 
IfMsgBox, Yes
{
    Send, {TAB}{Space}{TAB 22}{TAB}{TAB 2}{TAB}{Right}{TAB 2}NUEVO ADRIANO{TAB}Se recibe llamada relacionada con {@}driano. Se comprueba que no esta relacionado con puesto de trabajo. Se realiza transfer de llamada para su gesti{ó}n.{TAB 6}{Down}{TAB 34}NUEVO ADRIANO{TAB 3}Se realiza transfer de llamada a CA {@}driano para su gesti{ó}n. Se cierra ticket.^{enter}{Enter}
    Sleep 1000
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
    Sleep 1000
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}Se recibe llamada relacionada con {@}driano. Se comprueba que no esta relacionado con puesto de trabajo. Se realiza transfer de llamada para su gesti{ó}n. Se cierra ticket.{Tab}{Enter}

    Return
}
IfMsgBox, No
{
    InputBox, phone, Telefono, (Telefono del usuario)
    Send, {TAB}{Space}{TAB 3}
    Sleep 1000
    Send, %phone%
    Sleep 1000
    Send, {TAB 23}{Right}{TAB 2}NUEVO ADRIANO{TAB}Se recibe llamada relacionada con {@}driano. Se comprueba que no esta relacionado con puesto de trabajo. Se realiza transfer de llamada para su gesti{ó}n.{TAB 6}{Down}{TAB 34}NUEVO ADRIANO{TAB 3}Se realiza transfer de llamada a CA {@}driano para su gesti{ó}n. Se cierra ticket.^{enter}{Enter}
    Sleep 1000
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
    Sleep 1000
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
Send, {TAB}{Space}{TAB}
Sleep, 1000
Send, %pass%
Sleep, 1000
Send, {TAB 25}{Right}{TAB 2}GESTION USUARIOS{TAB}
Sleep 1000
Send, AD . Usuario no recuerda su contrase{U+00F1}a
Send, {TAB}
Send, CONTRASE{ASC 165}AS
Send, {TAB 2}
Send, Se cambia contrase{U+00F1}a del usuario{TAB 2}-
Send, ^{enter}{Enter}
Sleep 1000
Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
Sleep 1000
Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}
Send, Se modifica la contrase{U+00F1}a campo Remedy
Send, {Tab}{Enter}
Return
}
IfMsgBox, No
{
    InputBox, phone, Telefono, (Telefono del usuario)
    Send, {TAB}{Space}{TAB}
    Sleep 1000
    Send, %pass%
    Sleep 1000
    Send, {TAB 2}
    Send, %phone%
    Sleep 1000
    Send, {TAB 23}{Right}{TAB 2}GESTION USUARIOS{TAB}
    Sleep 1000
    Send, AD . Usuario no recuerda su contrase{U+00F1}a
    Send, {TAB}
    Send, CONTRASE{ASC 165}AS
    Send, {TAB 2}
    Send, Se cambia contrase{U+00F1}a del usuario{TAB 2}-
    Send, ^{enter}{Enter}
    Sleep 1000
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
    Sleep 1000
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
Send, {TAB}{Space}{TAB}
Sleep, 1000
Send, %pass%
Sleep, 1000
Send, {TAB 25}{Right}{TAB 2}GESTION USUARIOS{TAB}
Sleep 1000
Send, Correo . Usuario no recuerda su contrase{U+00F1}a
Send, {TAB}
Send, CONTRASE{ASC 165}AS
Send, {TAB 2}
Send, Se cambia contrase{U+00F1}a del usuario{TAB 2}-
Send, ^{enter}{Enter}
Sleep 1000
Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
Sleep 1000
Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}
Send, Se modifica la contrase{U+00F1}a campo Remedy
Send, {Tab}{Enter}
Return
}
IfMsgBox, No
{
    InputBox, phone, Telefono, (Telefono del usuario)
    Send, {TAB}{Space}{TAB}
    Sleep 1000
    Send, %pass%
    Sleep 1000
    Send, {TAB 2}
    Send, %phone%
    Sleep 1000
    Send, {TAB 23}{Right}{TAB 2}GESTION USUARIOS{TAB}
    Sleep 1000
    Send, Correo . Usuario no recuerda su contrase{U+00F1}a
    Send, {TAB}
    Send, CONTRASE{ASC 165}AS
    Send, {TAB 2}
    Send, Se cambia contrase{U+00F1}a del usuario{TAB 2}-
    Send, ^{enter}{Enter}
    Sleep 1000
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
    Sleep 1000
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
Send, {TAB}{Space}{TAB 22}{TAB}{TAB 2}{TAB}{Right}{TAB 2}COMUNICACIONES{TAB}Se recibe llamada relacionada con servicio no relacionado con el CIUS. Se comprueba que no esta relacionado con puesto de trabajo. Se comunica n{ú}mero del servicio correspondiente{TAB 6}{Down}{TAB 34}COMUNICACIONES{TAB 3}Se recibe llamada relacionada con servicio no relacionado con el CIUS. Se comprueba que no esta relacionado con puesto de trabajo. Se comunica n{ú}mero del servicio correspondiente^{enter}{Enter}
Sleep 1000
Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
Sleep 1000
Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}Se recibe llamada relacionada con servicio no relacionado con el CIUS. Se comprueba que no esta relacionado con puesto de trabajo. Se comunica n{ú}mero del servicio correspondiente. Se cierra ticket.{Tab}{Enter}
Return
}
IfMsgBox, No
{
    InputBox, phone, Telefono, (Telefono del usuario)
    Send, {TAB}{Space}{TAB 3}
    Sleep 1000
    Send, %phone%
    Sleep 1000
    Send, {TAB 23}{Right}{TAB 2}COMUNICACIONES{TAB}Se recibe llamada relacionada con servicio no relacionado con el CIUS. Se comprueba que no esta relacionado con puesto de trabajo. Se comunica n{ú}mero del servicio correspondiente{TAB 6}{Down}{TAB 34}COMUNICACIONES{TAB 3}Se recibe llamada relacionada con servicio no relacionado con el CIUS. Se comprueba que no esta relacionado con puesto de trabajo. Se comunica n{ú}mero del servicio correspondiente^{enter}{Enter}
    Sleep 1000
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
    Sleep 1000
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}Se recibe llamada relacionada con servicio no relacionado con el CIUS. Se comprueba que no esta relacionado con puesto de trabajo. Se comunica n{ú}mero del servicio correspondiente. Se cierra ticket.{Tab}{Enter}
Return
}


#6::
Run powershell.exe -file "C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\Adriano.ps1"
Sleep, 2000
WinActivate, [ BMC Remedy User - [Página de inicio (Buscar)]]
Send, ^i 
Send, {TAB 2}{End}{Up}{Enter}
Return




/*
                            Test Adriano

*/

#7::
MsgBox, 4,, ¿Tiene telefono en campo Remedy? 
IfMsgBox, Yes
{
Send, {TAB}{Space}{TAB}
Sleep, 1000
Send, {TAB 25}{Right}{TAB 2}ADRIANO{TAB}
Sleep 1000
FileEncoding UTF-8 ;
FileRead, Clipboard, C:\Users\CAU.LAP\AppData\Roaming\AR System\HOME\ARCmds\Plantillas\Adr_pro_blo.txt
Send, ^v
Send, {TAB}FLUJOS DE TRAMITACIÓN{TAB 2}

Return
}
IfMsgBox, No
{

Return
}




/*

                                                            Incidencia crítica plantilla
#6::
MsgBox, 4,, ¿Tiene telefono en campo Remedy? 
IfMsgBox, Yes
{
Send, {TAB}{Space}{TAB 22}{TAB}{TAB 2}{TAB}{Right}{TAB 2}COMUNICACIONES{TAB}Se recibe llamada relacionada con caida de red generalizada{TAB 6}{Down}{TAB 34}COMUNICACIONES{TAB 3}Se recibe llamada relacionada con caida de red generalizada^{enter}{Enter}
Sleep 1000
Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
Sleep 1000
Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}Se recibe llamada relacionada con caida de red generalizada. Se cierra ticket.{Tab}{Enter}
Return
}
IfMsgBox, No
{
    InputBox, phone, Telefono, (Telefono del usuario)
    Send, {TAB}{Space}{TAB 3}
    Sleep 1000
    Send, %phone%
    Sleep 1000
    Send, {TAB 23}{Right}{TAB 2}COMUNICACIONES{TAB}Se recibe llamada relacionada con caida de red generalizada{TAB 6}{Down}{TAB 34}COMUNICACIONES{TAB 3}Se recibe llamada relacionada con caida de red generalizada^{enter}{Enter}
    Sleep 1000
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
    Sleep 1000
    Send, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}Se recibe llamada relacionada con caida de red generalizada Se cierra ticket.{Tab}{Enter}
Return
}

*/