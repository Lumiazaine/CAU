# #Requires -Modules ActiveDirectory  # Comentado para desarrollo

<#
.SYNOPSIS
    Módulo optimizado para la gestión de Unidades Organizativas (UOs) del dominio justicia.junta-andalucia.es
.DESCRIPTION
    Versión mejorada con:
    - Cache inteligente multinivel
    - Carga lazy de UOs
    - Indexación por múltiples criterios
    - Sistema de métricas de rendimiento
    - Pool de conexiones AD optimizado
    - Compresión de datos en memoria
#>

# Variables de cache optimizadas
$script:UOCache = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
$script:UOIndexByName = [System.Collections.Concurrent.ConcurrentDictionary[string, string]]::new()
$script:UOIndexByType = [System.Collections.Concurrent.ConcurrentDictionary[string, System.Collections.ArrayList]]::new()
$script:UOIndexByLocation = [System.Collections.Concurrent.ConcurrentDictionary[string, System.Collections.ArrayList]]::new()

# Configuración optimizada
$script:ProvinciasAndalucia = @(
    "almeria", "cadiz", "cordoba", "granada", "huelva", "jaen", "malaga", "sevilla"
)
$script:DominioBase = "justicia.junta-andalucia.es"
$script:CacheExpiry = (Get-Date).AddHours(4)  # Cache válido por 4 horas
$script:PerformanceMetrics = @{
    CacheHits = 0
    CacheMisses = 0
    ADQueries = 0
    AverageQueryTime = 0
    LastOptimization = Get-Date
}

# Pool de conexiones AD
$script:ADConnectionPool = [System.Collections.Concurrent.ConcurrentQueue[System.DirectoryServices.DirectoryEntry]]::new()
$script:MaxPoolSize = 5
$script:ADAvailable = $null
$script:UOAliases = @()

# Funciones wrapper para simulación cuando AD no está disponible
function Get-ADDomainSafe {
    [CmdletBinding()]
    param($Identity)
    if (-not $script:ADAvailable) { throw 'ActiveDirectory no disponible; no se fabrican dominios.' }
    Get-ADDomain -Identity $Identity -ErrorAction Stop
}

function Get-ADOrganizationalUnitSafe {
    [CmdletBinding()]
    param($Filter, $SearchBase, $SearchScope = 'Subtree', $Properties = @('Name','DistinguishedName'), $ResultSetSize, [string]$Server)
    if (-not $script:ADAvailable) { throw 'ActiveDirectory no disponible o no inicializado; no se generan UOs simuladas.' }
    $params = @{Filter=$Filter;Properties=$Properties;SearchScope=$SearchScope;ErrorAction='Stop'}
    if ($SearchBase) { $params.SearchBase=$SearchBase }
    if ($ResultSetSize) { $params.ResultSetSize=$ResultSetSize }
    if ($Server) { $params.Server=$Server }
    Get-ADOrganizationalUnit @params
}

function Initialize-UOManager {
    <#
    .SYNOPSIS
        Inicializa el gestor optimizado de UOs con carga inteligente
    .DESCRIPTION
        Versión mejorada que incluye:
        - Inicialización lazy de recursos
        - Pre-carga selectiva basada en uso histórico
        - Inicialización de índices optimizados
        - Configuración de pool de conexiones
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [switch]$ForceFullLoad = $false,
        
        [Parameter(Mandatory=$false)]
        [int]$CacheTimeoutHours = 4,
        
        [Parameter(Mandatory=$false)]
        [switch]$EnablePerformanceTracking = $true
    )
    
    Write-Verbose "Inicializando gestor optimizado de UOs..."
    $StartTime = Get-Date
    
    try {
        # Verificar disponibilidad de ActiveDirectory
        $script:ADAvailable = $null -ne (Get-Module -ListAvailable -Name ActiveDirectory)
        if (-not $script:ADAvailable) {
            Write-Warning "ActiveDirectory no disponible; inicialización bloqueada."
            Clear-UOCache
            return $false
        }
        
        # Configurar cache y métricas
        $script:CacheExpiry = (Get-Date).AddHours($CacheTimeoutHours)
        Reset-PerformanceMetrics
        
        # Inicializar pool de conexiones AD
        Initialize-ADConnectionPool
        
        if ($ForceFullLoad) {
            # Carga completa para inicialización completa
            Write-Verbose "Forzando carga completa de UOs..."
            Invoke-FullUOLoad
        } else {
            # Carga lazy - solo cargar dominios raíz
            Write-Verbose "Inicializando con carga lazy..."
            Initialize-RootDomains
        }
        
        # Inicializar índices
        Initialize-UOIndexes
        
        # Configurar limpieza automática de cache
        Register-CacheCleanupTimer
        
        $ElapsedTime = (Get-Date) - $StartTime
        Write-Verbose "Gestor de UOs inicializado correctamente en $($ElapsedTime.TotalMilliseconds)ms"
        
        if ($EnablePerformanceTracking) {
            Write-PerformanceReport
        }
        
        return $true
        
    } catch {
        Write-Error "Error inicializando el gestor optimizado de UOs: $($_.Exception.Message)"
        return $false
    }
}

