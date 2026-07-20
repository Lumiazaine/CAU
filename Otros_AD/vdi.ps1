# ==============================================================================
# Script de Automatizacion: Altas y Bajas de Usuarios VDI (Version Optimizada)
# Plataforma: Windows Server 2019 / Active Directory
# Dominio: vdi.justicia.junta-andalucia.es
# Resolucion: Error de limite de tamano (MaxPageSize / >5000 miembros)
# ==============================================================================

# Importar el modulo de Active Directory
Import-Module ActiveDirectory

# Configuracion de variables globales
$Domain = "vdi.justicia.junta-andalucia.es"
$GCServer = "$Domain:3268" # Puerto 3268 para buscar en "Todo el directorio" (Global Catalog)
$GroupName = "GVDIEscPTV" # Grupo por defecto (GRP_Publicaciones)

Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "     GESTION DE ALTAS Y BAJAS EN ACTIVE DIRECTORY VDI" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Dominio de trabajo: $Domain" -ForegroundColor Gray
Write-Host "Catalogo Global   : $GCServer" -ForegroundColor Gray
Write-Host "Grupo objetivo    : $GroupName" -ForegroundColor Gray
Write-Host "----------------------------------------------------------" -ForegroundColor Cyan

# Obtener informacion del grupo primero para asegurar que existe y tener su DN
try {
    $Group = Get-ADGroup -Identity $GroupName -Server $Domain
} catch {
    Write-Host "[ERROR] No se pudo encontrar el grupo '$GroupName' en el dominio '$Domain'." -ForegroundColor Red
    Write-Error $_.Exception.Message
    Exit
}

# ------------------------------------------------------------------------------
# 1. SOLICITAR USUARIO DE BAJA Y COMPROBAR EXISTENCIA
# ------------------------------------------------------------------------------
$UserBajaInput = Read-Host "Introduzca el usuario (SAMAccountName) que desea dar de BAJA"

Write-Host "`nBuscando al usuario '$UserBajaInput' en todo el directorio (Catalogo Global)..." -ForegroundColor Yellow

# Buscar el usuario en todo el bosque usando el Catalogo Global (Paso 5/6 del manual)
try {
    $UserBaja = Get-ADUser -Filter "SamAccountName -eq '$UserBajaInput'" -Server $GCServer
    if (-not $UserBaja) {
        Write-Host "[ERROR] El usuario '$UserBajaInput' no existe en el directorio." -ForegroundColor Red
        Write-Host "Proceso abortado." -ForegroundColor Yellow
        Exit
    }
    Write-Host "[OK] Usuario '$UserBajaInput' encontrado: $($UserBaja.DistinguishedName)" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Fallo al conectar con el Catalogo Global ($GCServer)." -ForegroundColor Red
    Write-Error $_.Exception.Message
    Exit
}

# Comprobar pertenencia al grupo usando un filtro LDAP optimizado en lugar de Get-ADGroupMember
Write-Host "`nVerificando si el usuario pertenece al grupo '$GroupName'..." -ForegroundColor Yellow
$IsMemberBaja = Get-ADGroup -LDAPFilter "(&(distinguishedName=$($Group.DistinguishedName))(member=$($UserBaja.DistinguishedName)))" -Server $Domain

if (-not $IsMemberBaja) {
    Write-Host "[ERROR] El usuario '$UserBajaInput' NO es miembro de '$GroupName'." -ForegroundColor Red
    Write-Host "Proceso abortado." -ForegroundColor Yellow
    Exit
} else {
    Write-Host "[OK] Confirmado: El usuario es miembro de '$GroupName'." -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# 2. SOLICITAR USUARIO DE ALTA Y VERIFICAR EXISTENCIA
# ------------------------------------------------------------------------------
Write-Host ""
$UserAltaInput = Read-Host "Introduzca el usuario (SAMAccountName) que desea dar de ALTA"

Write-Host "`nBuscando al usuario '$UserAltaInput' en todo el directorio (Catalogo Global)..." -ForegroundColor Yellow

try {
    $UserAlta = Get-ADUser -Filter "SamAccountName -eq '$UserAltaInput'" -Server $GCServer
    if (-not $UserAlta) {
        Write-Host "[ERROR] El usuario de alta '$UserAltaInput' no existe en el directorio." -ForegroundColor Red
        Write-Host "Proceso abortado." -ForegroundColor Yellow
        Exit
    }
    Write-Host "[OK] Usuario de alta verificado: $($UserAlta.DistinguishedName)" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Fallo al consultar el Catalogo Global ($GCServer)." -ForegroundColor Red
    Write-Error $_.Exception.Message
    Exit
}

# Verificar si el usuario de alta ya es miembro del grupo mediante filtro LDAP
$IsMemberAlta = Get-ADGroup -LDAPFilter "(&(distinguishedName=$($Group.DistinguishedName))(member=$($UserAlta.DistinguishedName)))" -Server $Domain
if ($IsMemberAlta) {
    Write-Host "[ADVERTENCIA] El usuario '$UserAltaInput' ya es miembro del grupo '$GroupName'." -ForegroundColor Yellow
}

# ------------------------------------------------------------------------------
# 3. RESUMEN DE CAMBIOS Y CONFIRMACION DE OPERADOR
# ------------------------------------------------------------------------------
Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "                  RESUMEN DE OPERACION" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " * BAJA: $($UserBaja.SamAccountName) ($($UserBaja.Name))" -ForegroundColor Red
Write-Host " * ALTA: $($UserAlta.SamAccountName) ($($UserAlta.Name))" -ForegroundColor Green
Write-Host " * GRUPO: $GroupName" -ForegroundColor Yellow
Write-Host "----------------------------------------------------------" -ForegroundColor Cyan

$Confirmacion = Read-Host "Esta seguro de que desea aplicar estos cambios? (S/N)"

# Verificar la confirmacion del operador
if ($Confirmacion -eq 'S' -or $Confirmacion -eq 's') {
    try {
        # Ejecutar la Baja
        Remove-ADGroupMember -Identity $GroupName -Members $UserBaja.DistinguishedName -Server $Domain -Confirm:$false
        Write-Host "[OK] Baja realizada: '$($UserBaja.SamAccountName)' ha sido eliminado de '$GroupName'." -ForegroundColor Green

        # Ejecutar el Alta
        if (-not $IsMemberAlta) {
            Add-ADGroupMember -Identity $GroupName -Members $UserAlta.DistinguishedName -Server $Domain
            Write-Host "[OK] Alta realizada: '$($UserAlta.SamAccountName)' ha sido agregado a '$GroupName'." -ForegroundColor Green
        } else {
            Write-Host "[INFO] Se omitio el alta de '$($UserAlta.SamAccountName)' porque ya pertenecia al grupo." -ForegroundColor Yellow
        }

        Write-Host "`nOperaciones completadas con exito!" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Ocurrio un fallo al modificar los miembros del grupo." -ForegroundColor Red
        Write-Error $_.Exception.Message
    }
} else {
    Write-Host "`nOperacion cancelada. No se ha realizado ninguna modificacion." -ForegroundColor Yellow
}