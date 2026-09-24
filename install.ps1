#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Root,
    [string[]]$Packages,
    [switch]$NonInteractive,
    [switch]$Rollback,
    [switch]$DetectOnly,
    [switch]$LibraryOnly,
    [string]$SourceRoot,
    [string]$Commit
)

function Get-RuntimeHash([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Write-RuntimeJson([string]$Path, $Value) {
    $text = ConvertTo-Json -InputObject $Value -Depth 20
    $temporary = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($temporary, $text + "`n", (New-Object Text.UTF8Encoding($false)))
        Set-RuntimeFile $temporary $Path
    } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}

function Assert-RuntimeRelative([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -match '[\\:]' -or $Path.StartsWith('/')) {
        throw "Invalid relative path: $Path"
    }
    foreach ($part in $Path.Split('/')) {
        if (!$part -or $part -in @('.', '..') -or $part -match '[<>"|?*\x00-\x1f]' -or
            $part -match '[. ]$' -or $part -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') {
            throw "Invalid path component: $Path"
        }
    }
}

function Get-RuntimePath([string]$Base, [string]$Relative) {
    Assert-RuntimeRelative $Relative
    $basePath = [IO.Path]::GetFullPath($Base).TrimEnd('\', '/')
    $path = [IO.Path]::GetFullPath((Join-Path $basePath $Relative))
    if (!$path.StartsWith($basePath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes installation: $Relative"
    }
    $current = $path
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Linked paths are not supported: $current"
            }
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if ($parent -eq $current) { break }
        $current = $parent
    }
    return $path
}

function Get-RuntimeInstallations($Processes) {
    if ($null -eq $Processes) {
        $Processes = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
    }
    $found = @{}
    foreach ($process in $Processes) {
        if (!$process.ExecutablePath) { continue }
        try {
            $candidate = Join-Path ([IO.Path]::GetDirectoryName($process.ExecutablePath)) 'GamingOnSteroids'
            if (Test-Path -LiteralPath (Join-Path $candidate 'LOLEXT/Scripts') -PathType Container) {
                $candidate = [IO.Path]::GetFullPath($candidate)
                $found[$candidate] = $candidate
            }
        } catch { continue }
    }
    return @($found.Values | Sort-Object)
}

function Select-RuntimeRoot([string]$Requested, [bool]$Quiet) {
    if (!$Requested) {
        $candidates = @(Get-RuntimeInstallations)
        if ($candidates.Count -eq 1) { $Requested = $candidates[0] }
        elseif ($Quiet) { throw 'No unique installation found. Specify -Root with the GamingOnSteroids folder.' }
        elseif ($candidates.Count -gt 1) {
            for ($i = 0; $i -lt $candidates.Count; $i++) { Write-Host "[$($i+1)] $($candidates[$i])" }
            $choice = Read-Host 'Choose installation number'
            $index = 0
            if (![int]::TryParse($choice, [ref]$index) -or $index -lt 1 -or $index -gt $candidates.Count) {
                throw 'Invalid installation selection.'
            }
            $Requested = $candidates[$index-1]
        } else {
            Write-Host 'No running host installation found. Select the GamingOnSteroids folder.'
            try {
                Add-Type -AssemblyName System.Windows.Forms
                $picker = New-Object Windows.Forms.FolderBrowserDialog
                try {
                    $picker.Description = 'Select your GamingOnSteroids folder'
                    $picker.ShowNewFolderButton = $false
                    if ($picker.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) { $Requested = $picker.SelectedPath }
                } finally { $picker.Dispose() }
            } catch { Write-Host 'Folder picker unavailable.' }
            if (!$Requested) { $Requested = (Read-Host 'GamingOnSteroids folder path (blank cancels)').Trim('"') }
        }
    }
    if (!$Requested) { throw 'Installation cancelled.' }
    $resolved = [IO.Path]::GetFullPath($Requested)
    $scripts = Get-RuntimePath $resolved 'LOLEXT/Scripts'
    if (!(Test-Path -LiteralPath $scripts -PathType Container)) {
        throw "Not an installation: $resolved has no LOLEXT\Scripts directory."
    }
    return $resolved
}

function Get-RuntimeBytes([string]$Relative, [string]$LocalSource, [string]$Revision) {
    Assert-RuntimeRelative $Relative
    if ($LocalSource) { return ,([IO.File]::ReadAllBytes((Get-RuntimePath $LocalSource $Relative))) }
    if ($Revision -notmatch '^[a-f0-9]{40}$') { throw 'A full Git commit is required.' }
    $url = "https://raw.githubusercontent.com/LeeHarveyOsward/runtime-files/$Revision/$Relative"
    $client = New-Object Net.WebClient
    $client.Headers['User-Agent'] = 'runtime-files-installer'
    try { return ,($client.DownloadData($url)) } finally { $client.Dispose() }
}

function Resolve-RuntimePackages($Manifest, [string[]]$Requested) {
    if ($Manifest.schema -ne 1 -or $Manifest.repository -ne 'LeeHarveyOsward/runtime-files') {
        throw 'Unsupported package manifest.'
    }
    $catalog = @{}
    foreach ($package in $Manifest.packages) {
        if ($package.id -notmatch '^[a-z][a-z0-9-]*$' -or $catalog.ContainsKey($package.id)) { throw 'Invalid or duplicate package ID.' }
        $catalog[$package.id] = $package
    }
    $selected = @{}
    $visiting = @{}
    function Visit-RuntimePackage([string]$Id) {
        if ($selected.ContainsKey($Id)) { return }
        if (!$catalog.ContainsKey($Id)) { throw "Unknown package: $Id" }
        if ($visiting.ContainsKey($Id)) { throw "Dependency cycle: $Id" }
        $visiting[$Id] = $true
        foreach ($dependency in $catalog[$Id].depends) { Visit-RuntimePackage $dependency }
        $visiting.Remove($Id)
        $selected[$Id] = $catalog[$Id]
    }
    foreach ($id in $Requested) { Visit-RuntimePackage $id }
    return @($selected.Values | Sort-Object id)
}

function Update-RuntimeIni([string]$Text, [string[]]$Enable, [string[]]$Disable) {
    $newline = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
    foreach ($name in @($Enable) + @($Disable)) {
        if (!$name -or $name -notmatch '^[^\[\]\\/:\r\n]+\.lua$') { throw "Invalid loader entry: $name" }
        if ($name -in $Enable -and $name -in $Disable) { throw "Conflicting activation: $name" }
        $pattern = '(?im)^[ \t]*\[' + [regex]::Escape($name) + '\][^\r\n]*(?:\r?\n|$)'
        $matches = [regex]::Matches($Text, $pattern)
        if ($matches.Count -gt 1) { throw "Duplicate loader section: $name" }
        $active = if ($name -in $Enable) { '1' } else { '0' }
        if (!$matches.Count) {
            if ($active -eq '1') {
                if ($Text -and !$Text.EndsWith("`n")) { $Text += $newline }
                $Text += $newline + "[$name]" + $newline + 'ACTIVE = 1' + $newline + 'UPDATE =' + $newline
            }
            continue
        }
        $header = $matches[0]
        $start = $header.Index + $header.Length
        $next = [regex]::Match($Text.Substring($start), '(?m)^[ \t]*\[')
        $length = if ($next.Success) { $next.Index } else { $Text.Length - $start }
        $body = $Text.Substring($start, $length)
        $setting = [regex]::new('(?im)^([ \t]*ACTIVE[ \t]*=[ \t]*)[^;#\r\n]*([;#][^\r\n]*)?')
        if ($setting.Matches($body).Count -gt 1) { throw "Duplicate ACTIVE setting: $name" }
        if ($setting.IsMatch($body)) {
            $body = $setting.Replace($body, [Text.RegularExpressions.MatchEvaluator]{ param($m)
                $suffix = if ($m.Groups[2].Success) { ' ' + $m.Groups[2].Value } else { '' }
                $m.Groups[1].Value + $active + $suffix
            })
        } else { $body = 'ACTIVE = ' + $active + $newline + $body }
        if (!$header.Value.EndsWith("`n")) { $body = $newline + $body }
        $Text = $Text.Substring(0, $start) + $body + $Text.Substring($start + $length)
    }
    return $Text
}

function Convert-RuntimeIni([byte[]]$Bytes, [string[]]$Enable, [string[]]$Disable) {
    if ($null -eq $Bytes) { $Bytes = [byte[]]@() }
    $offset = 0
    $encoding = New-Object Text.UTF8Encoding($false, $true)
    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 239 -and $Bytes[1] -eq 187 -and $Bytes[2] -eq 191) {
        $encoding = New-Object Text.UTF8Encoding($true, $true); $offset = 3
    } elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 255 -and $Bytes[1] -eq 254) {
        $encoding = [Text.Encoding]::Unicode; $offset = 2
    } elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 254 -and $Bytes[1] -eq 255) {
        $encoding = [Text.Encoding]::BigEndianUnicode; $offset = 2
    }
    try { $text = $encoding.GetString($Bytes, $offset, $Bytes.Length - $offset) }
    catch { $encoding = [Text.Encoding]::Default; $text = $encoding.GetString($Bytes); $offset = 0 }
    $updated = Update-RuntimeIni $text $Enable $Disable
    $prefix = if ($offset) { $encoding.GetPreamble() } else { [byte[]]@() }
    return ,([byte[]]($prefix + $encoding.GetBytes($updated)))
}

