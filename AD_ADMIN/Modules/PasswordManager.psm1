#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Modulo para la gestion de contraseñas de usuarios en Active Directory
.DESCRIPTION
    Genera y establece contraseñas siguiendo el patron Justicia+Mes+Año
#>

function Get-StandardPassword {
    <#
    .SYNOPSIS
        Genera la contraseña standard basada en la fecha actual
    .DESCRIPTION
        Formato: Justicia + MM + YY (ejemplo: Justicia0825 para agosto 2025)
    #>
    [CmdletBinding()]
    param()
    
    $CurrentDate = Get-Date
    $Month = $CurrentDate.ToString("MM")
    $Year = $CurrentDate.ToString("yy")
    
    $StandardPassword = "Justicia$Month$Year"
    
    Write-Verbose "Contraseña standard generada para $($CurrentDate.ToString("MMMM yyyy")): $StandardPassword"
    
    return $StandardPassword
}

function Set-UserStandardPassword {
    <#
    .SYNOPSIS
        Establece la contraseña standard para un usuario
    .PARAMETER Identity
        Identificador del usuario (SamAccountName, DN, etc.)
    .PARAMETER ForceChange
        Forzar cambio de contraseña en el proximo inicio de sesion
    .PARAMETER WhatIf
        Simulacion sin realizar cambios
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Identity,
        
        [Parameter(Mandatory=$false)]
        [switch]$ForceChange = $true,
        
        [Parameter(Mandatory=$false)]
        [switch]$WhatIf
    )
    
    try {
        $User = Get-ADUser -Identity $Identity -ErrorAction Stop
        $StandardPassword = Get-StandardPassword
        
        if ($PSCmdlet.ShouldProcess($User.SamAccountName, "Establecer contraseña standard")) {
            if (-not $WhatIf) {
                $SecurePassword = ConvertTo-SecureString -String $StandardPassword -AsPlainText -Force
                Set-ADAccountPassword -Identity $User.SamAccountName -NewPassword $SecurePassword -Reset
                
                if ($ForceChange) {
                    Set-ADUser -Identity $User.SamAccountName -ChangePasswordAtLogon $true
                    Write-Host "Contraseña establecida para $($User.SamAccountName). Debe cambiar en el proximo inicio de sesion." -ForegroundColor Green
                } else {
                    Set-ADUser -Identity $User.SamAccountName -ChangePasswordAtLogon $false
                    Write-Host "Contraseña establecida para $($User.SamAccountName). No requiere cambio." -ForegroundColor Green
                }
                
                Write-Verbose "Contraseña standard aplicada exitosamente a $($User.SamAccountName)"
                return $true
                
            } else {
                Write-Host "WHATIF: Se estableceria la contraseña standard para $($User.SamAccountName)" -ForegroundColor Yellow
                Write-Host "WHATIF: Contraseña seria: $StandardPassword" -ForegroundColor Yellow
                Write-Host "WHATIF: Forzar cambio: $ForceChange" -ForegroundColor Yellow
                return $true
            }
        }
        
    } catch {
        Write-Error "Error estableciendo contraseña para $Identity`: $($_.Exception.Message)"
        return $false
    }
    
    return $false
}

function Set-UserCustomPassword {
    <#
    .SYNOPSIS
        Establece una contraseña personalizada para un usuario
    .PARAMETER Identity
        Identificador del usuario
    .PARAMETER Password
        Contraseña personalizada
    .PARAMETER ForceChange
        Forzar cambio de contraseña en el proximo inicio de sesion
    .PARAMETER WhatIf
        Simulacion sin realizar cambios
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Identity,
        
        [Parameter(Mandatory=$true)]
        [string]$Password,
        
        [Parameter(Mandatory=$false)]
        [switch]$ForceChange = $true,
        
        [Parameter(Mandatory=$false)]
        [switch]$WhatIf
    )
    
    try {
        $User = Get-ADUser -Identity $Identity -ErrorAction Stop
        
        if ($PSCmdlet.ShouldProcess($User.SamAccountName, "Establecer contraseña personalizada")) {
            if (-not $WhatIf) {
                $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
                Set-ADAccountPassword -Identity $User.SamAccountName -NewPassword $SecurePassword -Reset
                
                if ($ForceChange) {
                    Set-ADUser -Identity $User.SamAccountName -ChangePasswordAtLogon $true
                    Write-Host "Contraseña personalizada establecida para $($User.SamAccountName). Debe cambiar en el proximo inicio de sesion." -ForegroundColor Green
                } else {
                    Set-ADUser -Identity $User.SamAccountName -ChangePasswordAtLogon $false
                    Write-Host "Contraseña personalizada establecida para $($User.SamAccountName). No requiere cambio." -ForegroundColor Green
                }
                
                Write-Verbose "Contraseña personalizada aplicada exitosamente a $($User.SamAccountName)"
                return $true
                
            } else {
                Write-Host "WHATIF: Se estableceria una contraseña personalizada para $($User.SamAccountName)" -ForegroundColor Yellow
                Write-Host "WHATIF: Forzar cambio: $ForceChange" -ForegroundColor Yellow
                return $true
            }
        }
        
    } catch {
        Write-Error "Error estableciendo contraseña personalizada para $Identity`: $($_.Exception.Message)"
        return $false
    }
    
    return $false
}

