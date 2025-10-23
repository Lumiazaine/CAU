#Requires -Version 5.1

<#
.SYNOPSIS
    Suite de tests exhaustiva para la función Normalize-Text mejorada
.DESCRIPTION
    Conjunto de 500+ casos de prueba que valida:
    - Corrección de caracteres mal codificados
    - Normalización UTF-8
    - Patrones de corrupción específicos
    - Casos edge con múltiples corrupciones
    - Rendimiento con textos largos
    - Integración con Extract-LocationFromOffice
#>

# Importar el script principal
. "$PSScriptRoot\AD_UserManagement.ps1"

# Estructura global para recolectar resultados
$Global:TestResults = @{
    'Passed' = 0
    'Failed' = 0
    'Errors' = @()
    'Performance' = @()
}

function Test-NormalizeTextFunction {
    <#
    .SYNOPSIS
        Ejecuta todas las pruebas de normalización de texto
    #>
    [CmdletBinding()]
    param()
    
    Write-Host "🔬 INICIANDO SUITE DE TESTS EXHAUSTIVA PARA NORMALIZE-TEXT" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    # TEST CATEGORY 1: Caracteres corruptos básicos (100 casos)
    Test-BasicCorruptedCharacters
    
    # TEST CATEGORY 2: Nombres de provincias andaluzas (80 casos)
    Test-AndalusianProvinces
    
    # TEST CATEGORY 3: Términos judiciales específicos (120 casos)
    Test-JudicalTerms
    
    # TEST CATEGORY 4: Casos edge complejos (100 casos)
    Test-ComplexEdgeCases
    
    # TEST CATEGORY 5: Rendimiento con textos largos (50 casos)
    Test-PerformanceWithLongTexts
    
    # TEST CATEGORY 6: Integración con Extract-LocationFromOffice (50 casos)
    Test-LocationExtractionIntegration
    
    # TEST CATEGORY 7: UTF-8 y encodings especiales (100 casos)
    Test-UTF8AndSpecialEncodings
    
    # Generar reporte final
    Generate-TestReport
}

function Test-BasicCorruptedCharacters {
    Write-Host "`n📝 CATEGORÍA 1: Caracteres corruptos básicos (100 casos)" -ForegroundColor Yellow
    
    $TestCases = @(
        # Caracteres � (U+FFFD)
        @{ Input = "ALMER�A"; Expected = "ALMERÍA"; Description = "Almería con � mayúscula" }
        @{ Input = "Almer�a"; Expected = "Almería"; Description = "Almería con � mixta" }
        @{ Input = "almer�a"; Expected = "almería"; Description = "Almería con � minúscula" }
        @{ Input = "C�DIZ"; Expected = "CÁDIZ"; Description = "Cádiz con � mayúscula" }
        @{ Input = "C�diz"; Expected = "Cádiz"; Description = "Cádiz con � mixta" }
        @{ Input = "c�diz"; Expected = "cádiz"; Description = "Cádiz con � minúscula" }
        @{ Input = "C�RDOBA"; Expected = "CÓRDOBA"; Description = "Córdoba con � mayúscula" }
        @{ Input = "C�rdoba"; Expected = "Córdoba"; Description = "Córdoba con � mixta" }
        @{ Input = "c�rdoba"; Expected = "córdoba"; Description = "Córdoba con � minúscula" }
        @{ Input = "JA�N"; Expected = "JAÉN"; Description = "Jaén con � mayúscula" }
        @{ Input = "Ja�n"; Expected = "Jaén"; Description = "Jaén con � mixta" }
        @{ Input = "ja�n"; Expected = "jaén"; Description = "Jaén con � minúscula" }
        @{ Input = "M�LAGA"; Expected = "MÁLAGA"; Description = "Málaga con � mayúscula" }
        @{ Input = "M�laga"; Expected = "Málaga"; Description = "Málaga con � mixta" }
        @{ Input = "m�laga"; Expected = "málaga"; Description = "Málaga con � minúscula" }
        @{ Input = "L�PEZ"; Expected = "LÓPEZ"; Description = "López con � mayúscula" }
        @{ Input = "L�pez"; Expected = "López"; Description = "López con � mixta" }
        @{ Input = "l�pez"; Expected = "lópez"; Description = "López con � minúscula" }
        
        # Caracteres  (question mark)
        @{ Input = "ALMERA"; Expected = "ALMERÍA"; Description = "Almería con  mayúscula" }
        @{ Input = "Almera"; Expected = "Almería"; Description = "Almería con  mixta" }
        @{ Input = "almera"; Expected = "almería"; Description = "Almería con  minúscula" }
        @{ Input = "CDIZ"; Expected = "CÁDIZ"; Description = "Cádiz con  mayúscula" }
        @{ Input = "Cdiz"; Expected = "Cádiz"; Description = "Cádiz con  mixta" }
        @{ Input = "cdiz"; Expected = "cádiz"; Description = "Cádiz con  minúscula" }
        @{ Input = "CRDOBA"; Expected = "CÓRDOBA"; Description = "Córdoba con  mayúscula" }
        @{ Input = "Crdoba"; Expected = "Córdoba"; Description = "Córdoba con  mixta" }
        @{ Input = "crdoba"; Expected = "córdoba"; Description = "Córdoba con  minúscula" }
        @{ Input = "JAN"; Expected = "JAÉN"; Description = "Jaén con  mayúscula" }
        @{ Input = "Jan"; Expected = "Jaén"; Description = "Jaén con  mixta" }
        @{ Input = "jan"; Expected = "jaén"; Description = "Jaén con  minúscula" }
        @{ Input = "MLAGA"; Expected = "MÁLAGA"; Description = "Málaga con  mayúscula" }
        @{ Input = "Mlaga"; Expected = "Málaga"; Description = "Málaga con  mixta" }
        @{ Input = "mlaga"; Expected = "málaga"; Description = "Málaga con  minúscula" }
        @{ Input = "LPEZ"; Expected = "LÓPEZ"; Description = "López con  mayúscula" }
        @{ Input = "Lpez"; Expected = "López"; Description = "López con  mixta" }
        @{ Input = "lpez"; Expected = "lópez"; Description = "López con  minúscula" }
        
        # Apellidos comunes con corrupción
        @{ Input = "MART�NEZ"; Expected = "MARTÍNEZ"; Description = "Martínez con �" }
        @{ Input = "Mart�nez"; Expected = "Martínez"; Description = "Martínez mixto con �" }
        @{ Input = "G�MEZ"; Expected = "GÓMEZ"; Description = "Gómez con �" }
        @{ Input = "G�mez"; Expected = "Gómez"; Description = "Gómez mixto con �" }
        @{ Input = "HERN�NDEZ"; Expected = "HERNÁNDEZ"; Description = "Hernández con �" }
        @{ Input = "Hern�ndez"; Expected = "Hernández"; Description = "Hernández mixto con �" }
        @{ Input = "MARTNEZ"; Expected = "MARTÍNEZ"; Description = "Martínez con " }
        @{ Input = "Martnez"; Expected = "Martínez"; Description = "Martínez mixto con " }
        @{ Input = "GMEZ"; Expected = "GÓMEZ"; Description = "Gómez con " }
        @{ Input = "Gmez"; Expected = "Gómez"; Description = "Gómez mixto con " }
        
        # Múltiples corrupciones en una cadena
        @{ Input = "L�PEZ G�MEZ"; Expected = "LÓPEZ GÓMEZ"; Description = "Múltiples apellidos con �" }
        @{ Input = "MAR�A MART�NEZ"; Expected = "MARÍA MARTÍNEZ"; Description = "Nombre y apellido con �" }
        @{ Input = "JUZGADO DE M�LAGA"; Expected = "JUZGADO DE MÁLAGA"; Description = "Juzgado con provincia corrupta" }
        @{ Input = "FISCAL�A DE C�DIZ"; Expected = "FISCALÍA DE CÁDIZ"; Description = "Fiscalía con � múltiple" }
        @{ Input = "INSTRUCCI�N C�RDOBA"; Expected = "INSTRUCCIÓN CÓRDOBA"; Description = "Instrucción corrupta" }
        
        # Casos específicos reportados
        @{ Input = "mamámámálaga"; Expected = "málaga"; Description = "Patrón mamámámálaga específico" }
        @{ Input = "MAMÁMÁMÁLAGA"; Expected = "MÁLAGA"; Description = "MAMÁMÁMÁLAGA mayúscula" }
        @{ Input = "Mamámámálaga"; Expected = "Málaga"; Description = "Mamámámálaga mixta" }
        @{ Input = "mamamalaga"; Expected = "málaga"; Description = "mamamalaga sin tildes" }
        @{ Input = "MAMAMALAGA"; Expected = "MÁLAGA"; Description = "MAMAMALAGA mayúscula sin tildes" }
        
        # Caracteres de control y espacios
        @{ Input = "  ALMER�A  "; Expected = "ALMERÍA"; Description = "Espacios al inicio y final" }
        @{ Input = "JUZGADO   DE    M�LAGA"; Expected = "JUZGADO DE MÁLAGA"; Description = "Espacios múltiples internos" }
        @{ Input = "C�DIZ`t`nSEVILLA"; Expected = "CÁDIZ SEVILLA"; Description = "Caracteres de control tab y newline" }
        
        # Caracteres Unicode problemáticos
        @{ Input = [char]0x00F1 + "I�EZ"; Expected = "ÑIÑEZ"; Description = "Carácter ñ Unicode + corrupción" }
        @{ Input = "ADMINISTRACI" + [char]0x00F3 + "N"; Expected = "ADMINISTRACIÓN"; Description = "ó Unicode correcto" }
        @{ Input = "VI" + [char]0x00F1 + "A DEL MAR"; Expected = "VIÑA DEL MAR"; Description = "ñ Unicode en contexto" }
        
        # Casos extremos de longitud
        @{ Input = "�"; Expected = "i"; Description = "Solo un carácter corrupto" }
        @{ Input = ""; Expected = ""; Description = "Cadena vacía" }
        @{ Input = " "; Expected = ""; Description = "Solo espacios" }
        @{ Input = "   "; Expected = ""; Description = "Múltiples espacios" }
        
        # Más variaciones de provincias
        @{ Input = "GU�DIX"; Expected = "GUADIX"; Description = "Guadix con �" }
        @{ Input = "ANDUJAR"; Expected = "ANDUJAR"; Description = "Andújar sin tilde (debe mantener)" }
        @{ Input = "AND�JAR"; Expected = "ANDÚJAR"; Description = "Andújar con � -> ú" }
        @{ Input = "�BEDA"; Expected = "ÚBEDA"; Description = "Úbeda con � inicial" }
        @{ Input = "SANL�CAR"; Expected = "SANLÚCAR"; Description = "Sanlúcar con �" }
        @{ Input = "CHICLANA DE LA FRONTERA"; Expected = "CHICLANA DE LA FRONTERA"; Description = "Nombre largo sin corrupción" }
        @{ Input = "PUERTO DE SANTA MAR�A"; Expected = "PUERTO DE SANTA MARÍA"; Description = "Puerto con � -> í" }
        
        # Números con corrupción adyacente
        @{ Input = "JUZGADO N� 1 DE M�LAGA"; Expected = "JUZGADO Nº 1 DE MÁLAGA"; Description = "Número con � adyacente" }
        @{ Input = "INSTRUCCI�N N�MERO 5"; Expected = "INSTRUCCIÓN NÚMERO 5"; Description = "Instrucción y número con �" }
        @{ Input = "PRIMERA INSTANCIA N 19"; Expected = "PRIMERA INSTANCIA N 19"; Description = "Mantener  cuando no es corrupción obvia" }
        
        # Combinaciones de mayúsculas y minúsculas problemáticas
        @{ Input = "M�laga Ciudad de la Justicia"; Expected = "Málaga Ciudad de la Justicia"; Description = "Mixto con Ciudad de la Justicia" }
        @{ Input = "jUZGADO DE pRIMERA iNSTANCIA"; Expected = "jUZGADO DE pRIMERA iNSTANCIA"; Description = "Mantener capitalización original si no hay corrupción" }
        @{ Input = "jUZGADO DE pRIMERA �NSTANCIA"; Expected = "jUZGADO DE pRIMERA iNSTANCIA"; Description = "Corregir solo corrupción, mantener caps" }
        
        # Acentos en contextos inesperados
        @{ Input = "EXPEDIENTE N�M. 2024"; Expected = "EXPEDIENTE NÚM. 2024"; Description = "Número de expediente" }
        @{ Input = "A�O 2024"; Expected = "AÑO 2024"; Description = "Año con �" }
        @{ Input = "SECCI�N PENAL"; Expected = "SECCIÓN PENAL"; Description = "Sección con �" }
        @{ Input = "PENAL N�M. 1"; Expected = "PENAL NÚM. 1"; Description = "Penal núm" }
        
        # Casos con múltiples tipos de corrupción
        @{ Input = "FISCAL�A PROVINCIAL DE C�DIZ"; Expected = "FISCALÍA PROVINCIAL DE CÁDIZ"; Description = "Múltiple corrupción í y á" }
        @{ Input = "SECRETAR�A DE GOBIERNO"; Expected = "SECRETARÍA DE GOBIERNO"; Description = "Secretaría con �" }
        @{ Input = "ADMINISTRACI�N DE JUSTICIA"; Expected = "ADMINISTRACIÓN DE JUSTICIA"; Description = "Administración con �" }
        @{ Input = "TRIBUNAL SUPERIOR JUSTICIA ANDALUC�A"; Expected = "TRIBUNAL SUPERIOR JUSTICIA ANDALUCÍA"; Description = "Andalucía con �" }
        @{ Input = "SERVICIO COM�N DE ACTOS"; Expected = "SERVICIO COMÚN DE ACTOS"; Description = "Común con �" }
        
        # Edge cases con caracteres especiales seguidos
        @{ Input = "M��LAGA"; Expected = "MÁLAGA"; Description = "Doble � -> á" }
        @{ Input = "CDIZ"; Expected = "CÁDIZ"; Description = "Doble  -> á" }
        @{ Input = "JA�N"; Expected = "JAÉN"; Description = "Mezcla  y �" }
        @{ Input = "ALMER�A"; Expected = "ALMERÍA"; Description = "Mezcla � y " }
        
        # Casos con números y caracteres especiales
        @{ Input = "JUZGADO N.� 15"; Expected = "JUZGADO N.º 15"; Description = "N.� -> N.º" }
        @{ Input = "ART�CULO 394"; Expected = "ARTÍCULO 394"; Description = "Artículo con �" }
        @{ Input = "P�RRAFO 2�"; Expected = "PÁRRAFO 2º"; Description = "Párrafo con � y ordinal" }
        
        # Variaciones regionales de escritura
        @{ Input = "XEREZ DE LA FRONTERA"; Expected = "XEREZ DE LA FRONTERA"; Description = "Xerez (escritura histórica) - mantener" }
        @{ Input = "XERES"; Expected = "XERES"; Description = "Xeres - mantener" }
        @{ Input = "HOSPITAL PROVINCIAL"; Expected = "HOSPITAL PROVINCIAL"; Description = "Texto limpio - mantener" }
        @{ Input = "CENTRO PENITENCIARIO"; Expected = "CENTRO PENITENCIARIO"; Description = "Centro limpio - mantener" }
    )
    
    Execute-TestBatch -TestCases $TestCases -Category "BasicCorrupted"
}