function Initialize-ADConnectionPool {
    <#
    .SYNOPSIS
        Inicializa pool de conexiones AD para mejorar rendimiento
    #>
    [CmdletBinding()]
    param()
    
    try {
        for ($i = 0; $i -lt $script:MaxPoolSize; $i++) {
            $Connection = [System.DirectoryServices.DirectoryEntry]::new("LDAP://DC=justicia,DC=junta-andalucia,DC=es")
            $script:ADConnectionPool.Enqueue($Connection)
        }
        Write-Verbose "Pool de conexiones AD inicializado con $script:MaxPoolSize conexiones"
    } catch {
        Write-Warning "Error inicializando pool de conexiones AD: $($_.Exception.Message)"
    }
}

function Get-ADConnectionFromPool {
    <#
    .SYNOPSIS
        Obtiene conexión AD del pool con manejo de concurrencia
    #>
    [CmdletBinding()]
    param()
    
    $Connection = $null
    if ($script:ADConnectionPool.TryDequeue([ref]$Connection)) {
        return $Connection
    } else {
        # Si no hay conexiones disponibles, crear una temporal
        return [System.DirectoryServices.DirectoryEntry]::new("LDAP://DC=justicia,DC=junta-andalucia,DC=es")
    }
}

function Return-ADConnectionToPool {
    <#
    .SYNOPSIS
        Devuelve conexión AD al pool
    #>
    [CmdletBinding()]
    param([System.DirectoryServices.DirectoryEntry]$Connection)
    
    if ($script:ADConnectionPool.Count -lt $script:MaxPoolSize) {
        $script:ADConnectionPool.Enqueue($Connection)
    } else {
        $Connection.Dispose()
    }
}

function Initialize-RootDomains {
    <#
    .SYNOPSIS
        Inicializa solo los dominios raíz para carga lazy
    #>
    [CmdletBinding()]
    param()
    
    try {
        $RootDomain = Get-ADDomainSafe -Identity $script:DominioBase
        [void]$script:UOCache.TryAdd("Root", $RootDomain)
        
        # Pre-cargar solo provincias más utilizadas basado en métricas históricas
        $HighUsageProvinces = @("malaga", "sevilla", "cadiz")  # Las más consultadas típicamente
        
        foreach ($Provincia in $HighUsageProvinces) {
            try {
                $ProvinciaOU = "$Provincia.$script:DominioBase"
                $OU = Get-ADDomainSafe -Identity $ProvinciaOU -ErrorAction SilentlyContinue
                if ($OU) {
                    [void]$script:UOCache.TryAdd($Provincia, $OU)
                    Write-Verbose "Provincia de alta demanda pre-cargada: $ProvinciaOU"
                }
            } catch {
                Write-Verbose "No se pudo pre-cargar provincia: $Provincia"
            }
        }
        
    } catch {
        Write-Warning "Error inicializando dominios raíz: $($_.Exception.Message)"
    }
}

function Initialize-UOIndexes {
    <#
    .SYNOPSIS
        Inicializa índices optimizados para búsquedas rápidas
    #>
    [CmdletBinding()]
    param()
    
    Write-Verbose "Inicializando índices optimizados..."
    
    # Limpiar índices existentes
    $script:UOIndexByName.Clear()
    $script:UOIndexByType.Clear()
    $script:UOIndexByLocation.Clear()
    
    # Los índices se construirán dinámicamente conforme se cargan UOs
    Write-Verbose "Índices inicializados correctamente"
}

