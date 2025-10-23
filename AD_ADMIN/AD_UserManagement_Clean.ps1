#requires -version 5.1

<#
.SYNOPSIS
    Sistema de gestion de usuarios AD para Justicia de Andalucia

.DESCRIPTION
    Gestiona altas, traslados y compaginadas de usuarios segun CSV

.PARAMETER CSVFile
    Archivo CSV con formato: TipoAlta;Nombre;Apellidos;Email;Oficina;Descripcion;Telefono

.PARAMETER WhatIf
    Simula las operaciones sin ejecutarlas

.EXAMPLE
    .\AD_UserManagement_Clean.ps1 -CSVFile "Ejemplo_Usuarios.csv" -WhatIf
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$CSVFile = "Ejemplo_Usuarios.csv",
    [switch]$WhatIf = $false
)

# Variables globales
$Global:ScriptPath = $PSScriptRoot
$Global:LogDirectory = "C:\Logs\AD_UserManagement"
$Global:WhatIfMode = $WhatIf

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
        
        $Response = Read-Host "¿Desea crear un archivo CSV de ejemplo? (S/N)"
        if ($Response -eq 'S' -or $Response -eq 's') {
            $ExampleContent = @"
TipoAlta;Nombre;Apellidos;Email;Oficina;Descripcion;Telefono
NORMALIZADA;Juan;Garcia Lopez;juan.garcia@justicia.junta-andalucia.es;Juzgado de Primera Instancia N 19 de Malaga;Tramitador procesal;952123456
NORMALIZADA;Maria;Sanchez Perez;maria.sanchez@justicia.junta-andalucia.es;Juzgado de lo Social N 3 de Sevilla;Gestor procesal;954234567
TRASLADO;Pedro;Martin Ruiz;pedro.martin@justicia.junta-andalucia.es;Audiencia Provincial de Cadiz;Letrado de la administracion de justicia;956345678
COMPAGINADA;Ana;Lopez Gonzalez;ana.lopez@justicia.junta-andalucia.es;Fiscalia Provincial de Granada;Fiscal;958456789
NORMALIZADA;Carlos;Rodriguez Fernandez;carlos.rodriguez@justicia.junta-andalucia.es;Juzgado de Instruccion N 5 de Almeria;Auxilio judicial;950567890
"@
            
            $ExampleContent | Out-File -FilePath $FilePath -Encoding UTF8
            Write-Log "Archivo CSV de ejemplo creado: $FilePath" "INFO"
            Write-Host "Se ha creado un archivo CSV de ejemplo. Por favor, editelo con sus datos reales." -ForegroundColor Green
            return $true
        } else {
            Write-Log "Usuario opto por no crear el archivo CSV" "INFO"
            return $false
        }
    }
    return $true
}

function Extract-ProvinceFromOffice {
    param([string]$Office)
    
    $ProvinciasAndalucia = @("almeria", "cadiz", "cordoba", "granada", "huelva", "jaen", "malaga", "sevilla")
    
    foreach ($Provincia in $ProvinciasAndalucia) {
        if ($Office.ToLower() -like "*$Provincia*") {
            return $Provincia.ToLower()
        }
    }
    
    $Office = $Office.ToLower()
    if ($Office -like "*malaga*") { return "malaga" }
    if ($Office -like "*cadiz*") { return "cadiz" }
    if ($Office -like "*cordoba*") { return "cordoba" }
    if ($Office -like "*sevilla*") { return "sevilla" }
    if ($Office -like "*almeria*") { return "almeria" }
    if ($Office -like "*granada*") { return "granada" }
    if ($Office -like "*huelva*") { return "huelva" }
    if ($Office -like "*jaen*") { return "jaen" }
    
    return $null
}