function Get-RuntimeFileHash([string]$Path) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return Get-RuntimeHash ([IO.File]::ReadAllBytes($Path))
}

function Set-RuntimeFile([string]$Stage, [string]$Target) {
    if ([IO.File]::Exists($Target)) { [IO.File]::Replace($Stage, $Target, [NullString]::Value) }
    else { [IO.File]::Move($Stage, $Target) }
}

function Restore-RuntimeTransaction([string]$Base, [string]$Transaction) {
    $journalPath = Join-Path $Transaction 'journal.json'
    $journal = Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json
    if ($journal.root -ne $Base) { throw 'Backup belongs to a different installation.' }
    $restore = @()
    foreach ($entry in $journal.files) {
        $target = Get-RuntimePath $Base $entry.path
        $current = Get-RuntimeFileHash $target
        if ($current -eq $entry.before) { continue }
        if ($current -ne $entry.after) { throw "Rollback conflict at $target. Backup: $Transaction" }
        if ($null -ne $entry.before) {
            $backup = Get-RuntimePath $Transaction ('before/' + $entry.path)
            if ((Get-RuntimeFileHash $backup) -ne $entry.before) { throw "Backup hash mismatch: $backup" }
        }
        $restore += $entry
    }
    [array]::Reverse($restore)
    foreach ($entry in $restore) {
        $target = Get-RuntimePath $Base $entry.path
        if ((Get-RuntimeFileHash $target) -ne $entry.after) { throw "File changed during rollback: $target" }
        if ($null -eq $entry.before) { [IO.File]::Delete($target) }
        else {
            $temp = Join-Path $Transaction ([guid]::NewGuid().ToString('N') + '.restore')
            [IO.File]::WriteAllBytes($temp, [IO.File]::ReadAllBytes((Get-RuntimePath $Transaction ('before/' + $entry.path))))
            Set-RuntimeFile $temp $target
        }
        if ((Get-RuntimeFileHash $target) -ne $entry.before) { throw "Rollback verification failed: $target" }
    }
    $journal.state = 'rolled-back'
    Write-RuntimeJson $journalPath $journal
    Write-Host "Restored backup: $Transaction"
}

