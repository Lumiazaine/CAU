#Requires AutoHotkey v2.0
#SingleInstance Force

; Test individual de AppConfig
#Include "Config/AppConfig.ahk"
#Include "Utils/Logger.ahk"

; Test simple
MsgBox("Logger loaded successfully", "Test", "IconInfo")
ExitApp()