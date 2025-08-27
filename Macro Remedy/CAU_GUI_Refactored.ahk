; ===============================================================================
; CAU_GUI_Refactored.ahk - Gestor de Incidencias CAU (Versión Refactorizada v2)
; ===============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
A_MaxHotkeysPerInterval := 99000000
A_HotkeyInterval := 99000000
ListLines(false)
ProcessSetPriority("High")
SetKeyDelay(-1, -1)
SetMouseDelay(-1)
SetDefaultMouseSpeed(0)
SetWinDelay(-1)
SetControlDelay(-1)
SendMode("Input")

; Configurar resolución de timer de alta precisión
try {
    DllCall("ntdll\\ZwSetTimerResolution", "Int", 5000, "Int", 1, "Int*", &CurrentTimerResolution := 0)
} catch {
    ; Ignorar si no se puede configurar (no crítico)
}

SetWorkingDir(A_ScriptDir)

; Verificar archivos de módulos
RequiredFiles := [
    "Config\\AppConfig.ahk",
    "Utils\\Logger.ahk", 
    "Utils\\DNIValidator.ahk",
    "Core\\ButtonManager.ahk",
    "Core\\UpdateManager.ahk",
    "Core\\CAUApplication.ahk"
]

MissingFiles := ""
for filePath in RequiredFiles {
    if (!FileExist(A_ScriptDir . "\\" . filePath)) {
        MissingFiles .= "• " . filePath . "`n"
    }
}

if (MissingFiles != "") {
    FileAppend("Error Crítico - Archivos Faltantes:`n" . MissingFiles, "*")
    ExitApp()
}

; Incluir módulos principales
#Include "Core/CAUApplication.ahk"

; Función principal
Main() {
    ; Mostrar splash screen
    SplashText("Iniciando Gestor de Incidencias CAU v2.0.0`n`nCargando módulos...", "Cargando...", 400, 100)
    Sleep(1500)
    SplashText()
    
    try {
        ; Crear e inicializar aplicación principal
        app := CAUApplication.GetInstance()
        app.Start()
        
    } catch as e {
        ErrorMsg := "Error crítico durante la inicialización:`n`n"
        ErrorMsg .= "Mensaje: " . e.message . "`n"
        ErrorMsg .= "Línea: " . e.line . "`n"
        ErrorMsg .= "Archivo: " . e.file
        
        FileAppend("Error Crítico: `n" . ErrorMsg, "*")
        ExitApp()
    }
}

; Ejecutar función principal
Main()