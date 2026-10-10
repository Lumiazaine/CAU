import json, pathlib, re, subprocess, sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
SCOPES=['Scripts','Directorio correo','Temis','lazydirectory','lazytemis','Proyecto_HD','Macro Remedy','Otras herramientas','Otros_AD','Bateria de pruebas','@web']
PATTERNS={
 'tls_validation_bypass':r'ServerCertificateValidationCallback|SkipCertificateCheck|TrustAllCert|ICertificatePolicy',
 'plaintext_http':r'http://(?!localhost|127\.0\.0\.1)',
 'remote_evaluation':r'Invoke-Expression|\bIEX\b|scriptblock\]::Create.*\birm\b',
 'plaintext_credential_store':r'ADMIN_PASS|savecred|AccountPassword.*securePassword',
 'password_output':r'(?:Write-Log|Write-Host|echo).*(?:\$NewPassword|\$newPass|\$password|%pass%)',
 'ldap_dynamic_filter':r'LDAPFilter|DirectorySearcher|\.Filter\s*=',
 'destructive':r'New-ADUser|Set-ADUser|Set-ADAccountPassword|REG ADD|Remove-Item|EnableStatic|SetGateways|SetDNSServerSearchOrder',
 'embedded_session_cookie':r'newCookie\s+|Cookies\.Add',
 'external_http_api':r'Invoke-WebRequest|Invoke-RestMethod|URLDownloadToFile|DownloadFile|https?://raw\.githubusercontent',
}
files=[]
for s in SCOPES:
 for p in sorted((ROOT/s).rglob('*')):
  if not p.is_file():continue
  entry={'path':str(p.relative_to(ROOT)),'bytes':p.stat().st_size,'kind':p.suffix.lower(),'findings':[]}
  if p.suffix.lower() in ['.ps1','.psm1','.bat','.ahk','.py','.html','.js','.ini']:
   text=p.read_text(errors='replace')
   for kind,pattern in PATTERNS.items():
    lines=[i for i,line in enumerate(text.splitlines(),1) if re.search(pattern,line,re.I)]
    if lines:entry['findings'].append({'type':kind,'lines':lines})
  files.append(entry)
(root_out:=ROOT/'audit-other'/'static-inventory.json').write_text(json.dumps(files,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'files':len(files),'findings':[{'path':f['path'],'types':f['findings']} for f in files if f['findings']]},ensure_ascii=False,indent=2))
