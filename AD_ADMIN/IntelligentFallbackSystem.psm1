#Requires -Version 5.1

<#
.SYNOPSIS
    Sistema inteligente de fallback para mapeo de UOs cuando no se encuentran coincidencias
.DESCRIPTION
    Módulo avanzado que implementa estrategias de fallback jerárquicas:
    - Análisis de patrones de UOs similares
    - Mapeo por jerarquía organizacional
    - Fallback geográfico inteligente
    - Sistema de aprendizaje de patrones fallidos
    - Sugerencias alternativas con confianza calibrada
#>

$script:FallbackCache = @{}
$script:FailedPatternsDB = @{}
$script:OrganizationalHierarchy = $null
$script:GeographicFallbacks = $null

function Initialize-FallbackSystem {
    <#
    .SYNOPSIS
        Inicializa el sistema de fallback con datos del dominio
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [array]$AllAvailableOUs = @()
    )
    
    Write-Verbose "Inicializando sistema inteligente de fallback..."
    
    # Cargar jerarquía organizacional
    $script:OrganizationalHierarchy = Build-OrganizationalHierarchy -AllOUs $AllAvailableOUs
    
    # Configurar fallbacks geográficos
    $script:GeographicFallbacks = Initialize-GeographicFallbacks
    
    # Inicializar cache de fallbacks
    $script:FallbackCache = @{}
    
    # Cargar patrones de fallos históricos (simulados)
    $script:FailedPatternsDB = Initialize-FailedPatternsDatabase
    
    Write-Verbose "Sistema de fallback inicializado correctamente"
    return $true
}

