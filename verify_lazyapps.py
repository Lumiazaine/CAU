#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verificación estática de los parsers de lazydirectory contra los HTMLs reales de debug."""
import re, sys, glob, os

DEBUG = os.path.expanduser("~/CAU/lazydirectory/debug")

def clean(s):
    s = re.sub(r'<[^>]+>', '', s)
    s = s.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>')
    s = re.sub(r'\s+', ' ', s)
    return s.strip()

def test_search_partial(html):
    """Réplica del parser de filas de Search-User (lazydirectory)."""
    users = []
    seen = set()
    rows = re.findall(r'(?s)<div\s+class="fila_(?:par|impar)"[^>]*>.*?</div>', html)
    for row in rows:
        spans = re.findall(r'<span\s+class="campo ancho2">(.*?)</span>', row)
        email = clean(spans[0]) if len(spans) >= 1 else ''
        name = clean(spans[1]) if len(spans) >= 2 else ''
        m = re.search(r"enviar\('[^']+','[^']+','uid=([^,]+)", row)
        uid = m.group(1).lower() if m else ''
        if not uid:
            m2 = re.match(r'^([^@]+)@', email)
            uid = m2.group(1).lower() if m2 else ''
        if not uid or uid in seen:
            continue
        seen.add(uid)
        parts = re.split(r'\s+', name, 1)
        users.append({'uid': uid, 'nombre': parts[0] if parts else '', 'apellidos': parts[1] if len(parts) > 1 else '', 'email': email})
    return users

def test_exact_hit(html):
    """Réplica del exact-hit: name="dn" aparece exactamente 1 vez."""
    dns = re.findall(r'name="dn"\s*value="([^"]+)"', html)
    return dns

def test_form_fields(html):
    """Réplica de Extract-FormFields (inputs con name+value, ambos órdenes)."""
    fields = {}
    re1 = re.compile(r'<input[^>]*?\bname\s*=\s*(["\'])([^"\']*?)\1[^>]*?\bvalue\s*=\s*(["\'])([^"\']*?)\3[^>]*?>')
    for m in re1.finditer(html):
        fields[m.group(2)] = m.group(4)
    re2 = re.compile(r'<input[^>]*?\bvalue\s*=\s*(["\'])([^"\']*?)\1[^>]*?\bname\s*=\s*(["\'])([^"\']*?)\3[^>]*?>')
    for m in re2.finditer(html):
        fields[m.group(4)] = m.group(2)
    return fields

def test_display_data(html):
    """Réplica de Extract-DisplayData (form_field label/value)."""
    pairs = re.findall(r'(?s)<div\s+class="form_field">.*?<div\s+class="form_field_label[^"]*">(.*?)</div>\s*<div\s+class="form_field_value[^"]*">(.*?)</div>', html)
    out = []
    for label, val in pairs:
        lt, vt = clean(label), clean(val)
        if lt and vt and not re.search(r'<(input|select|textarea)\b', val):
            out.append((lt, vt))
    return out

print("=" * 70)
print("VERIFICACION DE PARSERS vs HTMLs REALES DE DEBUG")
print("=" * 70)

for f in sorted(glob.glob(os.path.join(DEBUG, 'search_*.html'))):
    html = open(f, encoding='utf-8', errors='replace').read()
    users = test_search_partial(html)
    dns = test_exact_hit(html)
    name = os.path.basename(f)
    print(f"\n--- {name} ({len(html)} bytes) ---")
    print(f"  exact-hit (name=dn): {len(dns)} ocurrencia(s)")
    if len(dns) == 1:
        print(f"    DN: {dns[0][:80]}")
    print(f"  filas parseadas (Search-User parcial): {len(users)}")
    for u in users[:6]:
        print(f"    - uid={u['uid']!r} nombre={u['nombre']!r} apellidos={u['apellidos']!r} email={u['email']!r}")

for f in sorted(glob.glob(os.path.join(DEBUG, 'profile_*.html'))):
    html = open(f, encoding='utf-8', errors='replace').read()
    name = os.path.basename(f)
    dns = test_exact_hit(html)
    fields = test_form_fields(html)
    disp = test_display_data(html)
    print(f"\n--- {name} ({len(html)} bytes) ---")
    print(f"  name=dn: {len(dns)}  | campos input extraidos: {len(fields)}  | pares label/value: {len(disp)}")
    for k in ['uid', 'dn', 'mail', 'cn', 'sn', 'description', 'tipoEntrada']:
        if k in fields:
            print(f"    campo {k!r}: {str(fields[k])[:70]!r}")
    # ¿DNI en el HTML? (verificación de fuga)
    dnis = re.findall(r'\b\d{8}[A-Z]\b', html)
    emails = re.findall(r'[\w.\-]+@(?:justicia|juntadeandalucia)\.es', html)
    if dnis:
        print(f"    ⚠️  DNI(s) presentes en el HTML: {sorted(set(dnis))}")
    if emails:
        print(f"    ⚠️  Email(s) presentes: {sorted(set(emails))[:4]}")

# Verificación del filtro de SirhusBajas (spans width)
print("\n" + "=" * 70)
print("OTRAS VERIFICACIONES")
print("=" * 70)
# ¿bar/empty usadas en lazydirectory? (código muerto)
src = open(os.path.expanduser("~/CAU/lazydirectory/lazydirectory.ps1"), encoding='utf-8').read()
for fn in ['bar', 'empty', 'Parse-SelectOptions', 'Select-Option']:
    uses = len(re.findall(rf'\b{fn}\b', src))
    defs = len(re.findall(rf'function\s+{fn}\b', src))
    print(f"  {fn}: definiciones={defs}, menciones totales={uses}")

# Balance de llaves/paréntesis (sanidad sintáctica básica)
for f in ['lazydirectory/lazydirectory.ps1', 'lazytemis/lazytemis.ps1']:
    s = open(os.path.expanduser("~/" + "CAU/" + f), encoding='utf-8').read()
    bal = {c: s.count(c) for c in '{}()[]'}
    print(f"  {f}: balance {{}}={bal['{'] - bal['}']} ()={bal['('] - bal[')']} []={bal['['] - bal[']']}")
print("\nVERIFICACION COMPLETA")
