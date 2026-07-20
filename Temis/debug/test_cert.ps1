$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -match 'LUNA GONZALEZ DAVID|29567764E' } | Select-Object -First 1
Write-Host ("Certificado: " + $cert.Subject) -ForegroundColor Cyan

$url = 'https://escritoriojudicial.justicia.junta-andalucia.es/Escritorio/AccesoCertificado.do'
try {
    $r = Invoke-WebRequest -Uri $url -Certificate $cert -UseBasicParsing -SessionVariable 'ses' -ErrorAction Stop
    Write-Host ("Status: " + $r.StatusCode) -ForegroundColor Green
    $cookieHeaders = $r.Headers['Set-Cookie']
    if ($cookieHeaders) { Write-Host ("Cookies: " + ($cookieHeaders -join '; ')) -ForegroundColor Yellow }
    $text = $r.Content.Substring(0, [Math]::Min(500, $r.Content.Length))
    Write-Host ("Content: " + $text) -ForegroundColor Gray
} catch {
    Write-Host ("ERROR: " + ($_ | Out-String)) -ForegroundColor Red
}