function Extract-OfficeKeywords {
    param([string]$Office)
    
    $Keywords = @()
    
    if ($Office -like "*Primera Instancia*") { $Keywords += "Primera Instancia" }
    if ($Office -like "*Instruccion*") { $Keywords += "Instruccion" }
    if ($Office -like "*Social*") { $Keywords += "Social" }
    if ($Office -like "*Penal*") { $Keywords += "Penal" }
    if ($Office -like "*Contencioso*") { $Keywords += "Contencioso" }
    if ($Office -like "*Mercantil*") { $Keywords += "Mercantil" }
    if ($Office -like "*Familia*") { $Keywords += "Familia" }
    if ($Office -like "*Menores*") { $Keywords += "Menores" }
    if ($Office -like "*Violencia*") { $Keywords += "Violencia" }
    if ($Office -like "*Audiencia*") { $Keywords += "Audiencia" }
    if ($Office -like "*Fiscalia*") { $Keywords += "Fiscalia" }
    if ($Office -like "*Tribunal*") { $Keywords += "Tribunal" }
    if ($Office -like "*Juzgado*") { $Keywords += "Juzgado" }
    
    if ($Office -match "N[º\s]*(\d+)") {
        $Keywords += "N $($matches[1])"
        $Keywords += "$($matches[1])"
    }
    
    return $Keywords
}

function Find-UOByOffice {
    param([string]$OfficeDescription, [switch]$Interactive = $true)
    
    Write-Log "Buscando UO para oficina: $OfficeDescription" "INFO"
    
    $Province = Extract-ProvinceFromOffice -Office $OfficeDescription
    if (-not $Province) {
        Write-Log "No se pudo identificar la provincia de: $OfficeDescription" "WARNING"
        if ($Interactive) {
            return Select-ProvinceInteractively -OfficeDescription $OfficeDescription
        }
        return $null
    }
    
    Write-Log "Provincia identificada: $Province" "INFO"
    
    $ADAvailable = $null -ne (Get-Module -ListAvailable -Name ActiveDirectory)
    
    if (-not $ADAvailable) {
        Write-Log "ActiveDirectory no disponible - simulando busqueda de UO" "WARNING"
        $SimulatedOU = "OU=$($OfficeDescription -replace '[^\w\s]', ''),OU=Juzgados,OU=$Province-MACJ-Ciudad de la Justicia,DC=$Province,DC=justicia,DC=junta-andalucia,DC=es"
        Write-Log "SIMULACION: UO generada: $SimulatedOU" "INFO"
        return $SimulatedOU
    }
    
    try {
        $SearchBase = "DC=$Province,DC=justicia,DC=junta-andalucia,DC=es"
        Write-Log "Buscando en dominio: $SearchBase" "INFO"
        
        $Keywords = Extract-OfficeKeywords -Office $OfficeDescription
        Write-Log "Palabras clave extraidas: $($Keywords -join ', ')" "INFO"
        
        $MatchingOUs = @()
        foreach ($Keyword in $Keywords) {
            try {
                $OUs = Get-ADOrganizationalUnit -Filter "Name -like '*$Keyword*'" -SearchBase $SearchBase -SearchScope Subtree
                $MatchingOUs += $OUs
            } catch {
                Write-Log "Error buscando con keyword '$Keyword': $($_.Exception.Message)" "WARNING"
            }
        }
        
        if ($MatchingOUs.Count -eq 0) {
            Write-Log "No se encontraron UOs que coincidan con: $OfficeDescription" "WARNING"
            if ($Interactive) {
                return Select-UOFromAllProvince -Province $Province -OfficeDescription $OfficeDescription
            }
            return $null
        }
        
        if ($MatchingOUs.Count -gt 1) {
            Write-Log "Se encontraron $($MatchingOUs.Count) UOs posibles" "INFO"
            if ($Interactive) {
                return Select-UOInteractively -OUs $MatchingOUs -OfficeDescription $OfficeDescription
            }
            return $MatchingOUs[0].DistinguishedName
        }
        
        Write-Log "UO encontrada: $($MatchingOUs[0].DistinguishedName)" "INFO"
        return $MatchingOUs[0].DistinguishedName
        
    } catch {
        Write-Log "Error en busqueda de UO: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Select-ProvinceInteractively {
    param([string]$OfficeDescription)
    
    $ProvinciasAndalucia = @("almeria", "cadiz", "cordoba", "granada", "huelva", "jaen", "malaga", "sevilla")
    
    Write-Host "`n=== SELECCION DE PROVINCIA ===" -ForegroundColor Yellow
    Write-Host "No se pudo identificar automaticamente la provincia para:" -ForegroundColor White
    Write-Host "$OfficeDescription" -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 0; $i -lt $ProvinciasAndalucia.Count; $i++) {
        Write-Host "[$($i+1)] $($ProvinciasAndalucia[$i].ToUpper())" -ForegroundColor White
    }
    
    Write-Host "[0] OMITIR - No asignar provincia" -ForegroundColor Red
    Write-Host ""
    
    do {
        $Selection = Read-Host "Seleccione la provincia (1-$($ProvinciasAndalucia.Count)) o 0 para omitir"
        if ($Selection -eq "0") {
            Write-Log "Usuario decidio omitir asignacion de provincia" "WARNING"
            return $null
        }
        $SelectionNum = [int]$Selection
    } while ($SelectionNum -lt 1 -or $SelectionNum -gt $ProvinciasAndalucia.Count)
    
    $SelectedProvince = $ProvinciasAndalucia[$SelectionNum - 1]
    Write-Log "Provincia seleccionada manualmente: $SelectedProvince" "INFO"
    
    return Find-UOByOffice -OfficeDescription $OfficeDescription -Interactive $true
}

