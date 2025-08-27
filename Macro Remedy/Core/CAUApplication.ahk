; ===============================================================================
; CAUApplication.ahk - Clase principal de la aplicación
; ===============================================================================

#Include "../Config/AppConfig.ahk"
#Include "../Utils/Logger.ahk"
#Include "../Utils/DNIValidator.ahk"
#Include "ButtonManager.ahk"
#Include "UpdateManager.ahk"

class CAUApplication {
    
    static instance := ""
    
    ; Instancias de componentes
    logger := ""
    dniValidator := ""
    buttonManager := ""
    updateManager := ""
    
    ; Variables de la GUI (AutoHotkey v2)
    gui := ""
    guiControls := Map()
    guiVars := {}
    
    ; Estado de la aplicación
    afkMode := false
    afkTimer := ""
    
    /**
     * Constructor
     */
    __New() {
        ; Inicializar componentes
        this.logger := Logger.GetInstance()
        this.dniValidator := DNIValidator.GetInstance()
        this.buttonManager := ButtonManager.GetInstance()
        this.updateManager := UpdateManager.GetInstance()
        
        ; Configurar AutoHotkey para rendimiento óptimo
        this.ConfigureAutoHotkey()
        
        ; Inicializar variables GUI
        this.InitializeGUIVars()
        
        ; Registrar inicio de aplicación
        this.logger.LogAppStart()
    }
    
    /**
     * Obtiene la instancia singleton
     */
    static GetInstance() {
        if (this.instance == "") {
            this.instance := CAUApplication()
        }
        return this.instance
    }
    
    /**
     * Configura AutoHotkey para rendimiento óptimo
     */
    ConfigureAutoHotkey() {
        ; En v2, las directivas se configuran al inicio del script
        ; La mayoría de estas configuraciones ya no son necesarias en v2
        
        ; Configurar resolución de timer para mayor precisión
        try {
            DllCall("ntdll\\ZwSetTimerResolution", "Int", 5000, "Int", 1, "Int*", &MyCurrentTimerResolution := 0)
        } catch as e {
            this.logger.Warning("No se pudo configurar resolución de timer: " . e.message)
        }
        
        ; Establecer directorio de trabajo
        SetWorkingDir(A_ScriptDir)
        
        this.logger.Debug("AutoHotkey configurado para rendimiento óptimo")
    }
    
    /**
     * Inicializa las variables de la GUI
     */
    InitializeGUIVars() {
        this.guiVars := {
            dni: "",
            telf: "",
            Inci: "",
            DNILetter: "",
            ModoSeguro: false
        }
    }
    
    /**
     * Inicia la aplicación
     */
    Start() {
        try {
            ; Verificar actualizaciones de forma asíncrona
            this.updateManager.CheckForUpdatesAsync()
            
            ; Crear y mostrar GUI
            this.CreateGUI()
            this.ShowGUI()
            
            ; Configurar hotkeys
            this.SetupHotkeys()
            
            ; Configurar timers
            this.SetupTimers()
            
            this.logger.Info("Aplicación iniciada correctamente")
            
            ; Mantener la aplicación ejecutándose
            return
            
        } catch as e {
            this.logger.LogException(e, "Start")
            this.ShowCriticalError("Error al iniciar la aplicación", e.message)
            ExitApp()
        }
    }
    
    /**
     * Crea la interfaz gráfica de usuario - AutoHotkey v2
     */
    CreateGUI() {
        try {
            ; Crear GUI principal con sintaxis v2
            this.gui := Gui("+Resize +MaximizeBox +MinimizeBox", AppConfig.GUI_TITLE)
            this.gui.BackColor := "White"
            this.gui.MarginX := 15
            this.gui.MarginY := 15
            
            ; Configurar manejador de eventos de cierre
            this.gui.OnEvent("Close", (*) => this.HandleGuiClose())
            this.gui.OnEvent("Escape", (*) => this.HandleGuiEscape())
            
            ; Crear secciones de la GUI
            this.CreateInputSection()
            this.CreateButtonSections()
            this.CreateSpecialControls()
            
            ; Establecer icono si existe
            if (FileExist(A_ScriptDir . "\\Assets\\icon.ico")) {
                this.gui.Opt("+Icon" . A_ScriptDir . "\\Assets\\icon.ico")
            }
            
            this.logger.Info("GUI completa creada con AutoHotkey v2")
            
        } catch as e {
            this.logger.LogException(e, "CreateGUI")
            MsgBox("Error al crear la GUI: " . e.message, "Error Crítico", "IconX")
            throw e
        }
    }
    
