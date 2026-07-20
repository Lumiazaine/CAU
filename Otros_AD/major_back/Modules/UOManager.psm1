#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Módulo para la gestión de Unidades Organizativas (UOs) del dominio justicia.junta-andalucia.es
.DESCRIPTION
    Proporciona funciones para cargar, detectar y gestionar las UOs del dominio
#>

$script:UOCache = @{}
$script:ProvinciasAndalucia = @(
    "almeria", "cadiz", "cordoba", "granada", "huelva", "jaen", "malaga", "sevilla"
)
$script:DominioBase = "justicia.junta-andalucia.es"

function Initialize-UOManager {
    <#
    .SYNOPSIS
        Inicializa el gestor de UOs y carga la estructura del dominio
    #>
    [CmdletBinding()]
    param()
    
    Write-Verbose "Inicializando gestor de UOs..."
    
    try {
        $RootOU = Get-ADDomain -Identity $script:DominioBase
        $script:UOCache["Root"] = $RootOU
        
        Write-Verbose "Cargando UOs de provincias..."
        foreach ($Provincia in $script:ProvinciasAndalucia) {
            $ProvinciaOU = "$Provincia.$script:DominioBase"
            
            try {
                $OU = Get-ADDomain -Identity $ProvinciaOU -ErrorAction SilentlyContinue
                if ($OU) {
                    $script:UOCache[$Provincia] = $OU
                    Write-Verbose "UO cargada: $ProvinciaOU"
                } else {
                    Write-Warning "UO no encontrada: $ProvinciaOU"
                }
            } catch {
                Write-Warning "Error al cargar UO $ProvinciaOU`: $($_.Exception.Message)"
            }
        }
        
        Find-NewOUs
        
        Write-Verbose "Gestor de UOs inicializado correctamente"
        return $true
        
    } catch {
        Write-Error "Error inicializando el gestor de UOs: $($_.Exception.Message)"
        return $false
    }
}

function Find-NewOUs {
    <#
    .SYNOPSIS
        Descubre nuevas UOs que puedan haberse añadido al dominio
    #>
    [CmdletBinding()]
    param()
    
    Write-Verbose "Buscando nuevas UOs en el dominio..."
    
    try {
        $AllOUs = Get-ADOrganizationalUnit -Filter * -SearchBase "DC=justicia,DC=junta-andalucia,DC=es" -SearchScope Subtree
        
        $NewOUsFound = 0
        foreach ($OU in $AllOUs) {
            $OUName = ($OU.Name -split '\.')[0].ToLower()
            
            if ($OUName -notin $script:UOCache.Keys -and $OUName -ne "root") {
                Write-Verbose "Nueva UO detectada: $($OU.DistinguishedName)"
                $script:UOCache[$OUName] = $OU
                $NewOUsFound++
            }
        }
        
        if ($NewOUsFound -gt 0) {
            Write-Information "Se han detectado $NewOUsFound nuevas UOs" -InformationAction Continue
        }
        
    } catch {
        Write-Warning "Error al buscar nuevas UOs: $($_.Exception.Message)"
    }
}

function Get-UOByName {
    <#
    .SYNOPSIS
        Obtiene una UO por su nombre
    .PARAMETER Name
        Nombre de la UO (provincia o identificador)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    $Name = $Name.ToLower().Trim()
    
    if ($script:UOCache.ContainsKey($Name)) {
        return $script:UOCache[$Name]
    }
    
    foreach ($Key in $script:UOCache.Keys) {
        if ($Key -like "*$Name*" -or $Name -like "*$Key*") {
            return $script:UOCache[$Key]
        }
    }
    
    Write-Warning "UO no encontrada: $Name"
    return $null
}

function Get-AvailableUOs {
    <#
    .SYNOPSIS
        Obtiene la lista de UOs disponibles
    #>
    [CmdletBinding()]
    param()
    
    return $script:UOCache.Keys | Sort-Object
}

function Test-UOExists {
    <#
    .SYNOPSIS
        Verifica si una UO existe
    .PARAMETER Name
        Nombre de la UO a verificar
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    $UO = Get-UOByName -Name $Name
    return $null -ne $UO
}

function Get-UOContainer {
    <#
    .SYNOPSIS
        Obtiene el contenedor padre de usuarios para una UO específica
    .PARAMETER UOName
        Nombre de la UO
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$UOName
    )
    
    $UO = Get-UOByName -Name $UOName
    if (-not $UO) {
        throw "UO no encontrada: $UOName"
    }
    
    try {
        $UsersContainer = Get-ADOrganizationalUnit -Filter "Name -eq 'Users'" -SearchBase $UO.DistinguishedName -SearchScope OneLevel
        
        if ($UsersContainer) {
            return $UsersContainer.DistinguishedName
        } else {
            return $UO.DistinguishedName
        }
        
    } catch {
        Write-Warning "Error al obtener contenedor de usuarios para $UOName`: $($_.Exception.Message)"
        return $UO.DistinguishedName
    }
}

Export-ModuleMember -Function @(
    'Initialize-UOManager',
    'Get-UOByName',
    'Get-AvailableUOs',
    'Test-UOExists',
    'Get-UOContainer',
    'Find-NewOUs'
)