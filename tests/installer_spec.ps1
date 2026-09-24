$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../installer/install.ps1" -LibraryOnly
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('runtime-installer-tests-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($sandbox)
$script:count = 0
function Assert($Condition, [string]$Message) { if (!$Condition) { throw $Message }; $script:count++ }
function Throws([scriptblock]$Action, [string]$Pattern) {
    $caught = $false
    try { & $Action } catch { $caught = $true; Assert ($_.ToString() -match $Pattern) "Wrong error: $_" }
    Assert $caught "Expected error: $Pattern"
}
function Make-Root([string]$Name) {
    $path = Join-Path $sandbox $Name
    [void][IO.Directory]::CreateDirectory((Join-Path $path 'LOLEXT/Scripts'))
    return $path
}
try {
    $root = Make-Root 'host/GamingOnSteroids'
    $other = Make-Root 'second/GamingOnSteroids'
    $processes = @(
        [pscustomobject]@{ExecutablePath=(Join-Path $sandbox 'host/random.exec')},
        [pscustomobject]@{ExecutablePath=(Join-Path $sandbox 'host/unrelated.exe')},
        [pscustomobject]@{ExecutablePath=$null},
        [pscustomobject]@{ExecutablePath=(Join-Path $sandbox 'second/anything.exe')}
    )
    $found = @(Get-RuntimeInstallations $processes)
    Assert ($found.Count -eq 2 -and $root -in $found -and $other -in $found) 'Extension-independent detection and deduplication'
    # WMI often exposes the PID but omits ExecutablePath for the running host.
    $nativePath = Get-RuntimeProcessPath $PID
    Assert ($nativePath -and [IO.Path]::GetFileName($nativePath) -eq 'powershell.exe') 'Actual limited-information native path query'
    Assert (!(Get-RuntimeProcessPath 2147483647)) 'Exited or inaccessible native process is skipped'
    $originalQuery = ${function:Get-RuntimeProcessPath}
    function Get-RuntimeProcessPath([int]$ProcessId) {
        if ($ProcessId -eq 12345) { return Join-Path $sandbox 'host/random.exec' }
        return $null
    }
    try {
        $missingPaths = @([pscustomobject]@{ProcessId=12345; ExecutablePath=$null},
                         [pscustomobject]@{ProcessId=23456; ExecutablePath=$null})
        $found = @(Get-RuntimeInstallations $missingPaths)
        Assert ($found.Count -eq 1 -and $found[0] -eq $root) 'Missing WMI path uses native fallback'
    } finally { ${function:Get-RuntimeProcessPath} = $originalQuery }
    Assert ((Select-RuntimeRoot $root $true) -eq $root) 'Explicit root'
    Throws { Select-RuntimeRoot $sandbox $true } 'Not an installation'
    foreach ($path in @('../escape','LOLEXT/../escape','C:/evil','/absolute','LOLEXT/Scripts/a:stream','LOLEXT/Scripts/CON.lua','LOLEXT/Scripts/x.','LOLEXT\Scripts\x')) {
        Throws { Get-RuntimePath $root $path } 'Invalid'
    }
    $ini = "; user settings`r`n[Other.lua]`r`nACTIVE = 1`r`nUPDATE = keep`r`n`r`n[Orbama.lua]`r`nACTIVE = 0 ; comment`r`nUPDATE = own`r`n[GGOrbwalker.lua]`r`nACTIVE = 1`r`n"
    $updated = Update-RuntimeIni $ini @('Orbama.lua','LeeHarveyOsward.lua') @('GGOrbwalker.lua')
    Assert ($updated.Contains("[Other.lua]`r`nACTIVE = 1`r`nUPDATE = keep")) 'Unrelated settings'
    Assert ($updated.Contains('ACTIVE = 1 ; comment')) 'Preserve inline comment'
    Assert ($updated.Contains('UPDATE = own')) 'Preserve updater setting'
    Assert ($updated.Contains("[LeeHarveyOsward.lua]`r`nACTIVE = 1`r`nUPDATE =")) 'Append new section'
    Assert ($updated -match '\[GGOrbwalker.lua\]\r\nACTIVE = 0') 'Disable provider conflict'
    Assert ((Update-RuntimeIni $updated @('Orbama.lua','LeeHarveyOsward.lua') @('GGOrbwalker.lua')) -eq $updated) 'Idempotent INI'
    Throws { Update-RuntimeIni "[x.lua]`n[x.lua]`n" @('x.lua') @() } 'Duplicate loader'
    Throws { Update-RuntimeIni "[x.lua]`nACTIVE=0`nACTIVE=1" @('x.lua') @() } 'Duplicate ACTIVE'
    Assert ((Update-RuntimeIni '[x.lua]' @('x.lua') @()).Contains("[x.lua]`nACTIVE = 1")) 'Header without final newline'
    foreach ($encoding in @([Text.Encoding]::Unicode, [Text.Encoding]::BigEndianUnicode, (New-Object Text.UTF8Encoding($true)))) {
        $bytes = [byte[]]($encoding.GetPreamble() + $encoding.GetBytes($ini))
        $converted = Convert-RuntimeIni $bytes @('Orbama.lua') @()
        Assert ($converted[0] -eq $bytes[0] -and $converted[1] -eq $bytes[1]) 'Preserve BOM'
        Assert ($encoding.GetString($converted).Contains('UPDATE = keep')) 'Preserve encoding'
    }
    $source = Join-Path $sandbox 'source'
    [void][IO.Directory]::CreateDirectory($source)
    $catalogPackages = @()
    foreach ($pair in @(@('orbama','Orbama.lua'), @('lho','LeeHarveyOsward.lua'))) {
        $bytes = [Text.Encoding]::UTF8.GetBytes('-- fixture ' + $pair[0])
        [IO.File]::WriteAllBytes((Join-Path $source $pair[1]), $bytes)
        $catalogPackages += [pscustomobject]@{id=$pair[0]; name=$pair[0]; version='1'; depends=@(); enable=@($pair[1]); disable=@();
            files=@([pscustomobject]@{source=$pair[1]; destination=('LOLEXT/Scripts/' + $pair[1]); size=$bytes.Length; sha256=(Get-RuntimeHash $bytes)})}
    }
    $catalogPackages[0].disable = @('GGOrbwalker.lua')
    $catalogPackages[1].depends = @('orbama')
    $manifest = [pscustomobject]@{schema=1; repository='LeeHarveyOsward/runtime-files'; release='1'; packages=$catalogPackages}
    Write-RuntimeJson (Join-Path $source 'installer-manifest.json') $manifest
    Assert (@(Resolve-RuntimePackages $manifest @('lho')).Count -eq 2) 'Dependency selection'
    Throws { Resolve-RuntimePackages $manifest @('missing') } 'Unknown package'
    $catalogPackages[0].depends = @('lho')
    Throws { Resolve-RuntimePackages $manifest @('lho') } 'Dependency cycle'
    $catalogPackages[0].depends = @()
    $iniPath = Join-Path $root 'LOLEXT/LocalScriptDB.ini'
    [IO.File]::WriteAllText($iniPath, $ini)
    $originalIniHash = Get-RuntimeFileHash $iniPath
    Invoke-RuntimeInstaller -Root $root -Packages lho -SourceRoot $source -NonInteractive
    Assert ((Get-RuntimeFileHash (Join-Path $root 'LOLEXT/Scripts/Orbama.lua')) -eq $catalogPackages[0].files[0].sha256) 'Provider installed'
    Assert ((Get-Content -LiteralPath $iniPath -Raw) -match '\[LeeHarveyOsward.lua\]') 'INI registered'
    $receiptPath = Join-Path $root '.runtime-files/installed.json'
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    Assert ($receipt.packages.Count -eq 2) 'Receipt includes dependencies'
    Invoke-RuntimeInstaller -Root $root -Rollback -NonInteractive
    Assert ((Get-RuntimeFileHash $iniPath) -eq $originalIniHash) 'Rollback restores exact INI bytes'
    Assert (!(Test-Path -LiteralPath $receiptPath)) 'Rollback removes new receipt'
    Assert (!(Test-Path -LiteralPath (Join-Path $root 'LOLEXT/Scripts/Orbama.lua'))) 'Rollback removes new scripts'
    # Bad downloads must not change scripts or the registry.
    [IO.File]::AppendAllText((Join-Path $source 'LeeHarveyOsward.lua'), 'corrupt')
    Throws { Invoke-RuntimeInstaller -Root $root -Packages lho -SourceRoot $source -NonInteractive } 'Download verification'
    Assert ((Get-RuntimeFileHash $iniPath) -eq $originalIniHash) 'Corrupt download leaves INI intact'
    Assert (!(Test-Path -LiteralPath (Join-Path $root 'LOLEXT/Scripts/Orbama.lua'))) 'Corrupt download leaves scripts intact'
    [IO.File]::WriteAllText((Join-Path $source 'LeeHarveyOsward.lua'), '-- fixture lho')
    # A failure after replacing the first file must restore every earlier write.
    $originalSetter = ${function:Set-RuntimeFile}
    $script:calls = 0
    function Set-RuntimeFile([string]$Stage, [string]$Target) {
        $script:calls++
        if ($Target -like '*LOLEXT*') { $script:targetCalls++ }
        if ($script:targetCalls -eq 2) { $script:targetCalls++; throw 'Injected replacement failure' }
        & $originalSetter $Stage $Target
    }
    $script:targetCalls = 0
    Throws { Invoke-RuntimeInstaller -Root $root -Packages lho -SourceRoot $source -NonInteractive } 'rolled back'
    Assert ((Get-RuntimeFileHash $iniPath) -eq $originalIniHash) 'Mid-install failure restores INI'
    Assert (!(Test-Path -LiteralPath (Join-Path $root 'LOLEXT/Scripts/LeeHarveyOsward.lua'))) 'Mid-install failure removes new file'
    ${function:Set-RuntimeFile} = $originalSetter
    # Adding/updating with a receipt includes all previously installed packages.
    Invoke-RuntimeInstaller -Root $root -Packages lho -SourceRoot $source -NonInteractive
    Invoke-RuntimeInstaller -Root $root -SourceRoot $source -NonInteractive
    Assert ((Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json).packages.Count -eq 2) 'Update installed packages'
    Invoke-RuntimeInstaller -Root $root -Rollback -NonInteractive
    [IO.File]::AppendAllText((Join-Path $root 'LOLEXT/Scripts/Orbama.lua'), '-- user edit')
    Throws { Invoke-RuntimeInstaller -Root $root -Rollback -NonInteractive } 'Rollback conflict'
    Assert ((Get-Content -LiteralPath (Join-Path $root 'LOLEXT/Scripts/Orbama.lua') -Raw).Contains('user edit')) 'Rollback preserves concurrent edits'
    # Blank/missing registry is supported, and assets are copied without activation.
    $asset = [Text.Encoding]::UTF8.GetBytes('image fixture')
    [IO.File]::WriteAllBytes((Join-Path $source 'asset.png'), $asset)
    $catalogPackages[1].files += [pscustomobject]@{source='asset.png'; destination='LOLEXT/Sprites/Test/icon.png'; size=$asset.Length; sha256=(Get-RuntimeHash $asset)}
    Write-RuntimeJson (Join-Path $source 'installer-manifest.json') $manifest
    Invoke-RuntimeInstaller -Root $other -Packages lho -SourceRoot $source -NonInteractive
    Assert ((Get-RuntimeFileHash (Join-Path $other 'LOLEXT/Sprites/Test/icon.png')) -eq (Get-RuntimeHash $asset)) 'Asset installation'
    Assert (!((Get-Content -LiteralPath (Join-Path $other 'LOLEXT/LocalScriptDB.ini') -Raw).Contains('icon.png'))) 'Assets not activated'
    # Do not silently bypass a held installer lock.
    $lock = [IO.File]::Open((Join-Path $other '.runtime-files/install.lock'), 'Open', 'ReadWrite', 'None')
    try { Throws { Invoke-RuntimeInstaller -Root $other -Packages lho -SourceRoot $source -NonInteractive } 'Another installer' }
    finally { $lock.Dispose() }
    # A crash after replacement is reconciled using hashes, not a write counter.
    $recoveryRoot = Make-Root 'recovery/GamingOnSteroids'
    $recoveryFile = Join-Path $recoveryRoot 'LOLEXT/Scripts/Orbama.lua'
    [IO.File]::WriteAllText($recoveryFile, 'before')
    $beforeHash = Get-RuntimeFileHash $recoveryFile
    $transaction = Join-Path $recoveryRoot '.runtime-files/backups/interrupted'
    [void][IO.Directory]::CreateDirectory((Join-Path $transaction 'before/LOLEXT/Scripts'))
    [IO.File]::Copy($recoveryFile, (Join-Path $transaction 'before/LOLEXT/Scripts/Orbama.lua'))
    [IO.File]::WriteAllText($recoveryFile, 'after')
    Write-RuntimeJson (Join-Path $transaction 'journal.json') ([pscustomobject]@{schema=1; root=$recoveryRoot; state='installing';
        files=@([pscustomobject]@{path='LOLEXT/Scripts/Orbama.lua'; before=$beforeHash; after=(Get-RuntimeFileHash $recoveryFile)})})
    Throws { Invoke-RuntimeInstaller -Root $recoveryRoot -Packages orbama -SourceRoot $source -NonInteractive } 'Interrupted installation'
    Invoke-RuntimeInstaller -Root $recoveryRoot -Rollback -NonInteractive
    Assert ((Get-RuntimeFileHash $recoveryFile) -eq $beforeHash) 'Interrupted transaction restored'
    # The installer must not follow junctions outside the destination.
    $junction = Join-Path $recoveryRoot 'LOLEXT/Sprites'
    $null = New-Item -ItemType Junction -Path $junction -Target $source
    try { Throws { Get-RuntimePath $recoveryRoot 'LOLEXT/Sprites/asset.png' } 'Linked paths' }
    finally { [IO.Directory]::Delete($junction) }
    Write-Host "PASS: $script:count installer assertions"
} finally {
    $resolved = [IO.Path]::GetFullPath($sandbox)
    if (!$resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolved) -notlike 'runtime-installer-tests-*') { throw 'Unsafe test cleanup path' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