function Get-IntelligentFallback {
    <#
    .SYNOPSIS
        Sistema principal de fallback inteligente para oficinas sin mapeo directo
    .DESCRIPTION
        Implementa múltiples estrategias de fallback en orden de prioridad:
        1. Análisis de patrones similares exitosos
        2. Mapeo por jerarquía organizacional
        3. Fallback geográfico con análisis de proximidad
        4. Generación de UO sintética con alta precisión
        5. Fallback de emergencia con logging
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$OfficeText,
        
        [Parameter(Mandatory=$false)]
        [array]$AllOUs = @(),
        
        [Parameter(Mandatory=$false)]
        [string]$DetectedLocation = "UNKNOWN",
        
        [Parameter(Mandatory=$false)]
        [hashtable]$ContextInfo = @{}
    )
    
    $FallbackResult = @{
        SelectedOU = $null
        FallbackStrategy = "NONE"
        ConfidenceLevel = "VERY_LOW"
        ReasonCode = "NO_FALLBACK"
        Alternatives = @()
        RequiresManualReview = $true
        GeneratedSuggestions = @()
    }
    
    # Normalizar entrada para procesamiento
    $NormalizedOffice = (Normalize-Text -Text $OfficeText).ToLower()
    
    Write-Verbose "Iniciando fallback inteligente para: '$OfficeText'"
    
    # ESTRATEGIA 1: Análisis de patrones similares exitosos
    $SimilarPatternResult = Find-SimilarSuccessfulPatterns -OfficeText $NormalizedOffice -AllOUs $AllOUs
    if ($SimilarPatternResult.Success) {
        $FallbackResult.SelectedOU = $SimilarPatternResult.RecommendedOU
        $FallbackResult.FallbackStrategy = "SIMILAR_PATTERN"
        $FallbackResult.ConfidenceLevel = $SimilarPatternResult.Confidence
        $FallbackResult.ReasonCode = "PATTERN_MATCH"
        $FallbackResult.RequiresManualReview = $SimilarPatternResult.Confidence -notin @("HIGH", "VERY_HIGH")
        return $FallbackResult
    }
    
    # ESTRATEGIA 2: Mapeo por jerarquía organizacional
    $HierarchicalResult = Get-HierarchicalFallback -OfficeText $NormalizedOffice -AllOUs $AllOUs -DetectedLocation $DetectedLocation
    if ($HierarchicalResult.Success) {
        $FallbackResult.SelectedOU = $HierarchicalResult.RecommendedOU
        $FallbackResult.FallbackStrategy = "HIERARCHICAL"
        $FallbackResult.ConfidenceLevel = $HierarchicalResult.Confidence
        $FallbackResult.ReasonCode = "HIERARCHY_MATCH"
        $FallbackResult.Alternatives = $HierarchicalResult.Alternatives
        $FallbackResult.RequiresManualReview = $HierarchicalResult.Confidence -ne "HIGH"
        return $FallbackResult
    }
    
    # ESTRATEGIA 3: Fallback geográfico inteligente
    if ($DetectedLocation -ne "UNKNOWN") {
        $GeographicResult = Get-GeographicFallback -OfficeText $NormalizedOffice -Location $DetectedLocation -AllOUs $AllOUs
        if ($GeographicResult.Success) {
            $FallbackResult.SelectedOU = $GeographicResult.RecommendedOU
            $FallbackResult.FallbackStrategy = "GEOGRAPHIC"
            $FallbackResult.ConfidenceLevel = $GeographicResult.Confidence
            $FallbackResult.ReasonCode = "GEOGRAPHIC_PROXIMITY"
            $FallbackResult.Alternatives = $GeographicResult.Alternatives
            $FallbackResult.RequiresManualReview = $true  # Siempre requiere revisión
            return $FallbackResult
        }
    }
    
    # ESTRATEGIA 4: Generación de UO sintética (último recurso antes del fallo)
    $SyntheticResult = Generate-SyntheticOUMapping -OfficeText $NormalizedOffice -DetectedLocation $DetectedLocation -ContextInfo $ContextInfo
    if ($SyntheticResult.Success) {
        $FallbackResult.SelectedOU = $SyntheticResult.SyntheticOU
        $FallbackResult.FallbackStrategy = "SYNTHETIC"
        $FallbackResult.ConfidenceLevel = "LOW"
        $FallbackResult.ReasonCode = "SYNTHETIC_GENERATION"
        $FallbackResult.GeneratedSuggestions = $SyntheticResult.Suggestions
        $FallbackResult.RequiresManualReview = $true
        return $FallbackResult
    }
    
    # ESTRATEGIA 5: Fallback de emergencia con logging
    $EmergencyResult = Get-EmergencyFallback -OfficeText $NormalizedOffice -DetectedLocation $DetectedLocation
    $FallbackResult.SelectedOU = $EmergencyResult.DefaultOU
    $FallbackResult.FallbackStrategy = "EMERGENCY"
    $FallbackResult.ConfidenceLevel = "VERY_LOW"
    $FallbackResult.ReasonCode = "EMERGENCY_FALLBACK"
    $FallbackResult.RequiresManualReview = $true
    
    # Registrar patrón fallido para aprendizaje
    Register-FailedPattern -OfficeText $NormalizedOffice -DetectedLocation $DetectedLocation -Timestamp (Get-Date)
    
    return $FallbackResult
}

