; ===============================================================================
; UpdateManager.ahk - Sistema de actualización automática
; ===============================================================================

#Include "../Config/AppConfig.ahk"
#Include "../Utils/Logger.ahk"

class UpdateManager {
    
    static instance := ""
    logger := ""
    currentVersion := ""
    
    /**
     * Constructor
     */
    __New() {
        this.logger := Logger.GetInstance()
        this.currentVersion := AppConfig.VERSION
    }
    
    /**
     * Obtiene la instancia singleton
     */
    static GetInstance() {
        if (this.instance == "") {
            this.instance := UpdateManager()
        }
        return this.instance
    }
    
    /**
     * Verifica si hay actualizaciones disponibles
     */
    CheckForUpdates(showNoUpdateMessage := false) {
        this.logger.Info("Verificando actualizaciones... Versión actual: " . this.currentVersion)
        
        try {
            latestVersion := this.GetLatestReleaseVersion()
            
            if (latestVersion == "") {
                this.logger.Warning("No se pudo obtener información de la versión remota")
                if (showNoUpdateMessage) {
                    MsgBox("No se pudo verificar si hay actualizaciones disponibles.`nRevise su conexión a internet.", "Actualización", "IconExclamation")
                }
                return false
            }
            
            if (this.IsNewerVersion(latestVersion)) {
                this.logger.Info("Nueva versión disponible: " . latestVersion)
                return this.PromptUpdate(latestVersion)
            } else {
                this.logger.Info("La aplicación está actualizada")
                if (showNoUpdateMessage) {
                    MsgBox("Su aplicación está actualizada.`nVersión actual: " . this.currentVersion, "Actualización", "IconInfo")
                }
                return false
            }
            
        } catch as e {
            this.logger.LogException(e, "CheckForUpdates")
            if (showNoUpdateMessage) {
                MsgBox("Error al verificar actualizaciones:`n" . e.message, "Error", "IconX")
            }
            return false
        }
    }
    
    /**
     * Obtiene la versión más reciente desde GitHub
     */
    GetLatestReleaseVersion() {
        try {
            ; Crear objeto HTTP
            HttpObj := ComObject("WinHttp.WinHttpRequest.5.1")
            
            ; Configurar timeouts
            HttpObj.SetTimeouts(10000, 10000, 30000, 30000) ; ms: resolve, connect, send, receive
            
            ; Realizar petición
            HttpObj.Open("GET", AppConfig.REPO_URL, false)
            HttpObj.SetRequestHeader("User-Agent", AppConfig.APP_NAME . "/" . AppConfig.VERSION . " (Windows)")
            HttpObj.SetRequestHeader("Accept", "application/vnd.github.v3+json")
            
            HttpObj.Send()
            
            ; Verificar código de respuesta
            if (HttpObj.Status != 200) {
                this.logger.Error("Error HTTP al obtener versión: " . HttpObj.Status . " - " . HttpObj.StatusText)
                return ""
            }
            
            response := HttpObj.ResponseText
            this.logger.Debug("Respuesta de GitHub recibida (longitud: " . StrLen(response) . ")")
            
            ; Parsear JSON para obtener tag_name
            if (RegExMatch(response, '""tag_name""\s*:\s*""v?(\d+\.\d+\.\d+)""', &match)) {
                version := match[1]
                this.logger.Debug("Versión extraída: " . version)
                return version
            } else {
                this.logger.Error("No se pudo parsear la versión desde la respuesta JSON")
                return ""
            }
            
        } catch as e {
            this.logger.LogException(e, "GetLatestReleaseVersion")
            return ""
        }
    }
    
    /**
     * Compara versiones usando formato semántico (major.minor.patch)
     */
    IsNewerVersion(remoteVersion) {
        ; Separar versiones por puntos
        remoteParts := StrSplit(remoteVersion, ".")
        currentParts := StrSplit(this.currentVersion, ".")
        
        ; Comparar cada componente
        Loop 3 {
            ; Obtener componentes (default 0 si no existe)
            remoteNum := (A_Index <= remoteParts.Length && remoteParts[A_Index] != "") ? Integer(remoteParts[A_Index]) : 0
            currentNum := (A_Index <= currentParts.Length && currentParts[A_Index] != "") ? Integer(currentParts[A_Index]) : 0
            
            if (remoteNum > currentNum) {
                return true
            } else if (remoteNum < currentNum) {
                return false
            }
        }
        
        return false
    }
    
