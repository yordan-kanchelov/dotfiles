#Requires -Version 5.1
# Isolated feature-enablement tests: never enables features or requests elevation.
$ErrorActionPreference = 'Stop'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-wsl-platform-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
$state = [pscustomobject]@{ Feature = 'Disabled'; Calls = 0; PackageCalls = 0; PackageExitCode = 0 }
function winget.exe {
    if (($args -join ' ') -notmatch 'install --id Microsoft.WSL --exact --source winget --silent') { throw 'Wrong WSL package install arguments.' }
    $state.PackageCalls++
    $global:LASTEXITCODE = $state.PackageExitCode
}
function Get-WindowsOptionalFeature {
    param([switch]$Online, [string]$FeatureName)
    if (-not $Online -or $FeatureName -ne 'VirtualMachinePlatform') { throw 'Wrong feature query.' }
    [pscustomobject]@{ State = $state.Feature }
}
function Enable-WindowsOptionalFeature {
    param([switch]$Online, [string]$FeatureName, [switch]$All, [switch]$NoRestart)
    if (-not $Online -or $FeatureName -ne 'VirtualMachinePlatform' -or -not $All -or -not $NoRestart) { throw 'Feature enable must not restart Windows.' }
    $state.Calls++
    [pscustomobject]@{ RestartNeeded = $true }
}
try {
    $helper = Join-Path $PSScriptRoot 'enable-wsl-platform.ps1'
    if (-not (Test-Path -LiteralPath $helper)) { throw 'Missing WSL platform initialization helper.' }
    $resultPath = Join-Path $fixture 'result.json'
    & $helper -ResultPath $resultPath -WhatIf | Out-Null
    if ($state.Calls -ne 0 -or (Test-Path -LiteralPath $resultPath)) { throw 'Feature preview changed state.' }
    & $helper -ResultPath $resultPath | Out-Null
    $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    if ($state.Calls -ne 1 -or -not $result.RestartRequired) { throw 'Disabled feature was not enabled with restart required.' }
    $state.Feature = 'EnablePending'
    & $helper -ResultPath $resultPath | Out-Null
    $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    if ($state.Calls -ne 1 -or -not $result.RestartRequired) { throw 'Pending feature was re-enabled or lost its restart status.' }
    $state.Feature = 'Enabled'
    & $helper -ResultPath $resultPath | Out-Null
    $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    if ($state.Calls -ne 1 -or $result.RestartRequired) { throw 'Enabled feature was changed or requested a restart.' }
    & $helper -ResultPath $resultPath -InstallPackage -WhatIf | Out-Null
    if ($state.PackageCalls) { throw 'Package preview installed WSL.' }
    & $helper -ResultPath $resultPath -InstallPackage | Out-Null
    if ($state.PackageCalls -ne 1) { throw 'Elevated helper did not install the missing WSL package.' }
    $state.PackageExitCode = 3010
    & $helper -ResultPath $resultPath -InstallPackage | Out-Null
    $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    if (-not $result.RestartRequired) { throw 'Package restart-required status was lost.' }
    Write-Host 'PASS: WSL feature preview, enablement without reboot, pending restart and repeatability.'
} finally {
    Remove-Item Function:\Get-WindowsOptionalFeature -ErrorAction SilentlyContinue
    Remove-Item Function:\Enable-WindowsOptionalFeature -ErrorAction SilentlyContinue
    Remove-Item Function:\winget.exe -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $fixture -Recurse -Force
}
