"""Describe the published standalone packages, not development Lua bundles."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGES = (
    ('orbama', 'Orbama', 'Orbama.lua', [], ['GGOrbwalker.lua']),
    ('lho', 'LeeHarveyOsward (Lee Sin)', 'LeeHarveyOsward.lua', ['orbama'], []),
    ('classic', 'ClassicAIO for Orbama (Classic mode)', 'ClassicAIO_Orbama.lua', ['orbama'],
     ['ClassicAIO.lua', 'ClassicAIOv2.lua']),
    ('evade', 'Orbama Evade', 'OrbamaEvade.lua', ['orbama'], []),
    ('katahari', 'Kata Hari (Katarina)', 'KataHari.lua', ['orbama'], ['Katarina.lua']),
    ('cardmarx', 'Card Marx (Twisted Fate)', 'CardMarx.lua', ['orbama'], ['TwistedFate.lua']),
)


def installer_files(files, version):
    packages = []
    for identity, label, filename, dependencies, disable in PACKAGES:
        data = files[filename]
        packages.append(dict(id=identity, name=label, version=str(version), depends=dependencies,
                             enable=[filename], disable=disable,
                             files=[dict(source=filename, destination='LOLEXT/Scripts/' + filename,
                                         sha256=hashlib.sha256(data).hexdigest(), size=len(data))]))
    manifest = dict(schema=1, repository='LeeHarveyOsward/runtime-files', release=str(version), packages=packages)
    return {
        'install.ps1': (ROOT/'installer/install.ps1').read_bytes(),
        'installer-manifest.json': (json.dumps(manifest, indent=2)+'\n').encode(),
        'INSTALL.md': (ROOT/'installer/INSTALL.md').read_bytes(),
        'README.md': (ROOT/'installer/README.md').read_bytes(),
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime-root', type=Path, required=True)
    parser.add_argument('--version', required=True)
    args = parser.parse_args()
    files = {row[2]: (args.runtime_root/row[2]).read_bytes() for row in PACKAGES}
    for name, body in installer_files(files, args.version).items():
        (args.runtime_root/name).write_bytes(body)