function Find-SimilarSuccessfulPatterns {
    <#
    .SYNOPSIS
        Busca patrones similares que hayan tenido éxito en el pasado
    #>
    [CmdletBinding()]
    param(
        [string]$OfficeText,
        [array]$AllOUs
    )
    
    $Result = @{
        Success = $false
        RecommendedOU = $null
        Confidence = "VERY_LOW"
        MatchedPatterns = @()
    }
    
    # Base de conocimientos de patrones exitosos (normalmente vendría de BD)
    $SuccessfulPatterns = @{
        # Patrones de juzgados exitosos
        'juzgado.*primera.*instancia.*numero.*(\d+)' = @{
            TargetPattern = 'OU=Juzgado de Primera Instancia.*N.*{0},OU=.*,DC=.*'
            Confidence = "HIGH"
            Context = "numbered-first-instance"
        }
        'juzgado.*instruccion.*numero.*(\d+)' = @{
            TargetPattern = 'OU=Juzgado de Primera Instancia e Instrucción.*N.*{0},OU=.*,DC=.*'
            Confidence = "HIGH"
            Context = "numbered-instruction"
        }
        'juzgado.*penal.*numero.*(\d+)' = @{
            TargetPattern = 'OU=Juzgado de lo Penal.*N.*{0},OU=.*,DC=.*'
            Confidence = "HIGH"
            Context = "numbered-penal"
        }
        'fiscal.*[ae].*de.*(.+)' = @{
            TargetPattern = 'OU=Fiscalía.*,OU=.*{0}.*,DC=.*'
            Confidence = "MEDIUM"
            Context = "fiscalia-location"
        }
        'registro.*civil.*de.*(.+)' = @{
            TargetPattern = 'OU=Registro Civil.*,OU=.*{0}.*,DC=.*'
            Confidence = "MEDIUM"
            Context = "registro-civil-location"
        }
    }
    
    foreach ($Pattern in $SuccessfulPatterns.Keys) {
        if ($OfficeText -match $Pattern) {
            $PatternData = $SuccessfulPatterns[$Pattern]
            $ExtractedValue = if ($Matches[1]) { $Matches[1] } else { "" }
            
            # Buscar UOs que coincidan con el patrón objetivo
            $TargetRegex = $PatternData.TargetPattern -f $ExtractedValue
            
            foreach ($OU in $AllOUs) {
                if ($OU.DistinguishedName -match $TargetRegex) {
                    $Result.Success = $true
                    $Result.RecommendedOU = $OU.DistinguishedName
                    $Result.Confidence = $PatternData.Confidence
                    $Result.MatchedPatterns += @{
                        Pattern = $Pattern
                        ExtractedValue = $ExtractedValue
                        Context = $PatternData.Context
                    }
                    
                    Write-Verbose "Patrón exitoso encontrado: $Pattern -> $($OU.DistinguishedName)"
                    return $Result
                }
            }
        }
    }
    
    return $Result
}

function Get-HierarchicalFallback {
    <#
    .SYNOPSIS
        Implementa fallback basado en jerarquía organizacional
    #>
    [CmdletBinding()]
    param(
        [string]$OfficeText,
        [array]$AllOUs,
        [string]$DetectedLocation
    )
    
    $Result = @{
        Success = $false
        RecommendedOU = $null
        Confidence = "LOW"
        Alternatives = @()
    }
    
    # Extraer tipo de oficina e información contextual
    $OfficeType = Get-OfficeTypeFromText -Text $OfficeText
    $OfficeLevel = Get-OrganizationalLevel -Text $OfficeText
    
    # Definir jerarquía de fallback por tipo
    $HierarchicalFallbacks = @{
        'JUZGADO' = @{
            Priorities = @('PRIMERA_INSTANCIA', 'INSTRUCCION', 'PENAL', 'CIVIL', 'MIXED')
            DefaultOU = 'OU=Juzgados,OU=.*,DC=.*'
            Confidence = "MEDIUM"
        }
        'FISCALIA' = @{
            Priorities = @('FISCALIA_TERRITORIAL', 'FISCALIA_PROVINCIAL')
            DefaultOU = 'OU=Fiscalía.*,OU=.*,DC=.*'
            Confidence = "MEDIUM"
        }
        'TRIBUNAL' = @{
            Priorities = @('AUDIENCIA_PROVINCIAL', 'TRIBUNAL_SUPERIOR')
            DefaultOU = 'OU=Audiencia Provincial,OU=.*,DC=.*'
            Confidence = "HIGH"
        }
        'REGISTRO' = @{
            Priorities = @('REGISTRO_CIVIL')
            DefaultOU = 'OU=Registro Civil,OU=.*,DC=.*'
            Confidence = "HIGH"
        }
        'SERVICIO' = @{
            Priorities = @('SERVICIO_COMUN', 'SERVICIO_TECNICO')
            DefaultOU = 'OU=Servicios,OU=.*,DC=.*'
            Confidence = "LOW"
        }
    }
    
    if ($HierarchicalFallbacks.ContainsKey($OfficeType)) {
        $FallbackData = $HierarchicalFallbacks[$OfficeType]
        
        # Buscar por prioridades
        foreach ($Priority in $FallbackData.Priorities) {
            $CandidateOUs = Find-OUsByTypeAndLocation -AllOUs $AllOUs -Type $Priority -Location $DetectedLocation
            
            if ($CandidateOUs.Count -gt 0) {
                # Seleccionar el más apropiado (por ahora el primero)
                $Result.Success = $true
                $Result.RecommendedOU = $CandidateOUs[0].DistinguishedName
                $Result.Confidence = $FallbackData.Confidence
                
                # Añadir alternativas
                for ($i = 1; $i -lt [Math]::Min($CandidateOUs.Count, 3); $i++) {
                    $Result.Alternatives += $CandidateOUs[$i].DistinguishedName
                }
                
                Write-Verbose "Fallback jerárquico encontrado: $Priority -> $($Result.RecommendedOU)"
                return $Result
            }
        }
        
        # Si no se encuentra nada específico, usar patrón por defecto
        $DefaultPattern = $FallbackData.DefaultOU
        if ($DetectedLocation -ne "UNKNOWN") {
            $DefaultPattern = $DefaultPattern -replace 'OU=\.\*', "OU=*$DetectedLocation*"
        }
        
        foreach ($OU in $AllOUs) {
            if ($OU.DistinguishedName -like $DefaultPattern) {
                $Result.Success = $true
                $Result.RecommendedOU = $OU.DistinguishedName
                $Result.Confidence = "LOW"
                Write-Verbose "Fallback jerárquico por defecto: $($Result.RecommendedOU)"
                return $Result
            }
        }
    }
    
    return $Result
}

