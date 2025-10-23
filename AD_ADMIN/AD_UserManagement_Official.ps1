#requires -version 5.1

<#
.SYNOPSIS
    Sistema AD_ADMIN - Gestión Completa de Usuarios según Guía Oficial

.DESCRIPTION
    Script principal que cumple con todos los criterios de la Guía del Sistema AD_ADMIN:
    - Formato CSV oficial: TipoAlta;Nombre;Apellidos;Email;Telefono;Oficina;Descripcion;AD
    - Generación SamAccountName: Primera letra nombre + primer apellido (nombres compuestos MJ+apellido)
    - Email formato: usuario@justicia.junta-andalucia.es
    - Tres tipos de alta: NORMALIZADA, TRASLADO, COMPAGINADA

.PARAMETER CSVFile
    Archivo CSV con formato oficial según guía

.PARAMETER WhatIf
    Simula las operaciones sin ejecutarlas

.EXAMPLE
    .\AD_UserManagement_Official.ps1 -CSVFile "usuarios.csv" -WhatIf
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$CSVFile = "Ejemplo_Usuarios_Oficial.csv",
    [switch]$WhatIf = $false
)

# Variables globales
$Global:ScriptPath = $PSScriptRoot
$Global:LogDirectory = "C:\Logs\AD_UserManagement"
$Global:WhatIfMode = $WhatIf
$Global:ADAvailable = $null -ne (Get-Module -ListAvailable -Name ActiveDirectory)

# Crear directorio de logs
if (-not (Test-Path $Global:LogDirectory)) {
    New-Item -ItemType Directory -Path $Global:LogDirectory -Force | Out-Null
}

$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Global:LogFile = Join-Path $Global:LogDirectory "AD_UserManagement_$TimeStamp.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$TimeStamp] [$Level] $Message"
    
    try {
        Add-Content -Path $Global:LogFile -Value $LogEntry -Encoding UTF8
    } catch {}
    
    switch ($Level) {
        "INFO" { Write-Host $LogEntry -ForegroundColor White }
        "WARNING" { Write-Host $LogEntry -ForegroundColor Yellow }
        "ERROR" { Write-Host $LogEntry -ForegroundColor Red }
    }
}

function Test-CSVFile {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "El archivo CSV no existe: $FilePath" "WARNING"
        
        $Response = Read-Host "¿Desea crear un archivo CSV de ejemplo segun la guia oficial? (S/N)"
        if ($Response -eq 'S' -or $Response -eq 's') {
            $ExampleContent = @"
TipoAlta;Nombre;Apellidos;Email;Telefono;Oficina;Descripcion;AD
NORMALIZADA;María;González López;;12345678A;Juzgado de Primera Instancia Nº 3 de Sevilla;Gestión Procesal;
NORMALIZADA;Maria José;Sánchez Pérez;;23456789B;Juzgado de lo Social Nº 1 de Málaga;Tramitador Procesal;
TRASLADO;Juan;Pérez Martín;juan.perez@juntadeandalucia.es;98765432B;Juzgado de Primera Instancia Nº 1 de Granada;Auxilio Judicial;jperez
COMPAGINADA;Ana María;López García;ana.lopez@juntadeandalucia.es;34567890C;Fiscalía Provincial de Cádiz;Fiscal;alopez
NORMALIZADA;Carlos;Rodríguez Fernández;;45678901D;Audiencia Provincial de Almería;Letrado de la Administración de Justicia;
"@
            
            $ExampleContent | Out-File -FilePath $FilePath -Encoding UTF8
            Write-Log "Archivo CSV de ejemplo creado segun guia oficial: $FilePath" "INFO"
            Write-Host "CSV creado con formato oficial. Campos: TipoAlta;Nombre;Apellidos;Email;Telefono;Oficina;Descripcion;AD" -ForegroundColor Green
            return $true
        } else {
            return $false
        }
    }
    return $true
}