function Test-AndalusianProvinces {
    Write-Host "`n🏛️ CATEGORÍA 2: Nombres de provincias andaluzas (80 casos)" -ForegroundColor Yellow
    
    $TestCases = @(
        # Almería - variaciones
        @{ Input = "ALMER�A"; Expected = "ALMERÍA"; Description = "ALMERÍA con �" }
        @{ Input = "Almer�a"; Expected = "Almería"; Description = "Almería con �" }
        @{ Input = "almer�a"; Expected = "almería"; Description = "almería con �" }
        @{ Input = "ALMERA"; Expected = "ALMERÍA"; Description = "ALMERÍA con " }
        @{ Input = "Almera"; Expected = "Almería"; Description = "Almería con " }
        @{ Input = "almera"; Expected = "almería"; Description = "almería con " }
        @{ Input = "ALMERIA"; Expected = "ALMERIA"; Description = "ALMERIA sin tilde - mantener" }
        @{ Input = "Almeria"; Expected = "Almeria"; Description = "Almeria sin tilde - mantener" }
        @{ Input = "almeria"; Expected = "almeria"; Description = "almeria sin tilde - mantener" }
        @{ Input = "ALMERÍA"; Expected = "ALMERÍA"; Description = "ALMERÍA correcta - mantener" }
        
        # Cádiz - variaciones
        @{ Input = "C�DIZ"; Expected = "CÁDIZ"; Description = "CÁDIZ con �" }
        @{ Input = "C�diz"; Expected = "Cádiz"; Description = "Cádiz con �" }
        @{ Input = "c�diz"; Expected = "cádiz"; Description = "cádiz con �" }
        @{ Input = "CDIZ"; Expected = "CÁDIZ"; Description = "CÁDIZ con " }
        @{ Input = "Cdiz"; Expected = "Cádiz"; Description = "Cádiz con " }
        @{ Input = "cdiz"; Expected = "cádiz"; Description = "cádiz con " }
        @{ Input = "CADIZ"; Expected = "CADIZ"; Description = "CADIZ sin tilde - mantener" }
        @{ Input = "Cadiz"; Expected = "Cadiz"; Description = "Cadiz sin tilde - mantener" }
        @{ Input = "cadiz"; Expected = "cadiz"; Description = "cadiz sin tilde - mantener" }
        @{ Input = "CÁDIZ"; Expected = "CÁDIZ"; Description = "CÁDIZ correcta - mantener" }
        
        # Córdoba - variaciones
        @{ Input = "C�RDOBA"; Expected = "CÓRDOBA"; Description = "CÓRDOBA con �" }
        @{ Input = "C�rdoba"; Expected = "Córdoba"; Description = "Córdoba con �" }
        @{ Input = "c�rdoba"; Expected = "córdoba"; Description = "córdoba con �" }
        @{ Input = "CRDOBA"; Expected = "CÓRDOBA"; Description = "CÓRDOBA con " }
        @{ Input = "Crdoba"; Expected = "Córdoba"; Description = "Córdoba con " }
        @{ Input = "crdoba"; Expected = "córdoba"; Description = "córdoba con " }
        @{ Input = "CORDOBA"; Expected = "CORDOBA"; Description = "CORDOBA sin tilde - mantener" }
        @{ Input = "Cordoba"; Expected = "Cordoba"; Description = "Cordoba sin tilde - mantener" }
        @{ Input = "cordoba"; Expected = "cordoba"; Description = "cordoba sin tilde - mantener" }
        @{ Input = "CÓRDOBA"; Expected = "CÓRDOBA"; Description = "CÓRDOBA correcta - mantener" }
        
        # Jaén - variaciones
        @{ Input = "JA�N"; Expected = "JAÉN"; Description = "JAÉN con �" }
        @{ Input = "Ja�n"; Expected = "Jaén"; Description = "Jaén con �" }
        @{ Input = "ja�n"; Expected = "jaén"; Description = "jaén con �" }
        @{ Input = "JAN"; Expected = "JAÉN"; Description = "JAÉN con " }
        @{ Input = "Jan"; Expected = "Jaén"; Description = "Jaén con " }
        @{ Input = "jan"; Expected = "jaén"; Description = "jaén con " }
        @{ Input = "JAEN"; Expected = "JAEN"; Description = "JAEN sin tilde - mantener" }
        @{ Input = "Jaen"; Expected = "Jaen"; Description = "Jaen sin tilde - mantener" }
        @{ Input = "jaen"; Expected = "jaen"; Description = "jaen sin tilde - mantener" }
        @{ Input = "JAÉN"; Expected = "JAÉN"; Description = "JAÉN correcta - mantener" }
        
        # Málaga - variaciones (incluyendo casos específicos)
        @{ Input = "M�LAGA"; Expected = "MÁLAGA"; Description = "MÁLAGA con �" }
        @{ Input = "M�laga"; Expected = "Málaga"; Description = "Málaga con �" }
        @{ Input = "m�laga"; Expected = "málaga"; Description = "málaga con �" }
        @{ Input = "MLAGA"; Expected = "MÁLAGA"; Description = "MÁLAGA con " }
        @{ Input = "Mlaga"; Expected = "Málaga"; Description = "Málaga con " }
        @{ Input = "mlaga"; Expected = "málaga"; Description = "málaga con " }
        @{ Input = "MALAGA"; Expected = "MALAGA"; Description = "MALAGA sin tilde - mantener" }
        @{ Input = "Malaga"; Expected = "Malaga"; Description = "Malaga sin tilde - mantener" }
        @{ Input = "malaga"; Expected = "malaga"; Description = "malaga sin tilde - mantener" }
        @{ Input = "MÁLAGA"; Expected = "MÁLAGA"; Description = "MÁLAGA correcta - mantener" }
        
        # Casos específicos de Málaga reportados
        @{ Input = "mamámámálaga"; Expected = "málaga"; Description = "Patrón específico mamámámálaga" }
        @{ Input = "MAMÁMÁMÁLAGA"; Expected = "MÁLAGA"; Description = "Patrón específico MAMÁMÁMÁLAGA" }
        @{ Input = "Mamámámálaga"; Expected = "Málaga"; Description = "Patrón específico Mamámámálaga" }
        @{ Input = "mamamalaga"; Expected = "málaga"; Description = "Variante sin tildes mamamalaga" }
        @{ Input = "MAMAMALAGA"; Expected = "MÁLAGA"; Description = "Variante sin tildes MAMAMALAGA" }
        @{ Input = "Mamamalaga"; Expected = "Málaga"; Description = "Variante sin tildes Mamamalaga" }
        
        # Granada y Sevilla (casos más simples pero importantes)
        @{ Input = "GRANADA"; Expected = "GRANADA"; Description = "GRANADA - mantener" }
        @{ Input = "Granada"; Expected = "Granada"; Description = "Granada - mantener" }
        @{ Input = "granada"; Expected = "granada"; Description = "granada - mantener" }
        @{ Input = "SEVILLA"; Expected = "SEVILLA"; Description = "SEVILLA - mantener" }
        @{ Input = "Sevilla"; Expected = "Sevilla"; Description = "Sevilla - mantener" }
        @{ Input = "sevilla"; Expected = "sevilla"; Description = "sevilla - mantener" }
        
        # Huelva
        @{ Input = "HUELVA"; Expected = "HUELVA"; Description = "HUELVA - mantener" }
        @{ Input = "Huelva"; Expected = "Huelva"; Description = "Huelva - mantener" }
        @{ Input = "huelva"; Expected = "huelva"; Description = "huelva - mantener" }
        
        # Casos con contexto judicial
        @{ Input = "JUZGADO DE M�LAGA"; Expected = "JUZGADO DE MÁLAGA"; Description = "Juzgado de Málaga con �" }
        @{ Input = "TRIBUNAL DE C�DIZ"; Expected = "TRIBUNAL DE CÁDIZ"; Description = "Tribunal de Cádiz con �" }
        @{ Input = "FISCAL�A DE JA�N"; Expected = "FISCALÍA DE JAÉN"; Description = "Fiscalía de Jaén con �" }
        @{ Input = "AUDIENCIA DE C�RDOBA"; Expected = "AUDIENCIA DE CÓRDOBA"; Description = "Audiencia de Córdoba con �" }
        @{ Input = "REGISTRO DE ALMER�A"; Expected = "REGISTRO DE ALMERÍA"; Description = "Registro de Almería con �" }
        
        # Ciudades importantes de cada provincia
        @{ Input = "MARBELLA, M�LAGA"; Expected = "MARBELLA, MÁLAGA"; Description = "Ciudad con provincia corrupta" }
        @{ Input = "JEREZ DE LA FRONTERA, C�DIZ"; Expected = "JEREZ DE LA FRONTERA, CÁDIZ"; Description = "Jerez con Cádiz corrupta" }
        @{ Input = "LINARES, JA�N"; Expected = "LINARES, JAÉN"; Description = "Linares con Jaén corrupta" }
        @{ Input = "LUCENA, C�RDOBA"; Expected = "LUCENA, CÓRDOBA"; Description = "Lucena con Córdoba corrupta" }
        @{ Input = "EL EJIDO, ALMER�A"; Expected = "EL EJIDO, ALMERÍA"; Description = "El Ejido con Almería corrupta" }
        @{ Input = "MOTRIL, GRANADA"; Expected = "MOTRIL, GRANADA"; Description = "Motril con Granada correcta" }
        @{ Input = "DOS HERMANAS, SEVILLA"; Expected = "DOS HERMANAS, SEVILLA"; Description = "Dos Hermanas con Sevilla correcta" }
        @{ Input = "AYAMONTE, HUELVA"; Expected = "AYAMONTE, HUELVA"; Description = "Ayamonte con Huelva correcta" }
    )
    
    Execute-TestBatch -TestCases $TestCases -Category "AndalusianProvinces"
}

