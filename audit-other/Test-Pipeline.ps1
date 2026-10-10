param([string]$Repo=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$dir=Join-Path $PSScriptRoot 'pipeline-fixture'
try {
    $null=New-Item $dir -ItemType Directory -Force
    $null=New-Item (Join-Path $dir 'wiki') -ItemType Directory -Force
    Copy-Item (Join-Path $Repo 'Proyecto_HD/ods_processor.ps1') (Join-Path $dir 'ods_processor.ps1')
    $row=@('header','1','fixture description','fixture class','fixture type','fixture category','','','fixture group','fixture level','','')
    @{Nuevo_Adriano=@(,$row)} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $dir 'ods_data.json') -Encoding UTF8
    & (Join-Path $dir 'ods_processor.ps1') | Out-Null
    $ods=Get-Content (Join-Path $dir 'ods_data.js') -Raw -Encoding UTF8
    if ($ods -notmatch 'const ODS_CASOS = \[' -or $ods -notmatch 'total:1' -or $ods -notmatch 'fixture description') { throw 'FAIL: ODS generator synthetic single row' }
    $wikiFile=Join-Path $dir 'wiki-fixture.js'
    & (Join-Path $Repo 'Proyecto_HD/process_wiki.ps1') -WikiDir (Join-Path $dir 'wiki') -OutFile $wikiFile | Out-Null
    $wiki=Get-Content $wikiFile -Raw -Encoding UTF8
    if ($wiki -notmatch 'WIKI_ROUTING' -or $wiki -notmatch 'WIKI_STATS') { throw 'FAIL: wiki generator synthetic empty input' }
    Write-Output 'PASS: ODS and wiki generators executed on isolated synthetic files; no corporate data'
} finally { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