    /**
     * Crea la sección de campos de entrada - AutoHotkey v2
     */
    CreateInputSection() {
        ; Etiquetas y campos de entrada
        this.gui.Add("Text", "x68 y644 w33 h21", "DNI:")
        this.guiControls["dni"] := this.gui.Add("Edit", "vdni x109 y639 w188 h26")
        this.guiControls["DNILetter"] := this.gui.Add("Edit", "vDNILetter x300 y639 w20 h26 ReadOnly")
        
        this.gui.Add("Text", "x327 y645 w76 h21", "TELÉFONO:")
        this.guiControls["telf"] := this.gui.Add("Edit", "vtelf x411 y638 w188 h26")
        
        this.gui.Add("Text", "x786 y646 w23 h21", "IN:")
        this.guiControls["Inci"] := this.gui.Add("Edit", "vInci x817 y637 w188 h26")
        
        ; Configurar eventos para actualización automática de letra DNI
        this.guiControls["dni"].OnEvent("Change", (*) => this.UpdateDNILetter())
        
        ; Botón de búsqueda y modo seguro
        btnBuscar := this.gui.Add("Button", "x1050 y635 w80 h23", "Buscar")
        btnBuscar.OnEvent("Click", (*) => this.HandleButtonClick("Button42"))
        
        this.guiControls["ModoSeguro"] := this.gui.Add("Checkbox", "vModoSeguro x1200 y635 w80 h23", "Modo Seguro")
        
        this.logger.Debug("Sección de entrada creada con AutoHotkey v2")
    }
    
    /**
     * Crea las secciones de botones organizadas por categoría - AutoHotkey v2
     */
    CreateButtonSections() {
        ; Headers de categorías con estilos mejorados
        this.gui.SetFont("s10 Bold", "Segoe UI")
        this.gui.Add("Text", "x288 y20 w95 h20 Center", "INCIDENCIAS")
        this.gui.Add("Text", "x289 y376 w98 h19 Center", "SOLICITUDES")
        this.gui.Add("Text", "x797 y18 w67 h18 Center", "CIERRES")
        this.gui.Add("Text", "x798 y368 w84 h19 Center", "MINISTERIO")
        this.gui.Add("Text", "x1219 y17 w25 h17 Center", "DP")
        
        ; Restaurar fuente normal para botones
        this.gui.SetFont("s9 Normal", "Segoe UI")
        
        ; Obtener configuraciones de botones
        buttonConfigs := this.buttonManager.buttonConfigs
        
        ; Crear botones dinámicamente
        for buttonId in buttonConfigs {
            config := buttonConfigs[buttonId]
            if (config.Has("special") && config["special"]) {
                continue  ; Los botones especiales se manejan por separado
            }
            
            ; Obtener posición del botón
            pos := this.GetButtonPosition(buttonId, config["category"])
            if (pos["x"] != 0) {
                btn := this.gui.Add("Button", "x" . pos["x"] . " y" . pos["y"] . " w183 h68", config["name"])
                btn.OnEvent("Click", (*) => this.HandleButtonClick(buttonId))
            }
        }
        
        this.logger.Debug("Secciones de botones creadas con AutoHotkey v2")
    }
    