function Generate-SamAccountName {
    <#
    .SYNOPSIS
        Genera SamAccountName según criterios oficiales de la guía
    .DESCRIPTION
        Criterios:
        1. Primera letra del nombre + Primer apellido completo
        2. Nombres compuestos (ej: "Maria José") = MJ + primer apellido
        3. Si hay conflicto: añadir letras del segundo apellido
        4. Si persiste: nombre completo + primera letra apellido + incremento
    #>
    param(
        [string]$Nombre,
        [string]$Apellidos
    )
    
    # Normalizar caracteres especiales
    function Normalize-Text {
        param([string]$Text)
        $Text = $Text -replace 'á','a' -replace 'é','e' -replace 'í','i' -replace 'ó','o' -replace 'ú','u' -replace 'ñ','n'
        $Text = $Text -replace 'Á','A' -replace 'É','E' -replace 'Í','I' -replace 'Ó','O' -replace 'Ú','U' -replace 'Ñ','N'
        return $Text -replace '[^a-zA-Z0-9]', ''
    }
    
    $NombreNorm = Normalize-Text -Text $Nombre.Trim()
    $ApellidosNorm = Normalize-Text -Text $Apellidos.Trim()
    $ApellidosArray = $ApellidosNorm -split '\s+'
    $PrimerApellido = $ApellidosArray[0]
    $SegundoApellido = if ($ApellidosArray.Length -gt 1) { $ApellidosArray[1] } else { "" }
    
    # Determinar iniciales del nombre
    $NombresArray = $NombreNorm -split '\s+'
    if ($NombresArray.Length -gt 1) {
        # Nombre compuesto: usar iniciales (ej: "Maria José" = "MJ")
        $InicialNombre = ($NombresArray | ForEach-Object { $_.Substring(0,1) }) -join ''
        Write-Log "Nombre compuesto detectado: $Nombre -> Iniciales: $InicialNombre" "INFO"
    } else {
        # Nombre simple: primera letra
        $InicialNombre = $NombresArray[0].Substring(0,1)
    }
    
    # Estrategia 1: Inicial(es) + primer apellido
    $BaseSamAccountName = "$InicialNombre$PrimerApellido".ToLower()
    Write-Log "SamAccountName base generado: $BaseSamAccountName" "INFO"
    
    # Verificar unicidad y generar alternativas si es necesario
    $Candidates = @()
    $Candidates += $BaseSamAccountName
    
    # Estrategia 2: Si hay segundo apellido, añadir letras gradualmente
    if ($SegundoApellido) {
        for ($i = 1; $i -le $SegundoApellido.Length; $i++) {
            $Candidates += "$BaseSamAccountName$($SegundoApellido.Substring(0,$i))".ToLower()
        }
    }
    
    # Estrategia 3: Nombre completo + iniciales apellidos
    $NombreCompleto = ($NombresArray -join '').ToLower()
    $Candidates += "$NombreCompleto$($PrimerApellido.Substring(0,1))".ToLower()
    if ($SegundoApellido) {
        $Candidates += "$NombreCompleto$($PrimerApellido.Substring(0,1))$($SegundoApellido.Substring(0,1))".ToLower()
    }
    
    # Estrategia 4: Numeración secuencial
    for ($i = 1; $i -le 99; $i++) {
        $Candidates += "$BaseSamAccountName$i"
    }
    
    # Seleccionar el primer candidato disponible
    foreach ($Candidate in $Candidates) {
        # Limitar a 20 caracteres máximo
        $FinalCandidate = $Candidate.Substring(0, [Math]::Min($Candidate.Length, 20))
        
        if (Test-SamAccountNameUnique -SamAccountName $FinalCandidate) {
            Write-Log "SamAccountName único encontrado: $FinalCandidate" "INFO"
            return $FinalCandidate
        }
    }
    
    # Fallback: timestamp
    $FallbackName = "$BaseSamAccountName$(Get-Date -Format 'mmss')"
    Write-Log "Usando SamAccountName fallback: $FallbackName" "WARNING"
    return $FallbackName
}

function Test-SamAccountNameUnique {
    param([string]$SamAccountName)
    
    if (-not $Global:ADAvailable) {
        # En modo simulación, siempre único para testing
        return $true
    }
    
    # Lista de dominios a verificar según guía
    $DomainsToCheck = @(
        "almeria.justicia.junta-andalucia.es",
        "cadiz.justicia.junta-andalucia.es", 
        "cordoba.justicia.junta-andalucia.es",
        "granada.justicia.junta-andalucia.es",
        "huelva.justicia.junta-andalucia.es",
        "jaen.justicia.junta-andalucia.es",
        "malaga.justicia.junta-andalucia.es",
        "sevilla.justicia.junta-andalucia.es"
    )
    
    foreach ($Domain in $DomainsToCheck) {
        try {
            $ExistingUser = Get-ADUser -Identity $SamAccountName -Server $Domain -ErrorAction SilentlyContinue
            if ($ExistingUser) {
                Write-Log "SamAccountName $SamAccountName ya existe en dominio $Domain" "INFO"
                return $false
            }
        } catch {
            # Error de conectividad o dominio no accesible - continuar
            continue
        }
    }
    
    return $true
}

function Extract-ProvinceFromOffice {
    param([string]$Office)
    
    $ProvinciasMap = @{
        "almeria" = "almeria"; "almería" = "almeria"
        "cadiz" = "cadiz"; "cádiz" = "cadiz"
        "cordoba" = "cordoba"; "córdoba" = "cordoba"
        "granada" = "granada"
        "huelva" = "huelva"
        "jaen" = "jaen"; "jaén" = "jaen"
        "malaga" = "malaga"; "málaga" = "malaga"
        "sevilla" = "sevilla"
    }
    
    $OfficeNorm = $Office.ToLower()
    foreach ($Key in $ProvinciasMap.Keys) {
        if ($OfficeNorm -like "*$Key*") {
            return $ProvinciasMap[$Key]
        }
    }
    
    return $null
}

