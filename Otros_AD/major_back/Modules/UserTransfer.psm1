#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Módulo para la gestión de traslados de usuarios en Active Directory
.DESCRIPTION
    Maneja el traslado de usuarios entre UOs, incluyendo copia de perfiles cuando es necesario
#>

Import-Module "$PSScriptRoot\UOManager.psm1" -Force
Import-Module "$PSScriptRoot\UserSearch.psm1" -Force
Import-Module "$PSScriptRoot\PasswordManager.psm1" -Force

function Move-UserTransfer {
    <#
    .SYNOPSIS
        Realiza el traslado de un usuario a otra UO
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
        Write-Verbose "Iniciando traslado de usuario: $($UserData.UsuarioExistente)"
        
        $ExistingUser = Find-ExistingUser -UserData $UserData
        if (-not $ExistingUser) {
            Write-Warning "Usuario no encontrado para traslado: $($UserData.UsuarioExistente)"
            return $false
        }
        
        $TargetUO = Get-UOContainer -UOName $UserData.UODestino
        if (-not $TargetUO) {
            throw "UO de destino no encontrada: $($UserData.UODestino)"
        }
        
        $CurrentUO = ($ExistingUser.DistinguishedName -split ',OU=')[1] -split ',DC=' | Select-Object -First 1
        Write-Verbose "UO actual: $CurrentUO"
        Write-Verbose "UO destino: $($UserData.UODestino)"
        
        if ($UserData.TipoTraslado -eq "Eliminar_Copiar") {
            return Move-UserWithProfileCopy -User $ExistingUser -UserData $UserData -TargetUO $TargetUO -WhatIf:$WhatIf
        } else {
            return Move-UserDirect -User $ExistingUser -UserData $UserData -TargetUO $TargetUO -WhatIf:$WhatIf
        }
        
    } catch {
        Write-Error "Error en traslado de usuario: $($_.Exception.Message)"
        return $false
    }
}

function Find-ExistingUser {
    <#
    .SYNOPSIS
        Busca el usuario existente para el traslado
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
    }
    
    if ($SearchCriteria.Count -eq 0) {
        throw "No se proporcionaron criterios suficientes para encontrar el usuario existente"
    }
    
    $Users = Find-ADUserByCriteria -SearchCriteria $SearchCriteria -ExactMatch
    
    if ($Users.Count -eq 0) {
        return $null
    } elseif ($Users.Count -eq 1) {
        return $Users[0]
    } else {
        Write-Warning "Se encontraron múltiples usuarios. Usando el primero: $($Users[0].SamAccountName)"
        return $Users[0]
    }
}

function Move-UserDirect {
    <#
    .SYNOPSIS
        Traslada un usuario directamente a otra UO
    .PARAMETER User
        Usuario de AD a trasladar
    .PARAMETER UserData
        Datos del CSV
    .PARAMETER TargetUO
        UO de destino
    .PARAMETER WhatIf
        Simulación
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADUser]$User,
        
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$UserData,
        
        [Parameter(Mandatory=$true)]
        [string]$TargetUO,
        
        [Parameter(Mandatory=$false)]
        [switch]$WhatIf
    )
    
    if ($PSCmdlet.ShouldProcess($User.SamAccountName, "Mover usuario a $TargetUO")) {
        if (-not $WhatIf) {
            Move-ADObject -Identity $User.DistinguishedName -TargetPath $TargetUO
            Write-Host "Usuario $($User.SamAccountName) movido a $TargetUO" -ForegroundColor Green
            
            Update-UserProperties -User $User -UserData $UserData
            
            Update-UserGroupMemberships -User $User -UserData $UserData
            
            return $true
        } else {
            Write-Host "WHATIF: Se movería el usuario $($User.SamAccountName) a $TargetUO" -ForegroundColor Yellow
            return $true
        }
    }
    
    return $false
}