function Test-JudicalTerms {
    Write-Host "`n⚖️ CATEGORÍA 3: Términos judiciales específicos (120 casos)" -ForegroundColor Yellow
    
    $TestCases = @(
        # Instrucción - variaciones comunes
        @{ Input = "INSTRUCCI�N"; Expected = "INSTRUCCIÓN"; Description = "Instrucción con �" }
        @{ Input = "Instrucci�n"; Expected = "Instrucción"; Description = "Instrucción mixta con �" }
        @{ Input = "instrucci�n"; Expected = "instrucción"; Description = "instrucción minúscula con �" }
        @{ Input = "INSTRUCCIN"; Expected = "INSTRUCCIÓN"; Description = "Instrucción con " }
        @{ Input = "Instruccin"; Expected = "Instrucción"; Description = "Instrucción mixta con " }
        @{ Input = "instruccin"; Expected = "instrucción"; Description = "instrucción minúscula con " }
        @{ Input = "INSTRUCCION"; Expected = "INSTRUCCION"; Description = "Instruccion sin tilde - mantener" }
        @{ Input = "INSTRUCCIÓN"; Expected = "INSTRUCCIÓN"; Description = "Instrucción correcta - mantener" }
        
        # Administración
        @{ Input = "ADMINISTRACI�N"; Expected = "ADMINISTRACIÓN"; Description = "Administración con �" }
        @{ Input = "Administraci�n"; Expected = "Administración"; Description = "Administración mixta con �" }
        @{ Input = "administraci�n"; Expected = "administración"; Description = "administración minúscula con �" }
        @{ Input = "ADMINISTRACIN"; Expected = "ADMINISTRACIÓN"; Description = "Administración con " }
        @{ Input = "Administracin"; Expected = "Administración"; Description = "Administración mixta con " }
        @{ Input = "administracin"; Expected = "administración"; Description = "administración minúscula con " }
        @{ Input = "ADMINISTRACION"; Expected = "ADMINISTRACION"; Description = "Administracion sin tilde - mantener" }
        @{ Input = "ADMINISTRACIÓN"; Expected = "ADMINISTRACIÓN"; Description = "Administración correcta - mantener" }
        
        # Contencioso
        @{ Input = "CONTENCI�SO"; Expected = "CONTENCIOSO"; Description = "Contencioso con �" }
        @{ Input = "Contenci�so"; Expected = "Contencioso"; Description = "Contencioso mixto con �" }
        @{ Input = "contenci�so"; Expected = "contencioso"; Description = "contencioso minúscula con �" }
        @{ Input = "CONTENCISO"; Expected = "CONTENCIOSO"; Description = "Contencioso con " }
        @{ Input = "Contenciso"; Expected = "Contencioso"; Description = "Contencioso mixto con " }
        @{ Input = "contenciso"; Expected = "contencioso"; Description = "contencioso minúscula con " }
        @{ Input = "CONTENCIOSO"; Expected = "CONTENCIOSO"; Description = "Contencioso correcto - mantener" }
        
        # Fiscalía
        @{ Input = "FISCAL�A"; Expected = "FISCALÍA"; Description = "Fiscalía con �" }
        @{ Input = "Fiscal�a"; Expected = "Fiscalía"; Description = "Fiscalía mixta con �" }
        @{ Input = "fiscal�a"; Expected = "fiscalía"; Description = "fiscalía minúscula con �" }
        @{ Input = "FISCALA"; Expected = "FISCALÍA"; Description = "Fiscalía con " }
        @{ Input = "Fiscala"; Expected = "Fiscalía"; Description = "Fiscalía mixta con " }
        @{ Input = "fiscala"; Expected = "fiscalía"; Description = "fiscalía minúscula con " }
        @{ Input = "FISCALIA"; Expected = "FISCALIA"; Description = "Fiscalia sin tilde - mantener" }
        @{ Input = "FISCALÍA"; Expected = "FISCALÍA"; Description = "Fiscalía correcta - mantener" }
        
        # Criminalístico
        @{ Input = "CRIMINAL�STICO"; Expected = "CRIMINALÍSTICO"; Description = "Criminalístico con �" }
        @{ Input = "Criminal�stico"; Expected = "Criminalístico"; Description = "Criminalístico mixto con �" }
        @{ Input = "criminal�stico"; Expected = "criminalístico"; Description = "criminalístico minúscula con �" }
        @{ Input = "CRIMINALSTICO"; Expected = "CRIMINALÍSTICO"; Description = "Criminalístico con " }
        @{ Input = "Criminalstico"; Expected = "Criminalístico"; Description = "Criminalístico mixto con " }
        @{ Input = "criminalstico"; Expected = "criminalístico"; Description = "criminalístico minúscula con " }
        @{ Input = "CRIMINALISTICO"; Expected = "CRIMINALISTICO"; Description = "Criminalistico sin tilde - mantener" }
        @{ Input = "CRIMINALÍSTICO"; Expected = "CRIMINALÍSTICO"; Description = "Criminalístico correcto - mantener" }
        
        # Ejecución
        @{ Input = "EJECUCI�N"; Expected = "EJECUCIÓN"; Description = "Ejecución con �" }
        @{ Input = "Ejecuci�n"; Expected = "Ejecución"; Description = "Ejecución mixta con �" }
        @{ Input = "ejecuci�n"; Expected = "ejecución"; Description = "ejecución minúscula con �" }
        @{ Input = "EJECUCIN"; Expected = "EJECUCIÓN"; Description = "Ejecución con " }
        @{ Input = "Ejecucin"; Expected = "Ejecución"; Description = "Ejecución mixta con " }
        @{ Input = "ejecucin"; Expected = "ejecución"; Description = "ejecución minúscula con " }
        @{ Input = "EJECUCION"; Expected = "EJECUCION"; Description = "Ejecucion sin tilde - mantener" }
        @{ Input = "EJECUCIÓN"; Expected = "EJECUCIÓN"; Description = "Ejecución correcta - mantener" }
        
        # Términos compuestos
        @{ Input = "VIGILANCIA PENITENCIARI�"; Expected = "VIGILANCIA PENITENCIARIA"; Description = "Vigilancia Penitenciaria con �" }
        @{ Input = "Vigilancia Penitenciari�"; Expected = "Vigilancia Penitenciaria"; Description = "Vigilancia Penitenciaria mixta con �" }
        @{ Input = "vigilancia penitenciari�"; Expected = "vigilancia penitenciaria"; Description = "vigilancia penitenciaria minúscula con �" }
        @{ Input = "VIGILANCIA PENITENCIARI"; Expected = "VIGILANCIA PENITENCIARIA"; Description = "Vigilancia Penitenciaria con " }
        @{ Input = "Vigilancia Penitenciari"; Expected = "Vigilancia Penitenciaria"; Description = "Vigilancia Penitenciaria mixta con " }
        @{ Input = "vigilancia penitenciari"; Expected = "vigilancia penitenciaria"; Description = "vigilancia penitenciaria minúscula con " }
        @{ Input = "VIGILANCIA PENITENCIARIA"; Expected = "VIGILANCIA PENITENCIARIA"; Description = "Vigilancia Penitenciaria correcta - mantener" }
        
        # Menores
        @{ Input = "MENORE�"; Expected = "MENORES"; Description = "Menores con �" }
        @{ Input = "Menore�"; Expected = "Menores"; Description = "Menores mixto con �" }
        @{ Input = "menore�"; Expected = "menores"; Description = "menores minúscula con �" }
        @{ Input = "MENORE"; Expected = "MENORES"; Description = "Menores con " }
        @{ Input = "Menore"; Expected = "Menores"; Description = "Menores mixto con " }
        @{ Input = "menore"; Expected = "menores"; Description = "menores minúscula con " }
        @{ Input = "MENORES"; Expected = "MENORES"; Description = "Menores correcto - mantener" }
        
        # Violencia
        @{ Input = "VIOLENCI�"; Expected = "VIOLENCIA"; Description = "Violencia con �" }
        @{ Input = "Violenci�"; Expected = "Violencia"; Description = "Violencia mixta con �" }
        @{ Input = "violenci�"; Expected = "violencia"; Description = "violencia minúscula con �" }
        @{ Input = "VIOLENCI"; Expected = "VIOLENCIA"; Description = "Violencia con " }
        @{ Input = "Violenci"; Expected = "Violencia"; Description = "Violencia mixta con " }
        @{ Input = "violenci"; Expected = "violencia"; Description = "violencia minúscula con " }
        @{ Input = "VIOLENCIA"; Expected = "VIOLENCIA"; Description = "Violencia correcta - mantener" }
        
        # Frases completas con múltiples términos corruptos
        @{ Input = "JUZGADO DE INSTRUCCI�N N�MERO 1"; Expected = "JUZGADO DE INSTRUCCIÓN NÚMERO 1"; Description = "Juzgado completo con múltiple �" }
        @{ Input = "FISCAL�A DE VIOLENCI� CONTRA LA MUJER"; Expected = "FISCALÍA DE VIOLENCIA CONTRA LA MUJER"; Description = "Fiscalía violencia con corrupción" }
        @{ Input = "JUZGADO DE PRIMERA INSTANCI� E INSTRUCCI�N"; Expected = "JUZGADO DE PRIMERA INSTANCIA E INSTRUCCIÓN"; Description = "Primera instancia e instrucción con �" }
        @{ Input = "TRIBUNAL SUPERIOR DE JUSTICI� DE ANDALUC�A"; Expected = "TRIBUNAL SUPERIOR DE JUSTICIA DE ANDALUCÍA"; Description = "TSJ Andalucía con corrupción múltiple" }
        @{ Input = "SERVICIO COM�N DE NOTIFICACIONES Y EMBARGOS"; Expected = "SERVICIO COMÚN DE NOTIFICACIONES Y EMBARGOS"; Description = "Servicio común con �" }
        @{ Input = "UNIDAD DE VALORACI�N INTEGRAL DE VIOLENCI�"; Expected = "UNIDAD DE VALORACIÓN INTEGRAL DE VIOLENCIA"; Description = "UVIVG con corrupción múltiple" }
        
        # Términos específicos de tipos de juzgados
        @{ Input = "JUZGADO DE LO PENAL N�MERO 1"; Expected = "JUZGADO DE LO PENAL NÚMERO 1"; Description = "Penal con número corrupto" }
        @{ Input = "JUZGADO DE LO CIVIL N�MERO 2"; Expected = "JUZGADO DE LO CIVIL NÚMERO 2"; Description = "Civil con número corrupto" }
        @{ Input = "JUZGADO DE LO SOCIAL N�MERO 3"; Expected = "JUZGADO DE LO SOCIAL NÚMERO 3"; Description = "Social con número corrupto" }
        @{ Input = "JUZGADO DE LO MERCANTIL N�MERO 4"; Expected = "JUZGADO DE LO MERCANTIL NÚMERO 4"; Description = "Mercantil con número corrupto" }
        @{ Input = "JUZGADO DE LO CONTENCIOSO-ADMINISTRATIVO N�MERO 5"; Expected = "JUZGADO DE LO CONTENCIOSO-ADMINISTRATIVO NÚMERO 5"; Description = "Contencioso-administrativo largo con corrupción" }
        
        # Abreviaciones comunes
        @{ Input = "N�M. 1"; Expected = "NÚM. 1"; Description = "Número abreviado con �" }
        @{ Input = "N�MERO 2"; Expected = "NÚMERO 2"; Description = "Número completo con �" }
        @{ Input = "ART�CULO 394"; Expected = "ARTÍCULO 394"; Description = "Artículo con �" }
        @{ Input = "P�RRAFO 2"; Expected = "PÁRRAFO 2"; Description = "Párrafo con �" }
        @{ Input = "SECCI�N PRIMERA"; Expected = "SECCIÓN PRIMERA"; Description = "Sección con �" }
        @{ Input = "SALA PRIMERA"; Expected = "SALA PRIMERA"; Description = "Sala primera sin corrupción - mantener" }
        
        # Términos de procedimiento
        @{ Input = "DILIGENCIAS PREVIAS N�M. 123/2024"; Expected = "DILIGENCIAS PREVIAS NÚM. 123/2024"; Description = "Diligencias previas con número corrupto" }
        @{ Input = "SUMARIO N�M. 456/2024"; Expected = "SUMARIO NÚM. 456/2024"; Description = "Sumario con número corrupto" }
        @{ Input = "PROCEDIMIENTO ABREVIADO N�M. 789/2024"; Expected = "PROCEDIMIENTO ABREVIADO NÚM. 789/2024"; Description = "Procedimiento abreviado con número corrupto" }
        @{ Input = "JUICIO R�PIDO N�M. 101/2024"; Expected = "JUICIO RÁPIDO NÚM. 101/2024"; Description = "Juicio rápido con corrupción múltiple" }
        
        # Especialidades judiciales
        @{ Input = "JUZGADO DE VIOLENCI� SOBRE LA MUJER"; Expected = "JUZGADO DE VIOLENCIA SOBRE LA MUJER"; Description = "JVM con violencia corrupta" }
        @{ Input = "JUZGADO DE MENORE� N�M. 1"; Expected = "JUZGADO DE MENORES NÚM. 1"; Description = "Menores con número corrupto" }
        @{ Input = "JUZGADO DE VIGILANCIA PENITENCIARI� N�M. 1"; Expected = "JUZGADO DE VIGILANCIA PENITENCIARIA NÚM. 1"; Description = "JVP con corrupción múltiple" }
        @{ Input = "JUZGADO DE FAMILIA N�MERO 1"; Expected = "JUZGADO DE FAMILIA NÚMERO 1"; Description = "Familia con número corrupto" }
        
        # IML y servicios técnicos
        @{ Input = "INSTITUTO DE MEDICINA LEGAL Y CIENCIAS FORENSES"; Expected = "INSTITUTO DE MEDICINA LEGAL Y CIENCIAS FORENSES"; Description = "IML completo sin corrupción - mantener" }
        @{ Input = "IML CENTRAL DE JA�N"; Expected = "IML CENTRAL DE JAÉN"; Description = "IML con Jaén corrupta" }
        @{ Input = "IMLCF CENTRAL DE JA�N - PATOLOG�A FORENSE"; Expected = "IMLCF CENTRAL DE JAÉN - PATOLOGÍA FORENSE"; Description = "IMLCF con múltiple corrupción" }
        @{ Input = "SERVICIO DE PATOLOG�A FORENSE"; Expected = "SERVICIO DE PATOLOGÍA FORENSE"; Description = "Patología forense con �" }
        
        # Registros civiles
        @{ Input = "REGISTRO CIVIL EXCLUSIVO DE M�LAGA"; Expected = "REGISTRO CIVIL EXCLUSIVO DE MÁLAGA"; Description = "Registro civil con Málaga corrupta" }
        @{ Input = "REGISTRO CIVIL DE SEVILLA"; Expected = "REGISTRO CIVIL DE SEVILLA"; Description = "Registro civil sin corrupción - mantener" }
        @{ Input = "REGISTRO CENTRAL DE PENADOS"; Expected = "REGISTRO CENTRAL DE PENADOS"; Description = "Registro penados sin corrupción - mantener" }
        
        # Términos administrativos
        @{ Input = "SECRETAR�A DE GOBIERNO"; Expected = "SECRETARÍA DE GOBIERNO"; Description = "Secretaría con �" }
        @{ Input = "DECANATO DE LOS JUZGADOS"; Expected = "DECANATO DE LOS JUZGADOS"; Description = "Decanato sin corrupción - mantener" }
        @{ Input = "GERENCIA TERRITORIAL"; Expected = "GERENCIA TERRITORIAL"; Description = "Gerencia sin corrupción - mantener" }
        @{ Input = "DIRECCI�N GENERAL"; Expected = "DIRECCIÓN GENERAL"; Description = "Dirección con �" }
    )
    
    Execute-TestBatch -TestCases $TestCases -Category "JudicalTerms"
}