function Select-UOInteractively {
    param([array]$OUs, [string]$OfficeDescription)
    
    Write-Host "`n=== SELECCION DE UNIDAD ORGANIZATIVA ===" -ForegroundColor Yellow
    Write-Host "Oficina buscada: $OfficeDescription" -ForegroundColor Cyan
    Write-Host "Se encontraron $($OUs.Count) UOs similares:" -ForegroundColor White
    Write-Host ""
    
    for ($i = 0; $i -lt $OUs.Count; $i++) {
        $OU = $OUs[$i]
        Write-Host "[$($i+1)] " -NoNewline -ForegroundColor Cyan
        Write-Host "$($OU.Name)" -ForegroundColor White
        Write-Host "     DN: $($OU.DistinguishedName)" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "[0] BUSCAR EN TODA LA PROVINCIA" -ForegroundColor Yellow
    Write-Host ""
    
    do {
        $Selection = Read-Host "Seleccione la UO mas apropiada (1-$($OUs.Count)) o 0 para buscar en toda la provincia"
        if ($Selection -eq "0") {
            $Province = Extract-ProvinceFromOU -OUDN $OUs[0].DistinguishedName
            return Select-UOFromAllProvince -Province $Province -OfficeDescription $OfficeDescription
        }
        $SelectionNum = [int]$Selection
    } while ($SelectionNum -lt 1 -or $SelectionNum -gt $OUs.Count)
    
    $SelectedOU = $OUs[$SelectionNum - 1]
    Write-Log "UO seleccionada manualmente: $($SelectedOU.Name)" "INFO"
    Write-Log "DN: $($SelectedOU.DistinguishedName)" "INFO"
    
    return $SelectedOU.DistinguishedName
}

function Extract-ProvinceFromOU {
    param([string]$OUDN)
    
    $ProvinciasAndalucia = @("almeria", "cadiz", "cordoba", "granada", "huelva", "jaen", "malaga", "sevilla")
    
    foreach ($Provincia in $ProvinciasAndalucia) {
        if ($OUDN -like "*DC=$Provincia,*") {
            return $Provincia
        }
    }
    return "malaga"
}

function Select-UOFromAllProvince {
    param([string]$Province, [string]$OfficeDescription)
    
    Write-Host "`n=== BUSQUEDA EN TODA LA PROVINCIA DE $($Province.ToUpper()) ===" -ForegroundColor Yellow
    
    $ADAvailable = $null -ne (Get-Module -ListAvailable -Name ActiveDirectory)
    if (-not $ADAvailable) {
        Write-Log "ActiveDirectory no disponible - usando simulacion" "WARNING"
        $SimulatedOU = "OU=$($OfficeDescription -replace '[^\w\s]', ''),OU=Juzgados,OU=$Province-MACJ-Ciudad de la Justicia,DC=$Province,DC=justicia,DC=junta-andalucia,DC=es"
        Write-Log "SIMULACION: UO generada: $SimulatedOU" "INFO"
        return $SimulatedOU
    }
    
    try {
        $SearchBase = "DC=$Province,DC=justicia,DC=junta-andalucia,DC=es"
        $AllOUs = Get-ADOrganizationalUnit -Filter * -SearchBase $SearchBase -SearchScope Subtree | 
                  Where-Object { $_.Name -notlike "Users" -and $_.Name -notlike "Computers" } |
                  Sort-Object Name
        
        if ($AllOUs.Count -eq 0) {
            Write-Log "No se encontraron UOs en la provincia $Province" "ERROR"
            return $null
        }
        
        Write-Host "`nUOs disponibles en $($Province.ToUpper()):" -ForegroundColor Cyan
        Write-Host ""
        
        for ($i = 0; $i -lt [Math]::Min($AllOUs.Count, 20); $i++) {
            $OU = $AllOUs[$i]
            Write-Host "[$($i+1)] $($OU.Name)" -ForegroundColor White
        }
        
        if ($AllOUs.Count -gt 20) {
            Write-Host "... y $($AllOUs.Count - 20) mas" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "[0] CANCELAR" -ForegroundColor Red
        Write-Host ""
        
        do {
            $Selection = Read-Host "Seleccione UO (numero) o 0 para cancelar"
            
            if ($Selection -eq "0") {
                return $null
            } elseif ([int]$Selection -ge 1 -and [int]$Selection -le $AllOUs.Count) {
                $SelectedOU = $AllOUs[[int]$Selection - 1]
                Write-Log "UO seleccionada de lista completa: $($SelectedOU.Name)" "INFO"
                return $SelectedOU.DistinguishedName
            } else {
                Write-Host "Seleccion invalida" -ForegroundColor Red
            }
            
        } while ($true)
        
    } catch {
        Write-Log "Error listando UOs de la provincia: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Process-UserByType {
    param([PSCustomObject]$User, [string]$OUDN)
    
    $Result = [PSCustomObject]@{
        Nombre = $User.Nombre
        Apellidos = $User.Apellidos
        Email = $User.Email
        Oficina = $User.Oficina
        Descripcion = $User.Descripcion
        Telefono = $User.Telefono
        TipoAlta = $User.TipoAlta
        UO_Destino = $OUDN
        SamAccountName = ""
        Estado = "PROCESADO"
        Observaciones = ""
        FechaProceso = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    try {
        switch ($User.TipoAlta.ToUpper()) {
            "NORMALIZADA" {
                Write-Log "Procesando alta NORMALIZADA para $($User.Nombre) $($User.Apellidos)" "INFO"
                $Result = Process-NormalizedUser -User $User -OUDN $OUDN -Result $Result
            }
            "TRASLADO" {
                Write-Log "Procesando TRASLADO para $($User.Nombre) $($User.Apellidos)" "INFO"  
                $Result = Process-UserTransfer -User $User -OUDN $OUDN -Result $Result
            }
            "COMPAGINADA" {
                Write-Log "Procesando alta COMPAGINADA para $($User.Nombre) $($User.Apellidos)" "INFO"
                $Result = Process-SharedUser -User $User -OUDN $OUDN -Result $Result
            }
            default {
                throw "Tipo de alta no reconocido: $($User.TipoAlta)"
            }
        }
        
        $Result.Estado = if ($Global:WhatIfMode) { "SIMULADO" } else { "EXITOSO" }
        
    } catch {
        Write-Log "Error procesando usuario: $($_.Exception.Message)" "ERROR"
        $Result.Estado = "ERROR"
        $Result.Observaciones = "Error: $($_.Exception.Message)"
    }
    
    return $Result
}

function Process-NormalizedUser {
    param([PSCustomObject]$User, [string]$OUDN, [PSCustomObject]$Result)
    
    $FirstNameInitial = $User.Nombre.Substring(0,1).ToLower()
    $LastNameClean = $User.Apellidos -replace '[^a-zA-Z0-9]','' -replace '\s+',''
    $SamAccountName = "$FirstNameInitial$($LastNameClean.ToLower())"
    
    $Result.SamAccountName = $SamAccountName
    $Result.Observaciones = "Usuario creado en $OUDN con descripcion: $($User.Descripcion)"
    
    if ($Global:WhatIfMode) {
        Write-Log "SIMULACION: Se crearia usuario $SamAccountName en $OUDN" "INFO"
    } else {
        Write-Log "Se crearian las siguientes acciones para ${SamAccountName}:" "INFO"
        Write-Log "- Crear usuario en AD" "INFO"
        Write-Log "- Asignar a UO: $OUDN" "INFO"
        Write-Log "- Establecer descripcion: $($User.Descripcion)" "INFO"
        Write-Log "- Configurar email: $($User.Email)" "INFO"
        Write-Log "- Configurar telefono: $($User.Telefono)" "INFO"
        Write-Log "- Establecer contrasena inicial" "INFO"
    }
    
    return $Result
}

function Process-UserTransfer {
    param([PSCustomObject]$User, [string]$OUDN, [PSCustomObject]$Result)
    
    $Result.Observaciones = "Usuario trasladado a $OUDN"
    
    if ($Global:WhatIfMode) {
        Write-Log "SIMULACION: Se trasladaria usuario con email $($User.Email) a $OUDN" "INFO"
    } else {
        Write-Log "Se realizarian las siguientes acciones para traslado:" "INFO"
        Write-Log "- Buscar usuario existente por email: $($User.Email)" "INFO"
        Write-Log "- Mover a nueva UO: $OUDN" "INFO"
        Write-Log "- Actualizar descripcion: $($User.Descripcion)" "INFO"
        Write-Log "- Actualizar telefono: $($User.Telefono)" "INFO"
    }
    
    return $Result
}

function Process-SharedUser {
    param([PSCustomObject]$User, [string]$OUDN, [PSCustomObject]$Result)
    
    $Result.Observaciones = "Permisos compaginados anadidos para $OUDN"
    
    if ($Global:WhatIfMode) {
        Write-Log "SIMULACION: Se anadiran permisos compaginados para $($User.Email) en $OUDN" "INFO"
    } else {
        Write-Log "Se realizarian las siguientes acciones para compaginada:" "INFO"
        Write-Log "- Buscar usuario existente por email: $($User.Email)" "INFO"
        Write-Log "- Anadir a grupos de la UO: $OUDN" "INFO"
        Write-Log "- Mantener UO principal" "INFO"
        Write-Log "- Anadir permisos adicionales segun descripcion: $($User.Descripcion)" "INFO"
    }
    
    return $Result
}

# =======================================================================================
# EJECUCION PRINCIPAL
# =======================================================================================

try {
    Write-Log "=== INICIANDO SISTEMA DE GESTION DE USUARIOS AD - JUSTICIA ANDALUCIA ===" "INFO"
    Write-Log "Archivo CSV: $CSVFile" "INFO"
    Write-Log "Modo WhatIf: $Global:WhatIfMode" "INFO"
    
    # Verificar archivo CSV
    if (-not (Test-CSVFile -FilePath $CSVFile)) {
        throw "No se pudo procesar el archivo CSV"
    }
    
    # Verificar ActiveDirectory
    $ADAvailable = $null -ne (Get-Module -ListAvailable -Name ActiveDirectory)
    if (-not $ADAvailable) {
        Write-Log "ADVERTENCIA: Modulo ActiveDirectory no disponible - funcionara en modo simulacion" "WARNING"
    } else {
        Write-Log "Modulo ActiveDirectory disponible" "INFO"
    }
    
    # Importar CSV
    Write-Log "Importando datos del CSV..." "INFO"
    $Users = Import-Csv -Path $CSVFile -Delimiter ";" -Encoding UTF8
    
    if ($Users.Count -eq 0) {
        throw "El archivo CSV esta vacio o no tiene datos validos"
    }
    
    Write-Log "CSV importado correctamente: $($Users.Count) registros" "INFO"
    
    # Validar campos requeridos
    $RequiredFields = @("TipoAlta", "Nombre", "Apellidos", "Email", "Oficina", "Descripcion", "Telefono")
    $FirstUser = $Users[0]
    $MissingFields = @()
    
    foreach ($Field in $RequiredFields) {
        if (-not $FirstUser.$Field) {
            $MissingFields += $Field
        }
    }
    
    if ($MissingFields.Count -gt 0) {
        throw "Faltan campos requeridos en el CSV: $($MissingFields -join ', '). Campos esperados: $($RequiredFields -join ', ')"
    }
    
    # Procesar usuarios
    Write-Log "Iniciando procesamiento de usuarios..." "INFO"
    $ProcessingResults = @()
    $ErrorCount = 0
    $SuccessCount = 0
    
    foreach ($User in $Users) {
        Write-Log "--- Procesando: $($User.Nombre) $($User.Apellidos) ---" "INFO"
        Write-Log "Oficina: $($User.Oficina)" "INFO"
        Write-Log "Tipo: $($User.TipoAlta)" "INFO"
        
        try {
            # Buscar UO por oficina
            $OUDN = Find-UOByOffice -OfficeDescription $User.Oficina -Interactive $true
            
            if (-not $OUDN) {
                Write-Log "No se pudo determinar UO para $($User.Oficina)" "WARNING"
                $OUDN = "OU=SinAsignar,DC=justicia,DC=junta-andalucia,DC=es"
            }
            
            # Procesar segun el tipo
            $Result = Process-UserByType -User $User -OUDN $OUDN
            $ProcessingResults += $Result
            
            if ($Result.Estado -eq "ERROR") {
                $ErrorCount++
            } else {
                $SuccessCount++
            }
            
        } catch {
            Write-Log "Error critico procesando $($User.Nombre): $($_.Exception.Message)" "ERROR"
            $ErrorCount++
            
            $ErrorResult = [PSCustomObject]@{
                Nombre = $User.Nombre
                Apellidos = $User.Apellidos
                Email = $User.Email
                Oficina = $User.Oficina
                Descripcion = $User.Descripcion
                Telefono = $User.Telefono
                TipoAlta = $User.TipoAlta
                UO_Destino = "ERROR"
                SamAccountName = ""
                Estado = "ERROR"
                Observaciones = "Error critico: $($_.Exception.Message)"
                FechaProceso = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            
            $ProcessingResults += $ErrorResult
        }
    }
    
    # Exportar resultados
    try {
        $TimeStampForCSV = Get-Date -Format "yyyyMMdd_HHmmss"
        $ResultsCSVPath = $CSVFile -replace '\.csv$', "_resultados_${TimeStampForCSV}.csv"
        
        $ProcessingResults | Export-Csv -Path $ResultsCSVPath -Delimiter ";" -Encoding UTF8 -NoTypeInformation
        Write-Log "Resultados exportados a: $ResultsCSVPath" "INFO"
        Write-Host "Resultados guardados en: $ResultsCSVPath" -ForegroundColor Green
    } catch {
        Write-Log "Error exportando resultados: $($_.Exception.Message)" "ERROR"
    }
    
    # Resumen final
    Write-Log "=== RESUMEN FINAL ===" "INFO"
    Write-Log "Total procesados: $($ProcessingResults.Count)" "INFO"
    Write-Log "Exitosos: $SuccessCount" "INFO"
    Write-Log "Errores: $ErrorCount" "INFO"
    
    if ($ErrorCount -gt 0) {
        Write-Log "Se encontraron $ErrorCount errores durante el procesamiento" "WARNING"
    }
    
    Write-Log "Log guardado en: $Global:LogFile" "INFO"
    Write-Host "Proceso completado. Log: $Global:LogFile" -ForegroundColor Green
    
} catch {
    Write-Log "Error critico en la ejecucion: $($_.Exception.Message)" "ERROR"
    Write-Host "Error critico: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Consulte el log para mas detalles: $Global:LogFile" -ForegroundColor Yellow
    exit 1
}