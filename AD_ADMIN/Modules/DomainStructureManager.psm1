#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Módulo para cargar y gestionar la estructura completa de todos los dominios
.DESCRIPTION
    Proporciona funciones para obtener árboles completos de OUs y grupos de todos los dominios
#>

function Get-AllAvailableDomains {
    <#
    .SYNOPSIS
        Obtiene todos los dominios disponibles en el bosque con información detallada
    #>
    [CmdletBinding()]
    param()
    
    $Domains = @()
    
    try {
        # Obtener el bosque actual
        $Forest = Get-ADForest -ErrorAction SilentlyContinue
        
        if ($Forest) {
            Write-Verbose "Bosque detectado: $($Forest.Name)"
            
            # Obtener todos los dominios del bosque
            foreach ($DomainName in $Forest.Domains) {
                try {
                    $Domain = Get-ADDomain -Identity $DomainName -ErrorAction SilentlyContinue
                    if ($Domain) {
                        $Domains += [PSCustomObject]@{
                            Name = $Domain.DNSRoot
                            NetBIOSName = $Domain.NetBIOSName
                            Forest = $Forest.Name
                            DistinguishedName = $Domain.DistinguishedName
                            DomainMode = $Domain.DomainMode
                            Available = $true
                        }
                        Write-Verbose "Dominio agregado: $($Domain.DNSRoot)"
                    }
                } catch {
                    $Domains += [PSCustomObject]@{
                        Name = $DomainName
                        NetBIOSName = "Desconocido"
                        Forest = $Forest.Name
                        DistinguishedName = "Desconocido"
                        DomainMode = "Desconocido"
                        Available = $false
                    }
                    Write-Warning "Dominio no accesible: $DomainName - $($_.Exception.Message)"
                }
            }
        }
    } catch {
        Write-Warning "Error obteniendo información del bosque: $($_.Exception.Message)"
    }
    
    # Si no se pudieron obtener dominios del bosque, intentar con el dominio actual
    if ($Domains.Count -eq 0) {
        try {
            $CurrentDomain = Get-ADDomain -Current LocalComputer -ErrorAction SilentlyContinue
            if ($CurrentDomain) {
                $Domains += [PSCustomObject]@{
                    Name = $CurrentDomain.DNSRoot
                    NetBIOSName = $CurrentDomain.NetBIOSName
                    Forest = "Local"
                    DistinguishedName = $CurrentDomain.DistinguishedName
                    DomainMode = $CurrentDomain.DomainMode
                    Available = $true
                }
                Write-Verbose "Usando dominio actual: $($CurrentDomain.DNSRoot)"
            }
        } catch {
            Write-Warning "Error obteniendo dominio actual: $($_.Exception.Message)"
        }
    }
    
    return $Domains
}

