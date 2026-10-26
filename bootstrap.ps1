#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$SkipPackages,
    [switch]$SkipNode,
    [switch]$SkipFonts,
    [switch]$SkipTerminal,
    [switch]$SkipWsl,
    [string]$WslDistribution = 'Ubuntu',
    [string]$WslRepository = 'https://github.com/yordan-kanchelov/dotfiles.git',
    [string]$WslRef = 'main',
    [switch]$RestartAndResume,
    [switch]$IncludeOllama,
    [string]$HomeDirectory = $env:USERPROFILE,
    [string]$LocalAppDataDirectory = $env:LOCALAPPDATA,
    [string]$RoamingAppDataDirectory = $env:APPDATA,
    [string]$ProfilePath,
    [string]$FontRegistryPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts',
    [string]$NodeVersion = '22'
)

$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Use bootstrap.sh on macOS/Linux.' }
$repo = $PSScriptRoot
$backupRoot = Join-Path $HomeDirectory ('.dotfiles_backup\windows-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
if (-not $ProfilePath) {
    $documents = [Environment]::GetFolderPath('MyDocuments')
    $ProfilePath = Join-Path $documents 'PowerShell\profile.ps1'
}

function Update-SessionPath {
    # Preserve injected tool paths as well as paths just added by installers.
    $paths = @([Environment]::GetEnvironmentVariable('Path', 'Machine'),
        [Environment]::GetEnvironmentVariable('Path', 'User'), $env:Path,
        (Join-Path $LocalAppDataDirectory 'Microsoft\WinGet\Links'),
        (Join-Path $env:ProgramFiles 'PowerShell\7'))
    $env:Path = ($paths -join ';').Split(';') | Where-Object { $_ } | Select-Object -Unique | Join-StringCompat
}
function Join-StringCompat {
    begin { $items = @() }
    process { $items += $_ }
    end { $items -join ';' }
}
function Backup-Config([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
        $name = [IO.Path]::GetFileName($Path) + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
        $backup = Join-Path $backupRoot $name
        Copy-Item -LiteralPath $Path -Destination $backup -Recurse -Force
        Write-Host "Backup: $Path -> $backup"
    }
}
function Write-ManagedFile([string]$Path, [string]$Content) {
    if ((Test-Path -LiteralPath $Path) -and [IO.File]::ReadAllText($Path) -ceq $Content) {
        Write-Host "Unchanged: $Path"
        return
    }
    if ($PSCmdlet.ShouldProcess($Path, 'Back up and write configuration')) {
        Backup-Config $Path
        New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
        [IO.File]::WriteAllText($Path, $Content, (New-Object Text.UTF8Encoding $false))
    }
}
function Set-ConfigJunction([string]$Source, [string]$Destination) {
    $existing = Get-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
    if ($existing -and $existing.LinkType -eq 'Junction' -and
        [string]$existing.Target -eq $Source) {
        Write-Host "Unchanged: $Destination"
        return
    }
    if ($PSCmdlet.ShouldProcess($Destination, "Back up conflict and junction to $Source")) {
        if ($existing) {
            # Move the entry itself; never recursively delete or follow an existing link.
            New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
            $backup = Join-Path $backupRoot ([IO.Path]::GetFileName($Destination) + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
            Move-Item -LiteralPath $Destination -Destination $backup
            Write-Host "Backup: $Destination -> $backup"
        }
        New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force | Out-Null
        New-Item -ItemType Junction -Path $Destination -Target $Source | Out-Null
    }
}

Update-SessionPath
if (-not $SkipPackages) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'Install Microsoft App Installer (WinGet) first.' }
    $packages = Get-Content -LiteralPath (Join-Path $repo 'windows\packages.json') -Raw | ConvertFrom-Json
    foreach ($package in $packages) {
        $available = Get-Command $package.command -ErrorAction SilentlyContinue
        # Codex injects its private rg.exe into this process; regular terminals cannot use it.
        if ($available -and $available.Source -notlike '*\.codex\packages\*') {
            Write-Host "Available: $($package.command)"
            continue
        }
        if ($PSCmdlet.ShouldProcess($package.id, 'Install using WinGet')) {
            & winget install --exact --id $package.id --source winget --silent --accept-source-agreements --accept-package-agreements --disable-interactivity
            if ($LASTEXITCODE -notin @(0, -1978335189)) { throw "WinGet failed for $($package.id): $LASTEXITCODE" }
            Update-SessionPath
        }
    }
    & (Join-Path $repo 'windows\install-agents.ps1') -WhatIf:$WhatIfPreference
}

