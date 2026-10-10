param([string]$Repo=(Split-Path $PSScriptRoot -Parent),[string]$Case='anonymous')
$ErrorActionPreference='Stop'
function Load-Fn($Name) {
 $t=$null;$e=$null
 $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo 'Proyecto_HD/servidor_helpdesk.ps1'),[ref]$t,[ref]$e)
 if($e.Count){throw 'FAIL: production parser'}
 $fn=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name},$true)
 if(-not $fn){throw "FAIL: missing $Name"}
 . ([scriptblock]::Create($fn.Extent.Text.Replace("function $Name", "function script:$Name")))
}
# Real handler, synthetic request/response; never invoke Remedy.
Load-Fn 'Handle-Request'
foreach($name in @('Get-HelpdeskRequestStatus','Test-HelpdeskToken')) {
 $t=$null;$e=$null;$a=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo 'Proyecto_HD/servidor_helpdesk.ps1'),[ref]$t,[ref]$e)
 if($a.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)){Load-Fn $name}
}
$script:port=8080
$token='OFFLINE-fixture-token-abcdefghijklmnopqrstuvwxyz-0123456789'
$sha=[Security.Cryptography.SHA256]::Create()
try{$script:tokenHash=$sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($token))}finally{$sha.Dispose()}
$script:cache=@{entries=@(@{id='IN123';desc='SYNTHETIC-PRIVATE'});status='ready';time=Get-Date}
$script:detailCalls=0
function Get-TicketDetail {param($id);$script:detailCalls++;return @{id=$id;dni='SYNTHETIC-PRIVATE'}}
function Write-Log {param($msg)}
$headers=New-Object Net.WebHeaderCollection
$headers['Host']='localhost:8080'
$headers['Authorization']='Bearer '+$token
$url='http://localhost:8080/api/helpdesk'
$method='GET';$expected=200
switch($Case){
 'anonymous' {$headers.Remove('Authorization');$expected=401}
 'wrong-token' {$headers['Authorization']='Bearer WRONG';$expected=401}
 'cross-origin' {$headers['Origin']='https://evil.invalid';$expected=403}
 'file-origin' {$headers['Origin']='null';$expected=403}
 'spoof-host' {$headers['Host']='evil.invalid:8080';$expected=403}
 'post' {$method='POST';$expected=405}
 'query-token' {$headers.Remove('Authorization');$url+='?token='+$token;$expected=400}
 'detail-anonymous' {$headers.Remove('Authorization');$url+='/IN123';$expected=401}
 'status-anonymous' {$headers.Remove('Authorization');$url+='/status';$expected=401}
 'public-page' {$url='http://localhost:8080/';$headers.Remove('Authorization');$script:dashboardRoot=Join-Path $Repo 'Proyecto_HD'}
 'private-asset' {$url='http://localhost:8080/predictor_data.js';$headers.Remove('Authorization');$expected=401}
 'traversal' {$url='http://localhost:8080/secret.env';$expected=404}
 'same-origin' {$headers['Origin']='http://localhost:8080'}
 'no-origin' {}
 default {throw 'unknown test'}
}
$stream=New-Object IO.MemoryStream
$resp=[pscustomobject]@{StatusCode=0;Headers=(New-Object Net.WebHeaderCollection);ContentType='';ContentLength64=0;OutputStream=$stream}
$req=[pscustomobject]@{Url=[uri]$url;Headers=$headers;HttpMethod=$method}
Handle-Request ([pscustomobject]@{Request=$req;Response=$resp})
$text=[Text.Encoding]::UTF8.GetString($stream.ToArray())
if($resp.StatusCode -ne $expected){throw "FAIL: $Case expected HTTP$expected got HTTP$($resp.StatusCode)"}
if($expected -ne 200 -and ($text.Contains('SYNTHETIC-PRIVATE') -or $script:detailCalls)){throw 'FAIL: rejected request accessed private data'}
if($resp.Headers['Access-Control-Allow-Origin']){throw 'FAIL: CORS present'}
if($resp.Headers['Cache-Control'] -ne 'no-store'){throw 'FAIL: response caching enabled'}
Write-Output "PASS: $Case"