    /**
     * Pregunta al usuario si desea actualizar
     */
    PromptUpdate(newVersion) {
        result := MsgBox(
            "Nueva versión disponible: " . newVersion . "`n" .
            "Versión actual: " . this.currentVersion . "`n`n" .
            "Características de esta versión:`n" .
            "• Interfaz mejorada y más estable`n" .
            "• Mejor gestión de errores`n" .
            "• Sistema de logging avanzado`n" .
            "• Configuración modular`n`n" .
            "¿Desea descargar e instalar la actualización?`n`n" .
            "La aplicación se reiniciará automáticamente después de la actualización.", 
            "Actualización disponible", "YesNo IconQuestion")
        
        if (result == "Yes") {
            return this.PerformUpdate(newVersion)
        } else {
            this.logger.Info("Usuario canceló la actualización")
            return false
        }
    }
    
    /**
     * Realiza el proceso de actualización
     */
    PerformUpdate(version) {
        this.logger.Info("Iniciando proceso de actualización a versión: " . version)
        
        try {
            ; Mostrar progreso usando SplashText de AutoHotkey v2
            SplashText("Descargando actualización...", "Actualización en progreso", 400, 100)
            
            ; Descargar nueva versión
            if (!this.DownloadLatestVersion(version)) {
                SplashText()
                MsgBox("No se pudo descargar la nueva versión.`nIntente nuevamente más tarde.", "Error de actualización", "IconX")
                return false
            }
            
            SplashText("Preparando instalación...", "Actualización en progreso", 400, 100)
            
            ; Crear y ejecutar script de actualización
            if (!this.CreateUpdateScript()) {
                SplashText()
                MsgBox("No se pudo crear el script de actualización.", "Error de actualización", "IconX")
                return false
            }
            
            SplashText("Finalizando...", "Actualización en progreso", 400, 100)
            
            ; Mostrar mensaje final
            SplashText()
            MsgBox("La actualización se completará en unos segundos.`nLa aplicación se reiniciará automáticamente.", "Actualización", "IconInfo")
            
            ; Ejecutar script de actualización y salir
            this.ExecuteUpdateScript()
            
            return true
            
        } catch as e {
            this.logger.LogException(e, "PerformUpdate")
            MsgBox("Error durante la actualización:`n" . e.message, "Error de actualización", "IconX")
            return false
        }
    }
    
    /**
     * Descarga la última versión
     */
    DownloadLatestVersion(version) {
        try {
            downloadUrl := AppConfig.GetDownloadUrl(version)
            tempFile := AppConfig.GetTempUpdatePath()
            
            this.logger.Info("Descargando desde: " . downloadUrl)
            this.logger.Info("Guardando en: " . tempFile)
            
            ; Eliminar archivo temporal anterior si existe
            FileDelete(tempFile)
            
            ; Descargar archivo
            Download(downloadUrl, tempFile)
            
            ; Verificar que se descargó correctamente
            if (!FileExist(tempFile)) {
                this.logger.Error("El archivo descargado no existe: " . tempFile)
                return false
            }
            
            ; Verificar tamaño del archivo
            fileSize := FileGetSize(tempFile)
            if (fileSize < 1000) { ; Menos de 1KB probablemente es un error
                this.logger.Error("Archivo descargado demasiado pequeño: " . fileSize . " bytes")
                FileDelete(tempFile)
                return false
            }
            
            this.logger.Info("Descarga completada. Tamaño: " . fileSize . " bytes")
            return true
            
        } catch as e {
            this.logger.LogException(e, "DownloadLatestVersion")
            return false
        }
    }
    
