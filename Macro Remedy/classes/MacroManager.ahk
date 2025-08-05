; =============================================================================
; CLASE PARA MACROS
; =============================================================================
class MacroManager {
    ; Ejecuta la macro Alba con el número especificado
    static ExecuteAlba(num) {
        if (!Utils.IsRemedyRunning()) {
            return
        }
        try {
            BlockInput, On
            RunWait, powershell.exe -ExecutionPolicy Bypass -File "%Config.ALBA_SCRIPT_PATH%",, Hide
            Utils.ActivateRemedyWindow()
            Send, ^i
            Send, {TAB 2}{End}{Up %num%}{Enter}
            Send, {TAB 22}
            Logger.Write("Ejecutó la macro Alba con parámetro " . num)
        } catch e {
            Logger.WriteError("Ejecutando macro Alba: " . e.Message)
        } finally {
            BlockInput, Off
        }
    }
    
    ; Ejecuta el proceso de cierre con texto personalizado
    static ExecuteCierre(closetext) {
        try {
            Sleep, 800
            Send, ^{enter}{Enter}
            Sleep, 800
            SendInput, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 5}{Enter 3}
            SendInput, !a {Down 9}{Right}{Enter}{TAB 12}{Right 2}{TAB 6}{Enter}%closetext%{Tab}{Enter}
            Logger.Write("Cierre ejecutado con texto: " . closetext)
        } catch e {
            Logger.WriteError("Cierre ejecutado con texto: " . e.Message)
        }
    }
    
    ; Ejecuta una macro estándar con DNI y teléfono
    static ExecuteStandardMacro(albaNumber, dni, telf, closeText := "") {
        if (!Utils.IsRemedyRunning()) {
            return
        }
        try {
            this.ExecuteAlba(albaNumber)
            Gui, Submit, NoHide
            Send, %dni%
            Send, {Tab}{Enter}
            Send, {Tab 3}
            Send, +{Left 90}{BackSpace}
            Send, %telf%
            GuiControl,, dni
            GuiControl,, telf
            
            if (closeText != "") {
                this.ExecuteCierre(closeText)
            }
            
            Logger.Write("Ejecutó macro alba " . dni . " y " . telf)
        } catch e {
            Logger.WriteError("Error ejecutando macro: " . e.Message)
        }
    }
    
    ; Ejecuta una macro de búsqueda
    static ExecuteSearchMacro(inci) {
        if (!Utils.IsRemedyRunning()) {
            return
        }
        try {
            Gui, Submit, NoHide
            this.ExecuteAlba(0)
            Send, {F3}{Enter}{Tab 5}
            Send, %inci%
            Send, ^{Enter}
            GuiControl,, Inci
            Logger.Write("Pulsó el botón Buscar y ejecutó la macro Alba con Inci: " . inci)
        } catch e {
            Logger.WriteError("Pulsando botón Buscar: " . e.Message)
        }
    }
    
    ; Ejecuta una macro con repetición
    static ExecuteRepeatMacro(albaNumber, repeatCount) {
        if (!Utils.IsRemedyRunning()) {
            return
        }
        
        Loop %repeatCount% {
            try {
                this.ExecuteAlba(albaNumber)
                Send ^{Enter}{Enter}
                Logger.Write("Ejecutó macro repetitiva (Iteración: " . A_Index . ")")
            } catch e {
                Logger.WriteError("Error en iteración " . A_Index . ": " . e.Message)
            }
            Sleep 100
        }
    }
} 