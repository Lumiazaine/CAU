# Módulo no requiere ActiveDirectory para las funciones básicas de generación

<#
.SYNOPSIS
    Módulo para generar SamAccountNames únicos según reglas específicas
.DESCRIPTION
    Genera nombres de usuario siguiendo las reglas:
    1. Primera letra del nombre + primer apellido
    2. Si nombre compuesto (ej: "MARIA LUISA"), usar iniciales (ML)
    3. Si existe, añadir letras del segundo apellido progresivamente
    4. Si segundo apellido se agota, usar nombre completo + primera letra primer apellido
    5. Continuar añadiendo letras hasta encontrar nombre único
#>

function New-SamAccountName {
    <#
    .SYNOPSIS
        Genera un SamAccountName único basado en nombre y apellidos
    .PARAMETER GivenName
        Nombre(s) del usuario
    .PARAMETER Surname
        Apellidos del usuario (separados por espacio)
    .PARAMETER Domain
        Dominio donde verificar unicidad
    .PARAMETER MaxLength
        Longitud máxima del SamAccountName (por defecto 20)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$GivenName,
        
        [Parameter(Mandatory=$true)]
        [string]$Surname,
        
        [Parameter(Mandatory=$true)]
        [string]$Domain,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxLength = 20
    )
    
    Write-Verbose "Generando SamAccountName para: $GivenName $Surname en dominio $Domain"
    
    # Limpiar y normalizar texto
    $CleanGivenName = Clean-TextForSamAccountName -Text $GivenName
    $CleanSurname = Clean-TextForSamAccountName -Text $Surname
    
    # Separar apellidos
    $SurnamesParts = $CleanSurname -split '\s+' | Where-Object { $_ -ne '' }
    $FirstSurname = $SurnamesParts[0]
    $SecondSurname = if ($SurnamesParts.Count -gt 1) { $SurnamesParts[1] } else { "" }
    
    Write-Verbose "Nombre limpio: $CleanGivenName"
    Write-Verbose "Primer apellido: $FirstSurname"
    Write-Verbose "Segundo apellido: $SecondSurname"
    
    # Determinar iniciales del nombre
    $NameInitials = Get-NameInitials -Name $CleanGivenName
    Write-Verbose "Iniciales del nombre: $NameInitials"
    
    # Estrategia 1: Iniciales nombre + primer apellido completo
    $Strategy1Result = Try-Strategy1 -NameInitials $NameInitials -FirstSurname $FirstSurname -Domain $Domain -MaxLength $MaxLength
    if ($Strategy1Result.Success) {
        Write-Host "SamAccountName generado (Estrategia 1): $($Strategy1Result.SamAccountName)" -ForegroundColor Green
        return $Strategy1Result.SamAccountName
    }
    
    # Estrategia 2: Iniciales nombre + primer apellido + letras del segundo apellido
    if (![string]::IsNullOrWhiteSpace($SecondSurname)) {
        $Strategy2Result = Try-Strategy2 -NameInitials $NameInitials -FirstSurname $FirstSurname -SecondSurname $SecondSurname -Domain $Domain -MaxLength $MaxLength
        if ($Strategy2Result.Success) {
            Write-Host "SamAccountName generado (Estrategia 2): $($Strategy2Result.SamAccountName)" -ForegroundColor Green
            return $Strategy2Result.SamAccountName
        }
    }
    
    # Estrategia 3: Nombre completo + iniciales del primer apellido
    $Strategy3Result = Try-Strategy3 -GivenName $CleanGivenName -FirstSurname $FirstSurname -SecondSurname $SecondSurname -Domain $Domain -MaxLength $MaxLength
    if ($Strategy3Result.Success) {
        Write-Host "SamAccountName generado (Estrategia 3): $($Strategy3Result.SamAccountName)" -ForegroundColor Green
        return $Strategy3Result.SamAccountName
    }
    
    # Si todas las estrategias fallan, usar numeración
    $FallbackResult = Try-NumericalFallback -BaseName ($NameInitials + $FirstSurname) -Domain $Domain -MaxLength $MaxLength
    if ($FallbackResult.Success) {
        Write-Host "SamAccountName generado (Fallback): $($FallbackResult.SamAccountName)" -ForegroundColor Yellow
        return $FallbackResult.SamAccountName
    }
    
    throw "No se pudo generar un SamAccountName único para $GivenName $Surname"
}

