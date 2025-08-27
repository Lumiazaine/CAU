#Requires AutoHotkey v2.0
#SingleInstance Force

; Test Logger sin includes
class TestLogger {
    static instance := ""
    
    static GetInstance() {
        if (this.instance == "") {
            this.instance := TestLogger()
        }
        return this.instance
    }
    
    Info(message) {
        ; Test básico
        return true
    }
}

logger := TestLogger.GetInstance()
logger.Info("Test message")
MsgBox("Logger básico funciona", "Test", "IconInfo")
ExitApp()