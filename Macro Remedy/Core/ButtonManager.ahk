; ===============================================================================
; ButtonManager.ahk - Sistema de gestión de botones y acciones
; ===============================================================================

#Include "../Config/AppConfig.ahk"
#Include "../Utils/Logger.ahk"

class ButtonManager {
    
    static instance := ""
    logger := ""
    buttonConfigs := Map()
    
    /**
     * Constructor
     */
    __New() {
        this.logger := Logger.GetInstance()
        this.LoadButtonConfigurations()
    }
    
    /**
     * Obtiene la instancia singleton
     */
    static GetInstance() {
        if (this.instance == "") {
            this.instance := ButtonManager()
        }
        return this.instance
    }
    
    /**
     * Carga las configuraciones de los botones
     */
    LoadButtonConfigurations() {
        ; Configuración de botones con sus parámetros Alba y descripciones
        this.buttonConfigs := Map()
        
        ; INCIDENCIAS
        this.buttonConfigs["Button1"] := Map("name", "Adriano", "albaParam", 42, "category", "INCIDENCIAS", "description", "Sistema Adriano")
        this.buttonConfigs["Button2"] := Map("name", "Escritorio judicial", "albaParam", 29, "category", "INCIDENCIAS", "description", "Problemas con escritorio judicial")
        this.buttonConfigs["Button3"] := Map("name", "Arconte", "albaParam", 39, "category", "INCIDENCIAS", "description", "Sistema Arconte")
        this.buttonConfigs["Button5"] := Map("name", "Agenda de señalamientos", "albaParam", 41, "category", "INCIDENCIAS", "description", "Gestión de citas judiciales")
        this.buttonConfigs["Button6"] := Map("name", "Expediente digital", "albaParam", 28, "category", "INCIDENCIAS", "description", "Gestión de expedientes digitales")
        this.buttonConfigs["Button7"] := Map("name", "Hermes", "albaParam", 22, "category", "INCIDENCIAS", "description", "Sistema de comunicaciones Hermes")
        this.buttonConfigs["Button8"] := Map("name", "Jara", "albaParam", 18, "category", "INCIDENCIAS", "description", "Sistema Jara")
        this.buttonConfigs["Button9"] := Map("name", "Quenda // Cita previa", "albaParam", 0, "category", "INCIDENCIAS", "description", "Sistema de citas previas")
        this.buttonConfigs["Button20"] := Map("name", "Emparejamiento ISL", "albaParam", 30, "category", "INCIDENCIAS", "description", "Configuración ISL")
        this.buttonConfigs["Button21"] := Map("name", "Certificado digital", "albaParam", 37, "category", "INCIDENCIAS", "description", "Gestión certificados digitales")
        this.buttonConfigs["Button24"] := Map("name", "Servicio no CEIURIS", "albaParam", 10, "category", "INCIDENCIAS", "description", "Servicios externos")
        this.buttonConfigs["Button33"] := Map("name", "@Driano", "albaParam", 13, "category", "INCIDENCIAS", "description", "Sistema @Driano")
        this.buttonConfigs["Button40"] := Map("name", "Contraseñas", "albaParam", 35, "category", "INCIDENCIAS", "description", "Gestión contraseñas")
        
        ; SOLICITUDES
        this.buttonConfigs["Button4"] := Map("name", "PortafirmasNG", "albaParam", 9, "category", "SOLICITUDES", "description", "Herramienta de firma digital")
        this.buttonConfigs["Button10"] := Map("name", "Suministros", "albaParam", 4, "category", "SOLICITUDES", "description", "Gestión de suministros")
        this.buttonConfigs["Button11"] := Map("name", "Internet libre", "albaParam", 21, "category", "SOLICITUDES", "description", "Solicitud acceso internet")
        this.buttonConfigs["Button12"] := Map("name", "Multiconferencia", "albaParam", 14, "category", "SOLICITUDES", "description", "Sistema de videoconferencia")
        this.buttonConfigs["Button13"] := Map("name", "Dragon Speaking", "albaParam", 32, "category", "SOLICITUDES", "description", "Software reconocimiento voz")
        this.buttonConfigs["Button14"] := Map("name", "Aumento espacio correo", "albaParam", 38, "category", "SOLICITUDES", "description", "Ampliación buzón correo")
        this.buttonConfigs["Button15"] := Map("name", "Abbypdf", "albaParam", 44, "category", "SOLICITUDES", "description", "Software PDF")
        this.buttonConfigs["Button16"] := Map("name", "GDU", "albaParam", 24, "category", "SOLICITUDES", "description", "Gestión documental unificada")
        this.buttonConfigs["Button34"] := Map("name", "Intervención video", "albaParam", 20, "category", "SOLICITUDES", "description", "Soporte videoconferencia")
        this.buttonConfigs["Button41"] := Map("name", "Formaciones", "albaParam", 27, "category", "SOLICITUDES", "description", "Solicitud formación")
        
        ; CIERRES
        this.buttonConfigs["Button17"] := Map("name", "Orfila", "albaParam", 12, "category", "CIERRES", "description", "Sistema Orfila")
        this.buttonConfigs["Button18"] := Map("name", "Lexnet", "albaParam", 16, "category", "CIERRES", "description", "Plataforma Lexnet")
        this.buttonConfigs["Button19"] := Map("name", "Siraj2", "albaParam", 6, "category", "CIERRES", "description", "Sistema Siraj2")
        this.buttonConfigs["Button22"] := Map("name", "Software", "albaParam", 5, "category", "CIERRES", "description", "Instalación software")
        this.buttonConfigs["Button23"] := Map("name", "PIN tarjeta", "albaParam", 11, "category", "CIERRES", "description", "Gestión PIN tarjetas")
        
        ; DP (Dispositivos/Hardware)
        this.buttonConfigs["Button25"] := Map("name", "Lector tarjeta", "albaParam", 17, "category", "DP", "description", "Dispositivos lectura tarjetas")
        this.buttonConfigs["Button26"] := Map("name", "Equipo sin red", "albaParam", 7, "category", "DP", "description", "Problemas conectividad")
        this.buttonConfigs["Button27"] := Map("name", "GM", "albaParam", 23, "category", "DP", "description", "Gestión de equipos")
        this.buttonConfigs["Button28"] := Map("name", "Teléfono", "albaParam", 2, "category", "DP", "description", "Problemas telefónicos")
        this.buttonConfigs["Button29"] := Map("name", "Ganes", "albaParam", 25, "category", "DP", "description", "Sistema Ganes")
        this.buttonConfigs["Button30"] := Map("name", "Equipo no enciende", "albaParam", 26, "category", "DP", "description", "Fallos hardware arranque")
        this.buttonConfigs["Button31"] := Map("name", "Disco duro", "albaParam", 33, "category", "DP", "description", "Problemas disco duro")
        this.buttonConfigs["Button32"] := Map("name", "Edoc Fortuny", "albaParam", 31, "category", "DP", "description", "Sistema Edoc Fortuny")
        this.buttonConfigs["Button35"] := Map("name", "Monitor", "albaParam", 15, "category", "DP", "description", "Problemas monitor")
        this.buttonConfigs["Button36"] := Map("name", "Teclado", "albaParam", 3, "category", "DP", "description", "Problemas teclado")
        this.buttonConfigs["Button37"] := Map("name", "Ratón", "albaParam", 8, "category", "DP", "description", "Problemas ratón")
        this.buttonConfigs["Button38"] := Map("name", "ISL Apagado", "albaParam", 19, "category", "DP", "description", "ISL desconectado")
        this.buttonConfigs["Button39"] := Map("name", "Error relación de confianza", "albaParam", 36, "category", "DP", "description", "Errores dominio")
        
        ; ESPECIALES
        this.buttonConfigs["Button42"] := Map("name", "Buscar", "albaParam", 0, "category", "SEARCH", "description", "Búsqueda incidencias", "special", true)
        
        ; Log de configuración cargada
        buttonCount := 0
        for buttonId in this.buttonConfigs {
            buttonCount++
        }
        this.logger.Info("Configuraciones de botones cargadas: " . buttonCount . " elementos")
    }
    
