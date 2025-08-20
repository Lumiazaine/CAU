#Requires -Version 5.1
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Script maestro de pruebas para todos los componentes del sistema AD_ADMIN
.DESCRIPTION
    Ejecuta pruebas completas de todos los módulos y funcionalidades del sistema
.PARAMETER WhatIf
    Ejecuta las pruebas en modo simulación
.PARAMETER TestModule
    Ejecuta pruebas solo para un módulo específico
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("All", "SamAccountName", "Password", "CSV", "Transfer", "Search", "Modules")]
    [string]$TestModule = "All"
)

$Global:ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

function Write-TestHeader {
    param([string]$Title)
    Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Yellow
    Write-Host "$('=' * 60)" -ForegroundColor Cyan
}

function Write-TestResult {
    param([string]$Test, [bool]$Success, [string]$Details = "")
    $Status = if ($Success) { "PASS" } else { "FAIL" }
    $Color = if ($Success) { "Green" } else { "Red" }
    
    Write-Host "[$Status] $Test" -ForegroundColor $Color
    if ($Details) {
        Write-Host "      $Details" -ForegroundColor Gray
    }
}

function Test-Modules {
    Write-TestHeader "PRUEBA DE CARGA DE MÓDULOS"
    
    $ModulesToTest = @(
        "SamAccountNameGenerator",
        "CSVValidation", 
        "PasswordManager",
        "UserSearch",
        "DomainStructureManager",
        "MultiDomainSearch",
        "TransferManager",
        "UOManager",
        "UserTemplateManager"
    )
    
    $LoadedModules = 0
    $FailedModules = 0
    
    foreach ($ModuleName in $ModulesToTest) {
        $ModulePath = Join-Path $Global:ScriptPath "Modules\$ModuleName.psm1"
        
        try {
            if (Test-Path $ModulePath) {
                Import-Module $ModulePath -Force -ErrorAction Stop
                Write-TestResult "Módulo $ModuleName" $true "Cargado correctamente"
                $LoadedModules++
            } else {
                Write-TestResult "Módulo $ModuleName" $false "Archivo no encontrado: $ModulePath"
                $FailedModules++
            }
        } catch {
            Write-TestResult "Módulo $ModuleName" $false $_.Exception.Message
            $FailedModules++
        }
    }
    
    Write-Host "`nResumen: $LoadedModules módulos cargados, $FailedModules fallos" -ForegroundColor $(if ($FailedModules -eq 0) { "Green" } else { "Yellow" })
    return $FailedModules -eq 0
}

function Test-SamAccountNameGeneration {
    Write-TestHeader "PRUEBA DE GENERACIÓN DE SAMACCOUNTNAME"
    
    try {
        Import-Module (Join-Path $Global:ScriptPath "Modules\SamAccountNameGenerator.psm1") -Force
        
        $TestCases = @(
            @{ Name = "Juan García López"; Expected = "jgarcia" },
            @{ Name = "María Luisa Rodríguez Martín"; Expected = "mlrodriguez" },
            @{ Name = "José Antonio Fernández"; Expected = "jafernandez" },
            @{ Name = "Carmen López"; Expected = "clopez" }
        )
        
        $AllPassed = $true
        
        foreach ($TestCase in $TestCases) {
            try {
                $Result = Generate-SamAccountName -FullName $TestCase.Name -Domain "test.local"
                $Success = $Result -like "$($TestCase.Expected)*"
                Write-TestResult "Nombre: '$($TestCase.Name)'" $Success "Resultado: $Result"
                
                if (-not $Success) {
                    $AllPassed = $false
                }
            } catch {
                Write-TestResult "Nombre: '$($TestCase.Name)'" $false $_.Exception.Message
                $AllPassed = $false
            }
        }
        
        return $AllPassed
    } catch {
        Write-TestResult "Sistema SamAccountName" $false $_.Exception.Message
        return $false
    }
}

function Test-PasswordGeneration {
    Write-TestHeader "PRUEBA DE GENERACIÓN DE CONTRASEÑAS"
    
    try {
        Import-Module (Join-Path $Global:ScriptPath "Modules\PasswordManager.psm1") -Force
        
        # Probar contraseña estándar
        $StandardPassword = Get-StandardPassword
        $Success = $StandardPassword -match "^Justicia\d{4}$"
        Write-TestResult "Contraseña estándar" $Success "Resultado: $StandardPassword"
        
        # Probar validación de complejidad
        $TestPasswords = @(
            @{ Password = "Password123!"; ShouldPass = $true },
            @{ Password = "weak"; ShouldPass = $false },
            @{ Password = "ComplexPassword2024!"; ShouldPass = $true }
        )
        
        $AllPassed = $Success
        
        foreach ($TestPass in $TestPasswords) {
            try {
                $Result = Test-PasswordComplexity -Password $TestPass.Password
                $Success = $Result.IsComplex -eq $TestPass.ShouldPass
                Write-TestResult "Validación: '$($TestPass.Password)'" $Success "Compleja: $($Result.IsComplex)"
                
                if (-not $Success) {
                    $AllPassed = $false
                }
            } catch {
                Write-TestResult "Validación: '$($TestPass.Password)'" $false $_.Exception.Message
                $AllPassed = $false
            }
        }
        
        return $AllPassed
    } catch {
        Write-TestResult "Sistema Contraseñas" $false $_.Exception.Message
        return $false
    }
}

