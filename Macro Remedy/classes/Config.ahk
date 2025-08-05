; =============================================================================
; CONFIGURACIÓN GLOBAL Y CONSTANTES
; =============================================================================
class Config {
    ; Versión actual del script
    static VERSION := "1.0.0"
    
    ; URLs y rutas
    static REPO_URL := "https://api.github.com/repos/JUST3EXT/CAU/releases/latest"
    static TEMP_FILE := A_Temp "\CAU_GUI.exe"
    static LOCAL_FILE := A_ScriptFullPath
    static ALBA_SCRIPT_PATH := "C:\ProgramData\Application Data\AR SYSTEM\home\Alba.ps1"
    
    ; Constantes de aplicación
    static DNI_LETTERS := "TRWAGMYFPDXBNJZSQVHLCKE"
    static REMEDY_EXE := "aruser.exe"
    static AR_FRAME_CLASS := "ArFrame"
    
    ; Configuración de UI
    static GUI_WIDTH := 1456
    static GUI_HEIGHT := 704
    static GUI_TITLE := "Gestor de incidencias"
    
    ; Configuración de botones
    static BUTTON_WIDTH := 183
    static BUTTON_HEIGHT := 68
    
    ; Configuración de logs
    static LOG_PREFIX := "log_"
    static LOG_EXTENSION := ".txt"
    static LOG_DIRECTORY := A_MyDocuments
} 