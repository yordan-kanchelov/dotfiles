#Requires -Version 5.1
# Run elevated only for the Windows feature; Linux/user provisioning stays unelevated.
[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$ResultPath, [switch]$InstallPackage)
$ErrorActionPreference = 'Stop'
$packageRestartRequired = $false
if ($InstallPackage -and $PSCmdlet.ShouldProcess('Microsoft.WSL', 'Install WSL through WinGet with administrator privileges')) {
    & winget.exe install --id Microsoft.WSL --exact --source winget --silent --accept-source-agreements --accept-package-agreements --disable-interactivity | Out-Host
    if ($LASTEXITCODE -notin @(0, 3010, -1978335189)) { throw "WSL installation failed: $LASTEXITCODE" }
    $packageRestartRequired = $LASTEXITCODE -eq 3010
}
$feature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
$restartRequired = $packageRestartRequired -or $feature.State -eq 'EnablePending'
if ($feature.State -notin @('Enabled', 'EnablePending')) {
    if ($PSCmdlet.ShouldProcess('VirtualMachinePlatform', 'Enable WSL 2 platform without restarting Windows')) {
        $enabled = Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart
        $restartRequired = $restartRequired -or [bool]$enabled.RestartNeeded
    }
}
if (-not $WhatIfPreference) {
    [IO.File]::WriteAllText($ResultPath, (@{ RestartRequired = $restartRequired } | ConvertTo-Json), (New-Object Text.UTF8Encoding $false))
}
