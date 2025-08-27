; ===============================================================================
; DNIValidator.ahk - Utilidades para validación y cálculo de DNI
; ===============================================================================

#Include "../Config/AppConfig.ahk"
#Include "Logger.ahk"

class DNIValidator {
    
    static instance := ""
    logger := ""
    
    /**
     * Constructor
     */
    __New() {
        this.logger := Logger.GetInstance()
    }
    
    /**
     * Obtiene la instancia singleton
     */
    static GetInstance() {
        if (this.instance == "") {
            this.instance := DNIValidator()
        }
        return this.instance
    }
    
    /**
     * Calcula la letra correspondiente a un número de DNI
     * @param dniNumber Número del DNI (1-8 dígitos)
     * @return Letra del DNI o cadena vacía si el número no es válido
     */
    CalculateDNILetter(dniNumber) {
        ; Validar entrada
        if (!this.IsValidDNINumber(dniNumber)) {
            this.logger.Debug("Número de DNI inválido: '" . dniNumber . "'")
            return ""
        }
        
        ; Convertir a número y calcular módulo
        number := dniNumber + 0  ; Forzar conversión numérica
        index := Mod(number, 23)
        
        ; Obtener letra correspondiente
        letter := SubStr(AppConfig.DNI_LETTERS, index + 1, 1)
        
        this.logger.Debug("DNI " . dniNumber . " -> Letra: " . letter)
        return letter
    }
    
    /**
     * Valida si un número de DNI es correcto
     * @param dniNumber Número a validar
     * @return true si es válido, false en caso contrario
     */
    IsValidDNINumber(dniNumber) {
        ; Verificar que no esté vacío
        if (dniNumber == "") {
            return false
        }
        
        ; Verificar que sea numérico y tenga la longitud correcta
        return RegExMatch(dniNumber, "^\d{" . AppConfig.DNI_MIN_LENGTH . "," . AppConfig.DNI_MAX_LENGTH . "}$")
    }
    
    /**
     * Valida un DNI completo (número + letra)
     * @param fullDNI DNI completo (ej: "12345678Z")
     * @return true si es válido, false en caso contrario
     */
    ValidateFullDNI(fullDNI) {
        ; Verificar formato básico
        if (!RegExMatch(fullDNI, "^(\d{1,8})([A-Z])$", &match)) {
            return false
        }
        
        dniNumber := match[1]
        dniLetter := match[2]
        
        ; Verificar que la letra calculada coincida
        calculatedLetter := this.CalculateDNILetter(dniNumber)
        
        return (calculatedLetter == dniLetter)
    }
    
    /**
     * Formatea un DNI añadiendo ceros a la izquierda si es necesario
     * @param dniNumber Número del DNI
     * @param targetLength Longitud objetivo (por defecto 8)
     * @return DNI formateado
     */
    FormatDNI(dniNumber, targetLength := 8) {
        if (!this.IsValidDNINumber(dniNumber)) {
            return dniNumber
        }
        
        ; Añadir ceros a la izquierda
        formatted := dniNumber
        while (StrLen(formatted) < targetLength) {
            formatted := "0" . formatted
        }
        
        return formatted
    }
    
    /**
     * Obtiene un DNI completo formateado (número + letra)
     * @param dniNumber Número del DNI
     * @param includeLetter Si incluir la letra (por defecto true)
     * @param formatNumber Si formatear el número con ceros (por defecto false)
     * @return DNI completo formateado
     */
    GetFullDNI(dniNumber, includeLetter := true, formatNumber := false) {
        if (!this.IsValidDNINumber(dniNumber)) {
            return dniNumber
        }
        
        ; Formatear número si se solicita
        formattedNumber := formatNumber ? this.FormatDNI(dniNumber) : dniNumber
        
        ; Añadir letra si se solicita
        if (includeLetter) {
            letter := this.CalculateDNILetter(dniNumber)
            if (letter != "") {
                return formattedNumber . letter
            }
        }
        
        return formattedNumber
    }
    
    /**
     * Separa un DNI completo en número y letra
     * @param fullDNI DNI completo
     * @return Objeto con propiedades 'number' y 'letter'
     */
    SeparateDNI(fullDNI) {
                result := Map("number", "", "letter", "")
        
        if (RegExMatch(fullDNI, "^(\d+)([A-Z])$", &match)) {
            result["number"] := match[1]
            result["letter"] := match[2]
        } else if (RegExMatch(fullDNI, "^(\d+)$", &match)) {
            result["number"] := match[1]
        }
        
        return result
    }
    
    /**
     * Obtiene información detallada sobre un DNI
     * @param input Número o DNI completo
     * @return Objeto con información del DNI
     */
    GetDNIInfo(input) {
        separated := this.SeparateDNI(input)
        
        info := Map(
            "originalInput", input,
            "number", separated["number"],
            "providedLetter", separated["letter"],
            "calculatedLetter", "",
            "formattedNumber", "",
            "fullDNI", "",
            "isValidNumber", false,
            "isValidComplete", false,
            "hasCorrectLetter", false
        )
        
        ; Validar número
        if (this.IsValidDNINumber(separated["number"])) {
            info["isValidNumber"] := true
            info["calculatedLetter"] := this.CalculateDNILetter(separated["number"])
            info["formattedNumber"] := this.FormatDNI(separated["number"])
            info["fullDNI"] := info["formattedNumber"] . info["calculatedLetter"]
            
            ; Verificar letra si se proporcionó
            if (separated["letter"] != "") {
                info["hasCorrectLetter"] := (separated["letter"] == info["calculatedLetter"])
                info["isValidComplete"] := info["hasCorrectLetter"]
            }
        }
        
        return info
    }
}