function Clean-TextForSamAccountName {
    <#
    .SYNOPSIS
        Limpia texto para uso en SamAccountName
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text
    )
    
    # Convertir a minúsculas y remover diacríticos
    $CleanText = $Text.ToLower()
    
    # Mapeo de caracteres especiales
    $CleanText = $CleanText -replace '[áàäâª]', 'a'
    $CleanText = $CleanText -replace '[éèëê]', 'e'
    $CleanText = $CleanText -replace '[íìïî]', 'i'
    $CleanText = $CleanText -replace '[óòöô]', 'o'
    $CleanText = $CleanText -replace '[úùüû]', 'u'
    $CleanText = $CleanText -replace '[ñ]', 'n'
    $CleanText = $CleanText -replace '[ç]', 'c'
    
    # Remover caracteres no alfanuméricos excepto espacios
    $CleanText = $CleanText -replace '[^a-z0-9\s]', ''
    
    # Limpiar espacios múltiples
    $CleanText = $CleanText -replace '\s+', ' '
    $CleanText = $CleanText.Trim()
    
    return $CleanText
}

function Get-NameInitials {
    <#
    .SYNOPSIS
        Obtiene las iniciales del nombre (maneja nombres compuestos)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    $NameParts = $Name -split '\s+' | Where-Object { $_ -ne '' }
    
    if ($NameParts.Count -eq 1) {
        # Nombre simple, usar primera letra
        return $NameParts[0].Substring(0, 1)
    } else {
        # Nombre compuesto, usar iniciales de cada parte
        $Initials = ""
        foreach ($Part in $NameParts) {
            if ($Part.Length -gt 0) {
                $Initials += $Part.Substring(0, 1)
            }
        }
        return $Initials
    }
}

function Try-Strategy1 {
    <#
    .SYNOPSIS
        Estrategia 1: Iniciales nombre + primer apellido completo
    #>
    [CmdletBinding()]
    param(
        [string]$NameInitials,
        [string]$FirstSurname,
        [string]$Domain,
        [int]$MaxLength
    )
    
    $CandidateName = $NameInitials + $FirstSurname
    
    if ($CandidateName.Length -le $MaxLength) {
        $IsUnique = Test-SamAccountNameUniqueness -SamAccountName $CandidateName -Domain $Domain
        if ($IsUnique) {
            return @{ Success = $true; SamAccountName = $CandidateName }
        }
    }
    
    return @{ Success = $false; SamAccountName = $null }
}

function Try-Strategy2 {
    <#
    .SYNOPSIS
        Estrategia 2: Iniciales nombre + primer apellido + letras progresivas del segundo apellido
    #>
    [CmdletBinding()]
    param(
        [string]$NameInitials,
        [string]$FirstSurname,
        [string]$SecondSurname,
        [string]$Domain,
        [int]$MaxLength
    )
    
    $BaseName = $NameInitials + $FirstSurname
    
    # Probar añadiendo letras del segundo apellido progresivamente
    for ($i = 1; $i -le $SecondSurname.Length; $i++) {
        $CandidateName = $BaseName + $SecondSurname.Substring(0, $i)
        
        if ($CandidateName.Length -le $MaxLength) {
            $IsUnique = Test-SamAccountNameUniqueness -SamAccountName $CandidateName -Domain $Domain
            if ($IsUnique) {
                return @{ Success = $true; SamAccountName = $CandidateName }
            }
        } else {
            # Si excede la longitud máxima, parar
            break
        }
    }
    
    return @{ Success = $false; SamAccountName = $null }
}

function Try-Strategy3 {
    <#
    .SYNOPSIS
        Estrategia 3: Nombre completo + letras progresivas del primer apellido
    #>
    [CmdletBinding()]
    param(
        [string]$GivenName,
        [string]$FirstSurname,
        [string]$SecondSurname,
        [string]$Domain,
        [int]$MaxLength
    )
    
    # Si el nombre compuesto es muy largo, usar solo el primer nombre
    $NameParts = $GivenName -split '\s+' | Where-Object { $_ -ne '' }
    $BaseName = $NameParts[0]  # Usar solo el primer nombre para evitar nombres muy largos
    
    # Probar añadiendo letras del primer apellido progresivamente
    for ($i = 1; $i -le $FirstSurname.Length; $i++) {
        $CandidateName = $BaseName + $FirstSurname.Substring(0, $i)
        
        if ($CandidateName.Length -le $MaxLength) {
            $IsUnique = Test-SamAccountNameUniqueness -SamAccountName $CandidateName -Domain $Domain
            if ($IsUnique) {
                return @{ Success = $true; SamAccountName = $CandidateName }
            }
        } else {
            break
        }
    }
    
    # Si el primer apellido se agota y hay segundo apellido, continuar con él
    if (![string]::IsNullOrWhiteSpace($SecondSurname)) {
        $BaseWithFirstSurname = $BaseName + $FirstSurname
        
        for ($i = 1; $i -le $SecondSurname.Length; $i++) {
            $CandidateName = $BaseWithFirstSurname + $SecondSurname.Substring(0, $i)
            
            if ($CandidateName.Length -le $MaxLength) {
                $IsUnique = Test-SamAccountNameUniqueness -SamAccountName $CandidateName -Domain $Domain
                if ($IsUnique) {
                    return @{ Success = $true; SamAccountName = $CandidateName }
                }
            } else {
                break
            }
        }
    }
    
    return @{ Success = $false; SamAccountName = $null }
}