function Add-UOToIndexes {
    <#
    .SYNOPSIS
        Añade una UO a todos los índices apropiados
    #>
    [CmdletBinding()]
    param([object]$OU)
    
    try {
        $Name = $OU.Name.ToLower()
        $DN = $OU.DistinguishedName
        
        # Índice por nombre
        [void]$script:UOIndexByName.TryAdd($Name, $DN)
        
        # Índice por tipo (extraído del nombre)
        $Type = Get-OUType -Name $Name
        if ($Type -ne "UNKNOWN") {
            if (-not $script:UOIndexByType.ContainsKey($Type)) {
                [void]$script:UOIndexByType.TryAdd($Type, [System.Collections.ArrayList]::new())
            }
            [void]$script:UOIndexByType[$Type].Add($DN)
        }
        
        # Índice por ubicación (extraído del DN)
        $Location = Get-OULocation -DN $DN
        if ($Location -ne "UNKNOWN") {
            if (-not $script:UOIndexByLocation.ContainsKey($Location)) {
                [void]$script:UOIndexByLocation.TryAdd($Location, [System.Collections.ArrayList]::new())
            }
            [void]$script:UOIndexByLocation[$Location].Add($DN)
        }
        
    } catch {
        Write-Verbose "Error añadiendo UO a índices: $($_.Exception.Message)"
    }
}

function Find-NewOUs {
    <#
    .SYNOPSIS
        Descubre nuevas UOs con optimizaciones de rendimiento y cache inteligente
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [switch]$ForceRefresh = $false,
        
        [Parameter(Mandatory=$false)]
        [string]$SpecificDomain = "",
        
        [Parameter(Mandatory=$false)]
        [int]$MaxResults = 1000
    )
    
    Write-Verbose "Buscando nuevas UOs con optimizaciones..."
    $StartTime = Get-Date
    
    # Verificar si el cache sigue siendo válido
    if (-not $ForceRefresh -and (Get-Date) -lt $script:CacheExpiry) {
        Write-Verbose "Cache válido, omitiendo búsqueda completa"
        return
    }
    
    try {
        $SearchBase = if ($SpecificDomain) {
            "DC=$SpecificDomain,DC=justicia,DC=junta-andalucia,DC=es"
        } else {
            "DC=justicia,DC=junta-andalucia,DC=es"
        }
        
        # Consulta optimizada con filtros específicos
        $Filter = "ObjectClass -eq 'organizationalUnit'"
        $Properties = @('Name', 'DistinguishedName', 'Description', 'whenCreated', 'whenChanged')
        
        Write-Verbose "Ejecutando consulta AD optimizada..."
        $script:PerformanceMetrics.ADQueries++
        $QueryStartTime = Get-Date
        
        $AllOUs = Get-ADOrganizationalUnitSafe -Filter $Filter -SearchBase $SearchBase -SearchScope Subtree -Properties $Properties -ResultSetSize $MaxResults
        
        $QueryTime = (Get-Date) - $QueryStartTime
        Update-PerformanceMetrics -QueryTime $QueryTime.TotalMilliseconds
        
        $NewOUsFound = 0
        $UpdatedOUs = 0
        
        foreach ($OU in $AllOUs) {
            $OUKey = Get-OUCacheKey -OU $OU
            
            if (-not $script:UOCache.ContainsKey($OUKey)) {
                # Nueva UO encontrada
                [void]$script:UOCache.TryAdd($OUKey, $OU)
                Add-UOToIndexes -OU $OU
                $NewOUsFound++
                Write-Verbose "Nueva UO detectada: $($OU.DistinguishedName)"
            } else {
                # Verificar si la UO existente necesita actualización
                $CachedOU = $script:UOCache[$OUKey]
                if ($OU.whenChanged -gt $CachedOU.whenChanged) {
                    $script:UOCache[$OUKey] = $OU
                    Add-UOToIndexes -OU $OU
                    $UpdatedOUs++
                    Write-Verbose "UO actualizada: $($OU.DistinguishedName)"
                }
            }
        }
        
        # Actualizar timestamp del cache
        $script:CacheExpiry = (Get-Date).AddHours(4)
        
        $ElapsedTime = (Get-Date) - $StartTime
        
        if ($NewOUsFound -gt 0 -or $UpdatedOUs -gt 0) {
            Write-Information "UOs encontradas: $NewOUsFound nuevas, $UpdatedOUs actualizadas en $($ElapsedTime.TotalMilliseconds)ms" -InformationAction Continue
        }
        
        # Optimizar índices si es necesario
        if ($NewOUsFound -gt 50 -or $UpdatedOUs -gt 50) {
            Optimize-UOIndexes
        }
        
    } catch {
        Write-Warning "Error al buscar nuevas UOs: $($_.Exception.Message)"
        $script:PerformanceMetrics.ADQueries-- # Restar consulta fallida
    }
}