function Invoke-RuntimeTransaction([string]$Base, $Writes, [string]$Revision) {
    $id = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffffffZ') + '-' + [guid]::NewGuid().ToString('N')
    $transaction = Get-RuntimePath $Base ('.runtime-files/backups/' + $id)
    [void][IO.Directory]::CreateDirectory($transaction)
    $entries = @()
    foreach ($write in $Writes) {
        $target = Get-RuntimePath $Base $write.path
        $before = Get-RuntimeFileHash $target
        if ($before -ne $write.expected) { throw "File changed while preparing installation: $target" }
        $after = Get-RuntimeHash $write.bytes
        if ($before -eq $after) { continue }
        if ($null -ne $before) {
            $backup = Get-RuntimePath $transaction ('before/' + $write.path)
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($backup))
            [IO.File]::WriteAllBytes($backup, [IO.File]::ReadAllBytes($target))
            if ((Get-RuntimeFileHash $backup) -ne $before) { throw "File changed while backing up: $target" }
        }
        $stage = Get-RuntimePath $transaction ('after/' + $write.path)
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($stage))
        [IO.File]::WriteAllBytes($stage, $write.bytes)
        if ((Get-RuntimeFileHash $stage) -ne $after) { throw "Staging verification failed: $stage" }
        $entries += [pscustomobject]@{path=$write.path; before=$before; after=$after}
    }
    $journal = [pscustomobject]@{schema=1; root=$Base; commit=$Revision; state='installing'; files=$entries}
    $journalPath = Join-Path $transaction 'journal.json'
    Write-RuntimeJson $journalPath $journal
    try {
        foreach ($entry in $entries) {
            $target = Get-RuntimePath $Base $entry.path
            if ((Get-RuntimeFileHash $target) -ne $entry.before) { throw "Concurrent file change: $target" }
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
            Set-RuntimeFile (Get-RuntimePath $transaction ('after/' + $entry.path)) $target
            if ((Get-RuntimeFileHash $target) -ne $entry.after) { throw "Installed hash mismatch: $target" }
        }
        $journal.state = 'installed'
        Write-RuntimeJson $journalPath $journal
    } catch {
        $failure = $_
        try { Restore-RuntimeTransaction $Base $transaction }
        catch { throw "Installation failed: $failure. Recovery failed: $_. Backups: $transaction" }
        throw "Installation failed and was rolled back: $failure"
    }
    Write-Host "Backup: $transaction"
    return $transaction
}

