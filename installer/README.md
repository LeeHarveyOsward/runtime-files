# Runtime scripts

Install Orbama, LeeHarveyOsward, or ClassicAIO for Orbama by pressing **Win+R** and
pasting:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/LeeHarveyOsward/runtime-files/main/install.ps1 | iex"
```

Choose scripts in the installer. It locates your GamingOnSteroids folder, installs
dependencies, and enables the selected scripts in `LocalScriptDB.ini`.
Reload the script runtime yourself when installation finishes.

See [installation, updates and rollback](INSTALL.md) for details.
