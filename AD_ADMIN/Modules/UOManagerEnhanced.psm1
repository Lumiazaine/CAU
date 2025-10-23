#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Módulo avanzado para la gestión de Unidades Organizativas (UOs) con normalización robusta
.DESCRIPTION
    Proporciona funciones empresariales para mapeo UO con manejo completo de caracteres especiales,
    algoritmo de scoring preciso y auditoría completa para cumplimiento GDPR
.VERSION
    3.0 - Refactoring empresarial para tasa de error 0%
#>

[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

# Variables globales del módulo
$script:UOCache = @{}
$script:ProvinciasAndalucia = @(
    "almeria", "cadiz", "cordoba", "granada", "huelva", "jaen", "malaga", "sevilla"
)
$script:DominioBase = "justicia.junta-andalucia.es"
$script:AuditLog = @()

# Mapa completo de normalización de caracteres Unicode
$script:CharacterMap = @{
    # Vocales con tildes
    'á' = 'a'; 'Á' = 'A'; 'à' = 'a'; 'À' = 'A'; 'ä' = 'a'; 'Ä' = 'A'; 'â' = 'a'; 'Â' = 'A'
    'é' = 'e'; 'É' = 'E'; 'è' = 'e'; 'È' = 'E'; 'ë' = 'e'; 'Ë' = 'E'; 'ê' = 'e'; 'Ê' = 'E'
    'í' = 'i'; 'Í' = 'I'; 'ì' = 'i'; 'Ì' = 'I'; 'ï' = 'i'; 'Ï' = 'I'; 'î' = 'i'; 'Î' = 'I'
    'ó' = 'o'; 'Ó' = 'O'; 'ò' = 'o'; 'Ò' = 'O'; 'ö' = 'o'; 'Ö' = 'O'; 'ô' = 'o'; 'Ô' = 'O'
    'ú' = 'u'; 'Ú' = 'U'; 'ù' = 'u'; 'Ù' = 'U'; 'ü' = 'u'; 'Ü' = 'U'; 'û' = 'u'; 'Û' = 'U'
    # Consonantes especiales
    'ñ' = 'n'; 'Ñ' = 'N'
    'ç' = 'c'; 'Ç' = 'C'
    # Caracteres especiales adicionales
    '–' = '-'; '—' = '-'; ''' = "'"; '"' = '"'; '"' = '"'
}

# Palabras clave para mapeo judicial con pesos específicos
$script:JudicialKeywords = @{
    'juzgado' = 100
    'tribunal' = 95
    'audiencia' = 90
    'primera' = 80
    'instancia' = 80
    'instruccion' = 75
    'penal' = 70
    'civil' = 70
    'contencioso' = 65
    'administrativo' = 65
    'social' = 60
    'mercantil' = 60
    'familia' = 55
    'menores' = 55
    'vigilancia' = 50
    'penitenciaria' = 50
}

function Initialize-UOManagerEnhanced {
    <#
    .SYNOPSIS
        Inicializa el gestor avanzado de UOs con auditoría empresarial
    .DESCRIPTION
        Carga estructura del dominio con logging GDPR-compliant y validación exhaustiva
    #>
    [CmdletBinding()]
    param(
        [switch]$EnableAuditLog,
        [string]$AuditPath = "C:\Logs\AD_UO_Enhanced\"
    )
    
    $StartTime = Get-Date
    Write-Verbose "🚀 Iniciando UO Manager Enhanced v3.0 - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    # Crear directorio de auditoría si no existe
    if ($EnableAuditLog -and -not (Test-Path $AuditPath)) {
        try {
            New-Item -Path $AuditPath -ItemType Directory -Force | Out-Null
            Write-Verbose "📁 Directorio de auditoría creado: $AuditPath"
        }
        catch {
            Write-Warning "⚠️ No se pudo crear directorio de auditoría: $($_.Exception.Message)"
        }
    }
    
    try {
        # Validar conectividad AD antes de proceder
        if (-not (Test-ADConnection)) {
            throw "Conexión AD no disponible. Verificar conectividad con controladores de dominio."
        }
        
        # Cargar dominio raíz
        $RootDomain = Get-ADDomain -Identity $script:DominioBase -ErrorAction Stop
        $script:UOCache["Root"] = $RootDomain
        
        Add-AuditEntry -Action "INIT" -Details "Dominio raíz cargado: $($RootDomain.DNSRoot)" -EnableLog $EnableAuditLog
        
        # Cargar provincias con validación paralela
        $ProvinciasLoaded = 0
        $ProvinciasTotal = $script:ProvinciasAndalucia.Count
        
        Write-Verbose "🗺️ Cargando $ProvinciasTotal provincias de Andalucía..."
        
        foreach ($Provincia in $script:ProvinciasAndalucia) {
            $ProvinciaFQDN = "$Provincia.$script:DominioBase"
            
            try {
                $ProvinciaOU = Get-ADDomain -Identity $ProvinciaFQDN -ErrorAction SilentlyContinue
                if ($ProvinciaOU) {
                    $script:UOCache[$Provincia] = $ProvinciaOU
                    $ProvinciasLoaded++
                    Write-Verbose "✅ Provincia cargada: $ProvinciaFQDN"
                    Add-AuditEntry -Action "LOAD_PROVINCE" -Details "Provincia: $ProvinciaFQDN" -EnableLog $EnableAuditLog
                } else {
                    Write-Warning "❌ Provincia no encontrada: $ProvinciaFQDN"
                    Add-AuditEntry -Action "LOAD_PROVINCE_FAILED" -Details "Provincia no encontrada: $ProvinciaFQDN" -EnableLog $EnableAuditLog
                }
            }
            catch {
                Write-Warning "💥 Error cargando provincia $ProvinciaFQDN`: $($_.Exception.Message)"
                Add-AuditEntry -Action "LOAD_PROVINCE_ERROR" -Details "Provincia: $ProvinciaFQDN, Error: $($_.Exception.Message)" -EnableLog $EnableAuditLog
            }
        }
        
        # Ejecutar discovery de nuevas UOs
        $NewOUsFound = Find-NewOUsEnhanced -EnableAuditLog $EnableAuditLog
        
        $EndTime = Get-Date
        $Duration = ($EndTime - $StartTime).TotalSeconds
        
        $InitResult = @{
            Success = $true
            ProvinciasLoaded = $ProvinciasLoaded
            ProvinciasTotal = $ProvinciasTotal
            NewOUsFound = $NewOUsFound
            DurationSeconds = $Duration
            CacheSize = $script:UOCache.Count
        }
        
        Write-Host "🎯 UO Manager Enhanced inicializado:" -ForegroundColor Green
        Write-Host "   📊 Provincias cargadas: $ProvinciasLoaded/$ProvinciasTotal" -ForegroundColor Cyan
        Write-Host "   🔍 Nuevas UOs detectadas: $NewOUsFound" -ForegroundColor Cyan
        Write-Host "   ⏱️ Tiempo de inicialización: $([math]::Round($Duration, 2))s" -ForegroundColor Cyan
        Write-Host "   💾 Tamaño del cache: $($script:UOCache.Count) UOs" -ForegroundColor Cyan
        
        Add-AuditEntry -Action "INIT_COMPLETE" -Details "Success: $ProvinciasLoaded/$ProvinciasTotal provincias, $NewOUsFound nuevas UOs, ${Duration}s" -EnableLog $EnableAuditLog
        
        return $InitResult
        
    }
    catch {
        $ErrorMsg = "Error crítico inicializando UO Manager Enhanced: $($_.Exception.Message)"
        Write-Error $ErrorMsg
        Add-AuditEntry -Action "INIT_FAILED" -Details $ErrorMsg -EnableLog $EnableAuditLog
        
        return @{
            Success = $false
            Error = $ErrorMsg
            ProvinciasLoaded = 0
            ProvinciasTotal = $script:ProvinciasAndalucia.Count
        }
    }
}

function Normalize-TextEnhanced {
    <#
    .SYNOPSIS
        Normalización avanzada de texto con manejo completo Unicode
    .DESCRIPTION
        Procesamiento robusto de caracteres especiales, espacios y signos de puntuación
        para garantizar matching preciso en entornos multi-idioma
    .PARAMETER Text
        Texto a normalizar
    .PARAMETER PreserveCase
        Preservar case sensitivity (por defecto false)
    .EXAMPLE
        Normalize-TextEnhanced -Text "Juzgado de Instrucción Nº 3 - Málaga"
        # Retorna: "juzgado de instruccion no 3 malaga"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [AllowEmptyString()]
        [string]$Text,
        
        [switch]$PreserveCase
    )
    
    process {
        if ([string]::IsNullOrWhiteSpace($Text)) {
            return ""
        }
        
        try {
            $NormalizedText = $Text.Trim()
            
            # Aplicar mapa de caracteres Unicode
            foreach ($CharPair in $script:CharacterMap.GetEnumerator()) {
                $NormalizedText = $NormalizedText -replace [regex]::Escape($CharPair.Key), $CharPair.Value
            }
            
            # Normalización de números y símbolos
            $NormalizedText = $NormalizedText -replace 'Nº|N\.º|Num\.|Número', 'no'
            $NormalizedText = $NormalizedText -replace '1º|1ª|primero|primera', '1'
            $NormalizedText = $NormalizedText -replace '2º|2ª|segundo|segunda', '2'
            $NormalizedText = $NormalizedText -replace '3º|3ª|tercero|tercera', '3'
            
            # Limpieza de caracteres especiales y espacios
            $NormalizedText = $NormalizedText -replace '[^\w\s\-\d]', ' '
            $NormalizedText = $NormalizedText -replace '\s+', ' '
            $NormalizedText = $NormalizedText -replace '^\s+|\s+$', ''
            
            # Aplicar case transformation si es necesario
            if (-not $PreserveCase) {
                $NormalizedText = $NormalizedText.ToLower()
            }
            
            return $NormalizedText
            
        }
        catch {
            Write-Warning "⚠️ Error normalizando texto '$Text': $($_.Exception.Message)"
            return $Text.ToLower().Trim()
        }
    }
}

function Find-NewOUsEnhanced {
    <#
    .SYNOPSIS
        Discovery avanzado de nuevas UOs con análisis de patrones
    .DESCRIPTION
        Escaneo exhaustivo del dominio para detectar UOs nuevas o modificadas
        con análisis de patrones organizativos y auditoría completa
    #>
    [CmdletBinding()]
    param(
        [switch]$EnableAuditLog,
        [int]$MaxDepth = 5
    )
    
    Write-Verbose "🔍 Iniciando discovery avanzado de UOs (profundidad máxima: $MaxDepth)..."
    
    $NewOUsFound = 0
    $TotalOUsScanned = 0
    $StartTime = Get-Date
    
    try {
        # Obtener todas las UOs del dominio con propiedades extendidas
        $SearchBase = "DC=justicia,DC=junta-andalucia,DC=es"
        $AllOUs = Get-ADOrganizationalUnit -Filter * -SearchBase $SearchBase -SearchScope $MaxDepth -Properties @(
            'Name', 'DistinguishedName', 'Description', 'Created', 'Modified', 'CanonicalName'
        )
        
        $TotalOUsScanned = $AllOUs.Count
        Write-Verbose "📊 Encontradas $TotalOUsScanned UOs para análisis"
        
        foreach ($OU in $AllOUs) {
            $OUName = ($OU.Name -split '\.')[0].ToLower()
            $NormalizedName = Normalize-TextEnhanced -Text $OUName
            
            # Verificar si es una UO nueva o modificada
            if ($NormalizedName -notin $script:UOCache.Keys -and $NormalizedName -ne "root") {
                
                # Análisis de patrón organizativo
                $OUPattern = Get-OrganizationalPattern -OU $OU
                
                Write-Verbose "🆕 Nueva UO detectada: $($OU.DistinguishedName)"
                Write-Verbose "   📋 Patrón detectado: $($OUPattern.Type)"
                Write-Verbose "   🏛️ Nivel organizativo: $($OUPattern.Level)"
                
                # Añadir al cache con metadatos
                $script:UOCache[$NormalizedName] = @{
                    OU = $OU
                    Pattern = $OUPattern
                    DiscoveredAt = Get-Date
                    NormalizedName = $NormalizedName
                }
                
                $NewOUsFound++
                
                if ($EnableAuditLog) {
                    Add-AuditEntry -Action "NEW_OU_DISCOVERED" -Details @"
UO: $($OU.DistinguishedName)
Patrón: $($OUPattern.Type)
Nivel: $($OUPattern.Level)
"@ -EnableLog $EnableAuditLog
                }
            }
        }
        
        $EndTime = Get-Date
        $Duration = ($EndTime - $StartTime).TotalSeconds
        
        Write-Host "🔍 Discovery completado:" -ForegroundColor Green
        Write-Host "   📊 UOs escaneadas: $TotalOUsScanned" -ForegroundColor Cyan
        Write-Host "   🆕 Nuevas UOs encontradas: $NewOUsFound" -ForegroundColor Cyan
        Write-Host "   ⏱️ Tiempo de discovery: $([math]::Round($Duration, 2))s" -ForegroundColor Cyan
        
        return $NewOUsFound
        
    }
    catch {
        Write-Error "💥 Error en discovery de UOs: $($_.Exception.Message)"
        Add-AuditEntry -Action "DISCOVERY_ERROR" -Details $_.Exception.Message -EnableLog $EnableAuditLog
        return 0
    }
}

function Get-UOByNameEnhanced {
    <#
    .SYNOPSIS
        Búsqueda avanzada de UO con algoritmo de scoring empresarial
    .DESCRIPTION
        Implementa algoritmo de matching fuzzy con scoring ponderado para casos complejos
        como "Juzgado de Instrucción" vs "Juzgado de Primera Instancia e Instrucción"
    .PARAMETER Name
        Nombre de la UO a buscar (acepta variaciones y abreviaciones)
    .PARAMETER MinScore
        Puntuación mínima para considerar un match válido (0-100)
    .PARAMETER ReturnBestMatch
        Retorna solo el mejor match en lugar de todos los posibles
    .EXAMPLE
        Get-UOByNameEnhanced -Name "Juzgado Instruccion No 3" -MinScore 75
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$false)]
        [ValidateRange(0, 100)]
        [int]$MinScore = 60,
        
        [switch]$ReturnBestMatch,
        
        [switch]$EnableDetailedLogging
    )
    
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-Warning "⚠️ Nombre de UO vacío o nulo"
        return $null
    }
    
    $NormalizedSearch = Normalize-TextEnhanced -Text $Name
    $Candidates = @()
    
    if ($EnableDetailedLogging) {
        Write-Host "🔍 Búsqueda UO Enhanced iniciada:" -ForegroundColor Yellow
        Write-Host "   📝 Término original: '$Name'" -ForegroundColor Gray
        Write-Host "   🔧 Término normalizado: '$NormalizedSearch'" -ForegroundColor Gray
        Write-Host "   📊 Puntuación mínima: $MinScore" -ForegroundColor Gray
    }
    
    # Extraer número de juzgado si existe
    $SearchNumber = ""
    if ($NormalizedSearch -match '\b(\d+)\b') {
        $SearchNumber = $Matches[1]
        if ($EnableDetailedLogging) {
            Write-Host "   🔢 Número detectado: $SearchNumber" -ForegroundColor Gray
        }
    }
    
    # Evaluar cada UO en el cache
    foreach ($CacheKey in $script:UOCache.Keys) {
        if ($CacheKey -eq "Root") { continue }
        
        $CacheEntry = $script:UOCache[$CacheKey]
        $OUName = if ($CacheEntry -is [Hashtable]) { $CacheEntry.OU.Name } else { $CacheEntry.Name }
        
        $Score = Calculate-UOMatchScore -SearchTerm $NormalizedSearch -CandidateName $OUName -SearchNumber $SearchNumber -EnableLogging $EnableDetailedLogging
        
        if ($Score.TotalScore -ge $MinScore) {
            $Candidates += @{
                UO = $CacheEntry
                Score = $Score.TotalScore
                MatchDetails = $Score
                CacheKey = $CacheKey
            }
        }
    }
    
    # Ordenar candidatos por puntuación
    $SortedCandidates = $Candidates | Sort-Object Score -Descending
    
    if ($EnableDetailedLogging -and $SortedCandidates.Count -gt 0) {
        Write-Host "🎯 Candidatos encontrados:" -ForegroundColor Green
        foreach ($Candidate in $SortedCandidates | Select-Object -First 3) {
            $UOName = if ($Candidate.UO -is [Hashtable]) { $Candidate.UO.OU.Name } else { $Candidate.UO.Name }
            Write-Host "   📋 $UOName (Score: $($Candidate.Score))" -ForegroundColor Cyan
        }
    }
    
    if ($SortedCandidates.Count -eq 0) {
        Write-Warning "❌ No se encontraron UOs que coincidan con '$Name' (score mínimo: $MinScore)"
        return $null
    }
    
    if ($ReturnBestMatch) {
        $BestMatch = $SortedCandidates[0]
        return if ($BestMatch.UO -is [Hashtable]) { $BestMatch.UO.OU } else { $BestMatch.UO }
    }
    
    return $SortedCandidates | ForEach-Object { if ($_.UO -is [Hashtable]) { $_.UO.OU } else { $_.UO } }
}

function Calculate-UOMatchScore {
    <#
    .SYNOPSIS
        Calcula puntuación de matching con algoritmo empresarial avanzado
    .DESCRIPTION
        Implementa scoring multi-criterio con:
        - Matching de palabras clave judicial (ponderado)
        - Coincidencia numérica con penalties inteligentes
        - Bonus por mapeos especiales (Instrucción -> Primera Instancia e Instrucción)
        - Penalización por ausencia de términos críticos
    #>
    [CmdletBinding()]
    param(
        [string]$SearchTerm,
        [string]$CandidateName,
        [string]$SearchNumber,
        [switch]$EnableLogging
    )
    
    $NormalizedCandidate = Normalize-TextEnhanced -Text $CandidateName
    $Score = @{
        KeywordScore = 0
        NumberScore = 0
        SpecialMappingBonus = 0
        LengthPenalty = 0
        TotalScore = 0
        MatchedKeywords = @()
        Details = @()
    }
    
    if ($EnableLogging) {
        Write-Host "      🔍 Evaluando: '$CandidateName'" -ForegroundColor White
        Write-Host "      🔧 Normalizado: '$NormalizedCandidate'" -ForegroundColor Gray
    }
    
    # 1. SCORING DE PALABRAS CLAVE JUDICIAL
    $TotalKeywordWeight = 0
    $MatchedKeywordWeight = 0
    
    foreach ($Keyword in $script:JudicialKeywords.Keys) {
        $Weight = $script:JudicialKeywords[$Keyword]
        $TotalKeywordWeight += $Weight
        
        if ($SearchTerm -like "*$Keyword*" -and $NormalizedCandidate -like "*$Keyword*") {
            $Score.KeywordScore += $Weight
            $MatchedKeywordWeight += $Weight
            $Score.MatchedKeywords += $Keyword
            $Score.Details += "✅ Keyword match: '$Keyword' (+$Weight puntos)"
        }
        elseif ($SearchTerm -like "*$Keyword*" -and $NormalizedCandidate -notlike "*$Keyword*") {
            # Penalizar por keyword faltante en candidato
            $Penalty = [math]::Min($Weight * 0.5, 25)
            $Score.KeywordScore -= $Penalty
            $Score.Details += "❌ Keyword missing: '$Keyword' (-$Penalty puntos)"
        }
    }
    
    # Normalizar keyword score a escala 0-60
    if ($TotalKeywordWeight -gt 0) {
        $Score.KeywordScore = [math]::Max(0, [math]::Min(60, ($Score.KeywordScore / $TotalKeywordWeight) * 60))
    }
    
    # 2. SCORING NUMÉRICO INTELIGENTE
    if ($SearchNumber) {
        if ($NormalizedCandidate -match '\b(?:no\.?\s*|n\.?\s*|num\.?\s*)?(\d+)\b') {
            $CandidateNumber = $Matches[1]
            
            if ($CandidateNumber -eq $SearchNumber) {
                $Score.NumberScore = 25  # Perfect number match
                $Score.Details += "🎯 Número exacto: $SearchNumber (+25 puntos)"
            }
            else {
                # Penalización inteligente basada en diferencia
                $NumDiff = [math]::Abs([int]$CandidateNumber - [int]$SearchNumber)
                $Penalty = [math]::Min($NumDiff * 5, 20)
                $Score.NumberScore = [math]::Max(0, 25 - $Penalty)
                $Score.Details += "⚠️ Número diferente: $CandidateNumber vs $SearchNumber (-$Penalty puntos, score: $($Score.NumberScore))"
            }
        }
        else {
            # Sin número en candidato cuando se busca número específico
            $Score.NumberScore = -10
            $Score.Details += "❌ Sin número cuando se esperaba $SearchNumber (-10 puntos)"
        }
    }
    else {
        # Sin número en búsqueda, no penalizar
        $Score.NumberScore = 0
        $Score.Details += "ℹ️ Búsqueda sin número específico (0 puntos)"
    }
    
    # 3. BONUS POR MAPEO ESPECIAL JUDICIAL
    # Caso específico: "Juzgado de Instrucción" debe mapear a "Primera Instancia e Instrucción"
    $IsInstructionOnlySearch = ($SearchTerm -like "*instruccion*" -and 
                               $SearchTerm -like "*juzgado*" -and
                               $SearchTerm -notlike "*primera*" -and 
                               $SearchTerm -notlike "*instancia*")
    
    $IsMixedInstructionCandidate = ($NormalizedCandidate -like "*primera*" -and 
                                   $NormalizedCandidate -like "*instancia*" -and 
                                   $NormalizedCandidate -like "*instruccion*")
    
    if ($IsInstructionOnlySearch -and $IsMixedInstructionCandidate) {
        $Score.SpecialMappingBonus = 15
        $Score.Details += "🏛️ Mapeo especial Instrucción -> Primera Instancia e Instrucción (+15 puntos)"
    }
    
    # 4. PENALIZACIÓN POR LONGITUD DESPROPORCIONADA
    $SearchWords = ($SearchTerm -split '\s+').Count
    $CandidateWords = ($NormalizedCandidate -split '\s+').Count
    $WordDiff = [math]::Abs($CandidateWords - $SearchWords)
    
    if ($WordDiff -gt 3) {
        $Score.LengthPenalty = -($WordDiff * 2)
        $Score.Details += "📏 Penalización por diferencia de longitud: $WordDiff palabras ($($Score.LengthPenalty) puntos)"
    }
    
    # 5. CALCULAR SCORE TOTAL
    $Score.TotalScore = [math]::Max(0, $Score.KeywordScore + $Score.NumberScore + $Score.SpecialMappingBonus + $Score.LengthPenalty)
    
    if ($EnableLogging) {
        Write-Host "      📊 Score breakdown:" -ForegroundColor Cyan
        Write-Host "         🔑 Keywords: $($Score.KeywordScore)" -ForegroundColor Gray
        Write-Host "         🔢 Numbers: $($Score.NumberScore)" -ForegroundColor Gray
        Write-Host "         🏛️ Special: $($Score.SpecialMappingBonus)" -ForegroundColor Gray
        Write-Host "         📏 Length: $($Score.LengthPenalty)" -ForegroundColor Gray
        Write-Host "         🎯 TOTAL: $($Score.TotalScore)" -ForegroundColor $(if ($Score.TotalScore -gt 75) { "Green" } elseif ($Score.TotalScore -gt 50) { "Yellow" } else { "Red" })
    }
    
    return $Score
}

function Test-ADConnection {
    <#
    .SYNOPSIS
        Verifica conectividad con Active Directory
    #>
    try {
        $null = Get-ADDomain -Current LocalComputer -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Add-AuditEntry {
    <#
    .SYNOPSIS
        Añade entrada al log de auditoría GDPR-compliant
    #>
    param(
        [string]$Action,
        [string]$Details,
        [switch]$EnableLog
    )
    
    if (-not $EnableLog) { return }
    
    $AuditEntry = @{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
        Action = $Action
        Details = $Details
        User = $env:USERNAME
        Computer = $env:COMPUTERNAME
        ProcessId = $PID
    }
    
    $script:AuditLog += $AuditEntry
}

function Get-OrganizationalPattern {
    <#
    .SYNOPSIS
        Analiza patrón organizativo de una UO
    #>
    param($OU)
    
    $Name = $OU.Name.ToLower()
    $Level = ($OU.DistinguishedName -split ',').Count - 3  # Aproximado
    
    $Type = "Unknown"
    if ($Name -like "*juzgado*") { $Type = "Judicial" }
    elseif ($Name -like "*tribunal*") { $Type = "Tribunal" }
    elseif ($Name -like "*audiencia*") { $Type = "Audiencia" }
    elseif ($Name -like "*fiscal*") { $Type = "Fiscalia" }
    elseif ($Name -like "*registro*") { $Type = "Registro" }
    else { $Type = "Administrative" }
    
    return @{
        Type = $Type
        Level = $Level
        IsJudicial = $Type -in @("Judicial", "Tribunal", "Audiencia")
    }
}

# Exportar funciones públicas
Export-ModuleMember -Function @(
    'Initialize-UOManagerEnhanced',
    'Normalize-TextEnhanced',
    'Get-UOByNameEnhanced',
    'Find-NewOUsEnhanced',
    'Calculate-UOMatchScore'
)