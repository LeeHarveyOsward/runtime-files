# Install or update scripts

Press **Win+R**, paste this command, and press Enter:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/LeeHarveyOsward/runtime-files/main/install.ps1 | iex"
```

The command executes this repository's PowerShell installer. It needs Windows
PowerShell 5.1 and HTTPS access to GitHub. No Git or Python installation is needed.

Choose the scripts you want. Required dependencies are included automatically.
The installer detects a running program with an adjacent
`GamingOnSteroids/LOLEXT/Scripts` directory, regardless of program name or extension.
If several installations match, choose one. If none match, select the
`GamingOnSteroids` folder in the folder picker or enter its path.
When WMI omits an executable path, the installer tries Windows'
`QueryFullProcessImageNameW` API with limited query access. This can find hosts
whose paths WMI hides without requesting administrator access. If both methods
are denied, the folder picker remains available. You can also select the folder
when the host is not running.

Files are installed beneath that folder. Selected loader scripts are registered
with `ACTIVE = 1` in `LOLEXT/LocalScriptDB.ini`. New sections have a blank `UPDATE =`
line for compatibility. Existing `UPDATE` values and unrelated settings are kept.
The Lua scripts retain their own autoupdaters.

Orbama disables the known `GGOrbwalker.lua` loader entry to prevent two providers
loading together. Classic disables the old `ClassicAIO.lua` and `ClassicAIOv2.lua`
entries. The installer displays these changes before applying them. It does not
attempt to identify every third-party script or provider. Shared libraries and
assets are never registered as loader entries.

Reload the complete script runtime yourself after installation. The installer
does not stop any process or reload scripts. Newly copied files are not proof
that the running game has loaded them.

Run the same command again to update installed packages or add packages. The
installer remembers packages in `.runtime-files/installed.json`. Existing managed
packages are updated together to the selected publication. A locally modified
managed file is backed up before replacement. Unrelated files are preserved.

## Versions and recovery

Each run resolves GitHub `main` to one commit and fetches the manifest and all
files from that commit. File lengths and SHA-256 hashes are checked before any
script or INI replacement. The publisher generates the manifest from the actual
public standalone files. These hashes detect mismatched content; they are not
an independent signature of the repository owner.

Backups and transaction journals live in
`GamingOnSteroids/.runtime-files/backups/<transaction>/`. A failed installation
restores scripts, INI and receipt, unless another process has changed one of the
files in the meantime. In that case it retains the backup and reports the conflict
instead of overwriting the newer change. An interrupted transaction must be
recovered before another installation.

For explicit paths, automation, or rollback, download `install.ps1` and run it
from PowerShell:

```powershell
.\install.ps1 -Root 'C:\path\GamingOnSteroids' -Packages lho,classic
.\install.ps1 -Root 'C:\path\GamingOnSteroids' -Rollback
.\install.ps1 -DetectOnly
```

`-Rollback` restores the most recent installation transaction, including loader
settings. It refuses to overwrite files changed since that transaction. Use the
reported backup directory for manual recovery if needed. `-NonInteractive`
requires an unambiguous destination and explicit packages, or an existing receipt.

## Adding packages

Maintain package definitions in `tools/build_installer_manifest.py`. A package
declares dependencies, loader entry points, known conflicting entries and files.
Each file has a repository source path, destination relative to GamingOnSteroids,
byte length and SHA-256 hash. Asset paths can target directories such as
`LOLEXT/Sprites`; they do not need loader entries. Paths outside `LOLEXT`, absolute
paths, traversal, reserved Windows names and reparse points are rejected.

Run the public release builder to include the installer and a matching manifest
in future publications. Do not regenerate a manifest from development scripts
and attach it to different public files.