    /**
     * Obtiene la configuración de un botón
     */
    GetButtonConfig(buttonId) {
        return this.buttonConfigs[buttonId]
    }
    
    /**
     * Obtiene todos los botones de una categoría
     */
    GetButtonsByCategory(category) {
        result := Map()
        for buttonId in this.buttonConfigs {
            config := this.buttonConfigs[buttonId]
            if (config["category"] == category) {
                result[buttonId] := config
            }
        }
        return result
    }
    
    /**
     * Ejecuta la acción estándar de un botón
     */
    ExecuteButtonAction(buttonId, guiVars) {
        config := this.GetButtonConfig(buttonId)
        if (!config) {
            this.logger.Error("Configuración no encontrada para botón: " . buttonId)
            return false
        }
        
        this.logger.Info("Ejecutando acción: " . config["name"] . " (" . buttonId . ")")
        
        try {
            ; Validar que Remedy esté abierto
            if (!this.CheckRemedy()) {
                return false
            }
            
            ; Manejar botones especiales
            if (config.Has("special") && config["special"]) {
                return this.HandleSpecialButton(buttonId, config, guiVars)
            }
            
            ; Ejecutar acción estándar
            return this.ExecuteStandardAction(config, guiVars)
            
        } catch as e {
            this.logger.LogException(e, "ExecuteButtonAction-" . buttonId)
            return false
        }
    }
    
    /**
     * Ejecuta una acción estándar de botón
     */
    ExecuteStandardAction(config, guiVars) {
        ; Bloquear entrada del usuario
        BlockInput("On")
        
        try {
            ; Ejecutar script Alba
            this.ExecuteAlbaScript(config["albaParam"])
            
            ; Activar ventana Remedy
            this.ActivateRemedyWindow()
            
            ; Enviar datos del formulario
            this.SendFormData(guiVars.dni, guiVars.telf)
            
            ; Limpiar campos GUI
            this.ClearGUIFields()
            
            this.logger.Info("Acción ejecutada exitosamente: " . config["name"])
            return true
            
        } finally {
            BlockInput("Off")
        }
    }
    