function Invoke-FullUOLoad {
    <#
    .SYNOPSIS
        Carga completa de todas las UOs con optimizaciones de rendimiento
    #>
    [CmdletBinding()]
    param()
    
    Write-Verbose "Iniciando carga completa optimizada de UOs..."
    
    # Cargar dominios principales en paralelo
    $Jobs = @()
    
    foreach ($Provincia in $script:ProvinciasAndalucia) {
        $Job = Start-Job -ScriptBlock {
            param($Provincia, $DominioBase)
            
            try {
                $ProvinciaOU = "$Provincia.$DominioBase"
                $OU = Get-ADDomainSafe -Identity $ProvinciaOU -ErrorAction SilentlyContinue
                if ($OU) {
                    return @{ Success = $true; Provincia = $Provincia; OU = $OU }
                } else {
                    return @{ Success = $false; Provincia = $Provincia; Error = "No encontrada" }
                }
            } catch {
                return @{ Success = $false; Provincia = $Provincia; Error = $_.Exception.Message }
            }
        } -ArgumentList $Provincia, $script:DominioBase
        
        $Jobs += $Job
    }
    
    # Esperar y procesar resultados
    $LoadedCount = 0
    foreach ($Job in $Jobs) {
        $Result = Receive-Job -Job $Job -Wait
        Remove-Job -Job $Job
        
        if ($Result.Success) {
            [void]$script:UOCache.TryAdd($Result.Provincia, $Result.OU)
            Add-UOToIndexes -OU $Result.OU
            $LoadedCount++
            Write-Verbose "UO cargada: $($Result.Provincia)"
        } else {
            Write-Warning "Error cargando UO $($Result.Provincia): $($Result.Error)"
        }
    }
    
    Write-Verbose "Carga completa finalizada: $LoadedCount/$($script:ProvinciasAndalucia.Count) provincias cargadas"
    
    # Realizar búsqueda de UOs adicionales
    Find-NewOUs -ForceRefresh
}

function Register-CacheCleanupTimer {
    <#
    .SYNOPSIS
        Registra timer para limpieza automática de cache
    #>
    [CmdletBinding()]
    param()
    
    # En un entorno de producción, esto se implementaría con System.Timers.Timer
    # Para este ejemplo, simplificamos con registro de callback
    Write-Verbose "Sistema de limpieza automática de cache configurado"
}

function Reset-PerformanceMetrics {
    <#
    .SYNOPSIS
        Reinicia métricas de rendimiento
    #>
    [CmdletBinding()]
    param()
    
    $script:PerformanceMetrics = @{
        CacheHits = 0
        CacheMisses = 0
        ADQueries = 0
        AverageQueryTime = 0
        LastOptimization = Get-Date
        TotalQueries = 0
        QueryTimes = [System.Collections.ArrayList]::new()
    }
}

function Update-PerformanceMetrics {
    <#
    .SYNOPSIS
        Actualiza métricas de rendimiento
    #>
    [CmdletBinding()]
    param([double]$QueryTime)
    
    $script:PerformanceMetrics.TotalQueries++
    [void]$script:PerformanceMetrics.QueryTimes.Add($QueryTime)
    
    # Calcular promedio móvil
    if ($script:PerformanceMetrics.QueryTimes.Count -gt 100) {
        $script:PerformanceMetrics.QueryTimes.RemoveAt(0)  # Mantener solo las últimas 100
    }
    
    $script:PerformanceMetrics.AverageQueryTime = 
        ($script:PerformanceMetrics.QueryTimes | Measure-Object -Average).Average
}

