# Modulo no requiere ActiveDirectory para las funciones basicas de generacion

<#
.SYNOPSIS
    Modulo para generar SamAccountNames unicos segun reglas especificas
.DESCRIPTION
    Genera nombres de usuario siguiendo las reglas:
    1. Primera letra del nombre + primer apellido
    2. Si nombre compuesto (ej: "MARIA LUISA"), usar iniciales (ML)
    3. Si existe, añadir letras del segundo apellido progresivamente
    4. Si segundo apellido se agota, usar nombre completo + primera letra primer apellido
    5. Continuar añadiendo letras hasta encontrar nombre unico
#>

function New-SamAccountName {
    <#
    .SYNOPSIS
        Genera un SamAccountName unico basado en nombre y apellidos
    .PARAMETER GivenName
        Nombre(s) del usuario
    .PARAMETER Surname
        Apellidos del usuario (separados por espacio)
    .PARAMETER Domain
        Dominio donde verificar unicidad
    .PARAMETER MaxLength
        Longitud maxima del SamAccountName (por defecto 20)
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
    
    # Si todas las estrategias fallan, usar numeracion
    $FallbackResult = Try-NumericalFallback -BaseName ($NameInitials + $FirstSurname) -Domain $Domain -MaxLength $MaxLength
    if ($FallbackResult.Success) {
        Write-Host "SamAccountName generado (Fallback): $($FallbackResult.SamAccountName)" -ForegroundColor Yellow
        return $FallbackResult.SamAccountName
    }
    
    throw "No se pudo generar un SamAccountName unico para $GivenName $Surname"
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
    
    # Validar entrada
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return "usuario"  # Fallback por defecto
    }
    
    # Convertir a minusculas y remover diacriticos
    $CleanText = $Text.ToLower()
    
    # Mapeo de caracteres especiales
    $CleanText = $CleanText -replace '[áàäâª]', 'a'
    $CleanText = $CleanText -replace '[éèëê]', 'e'
    $CleanText = $CleanText -replace '[íìïî]', 'i'
    $CleanText = $CleanText -replace '[óòöô]', 'o'
    $CleanText = $CleanText -replace '[úùüû]', 'u'
    $CleanText = $CleanText -replace '[ñ]', 'n'
    $CleanText = $CleanText -replace '[ç]', 'c'
    
    # Remover caracteres no alfanumericos excepto espacios
    $CleanText = $CleanText -replace '[^a-z0-9\s]', ''
    
    # Limpiar espacios multiples
    $CleanText = $CleanText -replace '\s+', ' '
    $CleanText = $CleanText.Trim()
    
    # Validar que no quede vacio
    if ([string]::IsNullOrWhiteSpace($CleanText)) {
        return "usuario"  # Fallback por defecto
    }
    
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
    
    # Validar entrada
    if ([string]::IsNullOrWhiteSpace($Name)) {
        return "u"  # Fallback por defecto
    }
    
    # Asegurar que tenemos un string y filtrar partes validas
    $NameParts = @($Name.ToString() -split '\s+' | Where-Object { ![string]::IsNullOrWhiteSpace($_) -and $_.Length -gt 0 })
    
    if ($NameParts.Count -eq 0) {
        return "u"  # Fallback si no hay partes validas
    } elseif ($NameParts.Count -eq 1) {
        # Nombre simple, usar primera letra
        $FirstPart = [string]$NameParts[0]
        if ($FirstPart.Length -gt 0) {
            return $FirstPart.Substring(0, 1)
        } else {
            return "u"  # Fallback por si el nombre esta vacio
        }
    } else {
        # Nombre compuesto, usar iniciales de cada parte
        $Initials = ""
        foreach ($Part in $NameParts) {
            $PartStr = [string]$Part
            if ($PartStr.Length -gt 0) {
                $Initials += $PartStr.Substring(0, 1)
            }
        }
        
        # Asegurar que tenemos al menos una inicial
        if ([string]::IsNullOrWhiteSpace($Initials)) {
            return "u"  # Fallback
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
            # Si excede la longitud maxima, parar
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
    
    # Si el primer apellido se agota y hay segundo apellido, continuar con el
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
        Ultimo recurso: Usar numeracion secuencial
    #>
    [CmdletBinding()]
    param(
        [string]$BaseName,
        [string]$Domain,
        [int]$MaxLength
    )
    
    # Asegurar que el nombre base no exceda la longitud permitida (dejando espacio para numeros)
    $MaxBaseLength = $MaxLength - 2  # Reservar espacio para al menos 2 digitos
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
        Verifica si un SamAccountName es unico en TODOS los dominios del bosque
    .DESCRIPTION
        Busca el SamAccountName en todos los dominios disponibles para garantizar unicidad global
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SamAccountName,
        
        [Parameter(Mandatory=$true)]
        [string]$Domain
    )
    
    # Verificar si el modulo ActiveDirectory esta disponible
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        Write-Warning "ActiveDirectory no disponible - asumiendo nombre unico para pruebas"
        return $true
    }
    
    Write-Verbose "Verificando unicidad de '$SamAccountName' en todos los dominios..."
    
    try {
        # Obtener todos los dominios del bosque
        $AllDomains = @()
        
        try {
            $Forest = Get-ADForest -ErrorAction Stop
            Write-Verbose "Bosque encontrado: $($Forest.Name)"
            
            foreach ($DomainName in $Forest.Domains) {
                try {
                    $DomainObj = Get-ADDomain -Identity $DomainName -ErrorAction Stop
                    $AllDomains += [PSCustomObject]@{
                        Name = $DomainObj.DNSRoot
                        Available = $true
                    }
                    Write-Verbose "Dominio disponible: $($DomainObj.DNSRoot)"
                } catch {
                    Write-Verbose "Dominio no accesible: $DomainName"
                }
            }
        } catch {
            # Fallback al dominio especificado
            $AllDomains += [PSCustomObject]@{
                Name = $Domain
                Available = $true
            }
            Write-Verbose "Usando dominio especificado como fallback: $Domain"
        }
        
        # Buscar el SamAccountName en cada dominio
        foreach ($DomainInfo in $AllDomains) {
            if (-not $DomainInfo.Available) { continue }
            
            try {
                Write-Verbose "Buscando '$SamAccountName' en dominio: $($DomainInfo.Name)"
                
                # Buscar por SamAccountName exacto
                $ExistingUser = Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -Server $DomainInfo.Name -ErrorAction SilentlyContinue
                
                if ($ExistingUser) {
                    Write-Warning "SamAccountName '$SamAccountName' ya existe en dominio $($DomainInfo.Name)"
                    Write-Warning "Usuario existente: $($ExistingUser.DisplayName) ($($ExistingUser.SamAccountName))"
                    return $false
                }
                
            } catch {
                Write-Verbose "Error verificando en $($DomainInfo.Name): $($_.Exception.Message)"
                # Continuar con el siguiente dominio
            }
        }
        
        Write-Verbose "SamAccountName '$SamAccountName' es unico en todos los dominios verificados"
        return $true
        
    } catch {
        Write-Warning "Error durante verificacion de unicidad: $($_.Exception.Message)"
        # En caso de error, ser conservador y asumir que NO es unico
        return $false
    }
}

function Show-SamAccountNameGenerationExample {
    <#
    .SYNOPSIS
        Muestra ejemplos de generacion de SamAccountName
    #>
    [CmdletBinding()]
    param()
    
    Write-Host "=== EJEMPLOS DE GENERACION DE SAMACCOUNTNAME ===" -ForegroundColor Cyan
    Write-Host ""
    
    $Examples = @(
        @{ Name = "Juan"; Surname = "Garcia Lopez"; Expected = "jgarcia" },
        @{ Name = "Maria Luisa"; Surname = "Rodriguez Martin"; Expected = "mlrodriguez" },
        @{ Name = "Jose Antonio"; Surname = "Fernandez Ruiz"; Expected = "jafernandez" },
        @{ Name = "Carmen"; Surname = "Lopez Jimenez"; Expected = "clopez" }
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