function Test-PasswordComplexity {
    <#
    .SYNOPSIS
        Verifica si una contraseña cumple con los requisitos de complejidad
    .PARAMETER Password
        Contraseña a verificar
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Password
    )
    
    $Requirements = @{
        MinLength = $Password.Length -ge 8
        HasUpper = $Password -cmatch '[A-Z]'
        HasLower = $Password -cmatch '[a-z]'
        HasNumber = $Password -cmatch '\d'
        HasSpecial = $Password -cmatch '[!@#$%^&*(),.?":{}|<>]'
    }
    
    $IsComplex = $Requirements.Values -contains $false -eq $false
    
    return @{
        IsComplex = $IsComplex
        Requirements = $Requirements
        Score = ($Requirements.Values | Where-Object { $_ }).Count
    }
}

function Show-PasswordComplexity {
    <#
    .SYNOPSIS
        Muestra los requisitos de complejidad de contraseña
    .PARAMETER Password
        Contraseña a analizar (opcional)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Password
    )
    
    Write-Host "Requisitos de complejidad de contraseña:" -ForegroundColor Cyan
    Write-Host "• Minimo 8 caracteres" -ForegroundColor Gray
    Write-Host "• Al menos una letra mayuscula" -ForegroundColor Gray
    Write-Host "• Al menos una letra minuscula" -ForegroundColor Gray
    Write-Host "• Al menos un numero" -ForegroundColor Gray
    Write-Host "• Al menos un caracter especial" -ForegroundColor Gray
    
    if (-not [string]::IsNullOrEmpty($Password)) {
        $Analysis = Test-PasswordComplexity -Password $Password
        
        Write-Host "`nAnalisis de la contraseña:" -ForegroundColor Yellow
        Write-Host "Longitud minima: $(if ($Analysis.Requirements.MinLength) {'Cumple'} else {'No cumple'})" -ForegroundColor $(if ($Analysis.Requirements.MinLength) {'Green'} else {'Red'})
        Write-Host "Mayusculas: $(if ($Analysis.Requirements.HasUpper) {'Cumple'} else {'No cumple'})" -ForegroundColor $(if ($Analysis.Requirements.HasUpper) {'Green'} else {'Red'})
        Write-Host "Minusculas: $(if ($Analysis.Requirements.HasLower) {'Cumple'} else {'No cumple'})" -ForegroundColor $(if ($Analysis.Requirements.HasLower) {'Green'} else {'Red'})
        Write-Host "Numeros: $(if ($Analysis.Requirements.HasNumber) {'Cumple'} else {'No cumple'})" -ForegroundColor $(if ($Analysis.Requirements.HasNumber) {'Green'} else {'Red'})
        Write-Host "Caracteres especiales: $(if ($Analysis.Requirements.HasSpecial) {'Cumple'} else {'No cumple'})" -ForegroundColor $(if ($Analysis.Requirements.HasSpecial) {'Green'} else {'Red'})
        Write-Host "Puntuacion: $($Analysis.Score)/5" -ForegroundColor $(if ($Analysis.IsComplex) {'Green'} else {'Yellow'})
    }
}

function Get-PasswordExpirationDate {
    <#
    .SYNOPSIS
        Obtiene la fecha de expiracion de la contraseña de un usuario
    .PARAMETER Identity
        Identificador del usuario
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Identity
    )
    
    try {
        $User = Get-ADUser -Identity $Identity -Properties PasswordLastSet, PasswordNeverExpires, msDS-UserPasswordExpiryTimeComputed -ErrorAction Stop
        
        if ($User.PasswordNeverExpires) {
            return @{
                ExpirationDate = $null
                NeverExpires = $true
                DaysUntilExpiration = $null
                Status = "Nunca expira"
            }
        }
        
        if ($User.'msDS-UserPasswordExpiryTimeComputed' -and $User.'msDS-UserPasswordExpiryTimeComputed' -ne 9223372036854775807) {
            $ExpirationDate = [DateTime]::FromFileTime($User.'msDS-UserPasswordExpiryTimeComputed')
            $DaysUntilExpiration = ($ExpirationDate - (Get-Date)).Days
            
            $Status = if ($DaysUntilExpiration -lt 0) {
                "Expirada"
            } elseif ($DaysUntilExpiration -le 7) {
                "Expira pronto"
            } else {
                "Activa"
            }
            
            return @{
                ExpirationDate = $ExpirationDate
                NeverExpires = $false
                DaysUntilExpiration = $DaysUntilExpiration
                Status = $Status
            }
        }
        
        return @{
            ExpirationDate = $null
            NeverExpires = $false
            DaysUntilExpiration = $null
            Status = "No determinado"
        }
        
    } catch {
        Write-Error "Error obteniendo informacion de contraseña para $Identity`: $($_.Exception.Message)"
        return $null
    }
}

Export-ModuleMember -Function @(
    'Get-StandardPassword',
    'Set-UserStandardPassword',
    'Set-UserCustomPassword',
    'Test-PasswordComplexity',
    'Show-PasswordComplexity',
    'Get-PasswordExpirationDate'
)