function Test-ComplexEdgeCases {
    Write-Host "`n🔄 CATEGORÍA 4: Casos edge complejos (100 casos)" -ForegroundColor Yellow
    
    $TestCases = @(
        # Casos con múltiples tipos de corrupción en una cadena
        @{ Input = "L�PEZ MART�NEZ, MAR�A"; Expected = "LÓPEZ MARTÍNEZ, MARÍA"; Description = "Múltiples apellidos con � mixto" }
        @{ Input = "GARC�A G�MEZ"; Expected = "GARCÍA GÓMEZ"; Description = "Dos apellidos con �" }
        @{ Input = "HERN�NDEZ L�PEZ"; Expected = "HERNÁNDEZ LÓPEZ"; Description = "Hernández López con �" }
        @{ Input = "MART�NEZ S�NCHEZ"; Expected = "MARTÍNEZ SÁNCHEZ"; Description = "Martínez Sánchez con �" }
        @{ Input = "FERN�NDEZ MU�OZ"; Expected = "FERNÁNDEZ MUÑOZ"; Description = "Fernández Muñoz con � y ñ" }
        
        # Mezcla de caracteres corruptos
        @{ Input = "M�LAGA"; Expected = "MÁLAGA"; Description = "Mezcla � y  en Málaga" }
        @{ Input = "C�DIZ"; Expected = "CÁDIZ"; Description = "Mezcla  y � en Cádiz" }
        @{ Input = "JA�N"; Expected = "JAÉN"; Description = "Mezcla � y  en Jaén" }
        @{ Input = "ALMER�A"; Expected = "ALMERÍA"; Description = "Mezcla  y � en Almería" }
        @{ Input = "CRDOBA"; Expected = "CÓRDOBA"; Description = "Doble  en Córdoba" }
        @{ Input = "M��LAGA"; Expected = "MÁLAGA"; Description = "Doble � en Málaga" }
        
        # Casos con caracteres de control y espacios problemáticos
        @{ Input = "  M�LAGA  "; Expected = "MÁLAGA"; Description = "Spaces alrededor de Málaga" }
        @{ Input = "JUZGADO    DE    M�LAGA"; Expected = "JUZGADO DE MÁLAGA"; Description = "Múltiples espacios internos" }
        @{ Input = "M�LAGA`t`nCIUDAD"; Expected = "MÁLAGA CIUDAD"; Description = "Tab y newline como separadores" }
        @{ Input = "PRIMERA`r`nINSTANCI�"; Expected = "PRIMERA INSTANCIA"; Description = "Carriage return con corrupción" }
        @{ Input = "  "; Expected = ""; Description = "Solo espacios" }
        @{ Input = ""; Expected = ""; Description = "Cadena vacía" }
        
        # Casos con números y ordinales corruptos
        @{ Input = "JUZGADO N� 1"; Expected = "JUZGADO Nº 1"; Description = "Número ordinal con �" }
        @{ Input = "PRIMERA INSTANCI� N�MERO 19"; Expected = "PRIMERA INSTANCIA NÚMERO 19"; Description = "Instancia número con múltiple �" }
        @{ Input = "INSTRUCCI�N N� 3"; Expected = "INSTRUCCIÓN Nº 3"; Description = "Instrucción número con �" }
        @{ Input = "PENAL N�M. 5"; Expected = "PENAL NÚM. 5"; Description = "Penal núm con �" }
        @{ Input = "SOCIAL N�MERO 2"; Expected = "SOCIAL NÚMERO 2"; Description = "Social número con �" }
        @{ Input = "CIVIL N� 4"; Expected = "CIVIL Nº 4"; Description = "Civil número ordinal con �" }
        
        # Casos con fechas y expedientes
        @{ Input = "EXPEDIENTE N�M. 123/2024"; Expected = "EXPEDIENTE NÚM. 123/2024"; Description = "Expediente con número y año" }
        @{ Input = "DILIGENCIAS PREVIAS N�M. 456/24"; Expected = "DILIGENCIAS PREVIAS NÚM. 456/24"; Description = "DP con número abreviado" }
        @{ Input = "SUMARIO N�M. 789/2024"; Expected = "SUMARIO NÚM. 789/2024"; Description = "Sumario con número completo" }
        @{ Input = "PROCEDIMIENTO A�O 2024"; Expected = "PROCEDIMIENTO AÑO 2024"; Description = "Año con ñ corrupta" }
        
        # Casos con direcciones y ubicaciones complejas
        @{ Input = "CIUDAD DE LA JUSTICIA, M�LAGA"; Expected = "CIUDAD DE LA JUSTICIA, MÁLAGA"; Description = "Ciudad de la Justicia con Málaga corrupta" }
        @{ Input = "AVDA. DE LA CONSTITUCI�N, SEVILLA"; Expected = "AVDA. DE LA CONSTITUCIÓN, SEVILLA"; Description = "Avenida Constitución con �" }
        @{ Input = "PLAZA DE LA CONSTITU��N"; Expected = "PLAZA DE LA CONSTITUCIÓN"; Description = "Constitución con doble corrupción" }
        @{ Input = "C/ RAM�N Y CAJAL, N� 1"; Expected = "C/ RAMÓN Y CAJAL, Nº 1"; Description = "Calle con nombre y número corrupto" }
        
        # Casos con acrónimos y abreviaciones
        @{ Input = "TSJ DE ANDALUC�A"; Expected = "TSJ DE ANDALUCÍA"; Description = "TSJ Andalucía con �" }
        @{ Input = "JCA N� 1 DE M�LAGA"; Expected = "JCA Nº 1 DE MÁLAGA"; Description = "JCA con número y provincia corrupta" }
        @{ Input = "JVM N�M. 2"; Expected = "JVM NÚM. 2"; Description = "JVM con número corrupto" }
        @{ Input = "IMLCF DE M�LAGA"; Expected = "IMLCF DE MÁLAGA"; Description = "IMLCF con Málaga corrupta" }
        
        # Casos con palabras en contextos inusuales
        @{ Input = "FUNCIONARIO P�BLICO"; Expected = "FUNCIONARIO PÚBLICO"; Description = "Público con �" }
        @{ Input = "ADMINISTRACI�N P�BLICA"; Expected = "ADMINISTRACIÓN PÚBLICA"; Description = "Administración pública con doble �" }
        @{ Input = "FUNCI�N P�BLICA"; Expected = "FUNCIÓN PÚBLICA"; Description = "Función pública con doble �" }
        @{ Input = "PERSONAL ESTAT�TARIO"; Expected = "PERSONAL ESTATUTARIO"; Description = "Estatutario con �" }
        
        # Casos con caracteres Unicode problemáticos
        @{ Input = [char]0x00F1 + "I�EZ"; Expected = "ÑIÑEZ"; Description = "ñ Unicode con � adyacente" }
        @{ Input = "NI" + [char]0x00F1 + "� DEL MAR"; Expected = "NIÑA DEL MAR"; Description = "ñ Unicode con � -> a" }
        @{ Input = "A" + [char]0x00F1 + "� 2024"; Expected = "AÑO 2024"; Description = "ñ Unicode con � -> o" }
        @{ Input = "SE" + [char]0x00D1 + "�R"; Expected = "SEÑOR"; Description = "Ñ mayúscula Unicode con � -> O" }
        
        # Casos con múltiples palabras corruptas seguidas
        @{ Input = "MAR�A JOS� L�PEZ MART�NEZ"; Expected = "MARÍA JOSÉ LÓPEZ MARTÍNEZ"; Description = "Nombre completo con múltiple corrupción" }
        @{ Input = "JOS� ANTONIO G�MEZ HERN�NDEZ"; Expected = "JOSÉ ANTONIO GÓMEZ HERNÁNDEZ"; Description = "Nombre compuesto con múltiple corrupción" }
        @{ Input = "ANA MAR�A FERN�NDEZ S�NCHEZ"; Expected = "ANA MARÍA FERNÁNDEZ SÁNCHEZ"; Description = "Nombre femenino con múltiple corrupción" }
        
        # Casos con puntuación y caracteres especiales
        @{ Input = "JUZGADO DE M�LAGA (ESPA�A)"; Expected = "JUZGADO DE MÁLAGA (ESPAÑA)"; Description = "Entre paréntesis con corrupción" }
        @{ Input = "TRIBUNAL - SECCI�N 1�"; Expected = "TRIBUNAL - SECCIÓN 1ª"; Description = "Con guión y ordinal femenino" }
        @{ Input = "FISCAL�A: SECCI�N ESPECIAL"; Expected = "FISCALÍA: SECCI�N ESPECIAL"; Description = "Con dos puntos y corrupción múltiple" }
        @{ Input = "JUZGADO DE 1� INSTANCIA"; Expected = "JUZGADO DE 1ª INSTANCIA"; Description = "Ordinal femenino corrupto" }
        
        # Casos extremos de longitud
        @{ Input = "A"; Expected = "A"; Description = "Un solo carácter válido" }
        @{ Input = "�"; Expected = "i"; Description = "Solo un carácter corrupto" }
        @{ Input = "AA"; Expected = "AA"; Description = "Dos caracteres válidos" }
        @{ Input = "A�"; Expected = "Ai"; Description = "Válido + corrupto" }
        @{ Input = "��"; Expected = "ii"; Description = "Dos caracteres corruptos" }
        
        # Casos con repeticiones problemáticas
        @{ Input = "MAMAMAMALAGA"; Expected = "MÁLAGA"; Description = "Múltiple repetición MAMA -> MÁLAGA" }
        @{ Input = "memememalaga"; Expected = "málaga"; Description = "Múltiple repetición meme -> málaga" }
        @{ Input = "dadadadada"; Expected = "dadadadada"; Description = "Repetición que no debe cambiarse" }
        @{ Input = "tatatatata"; Expected = "tatatatata"; Description = "Otra repetición que no debe cambiarse" }
        
        # Casos con corrupciones en medio de palabras válidas
        @{ Input = "CONSTITU�IONAL"; Expected = "CONSTITUCI�NAL"; Description = "Constitucional con � en medio" }
        @{ Input = "ADMINISTR�TIVO"; Expected = "ADMINISTRATIVO"; Description = "Administrativo con � en medio" }
        @{ Input = "JURISDIC�IONAL"; Expected = "JURISDICCIONAL"; Description = "Jurisdiccional con � en medio" }
        @{ Input = "PROCEDI�IENTO"; Expected = "PROCEDIMIENTO"; Description = "Procedimiento con � en medio" }
        
        # Casos con corrupciones al inicio y final
        @{ Input = "�RGAN"; Expected = "ÓRGANO"; Description = "Órgano con � al inicio" }
        @{ Input = "JUICI�"; Expected = "JUICIO"; Description = "Juicio con � al final" }
        @{ Input = "�LTIMO"; Expected = "ÚLTIMO"; Description = "Último con � al inicio" }
        @{ Input = "DECISI�"; Expected = "DECISIÓN"; Description = "Decisión con � al final" }
        
        # Casos con contextualización judicial compleja
        @{ Input = "JUZGADO DE PRIMERA INSTANCI� E INSTRUCCI�N N�MERO 19 DE M�LAGA"; Expected = "JUZGADO DE PRIMERA INSTANCIA E INSTRUCCIÓN NÚMERO 19 DE MÁLAGA"; Description = "Juzgado completo con múltiple corrupción" }
        @{ Input = "FISCAL�A PROVINCIAL DE VIOLENCI� SOBRE LA MUJER DE C�DIZ"; Expected = "FISCALÍA PROVINCIAL DE VIOLENCIA SOBRE LA MUJER DE CÁDIZ"; Description = "Fiscalía VG completa con corrupción múltiple" }
        @{ Input = "SERVICIO COM�N DE NOTIFICACIONES, EMBARGOS Y SUBASTAS JUDICIALES"; Expected = "SERVICIO COMÚN DE NOTIFICACIONES, EMBARGOS Y SUBASTAS JUDICIALES"; Description = "SCNES con � en común" }
        @{ Input = "TRIBUNAL SUPERIOR DE JUSTICI� DE ANDALUC�A, CEUTA Y MELILLA"; Expected = "TRIBUNAL SUPERIOR DE JUSTICIA DE ANDALUCÍA, CEUTA Y MELILLA"; Description = "TSJ completo con corrupción" }
        
        # Casos con caracteres especiales en secuencia
        @{ Input = ""; Expected = ""; Description = "Tres signos de interrogación - mantener" }
        @{ Input = "���"; Expected = "iii"; Description = "Tres caracteres corruptos" }
        @{ Input = "�"; Expected = "i"; Description = "Alternancia  y �" }
        @{ Input = "��"; Expected = "ii"; Description = "Alternancia � y " }
        
        # Casos con mayúsculas/minúsculas mezcladas problemáticas
        @{ Input = "jUZGADO de pRIMERA iNST�NCIA"; Expected = "jUZGADO de pRIMERA iNSTANCIA"; Description = "Mayúsculas mezcladas con corrupción" }
        @{ Input = "M�lAgA cIuDaD dE lA jUsTiCiA"; Expected = "MálAgA cIuDaD dE lA jUsTiCiA"; Description = "Málaga con mayúsculas aleatorias" }
        @{ Input = "fIsCaL�A eSpEcIaL"; Expected = "fIsCaLíA eSpEcIaL"; Description = "Fiscalía con mayúsculas aleatorias" }
        
        # Casos con espacios y tabulaciones mezclados
        @{ Input = "M�LAGA `t  CIUDAD"; Expected = "MÁLAGA CIUDAD"; Description = "Tab y espacios mezclados" }
        @{ Input = "`tJUZGADO`t`tDE`t`t`tM�LAGA`t"; Expected = "JUZGADO DE MÁLAGA"; Description = "Tabs múltiples con corrupción" }
        @{ Input = " `r`n M�LAGA `r`n "; Expected = "MÁLAGA"; Description = "Saltos de línea con corrupción" }
        
        # Casos límite con números de expedientes complejos
        @{ Input = "D.P. N�M. 123/2024-A"; Expected = "D.P. NÚM. 123/2024-A"; Description = "DP con sufijo alfabético" }
        @{ Input = "P.A. N�M. 456/24-B1"; Expected = "P.A. NÚM. 456/24-B1"; Description = "PA con sufijo alfanumérico" }
        @{ Input = "SUMARIO N�M. 789/2024-ESPECIAL"; Expected = "SUMARIO NÚM. 789/2024-ESPECIAL"; Description = "Sumario con tipo especial" }
        
        # Casos finales complejos de integración
        @{ Input = "EL ILUSTR�SIMO SE�OR MAGISTRADO-JUEZ"; Expected = "EL ILUSTRÍSIMO SEÑOR MAGISTRADO-JUEZ"; Description = "Tratamiento judicial completo" }
        @{ Input = "EXCELENT�SIMO TRIBUNAL SUPERIOR DE JUSTICI�"; Expected = "EXCELENTÍSIMO TRIBUNAL SUPERIOR DE JUSTICIA"; Description = "Tratamiento TSJ completo" }
        @{ Input = "SU SE�OR�A EL MAGISTRADO DE LA AUDIENCI�"; Expected = "SU SEÑORÍA EL MAGISTRADO DE LA AUDIENCIA"; Description = "Tratamiento audiencia" }
    )
    
    Execute-TestBatch -TestCases $TestCases -Category "ComplexEdgeCases"
}