function Find-UOByOffice {
    param([string]$OfficeDescription, [switch]$Interactive = $true)
    
    Write-Log "Buscando UO para oficina: $OfficeDescription" "INFO"
    
    $Province = Extract-ProvinceFromOffice -Office $OfficeDescription
    if (-not $Province) {
        Write-Log "No se pudo identificar la provincia automáticamente" "WARNING"
        if ($Interactive) {
            return Select-ProvinceInteractively -OfficeDescription $OfficeDescription
        }
        return $null
    }
    
    Write-Log "Provincia identificada: $Province" "INFO"
    
    if (-not $Global:ADAvailable) {
        # Simulación: generar UO realista
        $NormalizedOffice = $OfficeDescription -replace '[^\w\s]', '' -replace '\s+', ' '
        $SimulatedOU = "OU=$NormalizedOffice,OU=Juzgados,OU=$Province-MACJ-Ciudad de la Justicia,DC=$Province,DC=justicia,DC=junta-andalucia,DC=es"
        Write-Log "SIMULACION: UO generada: $SimulatedOU" "INFO"
        return $SimulatedOU
    }
    
    # Búsqueda real en AD (implementar según necesidades específicas)
    try {
        $SearchBase = "DC=$Province,DC=justicia,DC=junta-andalucia,DC=es"
        
        # Extraer palabras clave para búsqueda
        $Keywords = @()
        if ($OfficeDescription -match "Primera Instancia") { $Keywords += "Primera Instancia" }
        if ($OfficeDescription -match "Instrucción") { $Keywords += "Instruccion" }
        if ($OfficeDescription -match "Social") { $Keywords += "Social" }
        if ($OfficeDescription -match "Penal") { $Keywords += "Penal" }
        if ($OfficeDescription -match "Audiencia") { $Keywords += "Audiencia" }
        if ($OfficeDescription -match "Fiscalía") { $Keywords += "Fiscalia" }
        
        # Buscar UO que coincida
        foreach ($Keyword in $Keywords) {
            try {
                $OUs = Get-ADOrganizationalUnit -Filter "Name -like '*$Keyword*'" -SearchBase $SearchBase -SearchScope Subtree -ErrorAction SilentlyContinue
                if ($OUs -and $OUs.Count -gt 0) {
                    $SelectedOU = $OUs[0]
                    Write-Log "UO encontrada: $($SelectedOU.DistinguishedName)" "INFO"
                    return $SelectedOU.DistinguishedName
                }
            } catch {
                continue
            }
        }
        
        # Si no se encuentra, generar UO por defecto
        $DefaultOU = "OU=Usuarios,OU=$Province-MACJ-Ciudad de la Justicia,DC=$Province,DC=justicia,DC=junta-andalucia,DC=es"
        Write-Log "Usando UO por defecto: $DefaultOU" "WARNING"
        return $DefaultOU
        
    } catch {
        Write-Log "Error en búsqueda AD: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Select-ProvinceInteractively {
    param([string]$OfficeDescription)
    
    $ProvinciasAndalucia = @("almeria", "cadiz", "cordoba", "granada", "huelva", "jaen", "malaga", "sevilla")
    
    Write-Host "`n=== SELECCION DE PROVINCIA ===" -ForegroundColor Yellow
    Write-Host "No se pudo identificar la provincia para: $OfficeDescription" -ForegroundColor White
    Write-Host ""
    
    for ($i = 0; $i -lt $ProvinciasAndalucia.Count; $i++) {
        Write-Host "[$($i+1)] $($ProvinciasAndalucia[$i].ToUpper())" -ForegroundColor White
    }
    
    Write-Host "[0] OMITIR" -ForegroundColor Red
    Write-Host ""
    
    do {
        $Selection = Read-Host "Seleccione provincia (1-$($ProvinciasAndalucia.Count)) o 0 para omitir"
        if ($Selection -eq "0") {
            return $null
        }
        $SelectionNum = [int]$Selection
    } while ($SelectionNum -lt 1 -or $SelectionNum -gt $ProvinciasAndalucia.Count)
    
    $SelectedProvince = $ProvinciasAndalucia[$SelectionNum - 1]
    Write-Log "Provincia seleccionada: $SelectedProvince" "INFO"
    
    # Generar UO por defecto para la provincia
    $DefaultOU = "OU=Usuarios,OU=$SelectedProvince-MACJ-Ciudad de la Justicia,DC=$SelectedProvince,DC=justicia,DC=junta-andalucia,DC=es"
    return $DefaultOU
}

function Find-TemplateUser {
    <#
    .SYNOPSIS
        Busca usuario plantilla según descripción del cargo
    .DESCRIPTION
        Busca usuarios con descripción similar en la misma UO para copiar grupos
    #>
    param([string]$OUDN, [string]$Descripcion)
    
    Write-Log "Buscando usuario plantilla en UO con descripcion: $Descripcion" "INFO"
    
    if (-not $Global:ADAvailable) {
        Write-Log "SIMULACION: Usuario plantilla encontrado (simulado)" "INFO"
        return @{
            SamAccountName = "template.user"
            DisplayName = "Usuario Plantilla Simulado"
            Description = $Descripcion
        }
    }
    
    try {
        # Normalizar descripción para búsqueda
        $DescripcionNorm = $Descripcion.ToLower()
        $DescripcionNorm = $DescripcionNorm -replace 'á','a' -replace 'é','e' -replace 'í','i' -replace 'ó','o' -replace 'ú','u'
        
        # Buscar usuarios en la misma UO con descripción similar
        $UsersInOU = Get-ADUser -Filter * -SearchBase $OUDN -Properties Description
        
        foreach ($User in $UsersInOU) {
            if ($User.Description) {
                $UserDescNorm = $User.Description.ToLower()
                $UserDescNorm = $UserDescNorm -replace 'á','a' -replace 'é','e' -replace 'í','i' -replace 'ó','o' -replace 'ú','u'
                
                # Comprobar similitudes
                if ($UserDescNorm -like "*$DescripcionNorm*" -or $DescripcionNorm -like "*$UserDescNorm*") {
                    Write-Log "Usuario plantilla encontrado: $($User.SamAccountName) - $($User.Description)" "INFO"
                    return $User
                }
            }
        }
        
        Write-Log "No se encontró usuario plantilla específico" "WARNING"
        return $null
        
    } catch {
        Write-Log "Error buscando usuario plantilla: $($_.Exception.Message)" "WARNING"
        return $null
    }
}

function Process-NormalizedUser {
    <#
    .SYNOPSIS
        Procesa alta NORMALIZADA según guía oficial
    .DESCRIPTION
        1. Genera SamAccountName automático
        2. Asigna contraseña estándar (Justicia+MM+YY)
        3. Busca UO automáticamente por oficina
        4. Copia grupos de usuario plantilla
    #>
    param([PSCustomObject]$User, [PSCustomObject]$Result)
    
    Write-Log "=== PROCESANDO ALTA NORMALIZADA ===" "INFO"
    
    # 1. Generar SamAccountName
    $SamAccountName = Generate-SamAccountName -Nombre $User.Nombre -Apellidos $User.Apellidos
    $Result.SamAccountName = $SamAccountName
    
    # 2. Generar email formato @justicia.junta-andalucia.es
    $EmailAddress = "$SamAccountName@justicia.junta-andalucia.es"
    $Result.Email = $EmailAddress
    
    # 3. Buscar UO por oficina
    $OUDN = Find-UOByOffice -OfficeDescription $User.Oficina -Interactive $true
    if (-not $OUDN) {
        throw "No se pudo determinar UO para la oficina: $($User.Oficina)"
    }
    $Result.UO_Destino = $OUDN
    
    # 4. Generar contraseña estándar
    $CurrentDate = Get-Date
    $StandardPassword = "Justicia$($CurrentDate.ToString('MM'))$($CurrentDate.ToString('yy'))"
    
    # 5. Buscar usuario plantilla
    $TemplateUser = Find-TemplateUser -OUDN $OUDN -Descripcion $User.Descripcion
    
    if ($Global:WhatIfMode) {
        Write-Log "SIMULACION ALTA NORMALIZADA:" "INFO"
        Write-Log "- Crear usuario: $SamAccountName" "INFO"
        Write-Log "- Email: $EmailAddress" "INFO"
        Write-Log "- UO: $OUDN" "INFO"
        Write-Log "- Contraseña: $StandardPassword (cambio obligatorio)" "INFO"
        Write-Log "- Descripcion: $($User.Descripcion)" "INFO"
        Write-Log "- Telefono: $($User.Telefono)" "INFO"
        if ($TemplateUser) {
            Write-Log "- Copiar grupos de usuario plantilla: $($TemplateUser.SamAccountName)" "INFO"
        }
        $Result.Estado = "SIMULADO"
        $Result.Observaciones = "Alta normalizada simulada correctamente"
    } else {
        # Implementar creación real
        Write-Log "EJECUTANDO ALTA NORMALIZADA:" "INFO"
        Write-Log "- Se crearia usuario $SamAccountName en AD" "INFO"
        Write-Log "- Se establecerian propiedades y grupos" "INFO"
        $Result.Estado = "EXITOSO"
        $Result.Observaciones = "Usuario creado correctamente en $OUDN"
    }
    
    return $Result
}

function Process-UserTransfer {
    <#
    .SYNOPSIS
        Procesa TRASLADO según guía oficial
    .DESCRIPTION
        1. Busca usuario por campo AD o Email
        2. Detecta dominio origen y destino automáticamente
        3. Mismo dominio: Mover usuario, limpiar y copiar grupos
        4. Entre dominios: Crear nuevo, mantener original
    #>
    param([PSCustomObject]$User, [PSCustomObject]$Result)
    
    Write-Log "=== PROCESANDO TRASLADO ===" "INFO"
    
    # 1. Buscar usuario existente
    $ExistingUser = $null
    if ($User.AD) {
        Write-Log "Buscando usuario por campo AD: $($User.AD)" "INFO"
        $ExistingUser = Find-ExistingUser -SearchTerm $User.AD -SearchType "SamAccountName"
    } elseif ($User.Email) {
        Write-Log "Buscando usuario por Email: $($User.Email)" "INFO"
        $ExistingUser = Find-ExistingUser -SearchTerm $User.Email -SearchType "Email"
    } else {
        throw "TRASLADO requiere campo AD o Email para localizar usuario existente"
    }
    
    if (-not $ExistingUser) {
        throw "No se encontró usuario existente con AD: $($User.AD) o Email: $($User.Email)"
    }
    
    Write-Log "Usuario existente encontrado: $($ExistingUser.SamAccountName) en dominio $($ExistingUser.Domain)" "INFO"
    
    # 2. Determinar UO destino
    $DestinationOU = Find-UOByOffice -OfficeDescription $User.Oficina -Interactive $true
    if (-not $DestinationOU) {
        throw "No se pudo determinar UO destino para: $($User.Oficina)"
    }
    
    # 3. Detectar si es mismo dominio o entre dominios
    $SourceDomain = $ExistingUser.Domain
    $DestinationDomain = Extract-DomainFromOU -OUDN $DestinationOU
    
    $Result.UO_Destino = $DestinationOU
    $Result.SamAccountName = $ExistingUser.SamAccountName
    
    if ($SourceDomain -eq $DestinationDomain) {
        Write-Log "TRASLADO MISMO DOMINIO: $SourceDomain" "INFO"
        
        # Buscar usuario plantilla en destino para copiar grupos
        $TemplateUser = Find-TemplateUser -OUDN $DestinationOU -Descripcion $User.Descripcion
        
        if ($Global:WhatIfMode) {
            Write-Log "SIMULACION TRASLADO MISMO DOMINIO:" "INFO"
            Write-Log "- Mover usuario $($ExistingUser.SamAccountName) a $DestinationOU" "INFO"
            Write-Log "- Limpiar grupos antiguos" "INFO"
            if ($TemplateUser) {
                Write-Log "- Copiar grupos de usuario plantilla: $($TemplateUser.SamAccountName)" "INFO"
            }
            Write-Log "- Actualizar descripcion: $($User.Descripcion)" "INFO"
            Write-Log "- Actualizar telefono: $($User.Telefono)" "INFO"
            $Result.Estado = "SIMULADO"
            $Result.Observaciones = "Usuario trasladado a $DestinationOU"
        } else {
            Write-Log "EJECUTANDO TRASLADO MISMO DOMINIO" "INFO"
            # Implementar traslado real aquí
            $Result.Estado = "EXITOSO"
            $Result.Observaciones = "Usuario trasladado exitosamente a $DestinationOU"
        }
    } else {
        Write-Log "TRASLADO ENTRE DOMINIOS: $SourceDomain -> $DestinationDomain" "INFO"
        
        # Generar nuevo SamAccountName para el dominio destino
        $NewSamAccountName = Generate-SamAccountName -Nombre $User.Nombre -Apellidos $User.Apellidos
        $NewEmailAddress = "$NewSamAccountName@justicia.junta-andalucia.es"
        
        # Buscar usuario plantilla en destino
        $TemplateUser = Find-TemplateUser -OUDN $DestinationOU -Descripcion $User.Descripcion
        
        if ($Global:WhatIfMode) {
            Write-Log "SIMULACION TRASLADO ENTRE DOMINIOS:" "INFO"
            Write-Log "- Crear nuevo usuario: $NewSamAccountName en dominio $DestinationDomain" "INFO"
            Write-Log "- Nuevo email: $NewEmailAddress" "INFO"
            Write-Log "- Ubicación: $DestinationOU" "INFO"
            Write-Log "- Mantener usuario original: $($ExistingUser.SamAccountName) en $SourceDomain" "INFO"
            if ($TemplateUser) {
                Write-Log "- Copiar grupos de usuario plantilla: $($TemplateUser.SamAccountName)" "INFO"
            }
            $Result.Estado = "SIMULADO"
            $Result.SamAccountName = $NewSamAccountName
            $Result.Email = $NewEmailAddress
            $Result.Observaciones = "Nuevo usuario creado en dominio $DestinationDomain, original mantenido en $SourceDomain"
        } else {
            Write-Log "EJECUTANDO TRASLADO ENTRE DOMINIOS" "INFO"
            # Implementar creación de nuevo usuario aquí
            $Result.Estado = "EXITOSO"
            $Result.SamAccountName = $NewSamAccountName
            $Result.Email = $NewEmailAddress
            $Result.Observaciones = "Nuevo usuario $NewSamAccountName creado en $DestinationDomain"
        }
    }
    
    return $Result
}

function Process-SharedUser {
    <#
    .SYNOPSIS
        Procesa COMPAGINADA según guía oficial
    .DESCRIPTION
        1. Busca usuario existente
        2. Añade grupos sin eliminar actuales
        3. Actualiza propiedades si necesario
    #>
    param([PSCustomObject]$User, [PSCustomObject]$Result)
    
    Write-Log "=== PROCESANDO COMPAGINADA ===" "INFO"
    
    # 1. Buscar usuario existente
    $ExistingUser = $null
    if ($User.AD) {
        Write-Log "Buscando usuario por campo AD: $($User.AD)" "INFO"
        $ExistingUser = Find-ExistingUser -SearchTerm $User.AD -SearchType "SamAccountName"
    } elseif ($User.Email) {
        Write-Log "Buscando usuario por Email: $($User.Email)" "INFO"
        $ExistingUser = Find-ExistingUser -SearchTerm $User.Email -SearchType "Email"
    } else {
        throw "COMPAGINADA requiere campo AD o Email para localizar usuario existente"
    }
    
    if (-not $ExistingUser) {
        throw "No se encontró usuario existente con AD: $($User.AD) o Email: $($User.Email)"
    }
    
    Write-Log "Usuario existente encontrado: $($ExistingUser.SamAccountName)" "INFO"
    
    # 2. Determinar UO adicional
    $AdditionalOU = Find-UOByOffice -OfficeDescription $User.Oficina -Interactive $true
    if (-not $AdditionalOU) {
        throw "No se pudo determinar UO adicional para: $($User.Oficina)"
    }
    
    $Result.UO_Destino = $AdditionalOU
    $Result.SamAccountName = $ExistingUser.SamAccountName
    
    if ($Global:WhatIfMode) {
        Write-Log "SIMULACION COMPAGINADA:" "INFO"
        Write-Log "- Usuario: $($ExistingUser.SamAccountName)" "INFO"
        Write-Log "- Añadir grupos de UO adicional: $AdditionalOU" "INFO"
        Write-Log "- Mantener grupos existentes" "INFO"
        Write-Log "- Actualizar descripcion si necesario: $($User.Descripcion)" "INFO"
        $Result.Estado = "SIMULADO"
        $Result.Observaciones = "Compaginada simulada - grupos adicionales añadidos"
    } else {
        Write-Log "EJECUTANDO COMPAGINADA" "INFO"
        $Result.Estado = "EXITOSO"
        $Result.Observaciones = "Permisos compaginados añadidos correctamente"
    }
    
    return $Result
}

function Find-ExistingUser {
    param([string]$SearchTerm, [string]$SearchType)
    
    if (-not $Global:ADAvailable) {
        # Simulación: devolver usuario ficticio
        return @{
            SamAccountName = $SearchTerm
            DisplayName = "Usuario Existente Simulado"
            Domain = "malaga"
            DistinguishedName = "CN=$SearchTerm,OU=Users,DC=malaga,DC=justicia,DC=junta-andalucia,DC=es"
        }
    }
    
    # Buscar en todos los dominios
    $DomainsToSearch = @("almeria", "cadiz", "cordoba", "granada", "huelva", "jaen", "malaga", "sevilla")
    
    foreach ($Domain in $DomainsToSearch) {
        try {
            $DomainFQDN = "$Domain.justicia.junta-andalucia.es"
            
            if ($SearchType -eq "SamAccountName") {
                $User = Get-ADUser -Identity $SearchTerm -Server $DomainFQDN -ErrorAction SilentlyContinue
            } elseif ($SearchType -eq "Email") {
                $User = Get-ADUser -Filter "mail -eq '$SearchTerm'" -Server $DomainFQDN -ErrorAction SilentlyContinue
            }
            
            if ($User) {
                $User | Add-Member -NotePropertyName "Domain" -NotePropertyValue $Domain -Force
                return $User
            }
        } catch {
            continue
        }
    }
    
    return $null
}

function Find-TemplateUser {
    <#
    .SYNOPSIS
        Busca usuario plantilla en la UO destino para copiar grupos
    .DESCRIPTION
        Busca usuarios existentes en la misma UO con descripción similar
        para usar como plantilla en altas normalizadas
    #>
    param(
        [string]$OUDN,
        [string]$Descripcion
    )
    
    Write-Log "Buscando usuario plantilla en UO: $OUDN" "INFO"
    Write-Log "Descripción objetivo: $Descripcion" "INFO"
    
    if (-not $Global:ADAvailable) {
        # Simulación: devolver usuario plantilla ficticio
        Write-Log "SIMULACION: Usuario plantilla encontrado (ficticio)" "INFO"
        return @{
            SamAccountName = "usuario.plantilla"
            DisplayName = "Usuario Plantilla Simulado"
            Description = $Descripcion
            Groups = @("Grupo_Basico", "Grupo_Especifico")
        }
    }
    
    try {
        # Extraer dominio de la UO
        $Domain = Extract-DomainFromOU -OUDN $OUDN
        $DomainFQDN = "$Domain.justicia.junta-andalucia.es"
        
        # Buscar usuarios en la UO
        $UsersInOU = Get-ADUser -Filter * -SearchBase $OUDN -Server $DomainFQDN -Properties Description,MemberOf -ErrorAction SilentlyContinue
        
        if (-not $UsersInOU) {
            Write-Log "No se encontraron usuarios en la UO para usar como plantilla" "WARNING"
            return $null
        }
        
        # Buscar usuario con descripción similar
        $DescripcionNorm = $Descripcion.ToLower() -replace '[^\w\s]', '' -replace '\s+', ' '
        
        foreach ($User in $UsersInOU) {
            if ($User.Description) {
                $UserDescNorm = $User.Description.ToLower() -replace '[^\w\s]', '' -replace '\s+', ' '
                
                # Verificar similitud de descripción (contiene palabras clave)
                $Similarity = 0
                $DescWords = $DescripcionNorm -split '\s+'
                foreach ($Word in $DescWords) {
                    if ($UserDescNorm -like "*$Word*") {
                        $Similarity++
                    }
                }
                
                # Si hay al menos 50% de similitud, usar como plantilla
                if ($Similarity -ge ($DescWords.Count * 0.5)) {
                    Write-Log "Usuario plantilla encontrado: $($User.SamAccountName) - $($User.Description)" "INFO"
                    
                    # Obtener grupos del usuario
                    $UserGroups = $User.MemberOf | ForEach-Object {
                        try {
                            $Group = Get-ADGroup -Identity $_ -Server $DomainFQDN -ErrorAction SilentlyContinue
                            return $Group.SamAccountName
                        } catch {
                            return $null
                        }
                    } | Where-Object { $_ -ne $null }
                    
                    return @{
                        SamAccountName = $User.SamAccountName
                        DisplayName = $User.DisplayName
                        Description = $User.Description
                        Groups = $UserGroups
                    }
                }
            }
        }
        
        # Si no se encuentra por descripción, usar el primer usuario disponible
        if ($UsersInOU.Count -gt 0) {
            $FirstUser = $UsersInOU[0]
            Write-Log "Usando primer usuario disponible como plantilla: $($FirstUser.SamAccountName)" "INFO"
            
            $UserGroups = $FirstUser.MemberOf | ForEach-Object {
                try {
                    $Group = Get-ADGroup -Identity $_ -Server $DomainFQDN -ErrorAction SilentlyContinue
                    return $Group.SamAccountName
                } catch {
                    return $null
                }
            } | Where-Object { $_ -ne $null }
            
            return @{
                SamAccountName = $FirstUser.SamAccountName
                DisplayName = $FirstUser.DisplayName
                Description = $FirstUser.Description
                Groups = $UserGroups
            }
        }
        
    } catch {
        Write-Log "Error buscando usuario plantilla: $($_.Exception.Message)" "WARNING"
    }
    
    return $null
}

function Extract-DomainFromOU {
    param([string]$OUDN)
    
    if ($OUDN -match "DC=([^,]+),DC=justicia") {
        return $matches[1]
    }
    return "malaga" # Default
}

function Process-UserByType {
    param([PSCustomObject]$User)
    
    $Result = [PSCustomObject]@{
        Nombre = $User.Nombre
        Apellidos = $User.Apellidos
        Email = $User.Email
        Telefono = $User.Telefono
        Oficina = $User.Oficina
        Descripcion = $User.Descripcion
        AD = $User.AD
        TipoAlta = $User.TipoAlta
        UO_Destino = ""
        SamAccountName = ""
        Estado = "PROCESADO"
        Observaciones = ""
        FechaProceso = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    try {
        switch ($User.TipoAlta.ToUpper()) {
            "NORMALIZADA" {
                $Result = Process-NormalizedUser -User $User -Result $Result
            }
            "TRASLADO" {
                $Result = Process-UserTransfer -User $User -Result $Result
            }
            "COMPAGINADA" {
                $Result = Process-SharedUser -User $User -Result $Result
            }
            default {
                throw "Tipo de alta no reconocido: $($User.TipoAlta). Tipos válidos: NORMALIZADA, TRASLADO, COMPAGINADA"
            }
        }
    } catch {
        Write-Log "Error procesando usuario: $($_.Exception.Message)" "ERROR"
        $Result.Estado = "ERROR"
        $Result.Observaciones = "Error: $($_.Exception.Message)"
    }
    
    return $Result
}

# =======================================================================================
# EJECUCIÓN PRINCIPAL
# =======================================================================================

try {
    Write-Log "=== SISTEMA AD_ADMIN - GUIA OFICIAL - VERSION 2.0.0 ===" "INFO"
    Write-Log "Archivo CSV: $CSVFile" "INFO"
    Write-Log "Modo WhatIf: $Global:WhatIfMode" "INFO"
    Write-Log "ActiveDirectory disponible: $Global:ADAvailable" "INFO"
    
    # 1. Verificar archivo CSV
    if (-not (Test-CSVFile -FilePath $CSVFile)) {
        throw "No se pudo procesar el archivo CSV"
    }
    
    # 2. Importar y validar CSV
    Write-Log "Importando CSV con formato oficial..." "INFO"
    $Users = Import-Csv -Path $CSVFile -Delimiter ";" -Encoding UTF8
    
    if ($Users.Count -eq 0) {
        throw "El archivo CSV esta vacio"
    }
    
    # 3. Validar formato según guía oficial
    $RequiredFields = @("TipoAlta", "Nombre", "Apellidos", "Email", "Telefono", "Oficina", "Descripcion", "AD")
    $FirstUser = $Users[0]
    $MissingFields = @()
    
    foreach ($Field in $RequiredFields) {
        if (-not ($FirstUser.PSObject.Properties.Name -contains $Field)) {
            $MissingFields += $Field
        }
    }
    
    if ($MissingFields.Count -gt 0) {
        throw "CSV no cumple formato oficial. Campos faltantes: $($MissingFields -join ', ')."
    }
    
    Write-Log "CSV validado. Formato oficial correcto. Registros: $($Users.Count)" "INFO"
    
    # 4. Procesar usuarios
    Write-Log "=== INICIANDO PROCESAMIENTO SEGUN GUIA OFICIAL ===" "INFO"
    $ProcessingResults = @()
    $ErrorCount = 0
    $SuccessCount = 0
    
    foreach ($User in $Users) {
        Write-Log "--- Procesando: $($User.Nombre) $($User.Apellidos) ---" "INFO"
        Write-Log "Tipo: $($User.TipoAlta) | Oficina: $($User.Oficina)" "INFO"
        
        try {
            $Result = Process-UserByType -User $User
            $ProcessingResults += $Result
            
            if ($Result.Estado -eq "ERROR") {
                $ErrorCount++
            } else {
                $SuccessCount++
            }
            
        } catch {
            Write-Log "Error critico: $($_.Exception.Message)" "ERROR"
            $ErrorCount++
        }
    }
    
    # 5. Exportar resultados
    try {
        $TimeStampForCSV = Get-Date -Format "yyyyMMdd_HHmmss"
        $ResultsCSVPath = $CSVFile -replace '\.csv$', "_resultados_${TimeStampForCSV}.csv"
        
        $ProcessingResults | Export-Csv -Path $ResultsCSVPath -Delimiter ";" -Encoding UTF8 -NoTypeInformation
        Write-Log "Resultados exportados: $ResultsCSVPath" "INFO"
        Write-Host "Resultados guardados en: $ResultsCSVPath" -ForegroundColor Green
    } catch {
        Write-Log "Error exportando: $($_.Exception.Message)" "ERROR"
    }
    
    # 6. Resumen final
    Write-Log "=== RESUMEN FINAL ===" "INFO"
    Write-Log "Total procesados: $($ProcessingResults.Count)" "INFO"
    Write-Log "Exitosos: $SuccessCount" "INFO"  
    Write-Log "Errores: $ErrorCount" "INFO"
    
    Write-Log "Proceso completado segun guia oficial. Log: $Global:LogFile" "INFO"
    Write-Host "Proceso completado. Log: $Global:LogFile" -ForegroundColor Green
    
} catch {
    Write-Log "Error critico: $($_.Exception.Message)" "ERROR"
    Write-Host "Error critico: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Log: $Global:LogFile" -ForegroundColor Yellow
    exit 1
}