function Try-NumericalFallback {
    <#
    .SYNOPSIS
        Último recurso: Usar numeración secuencial
    #>
    [CmdletBinding()]
    param(
        [string]$BaseName,
        [string]$Domain,
        [int]$MaxLength
    )
    
    # Asegurar que el nombre base no exceda la longitud permitida (dejando espacio para números)
    $MaxBaseLength = $MaxLength - 2  # Reservar espacio para al menos 2 dígitos
    if ($BaseName.Length -gt $MaxBaseLength) {
        $BaseName = $BaseName.Substring(0, $MaxBaseLength)
    }
    
    for ($i = 1; $i -le 999; $i++) {
        $CandidateName = $BaseName + $i.ToString()
        
        if ($CandidateName.Length -le $MaxLength) {
            $IsUnique = Test-SamAccountNameUniqueness -SamAccountName $CandidateName -Domain $Domain
            if ($IsUnique) {
                return @{ Success = $true; SamAccountName = $CandidateName }
            }
        }
    }
    
    return @{ Success = $false; SamAccountName = $null }
}

function Test-SamAccountNameUniqueness {
    <#
    .SYNOPSIS
        Verifica si un SamAccountName es único en el dominio
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SamAccountName,
        
        [Parameter(Mandatory=$true)]
        [string]$Domain
    )
    
    # Verificar si el módulo ActiveDirectory está disponible
    if (Get-Module -ListAvailable -Name ActiveDirectory) {
        try {
            $ExistingUser = Get-ADUser -Identity $SamAccountName -Server $Domain -ErrorAction SilentlyContinue
            return ($ExistingUser -eq $null)
        } catch {
            # Si hay error (usuario no encontrado), entonces es único
            return $true
        }
    } else {
        # Si no hay ActiveDirectory, asumir que es único para pruebas
        Write-Warning "ActiveDirectory no disponible - asumiendo nombre único para pruebas"
        return $true
    }
}

function Show-SamAccountNameGenerationExample {
    <#
    .SYNOPSIS
        Muestra ejemplos de generación de SamAccountName
    #>
    [CmdletBinding()]
    param()
    
    Write-Host "=== EJEMPLOS DE GENERACIÓN DE SAMACCOUNTNAME ===" -ForegroundColor Cyan
    Write-Host ""
    
    $Examples = @(
        @{ Name = "Juan"; Surname = "García López"; Expected = "jgarcia" },
        @{ Name = "Maria Luisa"; Surname = "Rodríguez Martín"; Expected = "mlrodriguez" },
        @{ Name = "José Antonio"; Surname = "Fernández"; Expected = "jafernandez" },
        @{ Name = "Carmen"; Surname = "López Jiménez"; Expected = "clopez" }
    )
    
    foreach ($Example in $Examples) {
        Write-Host "Nombre: $($Example.Name) $($Example.Surname)" -ForegroundColor White
        
        $CleanGiven = Clean-TextForSamAccountName -Text $Example.Name
        $CleanSurname = Clean-TextForSamAccountName -Text $Example.Surname
        $Initials = Get-NameInitials -Name $CleanGiven
        
        $SurnamesParts = $CleanSurname -split '\s+' | Where-Object { $_ -ne '' }
        $FirstSurname = $SurnamesParts[0]
        
        $GeneratedName = $Initials + $FirstSurname
        
        Write-Host "  Iniciales: $Initials" -ForegroundColor Gray
        Write-Host "  Primer apellido: $FirstSurname" -ForegroundColor Gray
        Write-Host "  Resultado: $GeneratedName" -ForegroundColor Green
        Write-Host ""
    }
}

Export-ModuleMember -Function @(
    'New-SamAccountName',
    'Clean-TextForSamAccountName',
    'Get-NameInitials',
    'Test-SamAccountNameUniqueness',
    'Show-SamAccountNameGenerationExample'
)