if (-not $SkipNode) {
    if (Get-Command fnm -ErrorAction SilentlyContinue) {
        if ($PSCmdlet.ShouldProcess("Node $NodeVersion", 'Ensure installed through fnm; preserve existing default')) {
            $versions = & fnm list
            if ($LASTEXITCODE -ne 0) { throw 'Cannot list fnm versions.' }
            if (-not ($versions -match ('v' + [regex]::Escape($NodeVersion) + '\.'))) {
                & fnm install $NodeVersion
                if ($LASTEXITCODE -ne 0) { throw 'fnm install failed.' }
            }
            if (-not ($versions -match 'default')) {
                & fnm default $NodeVersion
                if ($LASTEXITCODE -ne 0) { throw 'fnm default failed.' }
            }
        }
    } elseif (-not $WhatIfPreference) { throw 'fnm is required. Install packages or use -SkipNode.' }
}

Set-ConfigJunction (Join-Path $repo '.config\nvim') (Join-Path $LocalAppDataDirectory 'nvim')
Set-ConfigJunction (Join-Path $repo '.config\yazi') (Join-Path $RoamingAppDataDirectory 'yazi\config')
# A file, not a directory, so it cannot be a junction; copy it like the profile block.
Write-ManagedFile (Join-Path $RoamingAppDataDirectory 'herdr\config.toml') ([IO.File]::ReadAllText((Join-Path $repo '.config\herdr\config.toml')))

$start = '# >>> dotfiles Windows >>>'
$end = '# <<< dotfiles Windows <<<'
$escapedProfile = (Join-Path $repo 'windows\profile.ps1').Replace("'", "''")
$block = "$start`r`n. '$escapedProfile'`r`n$end"
$oldProfile = if (Test-Path -LiteralPath $ProfilePath) { [IO.File]::ReadAllText($ProfilePath) } else { '' }
$pattern = '(?ms)^' + [regex]::Escape($start) + '\r?\n.*?^' + [regex]::Escape($end)
if ($oldProfile.Contains($start) -and -not [regex]::IsMatch($oldProfile, $pattern)) {
    throw "Incomplete managed profile block in $ProfilePath; inspect it before rerunning."
}
if ([regex]::IsMatch($oldProfile, $pattern)) {
    $newProfile = [regex]::Replace($oldProfile, $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($match) $block })
} else {
    $separator = if ($oldProfile -and -not $oldProfile.EndsWith("`n")) { "`r`n" } else { '' }
    $newProfile = $oldProfile + $separator + $block + "`r`n"
}
Write-ManagedFile $ProfilePath $newProfile

