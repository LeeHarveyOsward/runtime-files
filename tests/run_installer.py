"""Run the actual Windows PowerShell installer against isolated installations."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ps = 'C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'
result = subprocess.run([ps, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                         str(ROOT/'tests/installer_spec.ps1')], capture_output=True, text=True)
print(result.stdout)
print(result.stderr, file=sys.stderr)
passed = result.returncode == 0 and 'PASS:' in result.stdout
report = dict(passed=passed, code=result.returncode, output=result.stdout, error=result.stderr,
              hashes={p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in
                      ('installer/install.ps1', 'tools/build_installer_manifest.py', 'tests/installer_spec.ps1')})
(ROOT/'tests/results').mkdir(parents=True, exist_ok=True)
(ROOT/'tests/results/installer-tests.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
raise SystemExit(0 if passed else 1)