function Get-CompleteDomainStructure {
    <#
    .SYNOPSIS
        Obtiene la estructura completa de OUs y grupos de un dominio
    .PARAMETER Domain
        Nombre del dominio a analizar
    .PARAMETER IncludeGroups
        Incluir información de grupos en cada OU
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Domain,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeGroups
    )
    
    Write-Host "Cargando estructura completa del dominio: $Domain" -ForegroundColor Cyan
    
    try {
        # Obtener el DN raíz del dominio
        $DomainInfo = Get-ADDomain -Identity $Domain -Server $Domain
        $RootDN = $DomainInfo.DistinguishedName
        
        # Obtener todas las OUs del dominio
        Write-Host "  Obteniendo todas las Unidades Organizacionales..." -ForegroundColor Yellow
        $AllOUs = Get-ADOrganizationalUnit -Filter * -Server $Domain -Properties Description, ManagedBy, whenCreated
        
        Write-Host "  Encontradas $($AllOUs.Count) OUs" -ForegroundColor Green
        
        # Crear estructura jerárquica
        $RootStructure = [PSCustomObject]@{
            Name = $Domain
            DistinguishedName = $RootDN
            Type = "Domain"
            Level = 0
            Children = @()
            Groups = @()
            Users = @()
        }
        
        # Procesar cada OU y construir jerarquía
        foreach ($OU in $AllOUs) {
            $OUNode = [PSCustomObject]@{
                Name = $OU.Name
                DistinguishedName = $OU.DistinguishedName
                Description = $OU.Description
                ManagedBy = $OU.ManagedBy
                whenCreated = $OU.whenCreated
                Type = "OrganizationalUnit"
                Level = (($OU.DistinguishedName -split ',OU=').Count - 1)
                Children = @()
                Groups = @()
                Users = @()
            }
            
            # Si se solicita, cargar grupos en esta OU
            if ($IncludeGroups) {
                Write-Progress -Activity "Cargando estructura" -Status "Cargando grupos en $($OU.Name)" -PercentComplete (($AllOUs.IndexOf($OU) / $AllOUs.Count) * 100)
                $OUNode.Groups = Get-GroupsInOU -OU $OU.DistinguishedName -Domain $Domain
            }
            
            Add-ChildToStructure -RootNode $RootStructure -ChildNode $OUNode
        }
        
        Write-Progress -Activity "Cargando estructura" -Completed
        
        return $RootStructure
        
    } catch {
        Write-Error "Error cargando estructura del dominio $Domain`: $($_.Exception.Message)"
        return $null
    }
}

function Add-ChildToStructure {
    <#
    .SYNOPSIS
        Agrega un nodo hijo a la estructura jerárquica correcta
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$RootNode,
        
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$ChildNode
    )
    
    # Encontrar el padre correcto basado en el DN
    $ParentDN = ($ChildNode.DistinguishedName -split ',',2)[1]
    
    if ($ParentDN -eq $RootNode.DistinguishedName) {
        # Es hijo directo del nodo raíz
        $RootNode.Children += $ChildNode
    } else {
        # Buscar el padre en los hijos existentes
        $ParentFound = Find-NodeByDN -Node $RootNode -TargetDN $ParentDN
        if ($ParentFound) {
            $ParentFound.Children += $ChildNode
        } else {
            # Si no se encuentra el padre, agregarlo al raíz (fallback)
            $RootNode.Children += $ChildNode
        }
    }
}

function Find-NodeByDN {
    <#
    .SYNOPSIS
        Busca un nodo en la estructura por su Distinguished Name
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Node,
        
        [Parameter(Mandatory=$true)]
        [string]$TargetDN
    )
    
    if ($Node.DistinguishedName -eq $TargetDN) {
        return $Node
    }
    
    foreach ($Child in $Node.Children) {
        $Found = Find-NodeByDN -Node $Child -TargetDN $TargetDN
        if ($Found) {
            return $Found
        }
    }
    
    return $null
}

function Get-GroupsInOU {
    <#
    .SYNOPSIS
        Obtiene todos los grupos en una OU específica
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$OU,
        
        [Parameter(Mandatory=$true)]
        [string]$Domain
    )
    
    try {
        $Groups = Get-ADGroup -Filter * -SearchBase $OU -SearchScope OneLevel -Server $Domain -Properties Description, GroupCategory, GroupScope, MemberOf, Members
        
        $GroupObjects = @()
        foreach ($Group in $Groups) {
            $GroupObjects += [PSCustomObject]@{
                Name = $Group.Name
                DistinguishedName = $Group.DistinguishedName
                Description = $Group.Description
                GroupCategory = $Group.GroupCategory
                GroupScope = $Group.GroupScope
                MemberCount = $Group.Members.Count
            }
        }
        
        return $GroupObjects
        
    } catch {
        Write-Warning "Error obteniendo grupos en OU $OU`: $($_.Exception.Message)"
        return @()
    }
}

