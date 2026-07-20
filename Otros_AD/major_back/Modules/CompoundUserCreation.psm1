#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Módulo para la gestión de altas compaginadas en Active Directory
.DESCRIPTION
    Añade membresías adicionales a usuarios existentes para compaginar funciones
#>

Import-Module "$PSScriptRoot\UOManager.psm1" -Force
Import-Module "$PSScriptRoot\UserSearch.psm1" -Force

function Add-CompoundUserMembership {
    <#
    .SYNOPSIS
        Añade membresías de grupos para compaginar funciones
    .PARAMETER UserData
        Datos del usuario del CSV
    .PARAMETER WhatIf
        Simulación sin realizar cambios
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$UserData,
        
        [Parameter(Mandatory=$false)]
        [switch]$WhatIf
    )
    
    try {
        Write-Verbose "Iniciando alta compaginada para: $($UserData.UsuarioExistente)"
        
        $ExistingUser = Find-CompoundUser -UserData $UserData
        if (-not $ExistingUser) {
            Write-Warning "Usuario no encontrado para alta compaginada: $($UserData.UsuarioExistente)"
            return $false
        }
        
        Write-Host "Usuario encontrado: $($ExistingUser.DisplayName) ($($ExistingUser.SamAccountName))" -ForegroundColor Green
        
        $CurrentGroups = Get-UserCurrentGroups -User $ExistingUser
        Write-Verbose "Grupos actuales del usuario: $($CurrentGroups.Count)"
        
        $GroupsToAdd = Parse-CompoundGroups -UserData $UserData
        if ($GroupsToAdd.Count -eq 0) {
            Write-Warning "No se especificaron grupos para añadir"
            return $false
        }
        
        $GroupsAdded = 0
        $GroupsSkipped = 0
        
        foreach ($GroupInfo in $GroupsToAdd) {
            if ($PSCmdlet.ShouldProcess($ExistingUser.SamAccountName, "Añadir al grupo $($GroupInfo.Name)")) {
                
                $AlreadyMember = Test-UserGroupMembership -User $ExistingUser -GroupName $GroupInfo.Name
                
                if ($AlreadyMember) {
                    Write-Verbose "Usuario ya es miembro del grupo: $($GroupInfo.Name)"
                    $GroupsSkipped++
                    continue
                }
                
                if (-not $WhatIf) {
                    $Success = Add-UserToCompoundGroup -User $ExistingUser -GroupInfo $GroupInfo
                    if ($Success) {
                        $GroupsAdded++
                        Write-Host "  ✓ Añadido al grupo: $($GroupInfo.Name)" -ForegroundColor Green
                    }
                } else {
                    Write-Host "WHATIF: Se añadiría al usuario al grupo: $($GroupInfo.Name)" -ForegroundColor Yellow
                    $GroupsAdded++
                }
            }
        }
        
        Update-CompoundUserProperties -User $ExistingUser -UserData $UserData -WhatIf:$WhatIf
        
        Write-Host "Alta compaginada completada. Grupos añadidos: $GroupsAdded, Grupos ya existentes: $GroupsSkipped" -ForegroundColor Green
        
        return $true
        
    } catch {
        Write-Error "Error en alta compaginada: $($_.Exception.Message)"
        return $false
    }
}