function Move-UserWithProfileCopy {
    <#
    .SYNOPSIS
        Elimina el usuario actual y crea uno nuevo copiando el perfil
    .PARAMETER User
        Usuario original
    .PARAMETER UserData
        Datos del CSV
    .PARAMETER TargetUO
        UO de destino
    .PARAMETER WhatIf
        Simulación
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADUser]$User,
        
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$UserData,
        
        [Parameter(Mandatory=$true)]
        [string]$TargetUO,
        
        [Parameter(Mandatory=$false)]
        [switch]$WhatIf
    )
    
    try {
        $UserProfile = Backup-UserProfile -User $User
        
        if ($PSCmdlet.ShouldProcess($User.SamAccountName, "Eliminar y recrear usuario con nuevo perfil")) {
            if (-not $WhatIf) {
                Remove-ADUser -Identity $User.SamAccountName -Confirm:$false
                Write-Host "Usuario original eliminado: $($User.SamAccountName)" -ForegroundColor Yellow
                
                Start-Sleep -Seconds 2
                
                $NewUser = Restore-UserWithNewProfile -UserProfile $UserProfile -UserData $UserData -TargetUO $TargetUO
                
                if ($NewUser) {
                    Write-Host "Usuario recreado exitosamente: $($NewUser.SamAccountName)" -ForegroundColor Green
                    return $true
                } else {
                    throw "Error recreando el usuario"
                }
                
            } else {
                Write-Host "WHATIF: Se eliminaría y recrearía el usuario $($User.SamAccountName) en $TargetUO" -ForegroundColor Yellow
                return $true
            }
        }
        
    } catch {
        Write-Error "Error en proceso de eliminación y copia: $($_.Exception.Message)"
        return $false
    }
    
    return $false
}

function Backup-UserProfile {
    <#
    .SYNOPSIS
        Respalda las propiedades y membresías de un usuario
    .PARAMETER User
        Usuario a respaldar
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADUser]$User
    )
    
    $UserDetails = Get-UserDetails -Identity $User.SamAccountName
    
    $Profile = @{
        OriginalUser = $UserDetails.User
        Groups = $UserDetails.Groups
        Properties = @{
            GivenName = $UserDetails.User.GivenName
            Surname = $UserDetails.User.Surname
            DisplayName = $UserDetails.User.DisplayName
            EmailAddress = $UserDetails.User.mail
            OfficePhone = $UserDetails.User.telephoneNumber
            MobilePhone = $UserDetails.User.mobile
            Office = $UserDetails.User.Office
            Description = $UserDetails.User.Description
            Department = $UserDetails.User.Department
            Title = $UserDetails.User.Title
            Manager = $UserDetails.User.Manager
            EmployeeID = $UserDetails.User.EmployeeID
        }
    }
    
    Write-Verbose "Perfil de usuario respaldado: $($User.SamAccountName)"
    return $Profile
}

function Restore-UserWithNewProfile {
    <#
    .SYNOPSIS
        Restaura un usuario con un nuevo perfil en la UO de destino
    .PARAMETER UserProfile
        Perfil respaldado del usuario
    .PARAMETER UserData
        Datos actualizados del CSV
    .PARAMETER TargetUO
        UO de destino
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$UserProfile,
        
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$UserData,
        
        [Parameter(Mandatory=$true)]
        [string]$TargetUO
    )
    
    try {
        $NewSamAccountName = if (-not [string]::IsNullOrWhiteSpace($UserData.NuevoUsuario)) {
            $UserData.NuevoUsuario
        } else {
            $UserProfile.OriginalUser.SamAccountName
        }
        
        $DisplayName = if (-not [string]::IsNullOrWhiteSpace($UserData.Nombre) -and -not [string]::IsNullOrWhiteSpace($UserData.Apellidos)) {
            "$($UserData.Nombre) $($UserData.Apellidos)"
        } else {
            $UserProfile.Properties.DisplayName
        }
        
        $NewUserParams = @{
            Name = $DisplayName
            SamAccountName = $NewSamAccountName
            UserPrincipalName = "$NewSamAccountName@justicia.junta-andalucia.es"
            DisplayName = $DisplayName
            Path = $TargetUO
            Enabled = $true
            GivenName = if ($UserData.Nombre) { $UserData.Nombre } else { $UserProfile.Properties.GivenName }
            Surname = if ($UserData.Apellidos) { $UserData.Apellidos } else { $UserProfile.Properties.Surname }
        }
        
        if ($UserData.Email) { $NewUserParams.EmailAddress = $UserData.Email }
        elseif ($UserProfile.Properties.EmailAddress) { $NewUserParams.EmailAddress = $UserProfile.Properties.EmailAddress }
        
        if ($UserData.Telefono) { $NewUserParams.OfficePhone = $UserData.Telefono }
        elseif ($UserProfile.Properties.OfficePhone) { $NewUserParams.OfficePhone = $UserProfile.Properties.OfficePhone }
        
        if ($UserData.Oficina) { $NewUserParams.Office = $UserData.Oficina }
        elseif ($UserProfile.Properties.Office) { $NewUserParams.Office = $UserProfile.Properties.Office }
        
        if ($UserData.Descripcion) { $NewUserParams.Description = $UserData.Descripcion }
        elseif ($UserProfile.Properties.Description) { $NewUserParams.Description = $UserProfile.Properties.Description }
        
        $NewUser = New-ADUser @NewUserParams -PassThru
        
        Restore-UserGroupMemberships -User $NewUser -UserProfile $UserProfile -UserData $UserData
        
        if ($UserData.SetPassword -eq "Si") {
            if (-not [string]::IsNullOrWhiteSpace($UserData.Password)) {
                Set-UserCustomPassword -Identity $NewUser.SamAccountName -Password $UserData.Password -ForceChange:$true
            } else {
                Set-UserStandardPassword -Identity $NewUser.SamAccountName -ForceChange:$true
            }
        }
        
        return $NewUser
        
    } catch {
        Write-Error "Error restaurando usuario: $($_.Exception.Message)"
        return $null
    }
}