function Test-PerformanceWithLongTexts {
    Write-Host "`n⚡ CATEGORÍA 5: Rendimiento con textos largos (50 casos)" -ForegroundColor Yellow
    
    $TestCases = @()
    
    # Generar textos largos con diferentes patrones de corrupción
    for ($i = 1; $i -le 10; $i++) {
        $LongCorruptedText = "JUZGADO DE PRIMERA INSTANCI� E INSTRUCCI�N N�MERO $i DE M�LAGA, " * 5
        $ExpectedText = "JUZGADO DE PRIMERA INSTANCIA E INSTRUCCIÓN NÚMERO $i DE MÁLAGA, " * 5
        $ExpectedText = $ExpectedText.TrimEnd(', ')
        $LongCorruptedText = $LongCorruptedText.TrimEnd(', ')
        
        $TestCases += @{
            Input = $LongCorruptedText
            Expected = $ExpectedText
            Description = "Texto largo repetitivo $i con múltiple corrupción"
        }
    }
    
    # Textos con alta densidad de corrupción
    for ($i = 1; $i -le 5; $i++) {
        $HighDensityText = "M�LAGA C�DIZ ALMER�A JA�N C�RDOBA SEVILLA GRANADA HUELVA " * $i
        $ExpectedHighDensity = "MÁLAGA CÁDIZ ALMERÍA JAÉN CÓRDOBA SEVILLA GRANADA HUELVA " * $i
        $ExpectedHighDensity = $ExpectedHighDensity.TrimEnd(' ')
        $HighDensityText = $HighDensityText.TrimEnd(' ')
        
        $TestCases += @{
            Input = $HighDensityText
            Expected = $ExpectedHighDensity
            Description = "Alta densidad de corrupción $i"
        }
    }
    
    # Textos largos con patrones específicos
    $VeryLongText = @"
JUZGADO DE PRIMERA INSTANCI� E INSTRUCCI�N N�MERO 19 DE M�LAGA
FISCAL�A PROVINCIAL DE VIOLENCI� SOBRE LA MUJER DE C�DIZ
TRIBUNAL SUPERIOR DE JUSTICI� DE ANDALUC�A, CEUTA Y MELILLA
SERVICIO COM�N DE NOTIFICACIONES, EMBARGOS Y SUBASTAS JUDICIALES
INSTITUTO DE MEDICINA LEGAL Y CIENCIAS FORENSES DE ALMER�A
REGISTRO CIVIL EXCLUSIVO DE M�LAGA
AUDIENCIA PROVINCIAL DE C�RDOBA
JUZGADO DE LO PENAL N�MERO 5 DE JA�N
JUZGADO DE LO CONTENCIOSO-ADMINISTRATIVO N�MERO 3 DE SEVILLA
JUZGADO DE VIOLENCI� SOBRE LA MUJER N�MERO 1 DE GRANADA
"@
    
    $VeryLongExpected = @"
JUZGADO DE PRIMERA INSTANCIA E INSTRUCCIÓN NÚMERO 19 DE MÁLAGA
FISCALÍA PROVINCIAL DE VIOLENCIA SOBRE LA MUJER DE CÁDIZ
TRIBUNAL SUPERIOR DE JUSTICIA DE ANDALUCÍA, CEUTA Y MELILLA
SERVICIO COMÚN DE NOTIFICACIONES, EMBARGOS Y SUBASTAS JUDICIALES
INSTITUTO DE MEDICINA LEGAL Y CIENCIAS FORENSES DE ALMERÍA
REGISTRO CIVIL EXCLUSIVO DE MÁLAGA
AUDIENCIA PROVINCIAL DE CÓRDOBA
JUZGADO DE LO PENAL NÚMERO 5 DE JAÉN
JUZGADO DE LO CONTENCIOSO-ADMINISTRATIVO NÚMERO 3 DE SEVILLA
JUZGADO DE VIOLENCIA SOBRE LA MUJER NÚMERO 1 DE GRANADA
"@
    
    for ($i = 1; $i -le 5; $i++) {
        $ReplicatedText = $VeryLongText * $i
        $ReplicatedExpected = $VeryLongExpected * $i
        
        $TestCases += @{
            Input = $ReplicatedText.Trim()
            Expected = $ReplicatedExpected.Trim()
            Description = "Documento judicial completo replicado x$i"
        }
    }
    
    # Textos con diferentes tipos de espaciado
    for ($i = 1; $i -le 10; $i++) {
        $SpacedText = "M�LAGA" + (" " * $i) + "CIUDAD" + (" " * $i) + "DE" + (" " * $i) + "LA" + (" " * $i) + "JUSTICI�"
        $ExpectedSpaced = "MÁLAGA CIUDAD DE LA JUSTICIA"
        
        $TestCases += @{
            Input = $SpacedText
            Expected = $ExpectedSpaced
            Description = "Espaciado variable nivel $i con corrupción"
        }
    }
    
    # Textos extremadamente largos (límites de rendimiento)
    for ($i = 1; $i -le 10; $i++) {
        $ExtremeText = ("ADMINISTRACI�N P�BLICA DE ANDALUC�A " * ($i * 10)).TrimEnd(' ')
        $ExtremeExpected = ("ADMINISTRACIÓN PÚBLICA DE ANDALUCÍA " * ($i * 10)).TrimEnd(' ')
        
        $TestCases += @{
            Input = $ExtremeText
            Expected = $ExtremeExpected
            Description = "Texto extremo nivel $i ($(($i * 10)) repeticiones)"
        }
    }
    
    # Casos específicos de rendimiento con medición de tiempo
    $TestCases += @{
        Input = "M�LAGA" * 1000
        Expected = "MÁLAGA" * 1000
        Description = "Rendimiento: 1000 repeticiones de MÁLAGA"
    }
    
    $TestCases += @{
        Input = ("FISCAL�A " * 500).TrimEnd(' ')
        Expected = ("FISCALÍA " * 500).TrimEnd(' ')
        Description = "Rendimiento: 500 repeticiones de FISCALÍA"
    }
    
    Execute-TestBatch -TestCases $TestCases -Category "PerformanceLongTexts"
}

