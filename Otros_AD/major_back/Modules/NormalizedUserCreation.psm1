#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Módulo para la creación de usuarios normalizados en Active Directory
.DESCRIPTION
    Gestiona la creación de nuevos usuarios con todas sus propiedades y membresías
#>

Import-Module "$PSScriptRoot\UOManager.psm1" -Force
Import-Module "$PSScriptRoot\UserSearch.psm1" -Force
Import-Module "$PSScriptRoot\PasswordManager.psm1" -Force

function New-NormalizedUser {
    <#
    .SYNOPSIS
        Crea un nuevo usuario normalizado en Active Directory
    .PARAMETER UserData
        Objeto con los datos del usuario del CSV
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
        Write-Verbose "Iniciando creación de usuario normalizado: $($UserData.Nombre) $($UserData.Apellidos)"
        
        $UserParams = Build-UserCreationParameters -UserData $UserData
        $SamAccountName = $UserParams.SamAccountName
        
        $ExistingUser = try { 
            Get-ADUser -Identity $SamAccountName -ErrorAction Stop 
        } catch { 
            $null 
        }
        
        if ($ExistingUser) {
            Write-Warning "El usuario $SamAccountName ya existe. Omitiendo creación."
            return $false
        }
        
        if ($PSCmdlet.ShouldProcess($SamAccountName, "Crear usuario en AD")) {
            if (-not $WhatIf) {
                $NewUser = New-ADUser @UserParams -PassThru
                Write-Host "Usuario creado: $SamAccountName" -ForegroundColor Green
                
                Set-UserAdditionalProperties -User $NewUser -UserData $UserData
                
                Add-UserToGroups -User $NewUser -UserData $UserData
                
                if ($UserData.SetPassword -eq "Si") {
                    if (-not [string]::IsNullOrWhiteSpace($UserData.Password)) {
                        Set-UserCustomPassword -Identity $NewUser.SamAccountName -Password $UserData.Password -ForceChange:$true
                    } else {
                        Set-UserStandardPassword -Identity $NewUser.SamAccountName -ForceChange:$true
                    }
                }
                
                Write-Host "Usuario $SamAccountName creado y configurado exitosamente" -ForegroundColor Green
                return $true
                
            } else {
                Write-Host "WHATIF: Se crearía el usuario $SamAccountName" -ForegroundColor Yellow
                Write-Host "WHATIF: Parámetros: $($UserParams | ConvertTo-Json -Depth 2)" -ForegroundColor Yellow
                return $true
            }
        }
        
    } catch {
        Write-Error "Error creando usuario normalizado: $($_.Exception.Message)"
        return $false
    }
}

function Build-UserCreationParameters {
    <#
    .SYNOPSIS
        Construye los parámetros para la creación del usuario
    .PARAMETER UserData
        Datos del usuario del CSV
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$UserData
    )
    
    $SamAccountName = Generate-SamAccountName -FirstName $UserData.Nombre -LastName $UserData.Apellidos
    $UPN = "$SamAccountName@justicia.junta-andalucia.es"
    $DisplayName = "$($UserData.Nombre) $($UserData.Apellidos)"
    
    $UOContainer = Get-UOContainer -UOName $UserData.UO
    if (-not $UOContainer) {
        throw "No se pudo determinar la UO de destino: $($UserData.UO)"
    }
    
    $UserParams = @{
        Name = $DisplayName
        GivenName = $UserData.Nombre
        Surname = $UserData.Apellidos
        SamAccountName = $SamAccountName
        UserPrincipalName = $UPN
        DisplayName = $DisplayName
        Path = $UOContainer
        Enabled = $true
    }
    
    if (-not [string]::IsNullOrWhiteSpace($UserData.Email)) {
        $UserParams.EmailAddress = $UserData.Email
    }
    
    if (-not [string]::IsNullOrWhiteSpace($UserData.Telefono)) {
        $UserParams.OfficePhone = $UserData.Telefono
    }
    
    if (-not [string]::IsNullOrWhiteSpace($UserData.Oficina)) {
        $UserParams.Office = $UserData.Oficina
    }
    
    if (-not [string]::IsNullOrWhiteSpace($UserData.Descripcion)) {
        $UserParams.Description = $UserData.Descripcion
    }
    
    if (-not [string]::IsNullOrWhiteSpace($UserData.Departamento)) {
        $UserParams.Department = $UserData.Departamento
    }
    
    if (-not [string]::IsNullOrWhiteSpace($UserData.Titulo)) {
        $UserParams.Title = $UserData.Titulo
    }
    
    return $UserParams
}