    /**
     * Obtiene la posición de un botón basada en su ID y categoría
     */
    GetButtonPosition(buttonId, category) {
        ; Mapeo de posiciones (simplificado - en producción esto podría leerse desde configuración)
                positions := Map(
            "Button1", Map("x", 49, "y", 57),    ; Adriano
            "Button2", Map("x", 49, "y", 137),   ; Escritorio judicial
            "Button3", Map("x", 431, "y", 56),   ; Arconte
            "Button4", Map("x", 50, "y", 285),   ; PortafirmasNG
            "Button5", Map("x", 241, "y", 56),   ; Agenda de señalamientos
            "Button6", Map("x", 241, "y", 136),  ; Expediente digital
            "Button7", Map("x", 50, "y", 212),   ; Hermes
            "Button8", Map("x", 240, "y", 210),  ; Jara
            "Button9", Map("x", 432, "y", 209),  ; Quenda // Cita previa
            "Button10", Map("x", 240, "y", 284), ; Suministros
            "Button11", Map("x", 242, "y", 478), ; Internet libre
            "Button12", Map("x", 52, "y", 548),  ; Multiconferencia
            "Button13", Map("x", 432, "y", 408), ; Dragon Speaking
            "Button14", Map("x", 242, "y", 408), ; Aumento espacio correo
            "Button15", Map("x", 52, "y", 408),  ; Abbypdf
            "Button16", Map("x", 52, "y", 478),  ; GDU
            "Button17", Map("x", 741, "y", 476), ; Orfila
            "Button18", Map("x", 740, "y", 406), ; Lexnet
            "Button19", Map("x", 742, "y", 547), ; Siraj2
            "Button20", Map("x", 431, "y", 134), ; Emparejamiento ISL
            "Button21", Map("x", 642, "y", 127), ; Certificado digital
            "Button22", Map("x", 831, "y", 57),  ; Software
            "Button23", Map("x", 831, "y", 128), ; PIN tarjeta
            "Button24", Map("x", 643, "y", 199), ; Servicio no CEIURIS
            "Button25", Map("x", 1234, "y", 198), ; Lector tarjeta
            "Button26", Map("x", 1045, "y", 197), ; Equipo sin red
            "Button27", Map("x", 1233, "y", 57),  ; GM
            "Button28", Map("x", 1137, "y", 483), ; Teléfono
            "Button29", Map("x", 1046, "y", 410), ; Ganes
            "Button30", Map("x", 1045, "y", 268), ; Equipo no enciende
            "Button31", Map("x", 1045, "y", 57),  ; Disco duro
            "Button32", Map("x", 1045, "y", 127), ; Edoc Fortuny
            "Button33", Map("x", 832, "y", 199),  ; @Driano
            "Button34", Map("x", 432, "y", 478),  ; Intervención video
            "Button35", Map("x", 1235, "y", 267), ; Monitor
            "Button36", Map("x", 1236, "y", 410), ; Teclado
            "Button37", Map("x", 1236, "y", 338), ; Ratón
            "Button38", Map("x", 1233, "y", 127), ; ISL Apagado
            "Button39", Map("x", 1045, "y", 339), ; Error relación de confianza
            "Button40", Map("x", 642, "y", 56),   ; Contraseñas
            "Button41", Map("x", 244, "y", 549)   ; Formaciones
        )
        
        return positions.Has(buttonId) ? positions[buttonId] : Map("x", 0, "y", 0)
    }
    
    /**
     * Crea controles especiales - AutoHotkey v2
     */
    CreateSpecialControls() {
        ; Información de versión con estilo
        this.gui.SetFont("s8 Normal", "Segoe UI")
        this.gui.Add("Text", "x10 y680 w200 h20 c0x808080", "v" . AppConfig.VERSION . " - " . AppConfig.AUTHOR)
        
        ; Botón de ayuda
        this.gui.SetFont("s9 Normal", "Segoe UI")
        btnAyuda := this.gui.Add("Button", "x1350 y635 w80 h23", "Ayuda")
        btnAyuda.OnEvent("Click", (*) => this.ShowHelp())
        
        this.logger.Debug("Controles especiales creados con AutoHotkey v2")
    }
    
    /**
     * Muestra la GUI
     */
    ShowGUI() {
        try {
            if (this.gui) {
                this.gui.Show("w" . AppConfig.GUI_WIDTH . " h" . AppConfig.GUI_HEIGHT)
                this.logger.Debug("GUI mostrada")
            } else {
                this.logger.Warning("GUI no inicializada correctamente")
            }
        } catch as e {
            this.logger.LogException(e, "ShowGUI")
            ; La aplicación puede continuar funcionando con hotkeys aunque la GUI falle
        }
    }
    
    /**
     * Configura los hotkeys de la aplicación - AutoHotkey v2
     */
    SetupHotkeys() {
        ; En AutoHotkey v2, los hotkeys requieren funciones como parámetros
        ; Hotkeys numéricos (Win + número)
        HotKey("#1", (*) => this.HandleButtonClick("Button9"))   ; Quenda/Cita previa
        HotKey("#2", (*) => this.HandleButtonClick("Button4"))   ; PortafirmasNG
        HotKey("#3", (*) => this.HandleButtonClick("Button6"))   ; Expediente digital
        HotKey("#4", (*) => this.HandleButtonClick("Button40"))  ; Contraseñas
        HotKey("#5", (*) => this.HandleButtonClick("Button32"))  ; Edoc Fortuny
        HotKey("#6", (*) => this.HandleRepeatAction())           ; Repetir incidencias
        HotKey("#7", (*) => this.HandleAFKMode())               ; Modo AFK
        HotKey("#9", (*) => this.HandleButtonClick("Button42"))  ; Búsqueda rápida
        HotKey("#0", (*) => this.ReloadApplication())           ; Recargar aplicación
        
        ; Hotkeys de función (F12-F20) - mapeo a botones específicos
        fKeyMap := Map(
            "F12", "Button1",   ; Adriano
            "F13", "Button2",   ; Escritorio judicial
            "F14", "Button3",   ; Arconte
            "F15", "Button7",   ; Hermes
            "F16", "Button8",   ; Jara
            "F17", "Button33",  ; @Driano
            "F18", "Button20",  ; Emparejamiento ISL
            "F19", "Button21",  ; Certificado digital
            "F20", "Button24"   ; Servicio no CEIURIS
        )
        
        for fKey, buttonId in fKeyMap {
            HotKey(fKey, (*) => this.HandleButtonClick(buttonId))
        }
        
        ; Botones adicionales del ratón
        HotKey("XButton1", (*) => this.HandleXButton1())
        HotKey("XButton2", (*) => this.HandleXButton2())
        
        this.logger.Debug("Hotkeys configurados con AutoHotkey v2")
    }
    