function Get-GeographicFallback {
    <#
    .SYNOPSIS
        Implementa fallback basado en proximidad geográfica
    #>
    [CmdletBinding()]
    param(
        [string]$OfficeText,
        [string]$Location,
        [array]$AllOUs
    )
    
    $Result = @{
        Success = $false
        RecommendedOU = $null
        Confidence = "LOW"
        Alternatives = @()
    }
    
    if (-not $script:GeographicFallbacks.ContainsKey($Location)) {
        Write-Verbose "No hay fallbacks geográficos configurados para: $Location"
        return $Result
    }
    
    $LocationFallbacks = $script:GeographicFallbacks[$Location]
    
    # Buscar UOs en la ubicación principal
    $PrimaryOUs = $AllOUs | Where-Object { $_.DistinguishedName -like "*DC=$Location,DC=justicia,DC=junta-andalucia,DC=es" }
    
    if ($PrimaryOUs.Count -gt 0) {
        # Seleccionar UO más genérica en la ubicación
        $GenericOU = $PrimaryOUs | Where-Object { 
            $_.Name -like "*Juzgados*" -or 
            $_.Name -like "*Tribunal*" -or 
            $_.Name -like "*Audiencia*" 
        } | Select-Object -First 1
        
        if ($GenericOU) {
            $Result.Success = $true
            $Result.RecommendedOU = $GenericOU.DistinguishedName
            $Result.Confidence = "MEDIUM"
            Write-Verbose "Fallback geográfico en ubicación principal: $($GenericOU.DistinguishedName)"
            return $Result
        }
    }
    
    # Si no hay UOs primarias, buscar en ubicaciones cercanas
    foreach ($NearbyLocation in $LocationFallbacks.NearbyLocations) {
        $NearbyOUs = $AllOUs | Where-Object { $_.DistinguishedName -like "*DC=$NearbyLocation,DC=justicia,DC=junta-andalucia,DC=es" }
        
        if ($NearbyOUs.Count -gt 0) {
            $Result.Success = $true
            $Result.RecommendedOU = $NearbyOUs[0].DistinguishedName
            $Result.Confidence = "LOW"
            $Result.Alternatives = $NearbyOUs | Select-Object -Skip 1 -First 2 | ForEach-Object { $_.DistinguishedName }
            Write-Verbose "Fallback geográfico en ubicación cercana: $NearbyLocation"
            return $Result
        }
    }
    
    # Fallback final a sede provincial
    if ($LocationFallbacks.ProvincialSeat) {
        $ProvincialOUs = $AllOUs | Where-Object { $_.DistinguishedName -like "*DC=$($LocationFallbacks.ProvincialSeat),DC=justicia,DC=junta-andalucia,DC=es" }
        
        if ($ProvincialOUs.Count -gt 0) {
            $Result.Success = $true
            $Result.RecommendedOU = $ProvincialOUs[0].DistinguishedName
            $Result.Confidence = "VERY_LOW"
            Write-Verbose "Fallback a sede provincial: $($LocationFallbacks.ProvincialSeat)"
            return $Result
        }
    }
    
    return $Result
}

