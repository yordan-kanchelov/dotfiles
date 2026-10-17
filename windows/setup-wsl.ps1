#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Distribution = 'Ubuntu',
    [string]$Repository = 'https://github.com/yordan-kanchelov/dotfiles.git',
    [string]$Ref = 'main',
    [switch]$IncludeOllama,
    [switch]$RestartAndResume,
    [switch]$Resume,
    [ValidateRange(0, 2)][int]$RestartAttempt = 0
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'wsl-resume-state.ps1')
function Request-WslRestart {
    if ($RestartAndResume -and $RestartAttempt -ge 2) { throw 'Automatic restart limit reached. Check WSL and restart Windows manually before retrying.' }
    $action = if ($RestartAndResume) { 'Save setup options and restart Windows' } else { 'Save setup options for the next Windows sign-in; do not restart now' }
    if ($PSCmdlet.ShouldProcess('Windows', $action)) {
        $stateFile = Register-WslResume -Options @{
            Distribution = $Distribution; Repository = $Repository; Ref = $Ref
            IncludeOllama = [bool]$IncludeOllama
            RestartAndResume = [bool]$RestartAndResume
            RestartAttempt = $RestartAttempt + [int][bool]$RestartAndResume
        }
        $resumeScript = Join-Path $PSScriptRoot 'resume-wsl.ps1'
        Write-Host ('Manual resume command: powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -NoExit -File "' + $resumeScript + '" -StateFile "' + $stateFile + '"')
        if ($RestartAndResume) {
            Write-Host 'Setup will resume in a PowerShell console after your next login. Restarting Windows now.'
            # No -Force: do not forcibly close applications with unsaved work.
            Restart-Computer -ErrorAction Stop
            return [pscustomobject]@{ ResumeStatus = 'RestartScheduled' }
        }
        Write-Host 'Windows needs a restart. Save your work and restart when ready; Ubuntu setup will resume at your next sign-in.'
    }
    return [pscustomobject]@{ ResumeStatus = 'RestartRequired' }
}
function Invoke-WslCapture([string[]]$Arguments) {
    # Treat native stderr as data, including under Windows PowerShell 5.
    $ErrorActionPreference = 'Continue'
    $output = & $wslExe @Arguments 2>&1
    $code = $LASTEXITCODE
    [pscustomobject]@{ ExitCode = $code; Text = (($output | Out-String).Replace([string][char]0, '')).Trim() }
}
function Resolve-WslFailure($Response, [string]$Context) {
    if ($Response.Text -match 'restart|reboot|0x8007019e|0x80370102|HYPERV_NOT_INSTALLED|OPTIONAL_COMPONENT_REQUIRED') {
        Request-WslRestart
        return
    }
    throw "$Context (exit $($Response.ExitCode)): $($Response.Text)"
}
# System32 dispatches both MSIX/Store and MSI WSL installations. Do not pin
# the old Program Files layout: current Microsoft.WSL packages use MSIX.
$wslExe = Join-Path $env:WINDIR 'System32\wsl.exe'
$version = Invoke-WslCapture -Arguments @('--version')
$installPackage = $version.ExitCode -ne 0
if ($WhatIfPreference) {
    if ($installPackage) { Write-Host 'Would request approval to install Microsoft.WSL and enable its Windows platform without rebooting.' }
    Write-Host "Would install/start $Distribution, then run the Linux Ansible bootstrap from $Repository ($Ref)."
    Write-Host 'If a restart is needed, setup saves its options and resumes after your next Windows sign-in.'
    if ($RestartAndResume) { Write-Host 'Would save options, restart Windows if needed, and resume at next login.' }
    return
}
# Installing the WSL MSI alone does not enable the WSL 2 Windows feature.
# CIM can inspect it without admin rights, so working reruns do not ask for UAC.
$platform = Get-CimInstance -ClassName Win32_OptionalFeature | Where-Object Name -eq 'VirtualMachinePlatform'
if (-not $platform) { throw 'This Windows installation does not expose the VirtualMachinePlatform feature required by WSL 2.' }
if ($installPackage -or $platform.InstallState -ne 1) {
    if (-not $PSCmdlet.ShouldProcess('WSL 2', 'Request elevation to install WSL and enable its platform without restarting')) { return }
    $resultPath = [IO.Path]::GetTempFileName()
    try {
        $helper = Join-Path $PSScriptRoot 'enable-wsl-platform.ps1'
        $windowsPowerShell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $helperArguments = @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $helper + '"'), '-ResultPath', ('"' + $resultPath + '"')
        )
        if ($installPackage) { $helperArguments += '-InstallPackage' }
        $process = Start-Process -FilePath $windowsPowerShell -Verb RunAs -Wait -PassThru -ArgumentList $helperArguments
        if ($process.ExitCode -ne 0) { throw "WSL platform enablement failed (exit $($process.ExitCode)). Approve the UAC prompt and retry." }
        $platformResult = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
        if (-not $platformResult.PSObject.Properties['RestartRequired']) { throw 'WSL platform enablement returned no usable result.' }
        if ($platformResult.RestartRequired) {
            Request-WslRestart
            return
        }
    } finally {
        Remove-Item -LiteralPath $resultPath -Force -ErrorAction SilentlyContinue
    }
}
if ($installPackage) {
    $version = Invoke-WslCapture -Arguments @('--version')
    if ($version.ExitCode -ne 0) { throw "WSL installation did not provide a working version command: $($version.Text)" }
}
$response = Invoke-WslCapture -Arguments @('--list', '--quiet')
if ($response.ExitCode -ne 0) { Resolve-WslFailure $response 'WSL cannot list distributions'; return }
$distributions = $response.Text -split '\r?\n'
if ($Distribution -notin $distributions) {
    if (-not $PSCmdlet.ShouldProcess($Distribution, 'Install WSL Ubuntu (may require a Windows restart)')) { return }
    $response = Invoke-WslCapture -Arguments @('--install', '--distribution', $Distribution, '--no-launch')
    Write-Host $response.Text
    if ($response.ExitCode -eq 3010) {
        Request-WslRestart
        return
    }
    if ($response.ExitCode -ne 0) { Resolve-WslFailure $response 'Ubuntu installation failed'; return }
    $response = Invoke-WslCapture -Arguments @('--list', '--quiet')
    if ($response.ExitCode -ne 0) { Resolve-WslFailure $response 'WSL cannot initialize Ubuntu'; return }
    $distributions = $response.Text -split '\r?\n'
    if ($Distribution -notin $distributions) {
        Request-WslRestart
        return
    }
}
$response = Invoke-WslCapture -Arguments @('--distribution', $Distribution, '--exec', 'id', '-un')
if ($response.ExitCode -ne 0) { Resolve-WslFailure $response 'Ubuntu cannot start'; return }
$linuxUser = $response.Text
if ($linuxUser -eq 'root') {
    if (-not $Resume) {
        throw "Open $Distribution once and create your normal Linux username/password, then rerun this command. Ansible must not install the user tools as root."
    }
    Write-Host 'Create your Linux account in the Ubuntu window opening now. Setup will continue automatically when it is ready.'
    # This is intentionally visible: Ubuntu asks the user for their username/password.
    # Do not wait for that shell to exit after OOBE has already created the account.
    $quotedDistribution = '"' + $Distribution.Replace('"', '') + '"'
    Start-Process -FilePath $wslExe -ArgumentList @('--distribution', $quotedDistribution) -WindowStyle Normal | Out-Null
    $deadline = (Get-Date).AddMinutes(15)
    do {
        Start-Sleep -Seconds 2
        $response = Invoke-WslCapture -Arguments @('--distribution', $Distribution, '--exec', 'id', '-un')
        if ($response.ExitCode -eq 0 -and $response.Text -and $response.Text -ne 'root') {
            $linuxUser = $response.Text
            break
        }
    } while ((Get-Date) -lt $deadline)
    if ($linuxUser -eq 'root') { throw 'Ubuntu still has no normal default user. Finish account creation and rerun the saved resume command.' }
}
if (-not $PSCmdlet.ShouldProcess("$Distribution ($linuxUser)", 'Run the Ubuntu Ansible dotfiles setup')) { return }

# Write LF even from a CRLF Windows checkout, and pass arguments without bash -c interpolation.
$tempScript = [IO.Path]::GetTempFileName()
try {
    $content = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'bootstrap-wsl.sh')).Replace("`r`n", "`n")
    [IO.File]::WriteAllText($tempScript, $content, (New-Object Text.UTF8Encoding $false))
    $linuxScript = ((& $wslExe --distribution $Distribution --exec wslpath -a $tempScript) -join '').Trim()
    if ($LASTEXITCODE -ne 0 -or -not $linuxScript) { throw 'Cannot map bootstrap script into Ubuntu.' }
    $ansibleArguments = if ($IncludeOllama) { @() } else { @('--skip-tags', 'ollama') }
    & $wslExe --distribution $Distribution --exec bash $linuxScript $Repository $Ref @ansibleArguments
    if ($LASTEXITCODE -ne 0) { throw "Ubuntu Ansible setup failed: $LASTEXITCODE. See ~/.local/state/dotfiles/ansible-setup.log inside $Distribution for the failed task." }
} finally {
    Remove-Item -LiteralPath $tempScript -Force -ErrorAction SilentlyContinue
}
[pscustomobject]@{ ResumeStatus = 'Complete' }