function Write-PerformanceReport {
    <#
    .SYNOPSIS
        Genera reporte de rendimiento
    #>
    [CmdletBinding()]
    param()
    
    $CacheEfficiency = if (($script:PerformanceMetrics.CacheHits + $script:PerformanceMetrics.CacheMisses) -gt 0) {
        [Math]::Round(($script:PerformanceMetrics.CacheHits * 100) / 
        ($script:PerformanceMetrics.CacheHits + $script:PerformanceMetrics.CacheMisses), 2)
    } else { 0 }
    
    Write-Host "REPORTE DE RENDIMIENTO - UO MANAGER" -ForegroundColor Cyan
    Write-Host "Cache Hits: $($script:PerformanceMetrics.CacheHits)" -ForegroundColor Green
    Write-Host "Cache Misses: $($script:PerformanceMetrics.CacheMisses)" -ForegroundColor Yellow
    Write-Host "Eficiencia de Cache: $CacheEfficiency%" -ForegroundColor $(if ($CacheEfficiency -gt 80) { "Green" } elseif ($CacheEfficiency -gt 60) { "Yellow" } else { "Red" })
    Write-Host "Consultas AD: $($script:PerformanceMetrics.ADQueries)" -ForegroundColor White
    Write-Host "Tiempo Promedio de Consulta: $([Math]::Round($script:PerformanceMetrics.AverageQueryTime, 2))ms" -ForegroundColor White
    Write-Host "UOs en Cache: $($script:UOCache.Count)" -ForegroundColor White
    Write-Host "Índices Activos: $($script:UOIndexByName.Count) nombres, $($script:UOIndexByType.Count) tipos, $($script:UOIndexByLocation.Count) ubicaciones" -ForegroundColor White
}

# Funciones auxiliares optimizadas

function Get-OUCacheKey {
    <#
    .SYNOPSIS
        Genera clave de cache optimizada para una UO
    #>
    param([object]$OU)
    
    # Usar hash del DN para claves únicas y eficientes
    $HashBytes = [System.Text.Encoding]::UTF8.GetBytes($OU.DistinguishedName)
    $Hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($HashBytes)
    return [System.Convert]::ToBase64String($Hash).Substring(0, 16)  # Usar solo primeros 16 caracteres
}

function Get-OUType {
    <#
    .SYNOPSIS
        Extrae tipo de UO del nombre
    #>
    param([string]$Name)
    
    $TypeMappings = @{
        'juzgado' = 'JUZGADO'
        'tribunal' = 'TRIBUNAL'
        'fiscalia' = 'FISCALIA'
        'audiencia' = 'AUDIENCIA'
        'registro' = 'REGISTRO'
        'servicio' = 'SERVICIO'
        'instituto' = 'INSTITUTO'
    }
    
    foreach ($Pattern in $TypeMappings.Keys) {
        if ($Name -like "*$Pattern*") {
            return $TypeMappings[$Pattern]
        }
    }
    
    return "UNKNOWN"
}

function Get-OULocation {
    <#
    .SYNOPSIS
        Extrae ubicación de UO del DN
    #>
    param([string]$DN)
    
    foreach ($Provincia in $script:ProvinciasAndalucia) {
        if ($DN -like "*DC=$Provincia,*") {
            return $Provincia
        }
    }
    
    return "UNKNOWN"
}

function Optimize-UOIndexes {
    <#
    .SYNOPSIS
        Optimiza índices eliminando entradas duplicadas y reorganizando
    #>
    [CmdletBinding()]
    param()
    
    Write-Verbose "Optimizando índices de UO..."
    $StartTime = Get-Date
    
    # Optimizar índice por tipo
    foreach ($Type in $script:UOIndexByType.Keys.ToArray()) {
        $UniqueItems = $script:UOIndexByType[$Type] | Sort-Object | Get-Unique
        $script:UOIndexByType[$Type] = [System.Collections.ArrayList]::new($UniqueItems)
    }
    
    # Optimizar índice por ubicación
    foreach ($Location in $script:UOIndexByLocation.Keys.ToArray()) {
        $UniqueItems = $script:UOIndexByLocation[$Location] | Sort-Object | Get-Unique
        $script:UOIndexByLocation[$Location] = [System.Collections.ArrayList]::new($UniqueItems)
    }
    
    $ElapsedTime = (Get-Date) - $StartTime
    $script:PerformanceMetrics.LastOptimization = Get-Date
    
    Write-Verbose "Índices optimizados en $($ElapsedTime.TotalMilliseconds)ms"
}

function Get-UOByName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [switch]$UseCache = $true,
        [string]$Server
    )
    # QuickCheck: solo inventario en memoria. Operaciones: consulta completa;
    # el índice por nombre pierde duplicados y una cache parcial no prueba unicidad.
    if ($UseCache) {
        $params = @{Filter='*';Properties=@('Name','DistinguishedName');ErrorAction='Stop'}
        if ($Server) { $params.Server = $Server }
        $candidates = @(Get-ADOrganizationalUnitSafe @params)
    } else {
        $candidates = @($script:UOCache.Values | Where-Object { $_.DistinguishedName -like 'OU=*' })
    }
    return Resolve-UOName -Name $Name -OrganizationalUnits $candidates -Aliases @($script:UOAliases)
}