function Generate-SyntheticOUMapping {
    <#
    .SYNOPSIS
        Genera mapeo sintético de UO basado en análisis del texto de la oficina
    #>
    [CmdletBinding()]
    param(
        [string]$OfficeText,
        [string]$DetectedLocation,
        [hashtable]$ContextInfo
    )
    
    $Result = @{
        Success = $false
        SyntheticOU = $null
        Suggestions = @()
    }
    
    # Extraer componentes clave del texto de oficina
    $Components = Extract-OfficeComponents -Text $OfficeText
    
    if ($Components.Count -eq 0) {
        return $Result
    }
    
    # Construir DN sintético
    $SyntheticDN = Build-SyntheticDN -Components $Components -Location $DetectedLocation
    
    if ($SyntheticDN) {
        $Result.Success = $true
        $Result.SyntheticOU = $SyntheticDN
        
        # Generar sugerencias alternativas
        $Result.Suggestions = Generate-AlternativeSuggestions -Components $Components -Location $DetectedLocation
        
        Write-Verbose "UO sintética generada: $SyntheticDN"
    }
    
    return $Result
}

function Get-EmergencyFallback {
    <#
    .SYNOPSIS
        Fallback de emergencia cuando todos los otros métodos fallan
    #>
    [CmdletBinding()]
    param(
        [string]$OfficeText,
        [string]$DetectedLocation
    )
    
    # Mapeo de emergencia por ubicación
    $EmergencyMappings = @{
        'malaga' = 'OU=Usuarios,OU=Malaga-MACJ-Ciudad de la Justicia,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es'
        'sevilla' = 'OU=Usuarios,OU=Sevilla-SEAJ-Audiencia,DC=sevilla,DC=justicia,DC=junta-andalucia,DC=es'
        'cadiz' = 'OU=Usuarios,OU=Cadiz-CAAJ-Audiencia,DC=cadiz,DC=justicia,DC=junta-andalucia,DC=es'
        'cordoba' = 'OU=Usuarios,OU=Cordoba-COAJ-Audiencia,DC=cordoba,DC=justicia,DC=junta-andalucia,DC=es'
        'granada' = 'OU=Usuarios,OU=Granada-GRAA-Audiencia,DC=granada,DC=justicia,DC=junta-andalucia,DC=es'
        'jaen' = 'OU=Usuarios,OU=Jaen-JA4C-San Antonio,DC=jaen,DC=justicia,DC=junta-andalucia,DC=es'
        'almeria' = 'OU=Usuarios,OU=Almeria-ALEJ-Edificio Judicial,DC=almeria,DC=justicia,DC=junta-andalucia,DC=es'
        'huelva' = 'OU=Usuarios,OU=Huelva-HUEJ-Edificio Judicial,DC=huelva,DC=justicia,DC=junta-andalucia,DC=es'
    }
    
    $DefaultOU = if ($DetectedLocation -ne "UNKNOWN" -and $EmergencyMappings.ContainsKey($DetectedLocation)) {
        $EmergencyMappings[$DetectedLocation]
    } else {
        # Fallback absoluto a Sevilla (sede del TSJ)
        $EmergencyMappings['sevilla']
    }
    
    Write-Warning "Utilizando fallback de emergencia para '$OfficeText' -> '$DefaultOU'"
    
    return @{
        DefaultOU = $DefaultOU
        Reason = "EMERGENCY_FALLBACK"
    }
}

# Funciones auxiliares