    /**
     * Crea el script de actualización
     */
    CreateUpdateScript() {
        try {
            updateScriptPath := AppConfig.GetUpdateScriptPath()
            tempFile := AppConfig.GetTempUpdatePath()
            localFile := A_ScriptFullPath
            
            ; Script de actualización mejorado
            updateScript := "; Script de actualización automática`n"
            updateScript .= "#Requires AutoHotkey v2.0`n"
            updateScript .= "#SingleInstance Force`n`n"
            updateScript .= "; Logging`n"
            updateScript .= "DateTime := FormatTime(A_Now, `"yyyy-MM-dd HH:mm:ss`")`n"
            updateScript .= "LogFile := A_Temp . `"\\UpdateLog.txt`"`n"
            updateScript .= "FileAppend(`"[`" . DateTime . `"] Iniciando actualización\n`", LogFile)`n`n"
            updateScript .= "; Esperar a que se cierre la aplicación principal`n"
            updateScript .= "Sleep(3000)`n`n"
            updateScript .= "; Variables de archivos`n"
            updateScript .= "TempFile := `"" . tempFile . "`"`n"
            updateScript .= "LocalFile := `"" . localFile . "`"`n"
            updateScript .= "BackupFile := `"" . localFile . ".backup`"`n`n"
            updateScript .= "; Crear backup del archivo actual`n"
            updateScript .= "FileCopy(LocalFile, BackupFile, 1)`n"
            updateScript .= "FileAppend(`"[`" . DateTime . `"] Backup creado\n`", LogFile)`n`n"
            updateScript .= "; Intentar reemplazar el archivo`n"
            updateScript .= "Loop {`n"
            updateScript .= "    try {`n"
            updateScript .= "        FileMove(TempFile, LocalFile, 1)`n"
            updateScript .= "        FileAppend(`"[`" . DateTime . `"] Actualización exitosa\n`", LogFile)`n"
            updateScript .= "        break`n"
            updateScript .= "    } catch {`n"
            updateScript .= "        Sleep(1000)`n"
            updateScript .= "        if (A_Index > 30) {`n"
            updateScript .= "            FileAppend(`"[`" . DateTime . `"] Timeout en actualización\n`", LogFile)`n"
            updateScript .= "            FileMove(BackupFile, LocalFile, 1)`n"
            updateScript .= "            ExitApp()`n"
            updateScript .= "        }`n"
            updateScript .= "    }`n"
            updateScript .= "}`n`n"
            updateScript .= "; Limpiar archivos temporales`n"
            updateScript .= "FileDelete(BackupFile)`n"
            updateScript .= "Sleep(1000)`n`n"
            updateScript .= "; Reiniciar aplicación`n"
            updateScript .= "FileAppend(`"[`" . DateTime . `"] Reiniciando aplicación\n`", LogFile)`n"
            updateScript .= "Run('`"' . LocalFile . '`"')`n`n"
            updateScript .= "; Auto-eliminar este script después de un tiempo`n"
            updateScript .= "Sleep(5000)`n"
            updateScript .= "FileDelete(A_ScriptFullPath)`n`n"
            updateScript .= "ExitApp()"
            
            ; Eliminar script anterior si existe
            FileDelete(updateScriptPath)
            
            ; Escribir nuevo script
            FileAppend(updateScript, updateScriptPath)
            
            if (!FileExist(updateScriptPath)) {
                this.logger.Error("No se pudo crear el script de actualización")
                return false
            }
            
            this.logger.Info("Script de actualización creado: " . updateScriptPath)
            return true
            
        } catch as e {
            this.logger.LogException(e, "CreateUpdateScript")
            return false
        }
    }
    
    /**
     * Ejecuta el script de actualización y termina la aplicación
     */
    ExecuteUpdateScript() {
        try {
            updateScriptPath := AppConfig.GetUpdateScriptPath()
            
            this.logger.Info("Ejecutando script de actualización: " . updateScriptPath)
            this.logger.LogAppEnd()
            
            ; Ejecutar script de actualización
            Run('"' . updateScriptPath . '"')
            
            ; Salir de la aplicación
            ExitApp()
            
        } catch as e {
            this.logger.LogException(e, "ExecuteUpdateScript")
            MsgBox("No se pudo ejecutar la actualización.`nLa aplicación continuará con la versión actual.", "Error crítico", "IconX")
        }
    }
    
    /**
     * Verifica actualizaciones de forma asíncrona (sin bloquear la GUI)
     */
    CheckForUpdatesAsync() {
        ; Crear hilo separado para verificación
        SetTimer(UpdateCheck, -2000)  ; Verificar después de 2 segundos
    }
}

; Timer callback para verificación asíncrona - AutoHotkey v2
UpdateCheck() {
    UpdateManager.GetInstance().CheckForUpdates()
}