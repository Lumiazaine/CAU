; =============================================================================
; CLASE PARA MANEJO DE LOGS
; =============================================================================
class Logger {
    static LogFilePath := ""
    
    ; Inicializa el sistema de logging
    static Init() {
        FormatTime, LogFileName,, MMMMyyyy
        StringReplace, LogFileName, LogFileName, %A_Space%, _, All
        this.LogFilePath := Config.LOG_DIRECTORY "\" Config.LOG_PREFIX LogFileName Config.LOG_EXTENSION
    }
    
    ; Escribe un mensaje de log normal
    static Write(action) {
        if (!this.LogFilePath) {
            this.Init()
        }
        ComputerName := A_ComputerName
        FormatTime, DateTime,, yyyy-MM-dd HH:mm:ss
        FileAppend, %DateTime% - %ComputerName% - %action%`n, %this.LogFilePath%
        FileSetAttrib, +H, %this.LogFilePath%
    }
    
    ; Escribe un mensaje de error
    static WriteError(errorMessage) {
        if (!this.LogFilePath) {
            this.Init()
        }
        ComputerName := A_ComputerName
        FormatTime, DateTime,, yyyy-MM-dd HH:mm:ss
        FileAppend, %DateTime% - %ComputerName% - *** ERROR %errorMessage% ***`n, %this.LogFilePath%
        FileSetAttrib, +H, %this.LogFilePath%
    }
    
    ; Escribe un mensaje de advertencia
    static WriteWarning(warningMessage) {
        if (!this.LogFilePath) {
            this.Init()
        }
        ComputerName := A_ComputerName
        FormatTime, DateTime,, yyyy-MM-dd HH:mm:ss
        FileAppend, %DateTime% - %ComputerName% - *** WARNING %warningMessage% ***`n, %this.LogFilePath%
        FileSetAttrib, +H, %this.LogFilePath%
    }
    
    ; Limpia logs antiguos (más de 30 días)
    static CleanOldLogs() {
        Loop, %Config.LOG_DIRECTORY%\log_*.txt {
            FileGetTime, fileTime, %A_LoopFileFullPath%, M
            EnvSub, fileTime, A_Now, Days
            if (fileTime > 30) {
                FileDelete, %A_LoopFileFullPath%
                this.Write("Log antiguo eliminado: " A_LoopFileName)
            }
        }
    }
} 