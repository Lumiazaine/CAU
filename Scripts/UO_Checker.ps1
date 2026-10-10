#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
    [ValidateScript({ $_ -match '^(?=.{1,253}$)[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?$' -and $_ -notmatch '\.\.|\.-|-\.' })]
    [string[]]$Domains,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
    [ValidateScript({[IO.Path]::IsPathRooted($_) -and [IO.Path]::GetExtension($_) -eq '.csv' -and (Test-Path -LiteralPath (Split-Path -Parent $_) -PathType Container)})]
    [string]$OutputPath,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
# Complete all read-only queries before creating output. Never silently export an empty CSV.
if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) { throw 'Salida existente; use -Force para reemplazar explicitamente.' }
$rows = @(
    foreach ($domain in $Domains) {
        $ous = Get-ADOrganizationalUnit -Filter * -Server $domain -ErrorAction Stop
        foreach ($ou in $ous) {
            $objects = Get-ADObject -SearchBase $ou.DistinguishedName -Filter * -Server $domain -ErrorAction Stop
            foreach ($object in $objects) {
                [pscustomobject]@{
                    Dominio = $domain
                    UO = $ou.Name
                    UO_DistinguishedName = $ou.DistinguishedName
                    Objeto = $object.Name
                    Objeto_DistinguishedName = $object.DistinguishedName
                }
            }
        }
    }
)
if ($rows.Count -eq 0) { throw 'Consulta sin objetos; no se genera CSV vacio.' }
$rows | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8 -Delimiter ';'
Write-Output "Exportados $($rows.Count) objetos a $OutputPath"