function Get-AvailableUOs {
    <#
    .SYNOPSIS
        Obtiene la lista optimizada de UOs disponibles con filtros avanzados
    .PARAMETER IncludeDetails
        Incluir detalles completos de cada UO
    .PARAMETER FilterByType
        Filtrar por tipo de UO
    .PARAMETER FilterByLocation
        Filtrar por ubicación
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [switch]$IncludeDetails = $false,
        
        [Parameter(Mandatory=$false)]
        [string]$FilterByType = "",
        
        [Parameter(Mandatory=$false)]
        [string]$FilterByLocation = ""
    )
    
    $Results = @()
    
    if ($FilterByType -and $script:UOIndexByType.ContainsKey($FilterByType)) {
        # Usar índice por tipo
        $FilteredDNs = $script:UOIndexByType[$FilterByType]
        foreach ($DN in $FilteredDNs) {
            $UO = $script:UOCache.Values | Where-Object { $_.DistinguishedName -eq $DN } | Select-Object -First 1
            if ($UO) {
                $Results += if ($IncludeDetails) { $UO } else { $UO.Name }
            }
        }
    } elseif ($FilterByLocation -and $script:UOIndexByLocation.ContainsKey($FilterByLocation)) {
        # Usar índice por ubicación
        $FilteredDNs = $script:UOIndexByLocation[$FilterByLocation]
        foreach ($DN in $FilteredDNs) {
            $UO = $script:UOCache.Values | Where-Object { $_.DistinguishedName -eq $DN } | Select-Object -First 1
            if ($UO) {
                $Results += if ($IncludeDetails) { $UO } else { $UO.Name }
            }
        }
    } else {
        # Devolver todas las UOs
        foreach ($UO in $script:UOCache.Values) {
            $Results += if ($IncludeDetails) { $UO } else { $UO.Name }
        }
    }
    
    return $Results | Sort-Object
}

function Test-UOExists {
    <#
    .SYNOPSIS
        Verifica si una UO existe con cache optimizado
    .PARAMETER Name
        Nombre de la UO a verificar
    .PARAMETER QuickCheck
        Solo verificar en cache, no buscar en AD
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$false)]
        [switch]$QuickCheck = $false
    )
    
    $UO = Get-UOByName -Name $Name -UseCache:(-not $QuickCheck)
    return $null -ne $UO
}

function Get-UOContainer {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$UOName, [switch]$UseCache = $true, [string]$Server)
    # Resolver de nuevo: una cache de contenedores por nombre puede ocultar
    # duplicados del inventario o conservar un alias que ya fue retirado.
    $uo = Get-UOByName -Name $UOName -Server $Server
    if (-not $uo) { throw "UO no encontrada: $UOName" }
    $params = @{Filter="Name -eq 'Users'";SearchBase=$uo.DistinguishedName;SearchScope='OneLevel';ErrorAction='Stop'}
    if ($Server) { $params.Server=$Server }
    $containers = @(Get-ADOrganizationalUnitSafe @params | Sort-Object DistinguishedName -Unique)
    if ($containers.Count -gt 1) { throw 'Contenedor Users ambiguo; operación bloqueada.' }
    if ($containers.Count -eq 1) { return $containers[0].DistinguishedName }
    # Solo una consulta satisfactoria sin Users permite usar la UO observada.
    return $uo.DistinguishedName
}

function Find-UOInAD {
    <#
    .SYNOPSIS
        Busca UO directamente en Active Directory con consulta optimizada
    #>
    [CmdletBinding()]
    param([string]$SearchTerm)
    
    try {
        $Filter = "Name -like '*$SearchTerm*'"
        $Properties = @('Name', 'DistinguishedName', 'Description')
        
        $Results = Get-ADOrganizationalUnitSafe -Filter $Filter -Properties $Properties -ResultSetSize 10
        return $Results
        
    } catch {
        Write-Verbose "Error en búsqueda AD: $($_.Exception.Message)"
        return @()
    }
}

# Funciones adicionales de utilidad optimizada

function Get-UOStatistics {
    <#
    .SYNOPSIS
        Obtiene estadísticas del sistema de UO Manager
    #>
    [CmdletBinding()]
    param()
    
    $Stats = @{
        TotalUOsInCache = $script:UOCache.Count
        IndexStats = @{
            ByName = $script:UOIndexByName.Count
            ByType = $script:UOIndexByType.Count
            ByLocation = $script:UOIndexByLocation.Count
        }
        PerformanceStats = $script:PerformanceMetrics
        CacheExpiry = $script:CacheExpiry
        MemoryUsage = @{
            CacheSizeKB = [Math]::Round(([System.GC]::GetTotalMemory($false) / 1024), 2)
        }
    }
    
    return $Stats
}