function Generate-SamAccountName {
    <#
    .SYNOPSIS
        Genera un SamAccountName único basado en nombre y apellidos
    .PARAMETER FirstName
        Nombre del usuario
    .PARAMETER LastName
        Apellidos del usuario
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FirstName,
        
        [Parameter(Mandatory=$true)]
        [string]$LastName
    )
    
    $FirstName = Remove-Diacritics $FirstName.Trim()
    $LastName = Remove-Diacritics $LastName.Trim()
    
    $FirstNameClean = ($FirstName -replace '[^a-zA-Z]', '').ToLower()
    $LastNameClean = ($LastName -replace '[^a-zA-Z]', '').ToLower()
    
    $BaseName = $FirstNameClean.Substring(0, [Math]::Min(3, $FirstNameClean.Length))
    $BaseName += $LastNameClean.Substring(0, [Math]::Min(5, $LastNameClean.Length))
    
    $Counter = 1
    $SamAccountName = $BaseName
    
    while (Test-SamAccountNameExists $SamAccountName) {
        $SamAccountName = "$BaseName$Counter"
        $Counter++
        
        if ($Counter -gt 999) {
            throw "No se pudo generar un SamAccountName único para $FirstName $LastName"
        }
    }
    
    return $SamAccountName
}

function Remove-Diacritics {
    <#
    .SYNOPSIS
        Elimina acentos y diéresis de una cadena
    .PARAMETER Text
        Texto a limpiar
    #>
    [CmdletBinding()]
    param([string]$Text)
    
    $normalizedString = $Text.Normalize([System.Text.NormalizationForm]::FormD)
    $stringBuilder = New-Object System.Text.StringBuilder
    
    for ($i = 0; $i -lt $normalizedString.Length; $i++) {
        $unicodeCategory = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($normalizedString[$i])
        if ($unicodeCategory -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$stringBuilder.Append($normalizedString[$i])
        }
    }
    
    return $stringBuilder.ToString()
}

function Test-SamAccountNameExists {
    <#
    .SYNOPSIS
        Verifica si un SamAccountName ya existe
    .PARAMETER SamAccountName
        SamAccountName a verificar
    #>
    [CmdletBinding()]
    param([string]$SamAccountName)
    
    try {
        $null = Get-ADUser -Identity $SamAccountName -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Set-UserAdditionalProperties {
    <#
    .SYNOPSIS
        Configura propiedades adicionales del usuario
    .PARAMETER User
        Usuario de AD
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
    
    $SetParams = @{}
    
    if (-not [string]::IsNullOrWhiteSpace($UserData.EmployeeID)) {
        $SetParams.EmployeeID = $UserData.EmployeeID
    }
    
    if (-not [string]::IsNullOrWhiteSpace($UserData.Manager)) {
        try {
            $ManagerUser = Get-ADUser -Filter "DisplayName -eq '$($UserData.Manager)'" -ErrorAction Stop
            if ($ManagerUser) {
                $SetParams.Manager = $ManagerUser.DistinguishedName
            }
        } catch {
            Write-Warning "No se pudo encontrar el manager: $($UserData.Manager)"
        }
    }
    
    if ($SetParams.Count -gt 0) {
        Set-ADUser -Identity $User.SamAccountName @SetParams
        Write-Verbose "Propiedades adicionales configuradas para $($User.SamAccountName)"
    }
}

function Add-UserToGroups {
    <#
    .SYNOPSIS
        Añade el usuario a los grupos especificados
    .PARAMETER User
        Usuario de AD
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
    
    if ([string]::IsNullOrWhiteSpace($UserData.Grupos)) {
        Write-Verbose "No se especificaron grupos para el usuario"
        return
    }
    
    $Groups = $UserData.Grupos -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    
    foreach ($GroupName in $Groups) {
        try {
            $Group = Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction Stop
            if ($Group) {
                Add-ADGroupMember -Identity $Group -Members $User -ErrorAction Stop
                Write-Verbose "Usuario añadido al grupo: $GroupName"
            } else {
                Write-Warning "Grupo no encontrado: $GroupName"
            }
        } catch {
            Write-Warning "Error añadiendo usuario al grupo $GroupName`: $($_.Exception.Message)"
        }
    }
}


Export-ModuleMember -Function @(
    'New-NormalizedUser'
)