    /**
     * Configura los timers de la aplicación
     */
    SetupTimers() {
        ; Timer para mantener actividad (AFK)
        this.afkTimer := ObjBindMethod(this, "HandleAFKTimer")
    }
    
    
    /**
     * Actualiza la letra del DNI automáticamente - AutoHotkey v2
     */
    UpdateDNILetter() {
        try {
            dni := this.guiControls["dni"].Text
            if (dni != "") {
                letter := this.dniValidator.CalculateDNILetter(dni)
                this.guiControls["DNILetter"].Text := letter
            } else {
                this.guiControls["DNILetter"].Text := ""
            }
        } catch as e {
            this.logger.LogException(e, "UpdateDNILetter")
        }
    }
    
    /**
     * Maneja la ejecución de botones - AutoHotkey v2
     */
    HandleButtonClick(buttonId) {
        try {
            ; Obtener valores actualizados de los controles GUI
            this.UpdateGUIVars()
            
            ; Ejecutar acción del botón
            result := this.buttonManager.ExecuteButtonAction(buttonId, this.guiVars)
            
            if (result) {
                this.logger.Info("Botón " . buttonId . " ejecutado exitosamente")
            } else {
                this.logger.Warning("Falló la ejecución del botón " . buttonId)
            }
            
        } catch as e {
            this.logger.LogException(e, "HandleButtonClick-" . buttonId)
        }
    }
    
    /**
     * Actualiza las variables GUI con los valores actuales - AutoHotkey v2
     */
    UpdateGUIVars() {
        try {
            if (this.guiControls.Has("dni")) {
                this.guiVars.dni := this.guiControls["dni"].Text
            }
            if (this.guiControls.Has("telf")) {
                this.guiVars.telf := this.guiControls["telf"].Text
            }
            if (this.guiControls.Has("Inci")) {
                this.guiVars.Inci := this.guiControls["Inci"].Text
            }
            if (this.guiControls.Has("DNILetter")) {
                this.guiVars.DNILetter := this.guiControls["DNILetter"].Text
            }
            if (this.guiControls.Has("ModoSeguro")) {
                this.guiVars.ModoSeguro := this.guiControls["ModoSeguro"].Value
            }
        } catch as e {
            this.logger.LogException(e, "UpdateGUIVars")
        }
    }
    
    /**
     * Maneja el cierre de la GUI - AutoHotkey v2
     */
    HandleGuiClose() {
        this.logger.Info("Cerrando aplicación por solicitud del usuario")
        ExitApp()
    }
    
    /**
     * Maneja la tecla Escape en la GUI - AutoHotkey v2
     */
    HandleGuiEscape() {
        ; No hacer nada al presionar Escape, mantener la aplicación abierta
    }
    
    /**
     * Maneja el modo AFK
     */
    HandleAFKMode() {
        try {
            this.afkMode := !this.afkMode
            
            if (this.afkMode) {
                SetTimer(this.afkTimer, AppConfig.AFK_TIMER_INTERVAL)
                MsgBox("Modo AFK activado.`n`nLa aplicación enviará señales periódicas para mantener la sesión activa.", "Modo AFK", "IconInfo")
                this.logger.Info("Modo AFK activado")
            } else {
                SetTimer(this.afkTimer, 0)
                MsgBox("Modo AFK desactivado.", "Modo AFK", "IconInfo")
                this.logger.Info("Modo AFK desactivado")
            }
            
        } catch as e {
            this.logger.LogException(e, "HandleAFKMode")
        }
    }
    
    /**
     * Timer para mantener actividad
     */
    HandleAFKTimer() {
        try {
            if (this.afkMode) {
                MouseGetPos(&xpos, &ypos)
                MouseMove(xpos, ypos, 0)
                Send("{Shift}")
                this.logger.Debug("Señal AFK enviada")
            }
        } catch as e {
            this.logger.LogException(e, "HandleAFKTimer")
        }
    }
    