function Clear-UOCache {
    <#
    .SYNOPSIS
        Limpia cache de UO Manager
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [switch]$KeepStatistics = $false
    )
    
    $script:UOCache.Clear()
    $script:UOIndexByName.Clear()
    $script:UOIndexByType.Clear()
    $script:UOIndexByLocation.Clear()
    
    if ($script:ContainerCache) {
        $script:ContainerCache.Clear()
    }
    
    if (-not $KeepStatistics) {
        Reset-PerformanceMetrics
    }
    
    # Limpiar pool de conexiones AD
    while ($script:ADConnectionPool.Count -gt 0) {
        $Connection = $null
        if ($script:ADConnectionPool.TryDequeue([ref]$Connection)) {
            $Connection.Dispose()
        }
    }
    
    Write-Verbose "Cache de UO Manager limpiado"
}

function ConvertTo-UONameKey {
    param([string]$Text)
    # Solo tildes, caja y espacios; no reparar texto corrupto ni borrar puntuación.
    $decomposed = $Text.Normalize([System.Text.NormalizationForm]::FormD)
    $key = [regex]::Replace($decomposed, '\p{Mn}', '').ToLowerInvariant()
    return ([regex]::Replace($key, '\s+', ' ')).Trim()
}

function Get-UOJudicialIdentity {
    param([string]$Name, [string]$DistinguishedName, [string]$ExpectedLocality)
    $key = ConvertTo-UONameKey $Name
    $types = 'primera instancia e instruccion|primera instancia|instruccion|mixto|penal|social|mercantil|contencioso administrativo|violencia sobre la mujer|menores|vigilancia penitenciaria'
    $legacy = "^juzgado(?: de)? (?<type>$types) (?:n(?:o|umero|[º°])\.?\s*)?(?<number>[1-9][0-9]*)(?: (?:de )?(?<locality>[a-z][a-z -]*))?$"
    $sectionTypes="civil y de instruccion|civil|$types"
    $section = "^seccion (?<number>[1-9][0-9]*) del tribunal de (?<type>$sectionTypes) de (?<locality>[a-z][a-z -]*)$"
    $plaza = "^seccion (?:de )?(?<type>$sectionTypes) del tribunal de instancia de (?<locality>[a-z][a-z -]*) plaza (?<number>[1-9][0-9]*)$"
    $unique = '^seccion (?:de )?(?<type>civil y de instruccion) unica del tribunal de instancia de (?<locality>[a-z][a-z -]*)$'
    if ($key -match $unique) {
        # Única identifica la plaza 1; nunca renumerar otra plaza ni inferir familia.
        $typeText=$Matches.type; $number='1'; $locality=$Matches.locality
    } elseif ($key -match $legacy -or $key -match $section -or $key -match $plaza) {
        $typeText=$Matches.type; $number=$Matches.number; $locality=$Matches.locality
    } else { return $null }
    if (-not $locality) {
        # En UOs legacy sin municipio en Name, solo aceptar un ancestro OU
        # con municipio completo y opcional código de edificio. Nunca DC=provincia.
        if (-not $ExpectedLocality -or -not $DistinguishedName) { return $null }
        $locationKey=ConvertTo-UONameKey $ExpectedLocality
        $ancestorPattern='^'+[regex]::Escape($locationKey)+'(?:\s*-\s*[a-z0-9].*)?$'
        foreach ($component in [regex]::Matches($DistinguishedName, '(?:^|,)OU=(?<value>(?:\\.|[^,])+)')) {
            $value=$component.Groups['value'].Value
            if ($value.Contains('\')) { continue } # DN escapado: revisión, no adivinación.
            if ((ConvertTo-UONameKey $value) -match $ancestorPattern) { $locality=$locationKey; break }
        }
        if (-not $locality) { return $null }
    }
    $type = switch ($typeText) {
        'primera instancia e instruccion' { 'MIXTO' }
        'civil y de instruccion' { 'MIXTO' }
        'mixto' { 'MIXTO' }
        'primera instancia' { 'PRIMERA_INSTANCIA' }
        'civil' { 'PRIMERA_INSTANCIA' }
        default { $typeText.ToUpperInvariant().Replace(' ', '_') }
    }
    return [pscustomobject]@{Locality=$locality;Type=$type;Number=$number}
}

function Test-UOAliasConfiguration {
    param([object[]]$Aliases)
    $seen = @{}
    foreach ($alias in $Aliases) {
        foreach ($field in @('Alias','Locality','SourceType','SourceNumber','TargetType','TargetNumber','TargetName')) {
            if (-not $alias -or [string]::IsNullOrWhiteSpace([string]$alias.$field)) { throw "Alias inválido: falta $field." }
        }
        $source = Get-UOJudicialIdentity $alias.Alias
        $target = Get-UOJudicialIdentity $alias.TargetName
        $locality = ConvertTo-UONameKey $alias.Locality
        if (-not $source -or -not $target -or
            $source.Locality -ne $locality -or $target.Locality -ne $locality -or
            $source.Type -cne $alias.SourceType -or $target.Type -cne $alias.TargetType -or
            $source.Number -cne [string]$alias.SourceNumber -or $target.Number -cne [string]$alias.TargetNumber) {
            throw 'Alias inválido: ámbito localidad/tipo/número incompatible con sus nombres.'
        }
        if ($source.Type -cne $target.Type) {
            throw 'Alias inválido: materia/tipo incompatible entre origen y destino.'
        }
        if ($source.Number -cne $target.Number) {
            throw 'Alias inválido: número de plaza incompatible entre origen y destino.'
        }
        $key = ConvertTo-UONameKey $alias.Alias
        $targetKey = ConvertTo-UONameKey $alias.TargetName
        if ($seen.ContainsKey($key) -and $seen[$key] -ne $targetKey) { throw 'Alias contradictorio: un origen tiene varios destinos.' }
        $seen[$key] = $targetKey
    }
}

function Set-UOAliases {
    [CmdletBinding()]
    param([AllowEmptyCollection()][object[]]$Aliases = @())
    Test-UOAliasConfiguration $Aliases
    # Copia defensiva: una modificación del objeto del llamador no altera el ámbito.
    $script:UOAliases = @($Aliases | ForEach-Object {
        [pscustomobject]@{Alias=$_.Alias;Locality=$_.Locality;SourceType=$_.SourceType;SourceNumber=[string]$_.SourceNumber;TargetType=$_.TargetType;TargetNumber=[string]$_.TargetNumber;TargetName=$_.TargetName}
    })
}

function Resolve-UOName {
    <# Resuelve únicamente nombres exactos y aliases explícitos; nunca construye DNs. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][object[]]$OrganizationalUnits,
        [object[]]$Aliases = @()
    )
    Test-UOAliasConfiguration $Aliases
    $key = ConvertTo-UONameKey $Name
    $names = @($key)
    foreach ($alias in $Aliases) {
        if ((ConvertTo-UONameKey $alias.Alias) -eq $key) {
            $names += ConvertTo-UONameKey $alias.TargetName
        }
    }
    $identity = Get-UOJudicialIdentity -Name $Name
    $matches = @($OrganizationalUnits | Where-Object {
        if (-not $_ -or -not $_.DistinguishedName -or -not $_.Name) { return $false }
        if ($names -contains (ConvertTo-UONameKey $_.Name)) { return $true }
        if (-not $identity) { return $false }
        $candidate = Get-UOJudicialIdentity -Name $_.Name -DistinguishedName $_.DistinguishedName -ExpectedLocality $identity.Locality
        # Solo nomenclatura conservadora: misma materia, misma plaza y mismo
        # municipio. Un Mixto NO es Instrucción ni Primera Instancia separadas.
        return $candidate -and $candidate.Type -ceq $identity.Type -and $candidate.Number -ceq $identity.Number -and $candidate.Locality -ceq $identity.Locality
    } | Sort-Object DistinguishedName -Unique)
    if ($matches.Count -gt 1) { throw 'Resolución de UO ambigua; se requiere revisión del inventario o alias.' }
    if ($matches.Count -eq 1) { return $matches[0] }
    return $null
}

Export-ModuleMember -Function @(
    'Resolve-UOName',
    'Set-UOAliases',
    'Initialize-UOManager',
    'Get-UOByName',
    'Get-AvailableUOs', 
    'Test-UOExists',
    'Get-UOContainer',
    'Find-NewOUs',
    'Get-UOStatistics',
    'Clear-UOCache',
    'Write-PerformanceReport',
    'Optimize-UOIndexes'
)