function Update-UserProperties {
    <#
    .SYNOPSIS
        Actualiza las propiedades del usuario tras el traslado
    .PARAMETER User
        Usuario a actualizar
    .PARAMETER UserData
        Nuevos datos del CSV
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADUser]$User,
        
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$UserData
    )
    
    $UpdateParams = @{}
    
    if (-not [string]::IsNullOrWhiteSpace($UserData.Email)) {
        $UpdateParams.EmailAddress = $UserData.Email
    }
    
    if (-not [string]::IsNullOrWhiteSpace($UserData.Telefono)) {
        $UpdateParams.OfficePhone = $UserData.Telefono
    }
    
    if (-not [string]::IsNullOrWhiteSpace($UserData.Oficina)) {
        $UpdateParams.Office = $UserData.Oficina
    }
    
    if (-not [string]::IsNullOrWhiteSpace($UserData.Descripcion)) {
        $UpdateParams.Description = $UserData.Descripcion
    }
    
    if ($UpdateParams.Count -gt 0) {
        Set-ADUser -Identity $User.SamAccountName @UpdateParams
        Write-Verbose "Propiedades actualizadas para $($User.SamAccountName)"
    }
}

function Update-UserGroupMemberships {
    <#
    .SYNOPSIS
        Actualiza las membresías del usuario tras el traslado
    .PARAMETER User
        Usuario
    .PARAMETER UserData
        Datos del CSV
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADUser]$User,
        
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$UserData
    )
    
    if (-not [string]::IsNullOrWhiteSpace($UserData.GruposAdicionales)) {
        $NewGroups = $UserData.GruposAdicionales -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        
        foreach ($GroupName in $NewGroups) {
            try {
                $Group = Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction Stop
                if ($Group) {
                    Add-ADGroupMember -Identity $Group -Members $User -ErrorAction SilentlyContinue
                    Write-Verbose "Usuario añadido al grupo: $GroupName"
                }
            } catch {
                Write-Warning "Error añadiendo usuario al grupo $GroupName`: $($_.Exception.Message)"
            }
        }
    }
}

function Restore-UserGroupMemberships {
    <#
    .SYNOPSIS
        Restaura las membresías originales del usuario más las nuevas
    .PARAMETER User
        Nuevo usuario
    .PARAMETER UserProfile
        Perfil original
    .PARAMETER UserData
        Datos del CSV
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.ActiveDirectory.Management.ADUser]$User,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$UserProfile,
        
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$UserData
    )
    
    foreach ($Group in $UserProfile.Groups) {
        try {
            Add-ADGroupMember -Identity $Group.DistinguishedName -Members $User -ErrorAction SilentlyContinue
            Write-Verbose "Membresía restaurada: $($Group.Name)"
        } catch {
            Write-Warning "Error restaurando membresía $($Group.Name): $($_.Exception.Message)"
        }
    }
    
    Update-UserGroupMemberships -User $User -UserData $UserData
}


Export-ModuleMember -Function @(
    'Move-UserTransfer'
)