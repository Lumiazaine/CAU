
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

$lista = @()

foreach ($dominio in $dominios) {
    $OUs = Get-ADOrganizationalUnit -Filter * -Server $dominio | Select-Object Name, DistinguishedName

    foreach ($OU in $OUs) {

        Invoke-Command -ComputerName localhost -ScriptBlock {
            $dominio = $args[0]
            $ou=$args[1]
            #$lista=$args[2]
            $objetos = Get-ADObject -SearchBase $OU.DistinguishedName -Filter * -Server $dominio | Select-Object Name, DistinguishedName
            foreach ($objeto in $objetos){
               $lista += [PSCustomObject]@{
                  Dominio = $dominio
                  UO = $OU.Name
                  UO_DistinguishedName = $OU.DistinguishedName
                  Objeto = $objeto.Name
                  Objeto_DistinguishedName = $objeto.DistinguishedName
                    }
                }
           } -AsJob -JobName $OU -ArgumentList $dominio,$OU #,$lista
        }
}

$lista | Export-Csv -Path "E:\Users\dlunag\AD_UOs_Objetos2.csv" -NoTypeInformation -Encoding UTF8 -delimiter ";"