function Test-LocationExtractionIntegration {
    Write-Host "`n🌍 CATEGORÍA 6: Integración con Extract-LocationFromOffice (50 casos)" -ForegroundColor Yellow
    
    $TestCases = @()
    
    # Casos básicos de extracción de localidad con normalización
    $LocationTests = @(
        @{ Office = "JUZGADO DE M�LAGA"; ExpectedLocation = "malaga"; Description = "Juzgado de Málaga con �" }
        @{ Office = "TRIBUNAL DE C�DIZ"; ExpectedLocation = "cadiz"; Description = "Tribunal de Cádiz con �" }
        @{ Office = "FISCAL�A DE JA�N"; ExpectedLocation = "jaen"; Description = "Fiscalía de Jaén con �" }
        @{ Office = "AUDIENCIA DE C�RDOBA"; ExpectedLocation = "cordoba"; Description = "Audiencia de Córdoba con �" }
        @{ Office = "REGISTRO DE ALMER�A"; ExpectedLocation = "almeria"; Description = "Registro de Almería con �" }
        @{ Office = "JUZGADO DE SEVILLA"; ExpectedLocation = "sevilla"; Description = "Juzgado de Sevilla sin corrupción" }
        @{ Office = "TRIBUNAL DE GRANADA"; ExpectedLocation = "granada"; Description = "Tribunal de Granada sin corrupción" }
        @{ Office = "FISCAL�A DE HUELVA"; ExpectedLocation = "huelva"; Description = "Fiscalía de Huelva sin corrupción en provincia" }
        
        # Casos complejos con Ciudad de la Justicia
        @{ Office = "JUZGADO DE PRIMERA INSTANCIA N� 19 DE M�LAGA"; ExpectedLocation = "malaga"; Description = "JPI 19 Málaga con corrupción" }
        @{ Office = "CIUDAD DE LA JUSTICIA DE MALAGA"; ExpectedLocation = "malaga"; Description = "Ciudad de la Justicia Málaga" }
        @{ Office = "CIUDAD DE LA JUSTICIA DE M�LAGA"; ExpectedLocation = "malaga"; Description = "Ciudad de la Justicia Málaga con �" }
        @{ Office = "MALAGA-MACJ-CIUDAD DE LA JUSTICIA"; ExpectedLocation = "malaga"; Description = "Patrón MACJ específico" }
        
        # Casos con ciudades específicas que deben mapear a provincias
        @{ Office = "JUZGADO DE MARBELLA"; ExpectedLocation = "malaga"; Description = "Marbella -> Málaga" }
        @{ Office = "TRIBUNAL DE JEREZ"; ExpectedLocation = "cadiz"; Description = "Jerez -> Cádiz" }
        @{ Office = "FISCAL�A DE ALGECIRAS"; ExpectedLocation = "cadiz"; Description = "Algeciras -> Cádiz" }
        @{ Office = "JUZGADO DE ANTEQUERA"; ExpectedLocation = "malaga"; Description = "Antequera -> Málaga" }
        @{ Office = "REGISTRO DE LINARES"; ExpectedLocation = "jaen"; Description = "Linares -> Jaén" }
        @{ Office = "JUZGADO DE �BEDA"; ExpectedLocation = "jaen"; Description = "Úbeda con � -> Jaén" }
        @{ Office = "TRIBUNAL DE AND�JAR"; ExpectedLocation = "jaen"; Description = "Andújar con � -> Jaén" }
        @{ Office = "FISCAL�A DE LUCENA"; ExpectedLocation = "cordoba"; Description = "Lucena -> Córdoba" }
        @{ Office = "JUZGADO DE MOTRIL"; ExpectedLocation = "granada"; Description = "Motril -> Granada" }
        @{ Office = "REGISTRO DE EL EJIDO"; ExpectedLocation = "almeria"; Description = "El Ejido -> Almería" }
        
        # Casos edge con múltiple corrupción
        @{ Office = "IMLCF CENTRAL DE JA�N - PATOLOG�A FORENSE"; ExpectedLocation = "jaen"; Description = "IMLCF Jaén con doble corrupción" }
        @{ Office = "REGISTRO CIVIL EXCLUSIVO DE M�LAGA"; ExpectedLocation = "malaga"; Description = "RC exclusivo Málaga con �" }
        @{ Office = "SERVICIO COM�N DE NOTIF. DE C�DIZ"; ExpectedLocation = "cadiz"; Description = "SCNES Cádiz con corrupción múltiple" }
        
        # Casos con patrones problemáticos específicos reportados
        @{ Office = "mamámámálaga ciudad de la justicia"; ExpectedLocation = "malaga"; Description = "Patrón mamámámálaga específico" }
        @{ Office = "MAMÁMÁMÁLAGA JUZGADO"; ExpectedLocation = "malaga"; Description = "MAMÁMÁMÁLAGA en mayúsculas" }
        @{ Office = "JUZGADO DE mamamalaga"; ExpectedLocation = "malaga"; Description = "mamamalaga sin tildes" }
        
        # Casos con abreviaciones comunes
        @{ Office = "JPI N� 1 DE M�LAGA"; ExpectedLocation = "malaga"; Description = "JPI abreviado con corrupción" }
        @{ Office = "JCA N� 2 DE C�DIZ"; ExpectedLocation = "cadiz"; Description = "JCA abreviado con corrupción" }
        @{ Office = "JVM N� 1 DE ALMER�A"; ExpectedLocation = "almeria"; Description = "JVM abreviado con corrupción" }
        @{ Office = "JPenal N� 3 DE JA�N"; ExpectedLocation = "jaen"; Description = "JPenal abreviado con corrupción" }
        
        # Casos que deben devolver UNKNOWN
        @{ Office = "OFICINA SIN UBICACI�N"; ExpectedLocation = "UNKNOWN"; Description = "Oficina sin ubicación identificable" }
        @{ Office = "MINISTERIO DE JUSTICI�"; ExpectedLocation = "UNKNOWN"; Description = "Ministerio sin provincia específica" }
        @{ Office = "CENTRO FORMACI�N"; ExpectedLocation = "UNKNOWN"; Description = "Centro sin ubicación específica" }
        
        # Casos con fallback a Sevilla
        @{ Office = "TRIBUNAL SUPERIOR DE JUSTICI� DE ANDALUC�A"; ExpectedLocation = "sevilla"; Description = "TSJ Andalucía -> fallback Sevilla" }
        @{ Office = "FISCAL�A GENERAL DEL ESTADO"; ExpectedLocation = "UNKNOWN"; Description = "FGE -> UNKNOWN (no andaluz)" }
        @{ Office = "JUZGADO CENTRAL DE INSTRUCCI�N"; ExpectedLocation = "UNKNOWN"; Description = "JCI -> UNKNOWN (no andaluz)" }
        
        # Casos complejos con múltiples ubicaciones en el texto
        @{ Office = "TRASLADO DE SEVILLA A M�LAGA"; ExpectedLocation = "malaga"; Description = "Múltiples ubicaciones - última prevalece" }
        @{ Office = "SERVICIO DE C�DIZ EN ALMER�A"; ExpectedLocation = "almeria"; Description = "Múltiples ubicaciones - última prevalece" }
        
        # Casos con diferentes patrones de escritura de números
        @{ Office = "JUZGADO NUMERO 1 DE M�LAGA"; ExpectedLocation = "malaga"; Description = "NUMERO escrito completo" }
        @{ Office = "JUZGADO NRO. 2 DE C�DIZ"; ExpectedLocation = "cadiz"; Description = "NRO. abreviado" }
        @{ Office = "JUZGADO No. 3 DE JA�N"; ExpectedLocation = "jaen"; Description = "No. anglosajón" }
        
        # Casos con contexto de tipo de juzgado específico
        @{ Office = "JUZGADO DE FAMILIA DE M�LAGA"; ExpectedLocation = "malaga"; Description = "Juzgado de Familia específico" }
        @{ Office = "JUZGADO DE MENORES DE C�DIZ"; ExpectedLocation = "cadiz"; Description = "Juzgado de Menores específico" }
        @{ Office = "JUZGADO DE VIGILANCIA PENITENCIARI� DE ALMER�A"; ExpectedLocation = "almeria"; Description = "JVP específico con corrupción" }
        
        # Casos finales de integración compleja
        @{ Office = "EXPEDIENTE DEL JUZGADO DE PRIMERA INSTANCI� E INSTRUCCI�N N�MERO 19 DE M�LAGA (CIUDAD DE LA JUSTICIA)"; ExpectedLocation = "malaga"; Description = "Descripción completa con múltiple corrupción" }
        @{ Office = "DILIGENCIAS PREVIAS DEL JUZGADO DE INSTRUCCI�N N�MERO 3 DE C�DIZ"; ExpectedLocation = "cadiz"; Description = "DP con juzgado específico y corrupción" }
    )
    
    # Convertir a formato de test estándar
    foreach ($LocationTest in $LocationTests) {
        # Primero aplicar normalización
        $NormalizedOffice = Normalize-Text -Text $LocationTest.Office
        
        # Luego extraer localidad
        $ExtractedLocation = Extract-LocationFromOffice -Office $NormalizedOffice
        
        # Crear caso de test que valida la localidad extraída
        $TestCases += @{
            Input = $LocationTest.Office
            Expected = $LocationTest.ExpectedLocation
            Description = $LocationTest.Description
            TestType = "LocationExtraction"
            ExtractedLocation = $ExtractedLocation
        }
    }
    
    Execute-TestBatch -TestCases $TestCases -Category "LocationExtraction"
}