function Test-DomainStructure {
    Write-TestHeader "PRUEBA DE ESTRUCTURA DE DOMINIOS"
    
    try {
        Import-Module (Join-Path $Global:ScriptPath "Modules\DomainStructureManager.psm1") -Force
        
        # Probar obtención de dominios
        $Domains = Get-AllAvailableDomains
        $Success = $Domains.Count -gt 0
        Write-TestResult "Obtener dominios disponibles" $Success "Encontrados: $($Domains.Count) dominios"
        
        if ($Success) {
            foreach ($Domain in $Domains[0..2]) { # Solo los primeros 3 para no saturar
                if ($Domain.Available) {
                    Write-Host "  - $($Domain.Name) [$($Domain.NetBIOSName)] - $($Domain.DomainMode)" -ForegroundColor Gray
                }
            }
        }
        
        return $Success
    } catch {
        Write-TestResult "Sistema Dominios" $false $_.Exception.Message
        return $false
    }
}

function Test-MultiDomainSearch {
    Write-TestHeader "PRUEBA DE BÚSQUEDA MULTI-DOMINIO"
    
    try {
        Import-Module (Join-Path $Global:ScriptPath "Modules\MultiDomainSearch.psm1") -Force
        
        # Probar búsqueda (con un término que probablemente no existe para evitar datos reales)
        $TestSearch = "usuariopruebaquenoexiste123"
        $Domains = Get-AllAvailableDomains | Where-Object { $_.Available } | Select-Object -First 2
        
        if ($Domains.Count -gt 0) {
            $Results = Search-UsersInAllDomains -SearchTerm $TestSearch -SelectedDomains $Domains
            $Success = $Results -is [Array] # Debe retornar un array, incluso si está vacío
            Write-TestResult "Búsqueda multi-dominio" $Success "Resultados: $($Results.Count) usuarios"
        } else {
            Write-TestResult "Búsqueda multi-dominio" $false "No hay dominios disponibles"
            return $false
        }
        
        # Probar función auxiliar
        $SafeValue = Get-SafePropertyValue -Property "Valor de prueba"
        $Success2 = $SafeValue -eq "Valor de prueba"
        Write-TestResult "Función Get-SafePropertyValue" $Success2 "Resultado: '$SafeValue'"
        
        return $Success -and $Success2
    } catch {
        Write-TestResult "Sistema Búsqueda Multi-dominio" $false $_.Exception.Message
        return $false
    }
}

function Test-CSVValidation {
    Write-TestHeader "PRUEBA DE VALIDACIÓN CSV"
    
    try {
        # Crear CSV de prueba temporal
        $TempCSV = Join-Path $env:TEMP "test_users.csv"
        $TestData = @"
TipoAlta;Nombre;Apellidos;Email;Telefono;Oficina;Descripcion;AD
NORMALIZADA;Juan;García López;;12345678A;Sevilla Centro;Tramitador;
TRASLADO;María;Rodríguez;;55667788E;Almería Sur;Letrado;mrodriguez
"@
        Set-Content -Path $TempCSV -Value $TestData -Encoding UTF8
        
        Import-Module (Join-Path $Global:ScriptPath "Modules\CSVValidation.psm1") -Force
        
        $ValidationResult = Test-CSVStructure -CSVFile $TempCSV
        Write-TestResult "Validación estructura CSV" $ValidationResult.IsValid "Errores: $($ValidationResult.Errors.Count)"
        
        # Limpiar archivo temporal
        Remove-Item $TempCSV -ErrorAction SilentlyContinue
        
        return $ValidationResult.IsValid
    } catch {
        Write-TestResult "Sistema Validación CSV" $false $_.Exception.Message
        return $false
    }
}

# Función principal
function Start-SystemTests {
    $TestResults = @{}
    
    Write-Host "INICIANDO PRUEBAS DEL SISTEMA AD_ADMIN" -ForegroundColor Green
    Write-Host "Modo WhatIf: $WhatIf" -ForegroundColor Yellow
    Write-Host "Módulo de prueba: $TestModule" -ForegroundColor Yellow
    
    if ($TestModule -eq "All" -or $TestModule -eq "Modules") {
        $TestResults["Modules"] = Test-Modules
    }
    
    if ($TestModule -eq "All" -or $TestModule -eq "SamAccountName") {
        $TestResults["SamAccountName"] = Test-SamAccountNameGeneration
    }
    
    if ($TestModule -eq "All" -or $TestModule -eq "Password") {
        $TestResults["Password"] = Test-PasswordGeneration
    }
    
    if ($TestModule -eq "All" -or $TestModule -eq "CSV") {
        $TestResults["CSV"] = Test-CSVValidation
    }
    
    if ($TestModule -eq "All" -or $TestModule -eq "Search") {
        $TestResults["Search"] = Test-MultiDomainSearch
        $TestResults["Domains"] = Test-DomainStructure
    }
    
    # Mostrar resumen final
    Write-TestHeader "RESUMEN DE PRUEBAS"
    
    $TotalTests = $TestResults.Count
    $PassedTests = ($TestResults.Values | Where-Object { $_ -eq $true }).Count
    $FailedTests = $TotalTests - $PassedTests
    
    foreach ($TestName in $TestResults.Keys) {
        Write-TestResult "Sistema $TestName" $TestResults[$TestName]
    }
    
    Write-Host "`nRESULTADO FINAL:" -ForegroundColor Cyan
    Write-Host "  Total: $TotalTests pruebas" -ForegroundColor White
    Write-Host "  Exitosas: $PassedTests" -ForegroundColor Green
    Write-Host "  Fallidas: $FailedTests" -ForegroundColor $(if ($FailedTests -eq 0) { "Green" } else { "Red" })
    
    if ($FailedTests -eq 0) {
        Write-Host "`n¡TODOS LOS COMPONENTES FUNCIONAN CORRECTAMENTE!" -ForegroundColor Green
    } else {
        Write-Host "`nSe encontraron $FailedTests componentes con problemas." -ForegroundColor Red
    }
}

# Ejecutar pruebas
Start-SystemTests