    /**
     * Maneja botones especiales que requieren lógica diferente
     */
    HandleSpecialButton(buttonId, config, guiVars) {
        if (buttonId == "Button42") { ; Buscar
            return this.HandleSearchButton(guiVars)
        } else if (buttonId == "Button16") { ; GDU (copia DNI al clipboard)
            return this.HandleGDUButton(config, guiVars)
        } else {
            return this.ExecuteStandardAction(config, guiVars)
        }
    }
    
    /**
     * Maneja el botón de búsqueda
     */
    HandleSearchButton(guiVars) {
        try {
            this.ExecuteAlbaScript(0)
            Send("{F3}{Enter}{Tab 5}")
            Send(guiVars.Inci)
            Send("^{Enter}")
            this.ClearField("Inci")
            return true
        } catch as e {
            this.logger.LogException(e, "HandleSearchButton")
            return false
        }
    }
    
    /**
     * Maneja el botón GDU (con funcionalidad especial de clipboard)
     */
    HandleGDUButton(config, guiVars) {
        result := this.ExecuteStandardAction(config, guiVars)
        
        ; Funcionalidad especial: copiar DNI completo al clipboard
        if (result && guiVars.dni != "" && guiVars.DNILetter != "") {
            Clipboard := guiVars.dni . guiVars.DNILetter
            this.logger.Info("DNI completo copiado al clipboard: " . Clipboard)
        }
        
        return result
    }
    
    /**
     * Ejecuta el script de Alba con el parámetro especificado
     */
    ExecuteAlbaScript(param) {
        scriptPath := AppConfig.ALBA_SCRIPT_PATH
        command := "powershell.exe -ExecutionPolicy Bypass -File `"" . scriptPath . "`""
        
        RunWait(command, , "Hide")
        
        ; Enviar comandos a Remedy
        Send("^i")
        Send("{TAB 2}{End}{Up " . param . "}{Enter}")
        Send("{TAB 22}")
        
        this.logger.Debug("Script Alba ejecutado con parámetro: " . param)
    }
    
    /**
     * Activa la ventana de Remedy
     */
    ActivateRemedyWindow() {
        SetTitleMatchMode(2)
        WinActivate("ahk_class " . AppConfig.REMEDY_WINDOW_CLASS)
    }
    
    /**
     * Envía los datos del formulario a Remedy
     */
    SendFormData(dni, telf) {
        if (dni != "") {
            Send(dni)
            Send("{Tab}{Enter}")
            Send("{Tab 3}")
            Send("+{Left 90}{BackSpace}")
        }
        
        if (telf != "") {
            Send(telf)
        }
    }
    
    /**
     * Limpia los campos de la GUI - AutoHotkey v2
     */
    ClearGUIFields() {
        try {
            ; Obtener referencia a la aplicación principal
            app := CAUApplication.GetInstance()
            
            ; Limpiar campos usando el Map de controles GUI v2
            if (app.guiControls.Has("dni")) {
                app.guiControls["dni"].Text := ""
            }
            if (app.guiControls.Has("telf")) {
                app.guiControls["telf"].Text := ""
            }
            if (app.guiControls.Has("DNILetter")) {
                app.guiControls["DNILetter"].Text := ""
            }
            
            ; Actualizar variables internas
            app.guiVars.dni := ""
            app.guiVars.telf := ""
            app.guiVars.DNILetter := ""
            
            this.logger.Debug("Campos GUI limpiados con AutoHotkey v2")
            
        } catch as e {
            this.logger.LogException(e, "ClearGUIFields")
        }
    }
    
    /**
     * Limpia un campo específico de la GUI - AutoHotkey v2
     */
    ClearField(fieldName) {
        try {
            app := CAUApplication.GetInstance()
            
            if (app.guiControls.Has(fieldName)) {
                app.guiControls[fieldName].Text := ""
                ; Actualizar variable correspondiente
                if (app.guiVars.HasOwnProp(fieldName)) {
                    app.guiVars[fieldName] := ""
                }
            }
            
            this.logger.Debug("Campo " . fieldName . " limpiado con AutoHotkey v2")
            
        } catch as e {
            this.logger.LogException(e, "ClearField")
        }
    }
    
    /**
     * Verifica si Remedy está abierto
     */
    CheckRemedy() {
        if (WinExist("ahk_exe " . AppConfig.REMEDY_EXECUTABLE)) {
            return true
        } else {
            MsgBox("El programa Remedy no se encuentra abierto.`n`nPor favor, ábrelo antes de continuar.", "Error", "IconExclamation")
            this.logger.Warning("Intento de acción sin Remedy abierto")
            return false
        }
    }
}