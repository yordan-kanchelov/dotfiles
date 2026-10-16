#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param([switch]$OutputJson)
$ErrorActionPreference = 'Stop'
$changed = $false
$planned = @()
function Find-Noctty {
    foreach ($candidate in @((Join-Path $env:ProgramFiles 'noctty\noctty.exe'), (Join-Path $env:LOCALAPPDATA 'Programs\noctty\noctty.exe'))) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    $found = Get-Command noctty.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { return $found.Source }
}
$executable = Find-Noctty
if (-not $executable) {
    $planned += 'Install Noctty on Windows'
    if ($PSCmdlet.ShouldProcess('AmanThanvi.noctty', 'Install using WinGet')) {
        & winget install --id AmanThanvi.noctty --exact --source winget --silent --accept-source-agreements --accept-package-agreements --disable-interactivity | Out-Host
        if ($LASTEXITCODE -notin @(0, 3010, -1978335189)) { throw "Noctty installation failed: $LASTEXITCODE" }
        $changed = $true
        $executable = Find-Noctty
        if (-not $executable) { throw 'Noctty executable not found after installation.' }
    }
}
if ($executable) {
    $directory = Split-Path -Parent $executable
    $persistentPath = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($directory.TrimEnd('\') -notin @($persistentPath.Split(';') | ForEach-Object { [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') })) {
        $planned += 'Add Noctty to the user PATH'
        if ($PSCmdlet.ShouldProcess($directory, 'Add to persistent user PATH')) {
            $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
            [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ';' + $directory), 'User')
            $changed = $true
        }
    }
}
$tools = @()
$configPath = Join-Path $env:LOCALAPPDATA 'noctty\config.ghostty'
$config = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'noctty.ghostty'))
if (-not (Test-Path -LiteralPath $configPath) -or [IO.File]::ReadAllText($configPath) -cne $config) {
    $planned += 'Configure Noctty font, theme and PowerShell'
    if ($PSCmdlet.ShouldProcess($configPath, 'Back up conflict and configure Noctty')) {
        if (Test-Path -LiteralPath $configPath) {
            $backup = Join-Path $env:USERPROFILE ('.dotfiles_backup\noctty-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $backup -Force | Out-Null
            Copy-Item -LiteralPath $configPath -Destination (Join-Path $backup 'config.ghostty')
        }
        New-Item -ItemType Directory -Path (Split-Path -Parent $configPath) -Force | Out-Null
        [IO.File]::WriteAllText($configPath, $config, (New-Object Text.UTF8Encoding $false))
        $changed = $true
    }
}
if ($executable) {
    $version = & (Join-Path (Split-Path -Parent $executable) 'noctty.com') +version
    if ($LASTEXITCODE -ne 0) { throw 'Noctty version check failed.' }
    $tools += [pscustomobject]@{ name = 'noctty'; path = $executable; version = ($version | Select-Object -First 1) }
}
$result = [pscustomobject]@{ changed = $changed; planned = $planned; tools = $tools }
if ($OutputJson) { $result | ConvertTo-Json -Depth 4 -Compress } else { $tools | Format-Table -AutoSize }