function Test-UTF8AndSpecialEncodings {
    Write-Host "`n🔤 CATEGORÍA 7: UTF-8 y encodings especiales (100 casos)" -ForegroundColor Yellow
    
    $TestCases = @()
    
    # Casos con caracteres Unicode específicos
    $UnicodeTests = @(
        # Caracteres españoles específicos con códigos Unicode
        @{ Input = [char]0x00E1 + "LMER" + [char]0x00ED + "A"; Expected = "ALMERÍA"; Description = "á (U+00E1) + í (U+00ED)" }
        @{ Input = [char]0x00C1 + "LMER" + [char]0x00CD + "A"; Expected = "ALMERÍA"; Description = "Á (U+00C1) + Í (U+00CD)" }
        @{ Input = "C" + [char]0x00E1 + "diz"; Expected = "Cádiz"; Description = "á Unicode en Cádiz" }
        @{ Input = "C" + [char]0x00F3 + "rdoba"; Expected = "Córdoba"; Description = "ó Unicode en Córdoba" }
        @{ Input = "Ja" + [char]0x00E9 + "n"; Expected = "Jaén"; Description = "é Unicode en Jaén" }
        @{ Input = "M" + [char]0x00E1 + "laga"; Expected = "Málaga"; Description = "á Unicode en Málaga" }
        
        # Caracteres con tildes específicas
        @{ Input = "L" + [char]0x00F3 + "pez"; Expected = "López"; Description = "ó Unicode en López" }
        @{ Input = "Mart" + [char]0x00ED + "nez"; Expected = "Martínez"; Description = "í Unicode en Martínez" }
        @{ Input = "G" + [char]0x00F3 + "mez"; Expected = "Gómez"; Description = "ó Unicode en Gómez" }
        @{ Input = "Hern" + [char]0x00E1 + "ndez"; Expected = "Hernández"; Description = "á Unicode en Hernández" }
        
        # Caracteres ñ con diferentes encodings
        @{ Input = "A" + [char]0x00F1 + "o"; Expected = "Año"; Description = "ñ Unicode minúscula" }
        @{ Input = "A" + [char]0x00D1 + "O"; Expected = "AÑO"; Description = "Ñ Unicode mayúscula" }
        @{ Input = "Se" + [char]0x00F1 + "or"; Expected = "Señor"; Description = "ñ Unicode en señor" }
        @{ Input = "SE" + [char]0x00D1 + "ORA"; Expected = "SEÑORA"; Description = "Ñ Unicode en señora" }
        @{ Input = "Ni" + [char]0x00F1 + "a"; Expected = "Niña"; Description = "ñ Unicode en niña" }
        
        # Caracteres diéresis
        @{ Input = "G" + [char]0x00FC + "ell"; Expected = "Güell"; Description = "ü Unicode en apellido catalán" }
        @{ Input = "Arg" + [char]0x00FC + "elles"; Expected = "Argüelles"; Description = "ü Unicode en Argüelles" }
        @{ Input = "Ling" + [char]0x00FC + "ística"; Expected = "Lingüística"; Description = "ü Unicode en lingüística" }
        
        # Casos con múltiples acentos Unicode
        @{ Input = [char]0x00C1 + "LMER" + [char]0x00CD + "A Y C" + [char]0x00C1 + "DIZ"; Expected = "ALMERÍA Y CÁDIZ"; Description = "Múltiples acentos Unicode mayúsculas" }
        @{ Input = [char]0x00E1 + "lmer" + [char]0x00ED + "a y c" + [char]0x00E1 + "diz"; Expected = "almería y cádiz"; Description = "Múltiples acentos Unicode minúsculas" }
        @{ Input = "M" + [char]0x00E1 + "laga y C" + [char]0x00F3 + "rdoba"; Expected = "Málaga y Córdoba"; Description = "Múltiples acentos mixtos" }
        
        # Casos con caracteres de reemplazo UTF-8
        @{ Input = "ALMER" + [char]0xFFFD + "A"; Expected = "ALMERÍA"; Description = "Carácter de reemplazo UTF-8" }
        @{ Input = "C" + [char]0xFFFD + "DIZ"; Expected = "CÁDIZ"; Description = "Carácter reemplazo en Cádiz" }
        @{ Input = "M" + [char]0xFFFD + "LAGA"; Expected = "MÁLAGA"; Description = "Carácter reemplazo en Málaga" }
        
        # Casos con secuencias de bytes mal formadas (simuladas)
        @{ Input = "ALMER\u00ED\u00C1"; Expected = "ALMERÍA"; Description = "Secuencia mixta í + Á" }
        @{ Input = "C\u00C1\u00E1DIZ"; Expected = "CÁDIZ"; Description = "Secuencia mixta Á + á" }
        @{ Input = "M\u00E1\u00C1LAGA"; Expected = "MÁLAGA"; Description = "Secuencia duplicada á + Á" }
        
        # BOM y marcadores de encoding
        @{ Input = [char]0xFEFF + "MÁLAGA"; Expected = "MÁLAGA"; Description = "UTF-8 BOM + Málaga" }
        @{ Input = [char]0xFFFE + "CÁDIZ"; Expected = "CÁDIZ"; Description = "UTF-16 BE BOM + Cádiz" }
        
        # Caracteres de control Unicode
        @{ Input = "MÁLAGA" + [char]0x200B + "CIUDAD"; Expected = "MÁLAGA CIUDAD"; Description = "Zero-width space" }
        @{ Input = "JUZGADO" + [char]0x00A0 + "DE" + [char]0x00A0 + "MÁLAGA"; Expected = "JUZGADO DE MÁLAGA"; Description = "Non-breaking space" }
        @{ Input = "CÁDIZ" + [char]0x2000 + "CAPITAL"; Expected = "CÁDIZ CAPITAL"; Description = "En quad space" }
        
        # Ligaduras y caracteres combinados
        @{ Input = "ADMINISTRACI" + [char]0x00F3 + [char]0x0301 + "N"; Expected = "ADMINISTRACIÓN"; Description = "ó + combining acute accent" }
        @{ Input = "INSTRUCCI" + [char]0x006F + [char]0x0301 + "N"; Expected = "INSTRUCCIÓN"; Description = "o + combining acute accent" }
        
        # Caracteres homógrafos problemáticos
        @{ Input = "MALAGA"; Expected = "MALAGA"; Description = "Málaga sin tilde (mantener)" }
        @{ Input = "M" + [char]0x0410 + "LAGA"; Expected = "MÁLAGA"; Description = "А cirílica en lugar de A latina" }
        @{ Input = "CADI" + [char]0x0417 + ""; Expected = "CADIZ"; Description = "З cirílica problemática" }
        
        # Casos con diferentes normalizaciones Unicode
        @{ Input = [System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::GetEncoding("ISO-8859-1").GetBytes("MÁLAGA")); Expected = "MÁLAGA"; Description = "Conversión ISO-8859-1 -> UTF-8" }
        
        # Caracteres invisibles y de formato
        @{ Input = "MÁLAGA" + [char]0x200C + "CIUDAD"; Expected = "MÁLAGA CIUDAD"; Description = "Zero-width non-joiner" }
        @{ Input = "JUZGADO" + [char]0x200D + "MÁLAGA"; Expected = "JUZGADO MÁLAGA"; Description = "Zero-width joiner" }
        @{ Input = [char]0x202A + "MÁLAGA" + [char]0x202C; Expected = "MÁLAGA"; Description = "Left-to-right embedding + pop" }
        
        # Variaciones de espacios Unicode
        @{ Input = "JUZGADO" + [char]0x2009 + "DE" + [char]0x2009 + "MÁLAGA"; Expected = "JUZGADO DE MÁLAGA"; Description = "Thin space Unicode" }
        @{ Input = "TRIBUNAL" + [char]0x2007 + "MÁLAGA"; Expected = "TRIBUNAL MÁLAGA"; Description = "Figure space Unicode" }
        @{ Input = "FISCALÍA" + [char]0x2008 + "CÁDIZ"; Expected = "FISCALÍA CÁDIZ"; Description = "Punctuation space Unicode" }
        
        # Casos extremos con múltiples encodings
        @{ Input = [char]0x00C1 + "LMER" + [char]0xFFFD + "A Y C" + [char]0x00C1 + "DIZ"; Expected = "ALMERÍA Y CÁDIZ"; Description = "Unicode mixto con carácter reemplazo" }
        @{ Input = [char]0xFEFF + "M" + [char]0x00E1 + "laga " + [char]0x200B + "Ciudad"; Expected = "Málaga Ciudad"; Description = "BOM + Unicode + zero-width space" }
        
        # Casos de doble encoding problemático
        @{ Input = "M√°laga"; Expected = "Málaga"; Description = "Doble encoding UTF-8 -> Latin-1" }
        @{ Input = "C√°diz"; Expected = "Cádiz"; Description = "Doble encoding UTF-8 problemático" }
        @{ Input = "Almer√≠a"; Expected = "Almería"; Description = "Doble encoding con í problemático" }
        
        # Casos con encoding Windows-1252 problemático
        @{ Input = "M‡laga"; Expected = "Málaga"; Description = "Windows-1252 mal interpretado" }
        @{ Input = "C‡diz"; Expected = "Cádiz"; Description = "Windows-1252 problemático Cádiz" }
        
        # Casos finales complejos de múltiple corrupción Unicode
        @{ Input = [char]0xFFFD + "UZGADO DE " + [char]0x00C1 + "LMER" + [char]0xFFFD + "A"; Expected = "iUZGADO DE ALMERÍA"; Description = "Múltiple corrupción Unicode compleja" }
        @{ Input = "FISCAL" + [char]0xFFFD + "A DE C" + [char]0x00C1 + "DIZ"; Expected = "FISCALÍA DE CÁDIZ"; Description = "Fiscalía con corrupción Unicode mixta" }
        @{ Input = [char]0x200B + "JUZGADO" + [char]0x00A0 + "DE" + [char]0xFFFD + "ÁLAGA" + [char]0x200C; Expected = "JUZGADO DE iÁLAGA"; Description = "Caso extremo con múltiples caracteres especiales" }
    )
    
    # Convertir a casos de test
    foreach ($UnicodeTest in $UnicodeTests) {
        $TestCases += @{
            Input = $UnicodeTest.Input
            Expected = $UnicodeTest.Expected
            Description = $UnicodeTest.Description
        }
    }
    
    # Casos específicos de rendimiento con UTF-8
    for ($i = 1; $i -le 20; $i++) {
        $UnicodeRepeated = ([char]0x00E1 + "lmer" + [char]0x00ED + "a ") * $i
        $ExpectedRepeated = ("almería " * $i).TrimEnd(' ')
        $UnicodeRepeated = $UnicodeRepeated.TrimEnd(' ')
        
        $TestCases += @{
            Input = $UnicodeRepeated
            Expected = $ExpectedRepeated
            Description = "UTF-8 repetido $i veces con almería"
        }
    }
    
    Execute-TestBatch -TestCases $TestCases -Category "UTF8SpecialEncodings"
}

