param([string]$Repo = (Split-Path $PSScriptRoot -Parent), [string]$Case = 'temis-entities')
$ErrorActionPreference = 'Stop'
# Only reviewed function ASTs are loaded. Never dot-source production entrypoints.
function Load-ReviewedFunction([string]$File, [string]$Name) {
    $tokens=$null; $errors=$null
    $ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo $File),[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw 'Production parse failed' }
    $fn=$ast.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name},$true)
    if (-not $fn) { throw "Missing reviewed function: $Name" }
    . ([scriptblock]::Create($fn.Extent.Text.Replace("function $Name", "function script:$Name")))
}
function Assert-Equal($Actual,$Expected,[string]$Label) {
    if ($Actual -cne $Expected) { throw "FAIL: $Label (values omitted)" }
}
switch ($Case) {
    'temis-entities' {
        Load-ReviewedFunction 'Temis/cambiar_password_temis.ps1' 'Extract-FormFields'
        $f=Extract-FormFields '<form action="UsuarioGuardarModificar"><textarea name="note">&#65; &amp; &#x42;</textarea><input name="token" value="A&amp;B"></form>'
        Assert-Equal $f.note 'A & B' 'textarea numeric entities on PS5.1'
        Assert-Equal $f.token 'A&B' 'input entity decode'
    }
    'lazytemis-multiline' {
        Load-ReviewedFunction 'lazytemis/lazytemis.ps1' 'Extract-ProfileFields'
        $f=Extract-ProfileFields "<textarea name=`"note`">line1`nline2 &quot;ok&quot;</textarea><select name=`"cargo`">`n<option value=`"B`" selected>B</option>`n</select>"
        Assert-Equal $f.note "line1`nline2 `"ok`"" 'multiline textarea'
        Assert-Equal $f.cargo 'B' 'multiline selected option'
    }
    'lazydirectory-fields' {
        Load-ReviewedFunction 'lazydirectory/lazydirectory.ps1' 'Extract-FormFields'
        $f=Extract-FormFields "<input name='token' value='A&amp;B'><input value='x&amp;y' name='reverse'><textarea name='note'>line1`nline2 &quot;ok&quot;</textarea><select name='cargo'>`n<option value='B' selected>B</option>`n</select>"
        Assert-Equal $f.token 'A&B' 'input entity decode'
        Assert-Equal $f.reverse 'x&y' 'reverse attribute order'
        Assert-Equal $f.note "line1`nline2 `"ok`"" 'multiline textarea'
        Assert-Equal $f.cargo_value 'B' 'multiline selected option'
    }
    'correo-field' {
        Load-ReviewedFunction 'Directorio correo/cambiar_password_correo.ps1' 'Extract-FormField'
        Assert-Equal (Extract-FormField '<input name="token" value="A&amp;B">' 'token') 'A&B' 'entity decode'
    }
    'cache-empty' {
        Load-ReviewedFunction 'Proyecto_HD/servidor_helpdesk.ps1' 'Refresh-Cache'
        function Get-HelpdeskEntries { return ,@() }
        function Write-Log { param($msg) }
        $script:lock=New-Object System.Threading.Mutex $false
        try {
            Refresh-Cache
            Assert-Equal $script:cache.status 'ready' 'zero tickets is successful query'
            Assert-Equal $script:cache.entries.Count 0 'zero count'
        } finally { $script:lock.Dispose() }
    }
    'query-return-shape' {
        $t=$null;$e=$null
        $ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo 'Proyecto_HD/servidor_helpdesk.ps1'),[ref]$t,[ref]$e)
        $fn=$ast.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-HelpdeskEntries'},$true)
        $return=$fn.Find({param($n) $n -is [System.Management.Automation.Language.ReturnStatementAst] -and $n.Extent.Text -match '\$result'},$true)
        # Run only the real return expression with an empty fixture; no COM call.
        $shape=& ([scriptblock]::Create('$result=@(); '+$return.Extent.Text))
        if ($null -eq $shape) { throw 'FAIL: empty successful query collapses to null' }
        Assert-Equal $shape.Count 0 'empty successful query retains array'
    }
    'cache-response-empty' {
        Load-ReviewedFunction 'Proyecto_HD/servidor_helpdesk.ps1' 'Handle-Request'
        Load-ReviewedFunction 'Proyecto_HD/servidor_helpdesk.ps1' 'Get-HelpdeskRequestStatus'
        Load-ReviewedFunction 'Proyecto_HD/servidor_helpdesk.ps1' 'Test-HelpdeskToken'
        $script:port=8080
        $token='OFFLINE-fixture-token-abcdefghijklmnopqrstuvwxyz-0123456789'
        $sha=[Security.Cryptography.SHA256]::Create()
        try { $script:tokenHash=$sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($token)) } finally { $sha.Dispose() }
        $headers=New-Object Net.WebHeaderCollection
        $headers['Host']='localhost:8080'; $headers['Authorization']='Bearer '+$token
        $script:cache=@{entries=@();status='ready';time=Get-Date}
        $stream=New-Object System.IO.MemoryStream
        $response=[pscustomobject]@{StatusCode=0;Headers=(New-Object System.Net.WebHeaderCollection);ContentType='';ContentLength64=0;OutputStream=$stream}
        $ctx=[pscustomobject]@{Request=[pscustomobject]@{Url=[uri]'http://localhost:8080/api/helpdesk';Headers=$headers;HttpMethod='GET'};Response=$response}
        Handle-Request $ctx
        $json=[Text.Encoding]::UTF8.GetString($stream.ToArray()) | ConvertFrom-Json
        Assert-Equal $response.StatusCode 200 'empty ready cache returns HTTP200'
        Assert-Equal $json.ok $true 'empty ready cache is success'
        Assert-Equal $json.count 0 'empty ready cache count'
    }
    'macro-entries' {
        Load-ReviewedFunction 'Macro Remedy/verificar_indices.ps1' 'Convertir-Entradas'
        $entries=@(Convertir-Entradas @('M["Fixture"] := 45','    M["Other"] := 0'))
        Assert-Equal $entries.Count 2 'AHK v2 indexed Map assignments recognized'
        Assert-Equal $entries[0].Indice 45 'macro index retained'
        $legacy=@(Convertir-Entradas @('"Fixture": 45,'))
        Assert-Equal $legacy.Count 1 'legacy literal map retained'
    }
    'criticas-array' {
        Load-ReviewedFunction 'Proyecto_HD/scraper_criticas.ps1' 'Write-CriticasJs'
        function Write-Log { param($msg) }
        $script:outJs=Join-Path $PSScriptRoot 'criticas-fixture.js'
        try {
            Write-CriticasJs @{id='OFFLINE'}
            $generated=Get-Content $script:outJs -Raw
            if ($generated -notmatch '^window\.CRITICAS_DATA = \[') { throw 'FAIL: one critical ticket must serialize as JS array' }
            Write-CriticasJs @()
            Assert-Equal ((Get-Content $script:outJs -Raw).Trim()) 'window.CRITICAS_DATA = [];' 'empty critical tickets serialize as array'
        } finally { Remove-Item $script:outJs -ErrorAction SilentlyContinue }
    }
    'wiki-functions' {
        Load-ReviewedFunction 'Proyecto_HD/process_wiki.ps1' 'Strip-Wiki'
        Assert-Equal (Strip-Wiki '<WRAP>**fixture** [[namespace:page|Label]] {{image}}</WRAP>') 'fixture Label' 'wiki markup stripping'
        Load-ReviewedFunction 'Proyecto_HD/scrape_wiki.ps1' 'Extract-Links'
        $links=Extract-Links '[[fixture:page|label]] [[https://offline.invalid]] [[start]]'
        Assert-Equal $links.Count 1 'internal links only'
        Assert-Equal $links.ContainsKey('fixture:page') $true 'internal link retained'
    }
    'all' {
        foreach ($c in @('temis-entities','lazytemis-multiline','lazydirectory-fields','correo-field','cache-empty','query-return-shape','cache-response-empty','macro-entries','criticas-array','wiki-functions')) {
            & $PSCommandPath -Repo $Repo -Case $c
        }
    }
    default { throw 'Unknown test case' }
}
Write-Output "PASS: $Case"
