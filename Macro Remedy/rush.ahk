toggle := false ; Variable para controlar el estado del clic

; Inicia o detiene el clic automático al pulsar Ctrl izquierda
LControl::
toggle := !toggle
if (toggle) {
    SetTimer, AutoClick, 10 ; Configura un temporizador para hacer clic cada 10 ms
} else {
    SetTimer, AutoClick, Off ; Apaga el temporizador
}
return

; Subrutina para realizar el clic automático
AutoClick:
Click
return