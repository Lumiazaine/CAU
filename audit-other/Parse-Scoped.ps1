param([string]$Repo=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$results=@()
foreach($file in Get-ChildItem $Repo -Recurse -File | Where-Object {$_.Extension -in '.ps1','.psm1' -and $_.DirectoryName -notmatch '\\audit-other$'}) {
    $t=$null;$e=$null
    $null=[System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$t,[ref]$e)
    $fileErrors=@($e | ForEach-Object {[pscustomobject]@{Id=$_.ErrorId;Line=$_.Extent.StartLineNumber}})
    $null=[System.Management.Automation.Language.Parser]::ParseInput([System.IO.File]::ReadAllText($file.FullName,[System.Text.Encoding]::UTF8),[ref]$t,[ref]$e)
    $utf8Errors=@($e | ForEach-Object {[pscustomobject]@{Id=$_.ErrorId;Line=$_.Extent.StartLineNumber}})
    $results+=[pscustomobject]@{File=$file.FullName.Substring($Repo.Length).TrimStart('\','/');FileErrors=$fileErrors;Utf8Errors=$utf8Errors}
}
[pscustomobject]@{PS=$PSVersionTable.PSVersion.ToString();Files=$results.Count;FailedFile=@($results | Where-Object {$_.FileErrors.Count}).Count;FailedUtf8=@($results | Where-Object {$_.Utf8Errors.Count}).Count;Results=$results} | ConvertTo-Json -Depth 8
