; ===============================================================================
; Logger.ahk - Sistema de logging avanzado (AutoHotkey v2)
; ===============================================================================

#Include "../Config/AppConfig.ahk"

class Logger {
    
    static instance := ""
    
    ; Niveles de logging
    static LEVEL_DEBUG := 0
    static LEVEL_INFO := 1
    static LEVEL_WARNING := 2
    static LEVEL_ERROR := 3
    static LEVEL_CRITICAL := 4
    
    ; Nombres de los niveles
    static LEVEL_NAMES := {0: "DEBUG", 1: "INFO", 2: "WARNING", 3: "ERROR", 4: "CRITICAL"}
    
    ; Configuración
    currentLevel := 1  ; INFO por defecto
    logFilePath := ""
    isEnabled := true
    
    /**
     * Constructor de la clase Logger
     */
    __New() {
        this.logFilePath := AppConfig.GetLogFilePath()
        this.isEnabled := AppConfig.LOG_ENABLED
    }
    
    /**
     * Obtiene la instancia singleton del logger
     */
    static GetInstance() {
        if (this.instance == "") {
            this.instance := Logger()
        }
        return this.instance
    }
    
    /**
     * Establece el nivel mínimo de logging
     */
    SetLevel(level) {
        this.currentLevel := level
    }
    
    /**
     * Habilita o deshabilita el logging
     */
    SetEnabled(enabled) {
        this.isEnabled := enabled
    }
    
    /**
     * Método interno para escribir al log
     */
    _WriteLog(level, message, category := "") {
        if (!this.isEnabled || level < this.currentLevel) {
            return
        }
        
        try {
            ComputerName := A_ComputerName
            DateTime := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
            
            levelName := this.LEVEL_NAMES[level]
            categoryStr := (category != "") ? " [" . category . "]" : ""
            
            logEntry := DateTime . " - " . ComputerName . " - [" . levelName . "]" . categoryStr . " " . message . "`n"
            
            FileAppend(logEntry, this.logFilePath)
            
            ; Ocultar archivo de log si está configurado
            if (AppConfig.LOG_HIDDEN) {
                FileSetAttrib("+H", this.logFilePath)
            }
            
        } catch as e {
            ; Si falla el logging, mostrar en consola para debug
            OutputDebug("Logger Error: " . e.message)
        }
    }
    
    /**
     * Registra un mensaje de debug
     */
    Debug(message, category := "") {
        this._WriteLog(this.LEVEL_DEBUG, message, category)
    }
    
    /**
     * Registra un mensaje informativo
     */
    Info(message, category := "") {
        this._WriteLog(this.LEVEL_INFO, message, category)
    }
    
    /**
     * Registra una advertencia
     */
    Warning(message, category := "") {
        this._WriteLog(this.LEVEL_WARNING, message, category)
    }
    
    /**
     * Registra un error
     */
    Error(message, category := "") {
        this._WriteLog(this.LEVEL_ERROR, message, category)
    }
    
    /**
     * Registra un error crítico
     */
    Critical(message, category := "") {
        this._WriteLog(this.LEVEL_CRITICAL, message, category)
    }
    
    /**
     * Registra el inicio de la aplicación
     */
    LogAppStart() {
        this.Info("==========================================")
        this.Info(AppConfig.APP_NAME . " v" . AppConfig.VERSION . " iniciado")
        this.Info("Autor: " . AppConfig.AUTHOR)
        this.Info("==========================================")
    }
    
    /**
     * Registra el cierre de la aplicación
     */
    LogAppEnd() {
        this.Info("==========================================")
        this.Info(AppConfig.APP_NAME . " finalizando")
        this.Info("==========================================")
    }
    
    /**
     * Registra información de una excepción
     */
    LogException(e, context := "") {
        contextStr := (context != "") ? " [" . context . "]" : ""
        this.Error("Excepción capturada" . contextStr . ": " . e.message . " (Línea: " . e.line . ", Archivo: " . e.file . ")")
    }
    
    /**
     * Registra métricas de rendimiento
     */
    LogPerformance(operation, duration) {
        this.Info("Rendimiento - " . operation . ": " . duration . "ms", "PERFORMANCE")
    }
}

; Funciones globales para compatibilidad hacia atrás
WriteLog(message) {
    Logger.GetInstance().Info(message, "LEGACY")
}

WriteError(message) {
    Logger.GetInstance().Error(message, "LEGACY")
}