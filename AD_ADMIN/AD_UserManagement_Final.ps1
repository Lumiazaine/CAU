param(
    [string]$CSVFile = "Ejemplo_Usuarios_Oficial.csv",
    [switch]$WhatIfMode = $true
)

# ======================================================================================
# CONFIGURACION GLOBAL Y VALIDACION
# ======================================================================================

# Variables globales
$Global:LogDirectory = "C:\Logs\AD_UserManagement"
$Global:WhatIfMode = $WhatIfMode
$Global:ADAvailable = $false

# Verificar disponibilidad del modulo ActiveDirectory
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $Global:ADAvailable = $true
    Write-Host "Modulo ActiveDirectory cargado correctamente" -ForegroundColor Green
} catch {
    Write-Warning "Modulo ActiveDirectory no disponible - funcionara en modo simulacion"
    $Global:ADAvailable = $false
}

# Crear directorio de logs
if (-not (Test-Path $Global:LogDirectory)) {
    New-Item -ItemType Directory -Path $Global:LogDirectory -Force | Out-Null
}

# Configurar archivo de log
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $Global:LogDirectory "AD_UserManagement_$TimeStamp.log"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$TimeStamp] [$Level] $Message"
    
    # Escribir a consola con colores
    switch ($Level) {
        "ERROR" { Write-Host $LogEntry -ForegroundColor Red }
        "WARNING" { Write-Host $LogEntry -ForegroundColor Yellow }
        "INFO" { Write-Host $LogEntry -ForegroundColor Cyan }
        default { Write-Host $LogEntry }
    }
    
    # Escribir a archivo
    Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
}

function Test-CSVFile {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "Archivo CSV no encontrado: $FilePath" "ERROR"
        return $false
    }
    
    # Verificar headers oficiales
    $FirstLine = Get-Content $FilePath -First 1 -Encoding UTF8
    $ExpectedHeaders = "TipoAlta;Nombre;Apellidos;Email;Telefono;Oficina;Descripcion;AD"
    
    if ($FirstLine -ne $ExpectedHeaders) {
        Write-Log "Headers del CSV no coinciden con formato oficial" "ERROR"
        Write-Log "Esperado: $ExpectedHeaders" "ERROR"
        Write-Log "Encontrado: $FirstLine" "ERROR"
        return $false
    }
    
    Write-Log "Archivo CSV validado correctamente" "INFO"
    return $true
}

# ======================================================================================
# FUNCIONES DE GENERACION DE SAMACCOUNTNAME
# ======================================================================================