function Build-OrganizationalHierarchy {
    param([array]$AllOUs)
    
    # Construir jerarquía basada en OUs existentes
    # Esta es una versión simplificada; en producción sería más compleja
    return @{
        'ANDALUCIA' = @{
            'PROVINCIAS' = @('malaga', 'sevilla', 'cadiz', 'cordoba', 'granada', 'jaen', 'almeria', 'huelva')
            'ESTRUCTURA' = @{
                'TRIBUNALES' = @('TSJ', 'AUDIENCIAS_PROVINCIALES')
                'JUZGADOS' = @('PRIMERA_INSTANCIA', 'INSTRUCCION', 'PENAL', 'SOCIAL', 'CONTENCIOSO', 'MERCANTIL')
                'SERVICIOS' = @('FISCALIA', 'REGISTRO_CIVIL', 'IML', 'SERVICIOS_COMUNES')
            }
        }
    }
}

function Initialize-GeographicFallbacks {
    return @{
        'malaga' = @{
            NearbyLocations = @('granada', 'cordoba', 'cadiz')
            ProvincialSeat = 'malaga'
            Priority = 1
        }
        'sevilla' = @{
            NearbyLocations = @('cadiz', 'cordoba', 'huelva')
            ProvincialSeat = 'sevilla'
            Priority = 1
        }
        'cadiz' = @{
            NearbyLocations = @('sevilla', 'malaga', 'huelva')
            ProvincialSeat = 'cadiz'
            Priority = 2
        }
        'cordoba' = @{
            NearbyLocations = @('sevilla', 'malaga', 'jaen', 'granada')
            ProvincialSeat = 'cordoba'
            Priority = 2
        }
        'granada' = @{
            NearbyLocations = @('malaga', 'cordoba', 'jaen', 'almeria')
            ProvincialSeat = 'granada'
            Priority = 2
        }
        'jaen' = @{
            NearbyLocations = @('cordoba', 'granada', 'almeria')
            ProvincialSeat = 'jaen'
            Priority = 3
        }
        'almeria' = @{
            NearbyLocations = @('granada', 'jaen')
            ProvincialSeat = 'almeria'
            Priority = 3
        }
        'huelva' = @{
            NearbyLocations = @('sevilla', 'cadiz')
            ProvincialSeat = 'huelva'
            Priority = 3
        }
    }
}

function Initialize-FailedPatternsDatabase {
    # Base de datos simulada de patrones que han fallado
    # En producción esto vendría de una base de datos real
    return @{
        'PatronesFallidos' = @()
        'UltimaActualizacion' = Get-Date
    }
}

function Get-OfficeTypeFromText {
    param([string]$Text)
    
    $OfficeTypes = @{
        'JUZGADO' = @('juzgado', 'juz', 'tribunal de primera instancia')
        'FISCALIA' = @('fiscalia', 'fiscal', 'ministerio fiscal')
        'TRIBUNAL' = @('tribunal', 'audiencia', 'trib')
        'REGISTRO' = @('registro civil', 'registro', 'reg civil')
        'SERVICIO' = @('servicio', 'instituto', 'iml', 'imlcf')
        'SECRETARIA' = @('secretaria', 'decanato', 'gerencia')
    }
    
    foreach ($Type in $OfficeTypes.Keys) {
        foreach ($Pattern in $OfficeTypes[$Type]) {
            if ($Text -like "*$Pattern*") {
                return $Type
            }
        }
    }
    
    return "UNKNOWN"
}

function Get-OrganizationalLevel {
    param([string]$Text)
    
    if ($Text -like "*superior*" -or $Text -like "*supremo*") {
        return "SUPERIOR"
    } elseif ($Text -like "*provincial*" -or $Text -like "*audiencia*") {
        return "PROVINCIAL"
    } elseif ($Text -like "*central*" -or $Text -like "*territorial*") {
        return "TERRITORIAL"
    } else {
        return "LOCAL"
    }
}

