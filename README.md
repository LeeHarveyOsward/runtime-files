# Runtime scripts

Install all scripts by pressing **Win+R** and
pasting:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/LeeHarveyOsward/runtime-files/main/install.ps1 | iex"
```

The installer locates your GamingOnSteroids folder, installs all published scripts
and dependencies, and enables them in `LocalScriptDB.ini` without a selection menu.
Reload the script runtime yourself when installation finishes.

See [installation, updates and rollback](INSTALL.md) for details.