function Find-CompoundUser {
    <#
    .SYNOPSIS
        Busca el usuario existente para la compaginación
    .PARAMETER UserData
        Datos del usuario del CSV
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$UserData
    )
    
    $SearchCriteria = @{}
    
    if (-not [string]::IsNullOrWhiteSpace($UserData.UsuarioExistente)) {
        $SearchCriteria["samaccountname"] = $UserData.UsuarioExistente
    } elseif (-not [string]::IsNullOrWhiteSpace($UserData.Email)) {
        $SearchCriteria["email"] = $UserData.Email
    } elseif (-not [string]::IsNullOrWhiteSpace($UserData.Nombre) -and -not [string]::IsNullOrWhiteSpace($UserData.Apellidos)) {
        $SearchCriteria["nombre"] = $UserData.Nombre
        $SearchCriteria["apellidos"] = $UserData.Apellidos
    } elseif (-not [string]::IsNullOrWhiteSpace($UserData.Telefono)) {
        $SearchCriteria["telefono"] = $UserData.Telefono
    }
    
    if ($SearchCriteria.Count -eq 0) {
        throw "No se proporcionaron criterios suficientes para encontrar el usuario"
    }
    
    $Users = Find-ADUserByCriteria -SearchCriteria $SearchCriteria -ExactMatch
    
    if ($Users.Count -eq 0) {
        return $null
    } elseif ($Users.Count -eq 1) {
        return $Users[0]
    } else {
        Write-Host "Se encontraron múltiples usuarios coincidentes:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $Users.Count; $i++) {
            Write-Host "[$($i+1)] $($Users[$i].DisplayName) ($($Users[$i].SamAccountName)) - $($Users[$i].mail)" -ForegroundColor Yellow
        }
        
        Write-Warning "Se usará el primer usuario: $($Users[0].SamAccountName)"
        return $Users[0]
    }
}

function Parse-CompoundGroups {
    <#
    .SYNOPSIS
        Analiza y valida los grupos a añadir para la compaginación
    .PARAMETER UserData
        Datos del CSV
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$UserData
    )
    
    $GroupsToAdd = @()
    
    if (-not [string]::IsNullOrWhiteSpace($UserData.GruposCompaginados)) {
        $GroupNames = $UserData.GruposCompaginados -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        
        foreach ($GroupName in $GroupNames) {
            try {
                $Group = Get-ADGroup -Filter "Name -eq '$GroupName'" -Properties Description -ErrorAction Stop
                if ($Group) {
                    $GroupsToAdd += @{
                        Name = $Group.Name
                        DistinguishedName = $Group.DistinguishedName
                        Description = $Group.Description
                        SamAccountName = $Group.SamAccountName
                    }
                } else {
                    Write-Warning "Grupo no encontrado: $GroupName"
                }
            } catch {
                Write-Warning "Error buscando grupo $GroupName`: $($_.Exception.Message)"
            }
        }
    }
    
    if (-not [string]::IsNullOrWhiteSpace($UserData.UOCompaginada)) {
        $CompoundGroups = Get-UOSpecificGroups -UOName $UserData.UOCompaginada
        $GroupsToAdd += $CompoundGroups
    }
    
    return $GroupsToAdd
}

function Get-UOSpecificGroups {
    <#
    .SYNOPSIS
        Obtiene los grupos específicos de una UO para compaginación
    .PARAMETER UOName
        Nombre de la UO
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$UOName
    )
    
    $UOGroups = @()
    
    try {
        $UO = Get-UOByName -Name $UOName
        if ($UO) {
            $SearchBase = $UO.DistinguishedName
            $Groups = Get-ADGroup -Filter * -SearchBase $SearchBase -SearchScope Subtree -Properties Description
            
            foreach ($Group in $Groups) {
                if ($Group.Name -like "*$UOName*" -or $Group.Name -like "*Usuarios*" -or $Group.Name -like "*Acceso*") {
                    $UOGroups += @{
                        Name = $Group.Name
                        DistinguishedName = $Group.DistinguishedName
                        Description = $Group.Description
                        SamAccountName = $Group.SamAccountName
                    }
                }
            }
            
            Write-Verbose "Encontrados $($UOGroups.Count) grupos específicos para la UO: $UOName"
        }
        
    } catch {
        Write-Warning "Error obteniendo grupos de la UO $UOName`: $($_.Exception.Message)"
    }
    
    return $UOGroups
}

function Get-UserCurrentGroups {
    <#
    .SYNOPSIS
        Obtiene los grupos actuales del usuario
    .PARAMETER User
        Usuario de AD
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADUser]$User
    )
    
    try {
        $CurrentGroups = Get-ADPrincipalGroupMembership -Identity $User.SamAccountName
        return $CurrentGroups
    } catch {
        Write-Warning "Error obteniendo grupos actuales del usuario: $($_.Exception.Message)"
        return @()
    }
}