if (-not $SkipTerminal) {
    $fragment = Join-Path $LocalAppDataDirectory 'Microsoft\Windows Terminal\Fragments\dotfiles\terminal.json'
    Write-ManagedFile $fragment ([IO.File]::ReadAllText((Join-Path $repo 'windows\terminal.json')))
}
if (-not $SkipFonts) {
    $fontDestination = Join-Path $LocalAppDataDirectory 'Microsoft\Windows\Fonts'
    $fontRegistry = $FontRegistryPath
    $fonts = Get-ChildItem -LiteralPath (Join-Path $repo 'fonts\0xProto') -Filter '0xProtoNerdFont-*.ttf'
    $newFonts = @()
    foreach ($font in $fonts) {
        $target = Join-Path $fontDestination $font.Name
        $same = (Test-Path -LiteralPath $target) -and ((Get-FileHash -LiteralPath $font.FullName).Hash -eq (Get-FileHash -LiteralPath $target).Hash)
        if (-not $same -and $PSCmdlet.ShouldProcess($target, 'Install per-user Nerd Font')) {
            Backup-Config $target
            New-Item -ItemType Directory -Path $fontDestination -Force | Out-Null
            Copy-Item -LiteralPath $font.FullName -Destination $target -Force
            $newFonts += $target
        }
        $fontName = '0xProto Nerd Font ' + ($font.BaseName -replace '^0xProtoNerdFont-', '') + ' (TrueType)'
        $registered = Get-ItemProperty -LiteralPath $fontRegistry -Name $fontName -ErrorAction SilentlyContinue
        if ((-not $registered -or $registered.$fontName -ne $target) -and $PSCmdlet.ShouldProcess($fontName, 'Register per-user font')) {
            # Registry New-Item -Force empties an existing key, including unrelated fonts.
            if (-not (Test-Path -LiteralPath $fontRegistry)) {
                New-Item -Path $fontRegistry | Out-Null
            }
            New-ItemProperty -LiteralPath $fontRegistry -Name $fontName -Value $target -PropertyType String -Force | Out-Null
        }
    }
    if ($newFonts.Count) {
        if (-not ('Dotfiles.Fonts' -as [type])) {
            Add-Type @'
namespace Dotfiles {
    public static class Fonts {
        [System.Runtime.InteropServices.DllImport("gdi32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
        public static extern int AddFontResourceW(string path);
    }
}
'@
        }
        foreach ($newFont in $newFonts) { [Dotfiles.Fonts]::AddFontResourceW($newFont) | Out-Null }
    }
}
if (-not $SkipWsl) {
    $wslOptions = @{
        Distribution = $WslDistribution; Repository = $WslRepository; Ref = $WslRef
        RestartAndResume = [bool]$RestartAndResume; IncludeOllama = [bool]$IncludeOllama
        WhatIf = [bool]$WhatIfPreference
    }
    $wslResult = $null
    $wslStatusCount = 0
    # Native/Ansible progress shares the success pipeline with the final status.
    & (Join-Path $repo 'windows\setup-wsl.ps1') @wslOptions | ForEach-Object {
        if ($null -ne $_ -and $_.PSObject.Properties['ResumeStatus']) {
            $wslResult = $_
            $wslStatusCount++
        } else {
            Write-Output $_
        }
    }
    if (-not $WhatIfPreference -and ($wslStatusCount -ne 1 -or
        $wslResult.ResumeStatus -notin @('Complete', 'RestartRequired', 'RestartScheduled'))) {
        throw 'WSL setup did not return exactly one recognized ResumeStatus (Complete, RestartRequired, RestartScheduled). Native Windows configuration finished, but WSL setup could not be verified.'
    }
}
if ($WhatIfPreference) {
    Write-Host 'Preview complete. No packages or configuration files were changed.'
} elseif ($SkipWsl) {
    Write-Host 'Native Windows setup complete. WSL was skipped. Open a new Dotfiles PowerShell terminal tab.'
} elseif ($wslResult.ResumeStatus -eq 'RestartRequired') {
    Write-Host 'Native Windows configuration complete. WSL status: RestartRequired. Restart Windows manually when ready; setup will resume at next login, or use the saved resume command printed above. WSL setup is not complete.'
} elseif ($wslResult.ResumeStatus -eq 'RestartScheduled') {
    Write-Host 'Native Windows configuration complete. WSL status: RestartScheduled. Setup will resume after Windows restart and login; WSL setup is not complete.'
} else {
    Write-Host 'Setup complete. Open a new PowerShell 7 tab using the Dotfiles PowerShell terminal profile.'
}