function Execute-TestBatch {
    <#
    .SYNOPSIS
        Ejecuta un lote de casos de test y recolecta resultados
    #>
    param(
        [array]$TestCases,
        [string]$Category
    )
    
    $CategoryResults = @{
        'Passed' = 0
        'Failed' = 0
        'Errors' = @()
        'TotalTime' = 0
    }
    
    $TotalCases = $TestCases.Count
    Write-Host "  Ejecutando $TotalCases casos de test..." -ForegroundColor Gray
    
    foreach ($TestCase in $TestCases) {
        try {
            $StartTime = Get-Date
            
            if ($TestCase.TestType -eq "LocationExtraction") {
                # Test específico de extracción de localidad
                $ActualResult = $TestCase.ExtractedLocation
                $Expected = $TestCase.Expected
            } else {
                # Test estándar de normalización
                $ActualResult = Normalize-Text -Text $TestCase.Input
                $Expected = $TestCase.Expected
            }
            
            $EndTime = Get-Date
            $Duration = ($EndTime - $StartTime).TotalMilliseconds
            
            if ($ActualResult -eq $Expected) {
                $CategoryResults.Passed++
                $Global:TestResults.Passed++
                Write-Host "    ✅ PASS: $($TestCase.Description)" -ForegroundColor Green
            } else {
                $CategoryResults.Failed++
                $Global:TestResults.Failed++
                $ErrorInfo = @{
                    Category = $Category
                    Description = $TestCase.Description
                    Input = $TestCase.Input
                    Expected = $Expected
                    Actual = $ActualResult
                }
                $CategoryResults.Errors += $ErrorInfo
                $Global:TestResults.Errors += $ErrorInfo
                Write-Host "    ❌ FAIL: $($TestCase.Description)" -ForegroundColor Red
                Write-Host "        Input: '$($TestCase.Input)'" -ForegroundColor Gray
                Write-Host "        Expected: '$Expected'" -ForegroundColor Gray
                Write-Host "        Actual: '$ActualResult'" -ForegroundColor Gray
            }
            
            $CategoryResults.TotalTime += $Duration
            
            # Registrar rendimiento para casos largos
            if ($Duration -gt 100) {  # > 100ms
                $Global:TestResults.Performance += @{
                    Category = $Category
                    Description = $TestCase.Description
                    Duration = $Duration
                    InputLength = $TestCase.Input.Length
                }
            }
            
        } catch {
            $CategoryResults.Failed++
            $Global:TestResults.Failed++
            $ErrorInfo = @{
                Category = $Category
                Description = $TestCase.Description
                Input = $TestCase.Input
                Expected = $TestCase.Expected
                Error = $_.Exception.Message
            }
            $CategoryResults.Errors += $ErrorInfo
            $Global:TestResults.Errors += $ErrorInfo
            Write-Host "    💥 ERROR: $($TestCase.Description) - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Resumen de la categoría
    Write-Host "`n  📊 RESUMEN $Category:" -ForegroundColor Cyan
    Write-Host "    ✅ Pasaron: $($CategoryResults.Passed)/$TotalCases" -ForegroundColor Green
    Write-Host "    ❌ Fallaron: $($CategoryResults.Failed)/$TotalCases" -ForegroundColor Red
    Write-Host "    ⏱️ Tiempo total: $([Math]::Round($CategoryResults.TotalTime, 2))ms" -ForegroundColor Yellow
    Write-Host "    ⚡ Promedio: $([Math]::Round($CategoryResults.TotalTime / $TotalCases, 2))ms por test" -ForegroundColor Yellow
}

function Generate-TestReport {
    <#
    .SYNOPSIS
        Genera el reporte final de todos los tests ejecutados
    #>
    Write-Host "`n" + ("="*80) -ForegroundColor Cyan
    Write-Host "📋 REPORTE FINAL DE TESTS - NORMALIZE-TEXT MEJORADA" -ForegroundColor Cyan
    Write-Host ("="*80) -ForegroundColor Cyan
    
    $Total = $Global:TestResults.Passed + $Global:TestResults.Failed
    $SuccessRate = if ($Total -gt 0) { [Math]::Round(($Global:TestResults.Passed * 100) / $Total, 2) } else { 0 }
    
    Write-Host "`n🎯 ESTADÍSTICAS GENERALES:" -ForegroundColor Yellow
    Write-Host "  Total de tests ejecutados: $Total" -ForegroundColor White
    Write-Host "  ✅ Tests pasados: $($Global:TestResults.Passed)" -ForegroundColor Green
    Write-Host "  ❌ Tests fallados: $($Global:TestResults.Failed)" -ForegroundColor Red
    Write-Host "  📊 Tasa de éxito: $SuccessRate%" -ForegroundColor $(if ($SuccessRate -ge 95) { "Green" } elseif ($SuccessRate -ge 90) { "Yellow" } else { "Red" })
    
    if ($Global:TestResults.Errors.Count -gt 0) {
        Write-Host "`n❌ DETALLES DE FALLOS:" -ForegroundColor Red
        $ErrorsByCategory = $Global:TestResults.Errors | Group-Object Category
        foreach ($CategoryGroup in $ErrorsByCategory) {
            Write-Host "`n  📂 $($CategoryGroup.Name) ($($CategoryGroup.Count) fallos):" -ForegroundColor Red
            foreach ($Error in $CategoryGroup.Group | Select-Object -First 5) {
                Write-Host "    • $($Error.Description)" -ForegroundColor Gray
                if ($Error.Error) {
                    Write-Host "      Error: $($Error.Error)" -ForegroundColor DarkRed
                } else {
                    Write-Host "      Input: '$($Error.Input)'" -ForegroundColor DarkGray
                    Write-Host "      Expected: '$($Error.Expected)'" -ForegroundColor DarkGray
                    Write-Host "      Actual: '$($Error.Actual)'" -ForegroundColor DarkGray
                }
            }
            if ($CategoryGroup.Count -gt 5) {
                Write-Host "    ... y $($CategoryGroup.Count - 5) errores más" -ForegroundColor DarkGray
            }
        }
    }
    
    if ($Global:TestResults.Performance.Count -gt 0) {
        Write-Host "`n⚡ ANÁLISIS DE RENDIMIENTO:" -ForegroundColor Yellow
        $SlowTests = $Global:TestResults.Performance | Sort-Object Duration -Descending | Select-Object -First 10
        Write-Host "  Top 10 tests más lentos:" -ForegroundColor White
        foreach ($SlowTest in $SlowTests) {
            Write-Host "    • $($SlowTest.Description): $([Math]::Round($SlowTest.Duration, 2))ms (longitud: $($SlowTest.InputLength))" -ForegroundColor Gray
        }
        
        $AvgDuration = ($Global:TestResults.Performance | Measure-Object Duration -Average).Average
        Write-Host "`n  ⏱️ Duración promedio tests lentos: $([Math]::Round($AvgDuration, 2))ms" -ForegroundColor White
    }
    
    Write-Host "`n🎉 CONCLUSIONES:" -ForegroundColor Green
    if ($SuccessRate -ge 99) {
        Write-Host "  ✨ EXCELENTE: La función Normalize-Text funciona perfectamente" -ForegroundColor Green
        Write-Host "  🚀 Listo para producción sin modificaciones" -ForegroundColor Green
    } elseif ($SuccessRate -ge 95) {
        Write-Host "  ✅ MUY BUENO: La función funciona correctamente con fallos menores" -ForegroundColor Green
        Write-Host "  🔧 Revisar casos específicos que fallaron" -ForegroundColor Yellow
    } elseif ($SuccessRate -ge 90) {
        Write-Host "  ⚠️ BUENO: La función funciona pero necesita ajustes" -ForegroundColor Yellow
        Write-Host "  🛠️ Requiere correcciones antes de producción" -ForegroundColor Yellow
    } else {
        Write-Host "  🚨 REQUIERE ATENCIÓN: Muchos tests fallando" -ForegroundColor Red
        Write-Host "  🔥 Necesita revisión significativa antes de usar" -ForegroundColor Red
    }
    
    Write-Host "`n📈 MÉTRICAS DE CALIDAD:" -ForegroundColor Cyan
    Write-Host "  🎯 Objetivo de tasa de éxito: 99%+" -ForegroundColor White
    Write-Host "  🎯 Tasa actual: $SuccessRate%" -ForegroundColor $(if ($SuccessRate -ge 99) { "Green" } else { "Yellow" })
    Write-Host "  🎯 Tests críticos: $(($Global:TestResults.Errors | Where-Object { $_.Category -in @("BasicCorrupted", "AndalusianProvinces") }).Count) fallos" -ForegroundColor $(if (($Global:TestResults.Errors | Where-Object { $_.Category -in @("BasicCorrupted", "AndalusianProvinces") }).Count -eq 0) { "Green" } else { "Red" })
    
    Write-Host "`n" + ("="*80) -ForegroundColor Cyan
    Write-Host "🏁 FIN DEL REPORTE DE TESTS" -ForegroundColor Cyan
    Write-Host ("="*80) -ForegroundColor Cyan
}

# Ejecutar la suite completa si el script se ejecuta directamente
if ($MyInvocation.InvocationName -ne '.') {
    Test-NormalizeTextFunction
}