param(
    [string]$CSVFile = "Ejemplo_Usuarios_Oficial.csv"
)

Write-Host "=== TEST SIMPLE DEL SISTEMA AD ===" -ForegroundColor Green

# Verificar archivo CSV
if (-not (Test-Path $CSVFile)) {
    Write-Host "ERROR: Archivo CSV no encontrado: $CSVFile" -ForegroundColor Red
    exit 1
}

# Importar CSV
try {
    $Users = Import-Csv -Path $CSVFile -Delimiter ';' -Encoding UTF8
    Write-Host "CSV importado correctamente: $($Users.Count) usuarios" -ForegroundColor Cyan
} catch {
    Write-Host "ERROR: No se pudo importar CSV: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Mostrar estructura del CSV
Write-Host "`nEstructura del CSV:" -ForegroundColor Yellow
$FirstUser = $Users[0]
$FirstUser.PSObject.Properties | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor White
}

# Procesar cada usuario
Write-Host "`n=== PROCESANDO USUARIOS ===" -ForegroundColor Green

foreach ($User in $Users) {
    Write-Host "`n--- Usuario: $($User.Nombre) $($User.Apellidos) ---" -ForegroundColor Yellow
    Write-Host "Tipo: $($User.TipoAlta)" -ForegroundColor Cyan
    Write-Host "Oficina: $($User.Oficina)" -ForegroundColor Cyan
    Write-Host "Email: $($User.Email)" -ForegroundColor Cyan
    Write-Host "Campo AD: $($User.AD)" -ForegroundColor Cyan
    
    # Identificar provincia
    $Oficina = $User.Oficina.ToLower()
    $Provincia = "desconocida"
    
    if ($Oficina -like "*malaga*") { $Provincia = "malaga" }
    elseif ($Oficina -like "*sevilla*") { $Provincia = "sevilla" }
    elseif ($Oficina -like "*cadiz*") { $Provincia = "cadiz" }
    elseif ($Oficina -like "*granada*") { $Provincia = "granada" }
    elseif ($Oficina -like "*almeria*") { $Provincia = "almeria" }
    elseif ($Oficina -like "*cordoba*") { $Provincia = "cordoba" }
    elseif ($Oficina -like "*huelva*") { $Provincia = "huelva" }
    elseif ($Oficina -like "*jaen*") { $Provincia = "jaen" }
    
    Write-Host "Provincia identificada: $Provincia" -ForegroundColor Green
    
    # Generar SamAccountName simple
    $Nombre = $User.Nombre -replace '[^a-zA-Z]', ''
    $Apellidos = $User.Apellidos -replace '[^a-zA-Z\s]', ''
    $PrimerApellido = ($Apellidos -split '\s+')[0]
    
    $SamAccount = "$($Nombre.Substring(0,1))$PrimerApellido".ToLower()
    Write-Host "SamAccountName generado: $SamAccount" -ForegroundColor Green
    
    # Simular procesamiento por tipo
    switch ($User.TipoAlta.ToUpper()) {
        "NORMALIZADA" {
            Write-Host "SIMULACION: Crear nuevo usuario $SamAccount" -ForegroundColor Magenta
            $Email = "$SamAccount@justicia.junta-andalucia.es"
            Write-Host "Email: $Email" -ForegroundColor Magenta
        }
        "TRASLADO" {
            Write-Host "SIMULACION: Trasladar usuario existente" -ForegroundColor Magenta
            if ($User.Email) {
                Write-Host "Buscar por email: $($User.Email)" -ForegroundColor Magenta
            } elseif ($User.AD) {
                Write-Host "Buscar por AD: $($User.AD)" -ForegroundColor Magenta
            }
        }
        "COMPAGINADA" {
            Write-Host "SIMULACION: Anadir permisos compaginados" -ForegroundColor Magenta
            if ($User.Email) {
                Write-Host "Usuario: $($User.Email)" -ForegroundColor Magenta
            } elseif ($User.AD) {
                Write-Host "Usuario: $($User.AD)" -ForegroundColor Magenta
            }
        }
    }
}

Write-Host "`n=== TEST COMPLETADO ===" -ForegroundColor Green