function Invoke-RuntimeInstaller {
    [CmdletBinding()]
    param([string]$Root, [string[]]$Packages, [switch]$NonInteractive, [switch]$Rollback,
          [string]$SourceRoot, [string]$Commit)
    $ErrorActionPreference = 'Stop'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $rootPath = Select-RuntimeRoot $Root $NonInteractive.IsPresent
    Write-Host "Installation: $rootPath"
    $state = Get-RuntimePath $rootPath '.runtime-files'
    [void][IO.Directory]::CreateDirectory($state)
    $lockPath = Get-RuntimePath $rootPath '.runtime-files/install.lock'
    try { $lock = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
    catch { throw 'Another installer is running, or the installation folder is not writable.' }
    try {
        $backups = Get-RuntimePath $rootPath '.runtime-files/backups'
        $journals = @()
        if (Test-Path -LiteralPath $backups) {
            $journals = @(Get-ChildItem -LiteralPath $backups -Directory | Sort-Object Name -Descending | ForEach-Object {
                $path = Get-RuntimePath $_.FullName 'journal.json'
                if (Test-Path -LiteralPath $path) { [pscustomobject]@{path=$_.FullName; data=(Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)} }
            })
        }
        $pending = @($journals | Where-Object { $_.data.state -eq 'installing' })
        if ($Rollback) {
            $latest = $journals | Where-Object { $_.data.state -in @('installing', 'installed') } | Select-Object -First 1
            if (!$latest) { throw 'No installation backup to restore.' }
            Restore-RuntimeTransaction $rootPath $latest.path
            return
        }
        if ($pending.Count) { throw "Interrupted installation found. Run this installer with -Root '$rootPath' -Rollback first." }
        if (!$SourceRoot) {
            if (!$Commit) {
                $head = Invoke-RestMethod -Uri 'https://api.github.com/repos/LeeHarveyOsward/runtime-files/commits/main' -Headers @{'User-Agent'='runtime-files-installer'} -TimeoutSec 30
                $Commit = $head.sha
            }
        } else { $SourceRoot = [IO.Path]::GetFullPath($SourceRoot); if (!$Commit) { $Commit = 'local-test' } }
        $manifest = [Text.Encoding]::UTF8.GetString((Get-RuntimeBytes 'installer-manifest.json' $SourceRoot $Commit)) | ConvertFrom-Json
        # Validate the catalog before displaying or selecting packages.
        $null = Resolve-RuntimePackages $manifest @($manifest.packages.id)
        $receiptPath = Get-RuntimePath $rootPath '.runtime-files/installed.json'
        $receiptHash = Get-RuntimeFileHash $receiptPath
        $previous = @()
        if ($receiptHash) {
            $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
            if ($receipt.schema -ne 1) { throw 'Unsupported installation receipt.' }
            $previous = @($receipt.packages | ForEach-Object { $_.id })
        }
        if (!$Packages) {
            if ($NonInteractive) {
                if (!$previous.Count) { throw 'Specify -Packages for a new noninteractive installation.' }
                $Packages = $previous
            } else {
                Write-Host 'Select scripts. Required dependencies are included automatically.'
                $options = @($manifest.packages)
                for ($i = 0; $i -lt $options.Count; $i++) { Write-Host "[$($i+1)] $($options[$i].name)" }
                if ($previous.Count) { Write-Host '[U] Update installed packages' }
                $choice = Read-Host 'Enter numbers separated by commas (blank cancels)'
                if (!$choice) { throw 'Installation cancelled.' }
                if ($choice -eq 'u' -and $previous.Count) { $Packages = $previous }
                else {
                    $Packages = @()
                    foreach ($value in ($choice -split '[,\s]+' | Where-Object { $_ })) {
                        $index = 0
                        if (![int]::TryParse($value, [ref]$index) -or $index -lt 1 -or $index -gt $options.Count) { throw 'Invalid package selection.' }
                        $Packages += $options[$index-1].id
                    }
                }
            }
        }
        $selected = @(Resolve-RuntimePackages $manifest @($Packages + $previous | Select-Object -Unique))
        if (!$selected.Count) { throw 'No packages selected.' }
        $enable = @($selected | ForEach-Object { $_.enable } | Select-Object -Unique)
        $disable = @($selected | ForEach-Object { $_.disable } | Select-Object -Unique)
        Write-Host ('Install and enable: ' + ($enable -join ', '))
        if ($disable.Count) { Write-Host ('Disable if registered: ' + ($disable -join ', ')) }
        Write-Host "Release $($manifest.release), publication $Commit"
        $writes = @()
        $destinations = @{}
        foreach ($package in $selected) {
            foreach ($file in $package.files) {
                if ($file.destination -notmatch '^LOLEXT/(Scripts|Sprites|Fonts|Sounds)/' -or
                    $file.sha256 -notmatch '^[a-f0-9]{64}$' -or $file.size -le 0) { throw 'Invalid package file metadata.' }
                $target = Get-RuntimePath $rootPath $file.destination
                if ($destinations.ContainsKey($file.destination)) { throw "Duplicate package destination: $($file.destination)" }
                $destinations[$file.destination] = $true
                $expected = Get-RuntimeFileHash $target
                $bytes = Get-RuntimeBytes $file.source $SourceRoot $Commit
                if ($bytes.Length -ne $file.size -or (Get-RuntimeHash $bytes) -ne $file.sha256) { throw "Download verification failed: $($file.source)" }
                $writes += [pscustomobject]@{path=$file.destination; bytes=$bytes; expected=$expected}
            }
        }
        foreach ($name in $enable) {
            if (!$destinations.ContainsKey('LOLEXT/Scripts/' + $name)) { throw "Loader entry has no package file: $name" }
        }
        $iniPath = Get-RuntimePath $rootPath 'LOLEXT/LocalScriptDB.ini'
        $iniHash = Get-RuntimeFileHash $iniPath
        $iniBytes = if ($null -ne $iniHash) { [IO.File]::ReadAllBytes($iniPath) } else { [byte[]]@() }
        $writes += [pscustomobject]@{path='LOLEXT/LocalScriptDB.ini'; bytes=(Convert-RuntimeIni $iniBytes $enable $disable); expected=$iniHash}
        $receipt = [ordered]@{schema=1; commit=$Commit; release=$manifest.release; installedAt=[DateTime]::UtcNow.ToString('o');
            packages=@($selected | ForEach-Object { [ordered]@{id=$_.id; version=$_.version} });
            files=@($writes | ForEach-Object { [ordered]@{path=$_.path; sha256=(Get-RuntimeHash $_.bytes)} })}
        $receiptBytes = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $receipt -Depth 15) + "`n")
        $writes += [pscustomobject]@{path='.runtime-files/installed.json'; bytes=$receiptBytes; expected=$receiptHash}
        $null = Invoke-RuntimeTransaction $rootPath $writes $Commit
        Write-Host 'Installed and enabled. Reload the complete script runtime when ready.' -ForegroundColor Green
        Write-Host 'No running process was stopped or reloaded.'
    } finally { $lock.Dispose() }
}

if (!$LibraryOnly) {
    try {
        if ($DetectOnly) { Get-RuntimeInstallations }
        else { Invoke-RuntimeInstaller -Root $Root -Packages $Packages -NonInteractive:$NonInteractive -Rollback:$Rollback -SourceRoot $SourceRoot -Commit $Commit }
    } catch {
        if ($NonInteractive) { throw }
        Write-Host "Installer stopped: $_" -ForegroundColor Red
    } finally {
        if (!$NonInteractive -and !$DetectOnly) { $null = Read-Host 'Press Enter to close' }
    }
}