    /**
     * Muestra el diálogo de ayuda
     */
    ShowHelp() {
        helpText := "=== GESTOR DE INCIDENCIAS CAU ===`n`n"
        helpText .= "CARACTERÍSTICAS PRINCIPALES:`n"
        helpText .= "• Gestión automatizada de incidencias en Remedy`n"
        helpText .= "• Cálculo automático de letra de DNI`n"
        helpText .= "• Modo AFK para mantener sesión activa`n"
        helpText .= "• Sistema de actualización automática`n"
        helpText .= "• Logging avanzado de operaciones`n`n"
        helpText .= "INSTRUCCIONES DE USO:`n"
        helpText .= "1. Asegúrese de tener Remedy abierto`n"
        helpText .= "2. Complete los campos DNI y Teléfono`n"
        helpText .= "3. Haga clic en el botón correspondiente a su incidencia`n"
        helpText .= "4. Los datos se procesarán automáticamente`n`n"
        helpText .= "HOTKEYS DISPONIBLES:`n"
        helpText .= "• Win+1-5: Accesos rápidos a funciones principales`n"
        helpText .= "• Win+6: Repetir incidencias múltiples veces`n"
        helpText .= "• Win+7: Activar/Desactivar modo AFK`n"
        helpText .= "• Win+9: Búsqueda rápida`n"
        helpText .= "• Win+0: Recargar aplicación`n"
        helpText .= "• F12-F20: Funciones especializadas`n`n"
        helpText .= "CATEGORÍAS:`n"
        helpText .= "• INCIDENCIAS: Problemas técnicos generales`n"
        helpText .= "• SOLICITUDES: Peticiones de recursos/servicios`n"
        helpText .= "• CIERRES: Resolución de tickets existentes`n"
        helpText .= "• MINISTERIO: Sistemas específicos del ministerio`n"
        helpText .= "• DP: Problemas de hardware y dispositivos`n`n"
        helpText .= "SOPORTE:`n"
        helpText .= "Para soporte técnico o reportar errores,`n"
        helpText .= "consulte los logs en: " . AppConfig.GetLogFilePath() . "`n`n"
        helpText .= "Versión: " . AppConfig.VERSION . "`n"
        helpText .= "Desarrollado por: " . AppConfig.AUTHOR
        
        MsgBox(helpText, "Ayuda - " . AppConfig.GUI_TITLE, "IconInfo")
    }
    
    /**
     * Muestra un error crítico y termina la aplicación
     */
    ShowCriticalError(title, message) {
        this.logger.Critical(title . ": " . message)
        MsgBox(message . "`n`nLa aplicación se cerrará.", "Error Crítico - " . title, "IconX")
    }
    
    /**
     * Maneja el cierre de la aplicación
     */
    HandleClose() {
        try {
            ; Limpiar timers
            if (this.afkMode) {
                SetTimer(this.afkTimer, 0)
            }
            
            ; Registrar cierre
            this.logger.LogAppEnd()
            
            ; Salir
            ExitApp()
            
        } catch as e {
            ; Error en el cierre - salir de todas formas
            ExitApp()
        }
    }
    
    /**
     * Maneja la repetición de acciones - AutoHotkey v2
     */
    HandleRepeatAction() {
        try {
            repeatCount := InputBox("¿Cuántas veces deseas repetir la acción?", "Repeticiones", "w300 h150")
            if (repeatCount.Result == "OK" && IsInteger(repeatCount.Value) && repeatCount.Value > 0 && repeatCount.Value <= 999) {
                Loop repeatCount.Value {
                    this.HandleButtonClick("Button1")  ; Adriano por defecto
                    Sleep(100)
                }
                MsgBox("Completadas " . repeatCount.Value . " iteraciones.", "Completado", "IconInfo")
            }
        } catch as e {
            this.logger.LogException(e, "HandleRepeatAction")
        }
    }
    
    /**
     * Maneja XButton1 del ratón - AutoHotkey v2
     */
    HandleXButton1() {
        if (this.buttonManager.CheckRemedy()) {
            Send("{Alt}a{Down 9}{Right}{Enter}")
        }
    }
    
    /**
     * Maneja XButton2 del ratón - AutoHotkey v2
     */
    HandleXButton2() {
        Send("#+s")  ; Captura de pantalla
    }
    
    /**
     * Recarga la aplicación - AutoHotkey v2
     */
    ReloadApplication() {
        this.logger.Info("Recargando aplicación...")
        Reload()
    }
}