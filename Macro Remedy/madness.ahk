; =======================
; CONFIGURACIÓN INICIAL
; =======================
#NoEnv
SendMode Input
SetTitleMatchMode, 2

; Variable para activar o desactivar el clic automático
toggle := false

; Define cuánto es ~3 cm en tu pantalla (prueba 60, 80, 100, etc.)
threeCm := 80

; Valores hexadecimales de color (RGB) aproximados
; Ajusta según el color real que detectes en tu sistema
colorRojo := 0xFF0000
colorAzul := 0x0000FF

; Tolerancia de búsqueda de color (0 a 255)
; Más alto = más flexible ante variaciones
colorVariation := 50

; ============================
; TECLA PARA ACTIVAR/DESACTIVAR
; ============================
LControl::
toggle := !toggle
if (toggle) {
    ; Activa un temporizador que revisa cada 50 ms
    SetTimer, CheckForColors, 50
} else {
    ; Desactiva el temporizador
    SetTimer, CheckForColors, Off
}
return

; ===================================
; SUBRUTINA PRINCIPAL: CheckForColors
; ===================================
CheckForColors:
{
    ; 1) Buscar recuadro ROJO en la pantalla
    ;    Ajusta el área de búsqueda (0,0, A_ScreenWidth, A_ScreenHeight)
    ;    y la velocidad (Fast/ RGB).
    PixelSearch, foundX, foundY, 0, 0, A_ScreenWidth, A_ScreenHeight, colorRojo, colorVariation, Fast RGB
    if (ErrorLevel = 0)
    {
        ; Se encontró el color rojo
        ; Movemos el ratón a esa posición (rápidamente)
        MouseMove, foundX, foundY, 0
        ; Subimos ~3 cm
        MouseMove, 0, -threeCm, 0, R
        ; Hacemos clic
        Click
        return
    }

    ; 2) Buscar recuadro AZUL en la pantalla
    PixelSearch, foundX, foundY, 0, 0, A_ScreenWidth, A_ScreenHeight, colorAzul, colorVariation, Fast RGB
    if (ErrorLevel = 0)
    {
        ; Se encontró el color azul
        ; Movemos el ratón a esa posición o a la posición del botón “flecha a la derecha”
        MouseMove, foundX, foundY, 0
        Click
        return
    }

    ; 3) Si no se encontró recuadro rojo ni azul:
    ;    Realizamos un clic automático normal
    Click
}
return