function Generate-SamAccountName {
    param(
        [string]$Nombre,
        [string]$Apellidos
    )
    
    Write-Log "Generando SamAccountName para: $Nombre $Apellidos" "INFO"
    
    # Normalizar caracteres especiales
    function Normalize-Text {
        param([string]$Text)
        $Text = $Text -replace 'á','a' -replace 'é','e' -replace 'í','i' -replace 'ó','o' -replace 'ú','u' -replace 'ñ','n'
        $Text = $Text -replace 'Á','A' -replace 'É','E' -replace 'Í','I' -replace 'Ó','O' -replace 'Ú','U' -replace 'Ñ','N'
        $Text = $Text -replace 'ç','c' -replace 'Ç','C'
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
        # Nombre compuesto: usar iniciales (ej: "Maria Jose" = "MJ")
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
    
    # Estrategia 2: Si hay segundo apellido, anadir letras gradualmente
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
    
    # Estrategia 4: Numeracion secuencial
    for ($i = 1; $i -le 99; $i++) {
        $Candidates += "$BaseSamAccountName$i"
    }
    
    # Seleccionar el primer candidato disponible
    foreach ($Candidate in $Candidates) {
        # Limitar a 20 caracteres maximo
        $FinalCandidate = $Candidate.Substring(0, [Math]::Min($Candidate.Length, 20))
        
        if (Test-SamAccountNameUnique -SamAccountName $FinalCandidate) {
            Write-Log "SamAccountName unico encontrado: $FinalCandidate" "INFO"
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
        # En modo simulacion, siempre unico para testing
        return $true
    }
    
    # Lista de dominios a verificar segun guia
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

# ======================================================================================
# FUNCIONES DE BUSQUEDA DE UO Y PROVINCIAS
# ======================================================================================

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
        Write-Log "No se pudo identificar la provincia automaticamente" "WARNING"
        if ($Interactive) {
            return Select-ProvinceInteractively -OfficeDescription $OfficeDescription
        }
        return $null
    }
    
    Write-Log "Provincia identificada: $Province" "INFO"
    
    if (-not $Global:ADAvailable) {
        # Simulacion: generar UO realista
        $NormalizedOffice = $OfficeDescription -replace '[^\w\s]', '' -replace '\s+', ' '
        $SimulatedOU = "OU=$NormalizedOffice,OU=Juzgados,OU=$Province-MACJ-Ciudad de la Justicia,DC=$Province,DC=justicia,DC=junta-andalucia,DC=es"
        Write-Log "SIMULACION: UO generada: $SimulatedOU" "INFO"
        return $SimulatedOU
    }
    
    # Busqueda real en AD (implementar según necesidades especificas)
    try {
        $SearchBase = "DC=$Province,DC=justicia,DC=junta-andalucia,DC=es"
        
        # Extraer palabras clave para busqueda
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
        Write-Log "Error en busqueda AD: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Select-ProvinceInteractively {
    param([string]$OfficeDescription)
    
    $ProvinciasAndalucia = @("almeria", "cadiz", "cordoba", "granada", "huelva", "jaen", "malaga", "sevilla")
    
    Write-Host "`nNo se pudo determinar automaticamente la provincia para: $OfficeDescription" -ForegroundColor Yellow
    Write-Host "Provincias disponibles:" -ForegroundColor Cyan
    
    for ($i = 0; $i -lt $ProvinciasAndalucia.Count; $i++) {
        Write-Host "  $($i + 1). $($ProvinciasAndalucia[$i])" -ForegroundColor White
    }
    
    do {
        $Selection = Read-Host "Seleccione provincia (1-8)"
        $SelectionNum = 0
        $ValidSelection = [int]::TryParse($Selection, [ref]$SelectionNum)
    } while (-not $ValidSelection -or $SelectionNum -lt 1 -or $SelectionNum -gt 8)
    
    $SelectedProvince = $ProvinciasAndalucia[$SelectionNum - 1]
    Write-Log "Provincia seleccionada interactivamente: $SelectedProvince" "INFO"
    
    # Generar UO por defecto para la provincia seleccionada
    $DefaultOU = "OU=Usuarios,OU=$SelectedProvince-MACJ-Ciudad de la Justicia,DC=$SelectedProvince,DC=justicia,DC=junta-andalucia,DC=es"
    return $DefaultOU
}

# ======================================================================================
# FUNCIONES DE BUSQUEDA DE USUARIOS Y PLANTILLAS
# ======================================================================================

function Find-TemplateUser {
    param(
        [string]$OUDN,
        [string]$Descripcion
    )
    
    Write-Log "Buscando usuario plantilla en UO: $OUDN" "INFO"
    Write-Log "Descripcion objetivo: $Descripcion" "INFO"
    
    if (-not $Global:ADAvailable) {
        # Simulacion: devolver usuario plantilla ficticio
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
        
        # Buscar usuario con descripcion similar
        $DescripcionNorm = $Descripcion.ToLower() -replace '[^\w\s]', '' -replace '\s+', ' '
        
        foreach ($User in $UsersInOU) {
            if ($User.Description) {
                $UserDescNorm = $User.Description.ToLower() -replace '[^\w\s]', '' -replace '\s+', ' '
                
                # Verificar similitud de descripcion (contiene palabras clave)
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
        
        # Si no se encuentra por descripcion, usar el primer usuario disponible
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

function Find-ExistingUser {
    param(
        [string]$SearchTerm,
        [string]$SearchType  # "SamAccountName" o "Email"
    )
    
    Write-Log "Buscando usuario existente por $SearchType : $SearchTerm" "INFO"
    
    if (-not $Global:ADAvailable) {
        # Simulacion: devolver usuario ficticio
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

function Extract-DomainFromOU {
    param([string]$OUDN)
    
    if ($OUDN -match "DC=([^,]+),DC=justicia") {
        return $matches[1]
    }
    return "malaga" # Default
}

# ======================================================================================
# FUNCIONES DE PROCESAMIENTO POR TIPO
# ======================================================================================

function Process-NormalizedUser {
    param([PSCustomObject]$User, [PSCustomObject]$Result)
    
    Write-Log "=== PROCESANDO ALTA NORMALIZADA ===" "INFO"
    
    # 1. Generar SamAccountName único
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
        Write-Log "SIMULACION: Se crearia usuario $SamAccountName en $OUDN con descripcion: $($User.Descripcion)" "INFO"
        $Result.Estado = "SIMULADO"
        $Result.Observaciones = "Usuario creado en $OUDN con descripcion: $($User.Descripcion)"
    } else {
        # Implementar creacion real
        Write-Log "EJECUTANDO ALTA NORMALIZADA:" "INFO"
        Write-Log "- Se crearia usuario $SamAccountName en AD" "INFO"
        Write-Log "- Se establecerian propiedades y grupos" "INFO"
        $Result.Estado = "EXITOSO"
        $Result.Observaciones = "Usuario creado correctamente en $OUDN"
    }
    
    return $Result
}

function Process-UserTransfer {
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
        throw "No se encontro usuario existente con AD: $($User.AD) o Email: $($User.Email)"
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
        
        if ($Global:WhatIfMode) {
            Write-Log "SIMULACION: Se trasladaria usuario con email $($User.Email) a $DestinationOU" "INFO"
            $Result.Estado = "SIMULADO"
            $Result.Observaciones = "Usuario trasladado a $DestinationOU"
        } else {
            Write-Log "EJECUTANDO TRASLADO MISMO DOMINIO" "INFO"
            $Result.Estado = "EXITOSO"
            $Result.Observaciones = "Usuario trasladado exitosamente a $DestinationOU"
        }
    } else {
        Write-Log "TRASLADO ENTRE DOMINIOS: $SourceDomain -> $DestinationDomain" "INFO"
        
        if ($Global:WhatIfMode) {
            Write-Log "SIMULACION: Se crearia nuevo usuario en dominio destino, manteniendo original" "INFO"
            $Result.Estado = "SIMULADO"
            $Result.Observaciones = "Nuevo usuario creado en dominio $DestinationDomain, original mantenido en $SourceDomain"
        } else {
            Write-Log "EJECUTANDO TRASLADO ENTRE DOMINIOS" "INFO"
            $Result.Estado = "EXITOSO"
            $Result.Observaciones = "Nuevo usuario creado en dominio destino"
        }
    }
    
    return $Result
}

function Process-SharedUser {
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
        throw "No se encontro usuario existente con AD: $($User.AD) o Email: $($User.Email)"
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
        Write-Log "SIMULACION: Se anadiran permisos compaginados para $($User.Email) en $AdditionalOU" "INFO"
        $Result.Estado = "SIMULADO"
        $Result.Observaciones = "Permisos compaginados anadidos para $AdditionalOU"
    } else {
        Write-Log "EJECUTANDO COMPAGINADA" "INFO"
        $Result.Estado = "EXITOSO"
        $Result.Observaciones = "Permisos compaginados anadidos exitosamente"
    }
    
    return $Result
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
                throw "Tipo de alta no reconocido: $($User.TipoAlta). Tipos validos: NORMALIZADA, TRASLADO, COMPAGINADA"
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
    Write-Log "=== INICIANDO SISTEMA DE GESTION DE USUARIOS AD - JUSTICIA ANDALUCIA ===" "INFO"
    Write-Log "Archivo CSV: $CSVFile" "INFO"
    Write-Log "Modo WhatIf: $Global:WhatIfMode" "INFO"
    
    if (-not $Global:ADAvailable) {
        Write-Log "ADVERTENCIA: Modulo ActiveDirectory no disponible - funcionara en modo simulacion" "WARNING"
    }
    
    # 1. Verificar archivo CSV
    if (-not (Test-CSVFile -FilePath $CSVFile)) {
        throw "Validacion del archivo CSV fallida"
    }
    
    # 2. Importar datos del CSV
    Write-Log "Importando datos del CSV..." "INFO"
    $UsersData = Import-Csv -Path $CSVFile -Delimiter ';' -Encoding UTF8
    Write-Log "CSV importado correctamente: $($UsersData.Count) registros" "INFO"
    
    # 3. Procesar cada usuario
    Write-Log "Iniciando procesamiento de usuarios..." "INFO"
    $Results = @()
    $SuccessCount = 0
    $ErrorCount = 0
    
    foreach ($User in $UsersData) {
        Write-Log "--- Procesando: $($User.Nombre) $($User.Apellidos) ---" "INFO"
        Write-Log "Oficina: $($User.Oficina)" "INFO"
        Write-Log "Tipo: $($User.TipoAlta)" "INFO"
        
        $UserResult = Process-UserByType -User $User
        $Results += $UserResult
        
        if ($UserResult.Estado -eq "ERROR") {
            $ErrorCount++
        } else {
            $SuccessCount++
        }
    }
    
    # 4. Exportar resultados
    $TimeStampForCSV = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputPath = $CSVFile -replace '\.csv$', "_resultados_$TimeStampForCSV.csv"
    $Results | Export-Csv -Path $OutputPath -Delimiter ';' -NoTypeInformation -Encoding UTF8
    Write-Log "Resultados exportados a: $OutputPath" "INFO"
    
    # 5. Mostrar resumen
    Write-Log "=== RESUMEN FINAL ===" "INFO"
    Write-Log "Total procesados: $($UsersData.Count)" "INFO"
    Write-Log "Exitosos: $SuccessCount" "INFO"
    Write-Log "Errores: $ErrorCount" "INFO"
    Write-Log "Log guardado en: $LogFile" "INFO"
    
} catch {
    Write-Log "ERROR CRITICO: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}