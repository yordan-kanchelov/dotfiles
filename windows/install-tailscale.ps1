#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param([switch]$OutputJson, [switch]$VerifyOnly)
$ErrorActionPreference = 'Stop'
$changed = $false
$planned = @()
$env:Path = [Environment]::ExpandEnvironmentVariables(([Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')))
$command = Get-Command tailscale.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $command -and -not $VerifyOnly) {
    $planned += 'Install Tailscale on Windows'
    if ($PSCmdlet.ShouldProcess('Tailscale.Tailscale', 'Install native Windows Tailscale using WinGet')) {
        & winget install --id Tailscale.Tailscale --exact --source winget --silent --accept-source-agreements --accept-package-agreements --disable-interactivity | Out-Host
        if ($LASTEXITCODE -notin @(0, 3010, -1978335189)) { throw "Tailscale installation failed: $LASTEXITCODE" }
        $changed = $true
        $env:Path = [Environment]::ExpandEnvironmentVariables(([Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')))
        $command = Get-Command tailscale.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    }
}
if (-not $command -and -not $WhatIfPreference) { throw 'Tailscale is not available on the persistent Windows PATH.' }
$tools = @()
if ($command) {
    $version = (& $command.Source version | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Tailscale version check failed.' }
    $tools += [pscustomobject]@{ name = 'tailscale'; path = $command.Source; version = $version }
}
$result = [pscustomobject]@{ changed = $changed; planned = $planned; tools = $tools }
if ($OutputJson) { $result | ConvertTo-Json -Depth 4 -Compress } else { $tools | Format-Table -AutoSize }
# Installation only: joining a tailnet requires the user's separate sign-in.
