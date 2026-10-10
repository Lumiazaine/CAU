# Static security contracts only. Never execute legacy AD entrypoints or batch macros.
from pathlib import Path
import re, unittest
ROOT=Path(__file__).resolve().parents[1]
class LegacyCredentialTests(unittest.TestCase):
 def test_legacy_ad_requires_secure_input(self):
  for rel in ['Otros_AD/ADaltas.ps1','Otros_AD/AltasAD.ps1']:
   with self.subTest(file=rel):
    s=(ROOT/rel).read_text(encoding='utf-8-sig')
    self.assertFalse(bool(re.search(r'''(?i)ConvertTo-SecureString\s+['"]''',s)), 'embedded password (value omitted)')
    self.assertTrue(bool(re.search(r'(?is)Parameter\(Mandatory\s*=\s*\$true\).*?\[Security\.SecureString\]\$AccountPassword',s)), 'explicit SecureString input absent (source omitted)')
if __name__=='__main__':unittest.main()