function Test-UserGroupMembership {
    <#
    .SYNOPSIS
        Verifica si el usuario ya es miembro de un grupo
    .PARAMETER User
        Usuario de AD
    .PARAMETER GroupName
        Nombre del grupo
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADUser]$User,
        
        [Parameter(Mandatory=$true)]
        [string]$GroupName
    )
    
    try {
        $IsMember = Get-ADGroupMember -Identity $GroupName | Where-Object { $_.SamAccountName -eq $User.SamAccountName }
        return $null -ne $IsMember
    } catch {
        return $false
    }
}

function Add-UserToCompoundGroup {
    <#
    .SYNOPSIS
        Añade el usuario a un grupo para compaginación
    .PARAMETER User
        Usuario de AD
    .PARAMETER GroupInfo
        Información del grupo
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADUser]$User,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$GroupInfo
    )
    
    try {
        Add-ADGroupMember -Identity $GroupInfo.DistinguishedName -Members $User.DistinguishedName -ErrorAction Stop
        Write-Verbose "Usuario $($User.SamAccountName) añadido al grupo $($GroupInfo.Name)"
        return $true
    } catch {
        Write-Warning "Error añadiendo usuario al grupo $($GroupInfo.Name): $($_.Exception.Message)"
        return $false
    }
}

function Update-CompoundUserProperties {
    <#
    .SYNOPSIS
        Actualiza propiedades del usuario para la compaginación
    .PARAMETER User
        Usuario de AD
    .PARAMETER UserData
        Datos del CSV
    .PARAMETER WhatIf
        Simulación
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADUser]$User,
        
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$UserData,
        
        [Parameter(Mandatory=$false)]
        [switch]$WhatIf
    )
    
    $UpdateParams = @{}
    $UpdateRequired = $false
    
    if (-not [string]::IsNullOrWhiteSpace($UserData.DescripcionCompaginada)) {
        $CurrentDescription = $User.Description
        $NewDescription = if ($CurrentDescription) {
            "$CurrentDescription | Compaginado: $($UserData.DescripcionCompaginada)"
        } else {
            "Compaginado: $($UserData.DescripcionCompaginada)"
        }
        $UpdateParams.Description = $NewDescription
        $UpdateRequired = $true
    }
    
    if (-not [string]::IsNullOrWhiteSpace($UserData.OficinaCompaginada)) {
        $UpdateParams.Office = "$($User.Office); $($UserData.OficinaCompaginada)"
        $UpdateRequired = $true
    }
    
    if ($UpdateRequired) {
        if ($PSCmdlet.ShouldProcess($User.SamAccountName, "Actualizar propiedades de compaginación")) {
            if (-not $WhatIf) {
                Set-ADUser -Identity $User.SamAccountName @UpdateParams
                Write-Verbose "Propiedades de compaginación actualizadas para $($User.SamAccountName)"
            } else {
                Write-Host "WHATIF: Se actualizarían las propiedades de compaginación" -ForegroundColor Yellow
            }
        }
    }
}

function Show-CompoundUserSummary {
    <#
    .SYNOPSIS
        Muestra un resumen del usuario después de la compaginación
    .PARAMETER User
        Usuario de AD
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADUser]$User
    )
    
    Write-Host "`n=== Resumen de Compaginación ===" -ForegroundColor Cyan
    Write-Host "Usuario: $($User.DisplayName) ($($User.SamAccountName))" -ForegroundColor White
    Write-Host "Email: $($User.mail)" -ForegroundColor Gray
    
    $Groups = Get-UserCurrentGroups -User $User
    Write-Host "Grupos totales: $($Groups.Count)" -ForegroundColor White
    
    Write-Host "`nGrupos del usuario:" -ForegroundColor Yellow
    foreach ($Group in ($Groups | Sort-Object Name)) {
        Write-Host "  - $($Group.Name)" -ForegroundColor Gray
    }
    
    Write-Host "=== Fin del Resumen ===" -ForegroundColor Cyan
}

Export-ModuleMember -Function @(
    'Add-CompoundUserMembership',
    'Show-CompoundUserSummary'
)