function Get-TargetDomainForOffice {
    <#
    .SYNOPSIS
        Determina el dominio de destino basado en la oficina
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Office
    )
    
    $AllDomains = Get-AllAvailableDomains | Where-Object { $_.Available }
    
    # Mapeo básico de oficinas a dominios
    $OfficeNormalized = $Office.ToLower()
    
    foreach ($Domain in $AllDomains) {
        $DomainName = $Domain.Name.ToLower()
        
        # Buscar coincidencia por nombre de provincia en el dominio
        if ($DomainName -like "*almeria*" -and $OfficeNormalized -like "*almeria*") { return $Domain }
        if ($DomainName -like "*cadiz*" -and $OfficeNormalized -like "*cadiz*") { return $Domain }
        if ($DomainName -like "*cordoba*" -and $OfficeNormalized -like "*cordoba*") { return $Domain }
        if ($DomainName -like "*granada*" -and $OfficeNormalized -like "*granada*") { return $Domain }
        if ($DomainName -like "*huelva*" -and $OfficeNormalized -like "*huelva*") { return $Domain }
        if ($DomainName -like "*jaen*" -and $OfficeNormalized -like "*jaen*") { return $Domain }
        if ($DomainName -like "*malaga*" -and $OfficeNormalized -like "*malaga*") { return $Domain }
        if ($DomainName -like "*sevilla*" -and $OfficeNormalized -like "*sevilla*") { return $Domain }
    }
    
    # Si no hay coincidencia específica, retornar el primer dominio disponible
    return $AllDomains[0]
}

function Show-DomainStructureTree {
    <#
    .SYNOPSIS
        Muestra la estructura del dominio en formato de árbol
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Structure,
        
        [Parameter(Mandatory=$false)]
        [int]$IndentLevel = 0,
        
        [Parameter(Mandatory=$false)]
        [switch]$ShowGroups
    )
    
    $Indent = "  " * $IndentLevel
    
    Write-Host "$Indent$($Structure.Name)" -ForegroundColor White
    
    if ($ShowGroups -and $Structure.Groups.Count -gt 0) {
        Write-Host "$Indent  Grupos ($($Structure.Groups.Count)):" -ForegroundColor Yellow
        foreach ($Group in $Structure.Groups) {
            Write-Host "$Indent    - $($Group.Name) ($($Group.GroupCategory)/$($Group.GroupScope))" -ForegroundColor Gray
        }
    }
    
    foreach ($Child in $Structure.Children) {
        Show-DomainStructureTree -Structure $Child -IndentLevel ($IndentLevel + 1) -ShowGroups:$ShowGroups
    }
}

function Find-OUsByDescription {
    <#
    .SYNOPSIS
        Busca OUs por descripción en todos los dominios
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Description,
        
        [Parameter(Mandatory=$false)]
        [array]$Domains
    )
    
    if (-not $Domains) {
        $Domains = Get-AllAvailableDomains | Where-Object { $_.Available }
    }
    
    $MatchingOUs = @()
    
    foreach ($Domain in $Domains) {
        try {
            Write-Verbose "Buscando OUs con descripción '$Description' en $($Domain.Name)"
            
            $OUs = Get-ADOrganizationalUnit -Filter "Description -like '*$Description*'" -Server $Domain.Name -Properties Description, whenCreated
            
            foreach ($OU in $OUs) {
                $MatchingOUs += [PSCustomObject]@{
                    Name = $OU.Name
                    DistinguishedName = $OU.DistinguishedName
                    Description = $OU.Description
                    Domain = $Domain.Name
                    DomainNetBIOS = $Domain.NetBIOSName
                    Created = $OU.whenCreated
                }
            }
            
        } catch {
            Write-Warning "Error buscando en dominio $($Domain.Name): $($_.Exception.Message)"
        }
    }
    
    return $MatchingOUs
}

Export-ModuleMember -Function @(
    'Get-AllAvailableDomains',
    'Get-CompleteDomainStructure',
    'Get-GroupsInOU',
    'Get-TargetDomainForOffice',
    'Show-DomainStructureTree',
    'Find-OUsByDescription'
)