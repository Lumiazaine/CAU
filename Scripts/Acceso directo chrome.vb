Create a vbscript file
======= myScript.vbs ==============

set WshShell = CreateObject(“WScript.Shell”)
WshShell.run ("chrome https://someFullURL.com" )

Create a shortcut to wscript & the vbscript

=========== shortcut target ==================
C:\Windows\System32\wscript.exe “c:\path\to\myScript.vbs”