function Find-OUsByTypeAndLocation {
    param([array]$AllOUs, [string]$Type, [string]$Location)
    
    $TypePatterns = @{
        'PRIMERA_INSTANCIA' = @('primera instancia', '1a instancia', 'civil')
        'INSTRUCCION' = @('instruccion', 'investigacion')
        'PENAL' = @('penal', 'criminal')
        'FISCALIA_TERRITORIAL' = @('fiscalia territorial', 'fiscalia de area')
        'FISCALIA_PROVINCIAL' = @('fiscalia provincial')
        'AUDIENCIA_PROVINCIAL' = @('audiencia provincial')
        'REGISTRO_CIVIL' = @('registro civil')
        'SERVICIO_COMUN' = @('servicio comun', 'scnes')
    }
    
    $Results = @()
    
    if ($TypePatterns.ContainsKey($Type)) {
        foreach ($Pattern in $TypePatterns[$Type]) {
            $MatchingOUs = $AllOUs | Where-Object { 
                $_.Name -like "*$Pattern*" -and 
                ($Location -eq "UNKNOWN" -or $_.DistinguishedName -like "*$Location*")
            }
            $Results += $MatchingOUs
        }
    }
    
    return $Results | Sort-Object Name | Get-Unique
}

function Extract-OfficeComponents {
    param([string]$Text)
    
    $Components = @{}
    
    # Extraer tipo
    $Components.Type = Get-OfficeTypeFromText -Text $Text
    
    # Extraer número si existe
    if ($Text -match '\b(\d+)\b') {
        $Components.Number = $Matches[1]
    }
    
    # Extraer especialidad
    $Specialties = @('penal', 'civil', 'social', 'mercantil', 'familia', 'menores', 'violencia', 'instruccion', 'contencioso')
    foreach ($Specialty in $Specialties) {
        if ($Text -like "*$Specialty*") {
            $Components.Specialty = $Specialty
            break
        }
    }
    
    return $Components
}

function Build-SyntheticDN {
    param($Components, [string]$Location)
    
    if (-not $Components.Type -or $Components.Type -eq "UNKNOWN") {
        return $null
    }
    
    # Mapear componentes a estructura DN
    $OUMappings = @{
        'JUZGADO' = 'Juzgado'
        'FISCALIA' = 'Fiscalía'
        'TRIBUNAL' = 'Tribunal'
        'REGISTRO' = 'Registro Civil'
        'SERVICIO' = 'Servicio'
    }
    
    $OUName = $OUMappings[$Components.Type]
    
    if ($Components.Specialty) {
        $OUName += " de $($Components.Specialty)"
    }
    
    if ($Components.Number) {
        $OUName += " Nº $($Components.Number)"
    }
    
    # Construir DN completo
    $LocationPart = if ($Location -ne "UNKNOWN") {
        "DC=$Location,DC=justicia,DC=junta-andalucia,DC=es"
    } else {
        "DC=justicia,DC=junta-andalucia,DC=es"
    }
    
    return "OU=$OUName,OU=Usuarios,OU=Default-Location,$LocationPart"
}

function Generate-AlternativeSuggestions {
    param($Components, [string]$Location)
    
    $Suggestions = @()
    
    # Generar variaciones del nombre base
    if ($Components.Type -eq "JUZGADO") {
        $Suggestions += "OU=Juzgado Mixto,OU=Usuarios,OU=Default-Location,DC=$Location,DC=justicia,DC=junta-andalucia,DC=es"
        $Suggestions += "OU=Juzgado de Primera Instancia,OU=Usuarios,OU=Default-Location,DC=$Location,DC=justicia,DC=junta-andalucia,DC=es"
    }
    
    return $Suggestions
}

function Register-FailedPattern {
    param([string]$OfficeText, [string]$DetectedLocation, [datetime]$Timestamp)
    
    # Registrar patrón fallido para aprendizaje futuro
    $FailedEntry = @{
        Office = $OfficeText
        Location = $DetectedLocation
        Timestamp = $Timestamp
        Attempts = 1
    }
    
    $script:FailedPatternsDB.PatronesFallidos += $FailedEntry
    Write-Verbose "Patrón fallido registrado: $OfficeText ($DetectedLocation)"
}

Export-ModuleMember -Function @(
    'Initialize-FallbackSystem',
    'Get-IntelligentFallback'
)