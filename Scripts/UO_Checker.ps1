<#
# Definir el dominio raíz
$dominios = @(
    "justicia.junta-andalucia.es",
    "almeria.justicia.junta-andalucia.es",
    "cadiz.justicia.junta-andalucia.es",
    "cordoba.justicia.junta-andalucia.es",
    "formacion.justicia.junta-andalucia.es",
    "granada.justicia.junta-andalucia.es",
    "huelva.justicia.junta-andalucia.es",
    "jaen.justicia.junta-andalucia.es",
    "malaga.justicia.junta-andalucia.es",
    "sevilla.justicia.junta-andalucia.es",
    "vdi.justicia.junta-andalucia.es"
)

# Recorremos cada dominio y extraemos UOs y objetos
foreach ($dominio in $dominios) {
    Write-Output "Dominio: $dominio"

    # Obtener todas las UOs en el dominio
    $OUs = Get-ADOrganizationalUnit -Filter * -Server $dominio | Select-Object Name, DistinguishedName

    foreach ($OU in $OUs) {
        Write-Output "`tUO: $($OU.Name) - $($OU.DistinguishedName)"

        # Obtener los objetos dentro de la UO
        $objetos = Get-ADObject -SearchBase $OU.DistinguishedName -Filter * -Server $dominio | Select-Object Name, DistinguishedName

        foreach ($objeto in $objetos) {
            Write-Output "`t`tObjeto: $($objeto.Name) - $($objeto.DistinguishedName)"
        }
    }
}
#>
$lista = @()

foreach ($dominio in $dominios) {
    $OUs = Get-ADOrganizationalUnit -Filter * -Server $dominio | Select-Object Name, DistinguishedName

    foreach ($OU in $OUs) {
        $objetos = Get-ADObject -SearchBase $OU.DistinguishedName -Filter * -Server $dominio | Select-Object Name, DistinguishedName

        foreach ($objeto in $objetos) {
            $lista += [PSCustomObject]@{
                Dominio = $dominio
                UO = $OU.Name
                UO_DistinguishedName = $OU.DistinguishedName
                Objeto = $objeto.Name
                Objeto_DistinguishedName = $objeto.DistinguishedName
            }
        }
    }
}

$lista | Export-Csv -Path "E:\Users\dlunag\AD_UOs_Objetos.csv" -NoTypeInformation -Encoding UTF8 -delimiter ";"
