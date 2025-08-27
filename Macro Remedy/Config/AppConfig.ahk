; ===============================================================================
; AppConfig.ahk - Configuración centralizada de la aplicación (AutoHotkey v2)
; ===============================================================================

class AppConfig {
    
    ; Información de la aplicación
    static APP_NAME := "Gestor de incidencias CAU"
    static VERSION := "2.0.0"
    static AUTHOR := "CAU Team"
    static DESCRIPTION := "Sistema automatizado de gestión de incidencias"
    
    ; URLs y rutas de actualización
    static REPO_URL := "https://api.github.com/repos/JUST3EXT/CAU/releases/latest"
    static DOWNLOAD_BASE_URL := "https://github.com/JUST3EXT/CAU/releases/download/"
    static EXECUTABLE_NAME := "CAU_GUI.exe"
    
    ; Configuración de la GUI
    static GUI_WIDTH := 1456
    static GUI_HEIGHT := 704
    static GUI_TITLE := "Gestor de incidencias CAU"
    
    ; Configuración de logging
    static LOG_ENABLED := true
    static LOG_HIDDEN := true
    static ERROR_LOG_ENABLED := true
    
    ; Configuración de temporización optimizada
    static AFK_TIMER_INTERVAL := 60000  ; 1 minuto
    static UPDATE_CHECK_DELAY := 1000   ; 1 segundo (optimizado)
    static BUTTON_ACTION_DELAY := 100   ; 0.1 segundos (optimizado)
    static GUI_REFRESH_RATE := 16       ; ~60 FPS para animaciones
    static HOTKEY_DEBOUNCE := 50        ; Anti-rebote de hotkeys
    
    ; Paths del sistema
    static TEMP_DIR := A_Temp
    static DOCUMENTS_DIR := A_MyDocuments
    static SCRIPT_DIR := A_ScriptDir
    static ALBA_SCRIPT_PATH := "C:\ProgramData\Application Data\AR SYSTEM\home\Alba.ps1"
    
    ; Configuración de Remedy
    static REMEDY_EXECUTABLE := "aruser.exe"
    static REMEDY_WINDOW_CLASS := "ArFrame"
    
    ; Validación de DNI
    static DNI_LETTERS := "TRWAGMYFPDXBNJZSQVHLCKE"
    static DNI_MIN_LENGTH := 1
    static DNI_MAX_LENGTH := 8
    
    ; Límites de repetición y rendimiento
    static MAX_REPEAT_COUNT := 999
    static MIN_REPEAT_COUNT := 1
    static BATCH_SIZE := 50             ; Procesar en lotes para mejor rendimiento
    static MEMORY_CLEANUP_INTERVAL := 300000  ; Limpieza memoria cada 5 minutos
    
    /**
     * Obtiene la ruta completa del archivo de log actual
     */
    static GetLogFilePath() {
        LogFileName := FormatTime(A_Now, "MMMMyyyy")
        LogFileName := StrReplace(LogFileName, A_Space, "_")
        return this.DOCUMENTS_DIR . "\log_" . LogFileName . ".txt"
    }
    
    /**
     * Obtiene la ruta del archivo temporal de actualización
     */
    static GetTempUpdatePath() {
        return this.TEMP_DIR . "\" . this.EXECUTABLE_NAME
    }
    
    /**
     * Obtiene la ruta del script de actualización
     */
    static GetUpdateScriptPath() {
        return this.TEMP_DIR . "\UpdateScript.ahk"
    }
    
    /**
     * Obtiene la URL de descarga para una versión específica
     */
    static GetDownloadUrl(version) {
        return this.DOWNLOAD_BASE_URL . "v" . version . "/" . this.EXECUTABLE_NAME
    }
    
    /**
     * Valida si un número de DNI es válido
     */
    static IsValidDNI(dniNumber) {
        return (dniNumber != "" && RegExMatch(dniNumber, "^\\d{" . this.DNI_MIN_LENGTH . "," . this.DNI_MAX_LENGTH . "}$"))
    }
}