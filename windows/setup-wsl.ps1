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
    if (-not $RestartAndResume) {
        Write-Host 'Windows needs a restart. Restart and rerun, or use -RestartAndResume to automate the next login.'
        return [pscustomobject]@{ ResumeStatus = 'RestartRequired' }
    }
    if ($RestartAttempt -ge 2) { throw 'Automatic restart limit reached. Check WSL and restart Windows manually before retrying.' }
    if ($PSCmdlet.ShouldProcess('Windows', 'Save setup options, restart, and resume at next login')) {
        Register-WslResume -Options @{
            Distribution = $Distribution; Repository = $Repository; Ref = $Ref
            IncludeOllama = [bool]$IncludeOllama; RestartAttempt = $RestartAttempt + 1
        } | Out-Null
        Write-Host 'Setup will resume in a PowerShell console after your next login. Restarting Windows now.'
        # No -Force: do not forcibly close applications with unsaved work.
        Restart-Computer -ErrorAction Stop
    }
    return [pscustomobject]@{ ResumeStatus = 'RestartScheduled' }
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
$wslExe = Join-Path $env:ProgramFiles 'WSL\wsl.exe'
if (-not (Test-Path -LiteralPath $wslExe)) {
    if ($PSCmdlet.ShouldProcess('Microsoft.WSL', 'Install WSL through WinGet')) {
        & winget install --id Microsoft.WSL --exact --source winget --silent --accept-source-agreements --accept-package-agreements --disable-interactivity
        if ($LASTEXITCODE -notin @(0, 3010)) { throw "WSL installation failed: $LASTEXITCODE" }
        if ($LASTEXITCODE -eq 3010) {
            Request-WslRestart
            return
        }
    }
}
if ($WhatIfPreference) {
    Write-Host "Would install/start $Distribution, then run the Linux Ansible bootstrap from $Repository ($Ref)."
    if ($RestartAndResume) { Write-Host 'Would save options, restart Windows if needed, and resume at next login.' }
    return
}
$isAdministrator = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdministrator) {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
    if ($feature.State -eq 'EnablePending') {
        Request-WslRestart
        return
    }
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
    Write-Host 'Finish Ubuntu first-run account creation below. Once its shell opens, type exit so setup can continue.'
    & $wslExe --distribution $Distribution
    if ($LASTEXITCODE -ne 0) { throw 'Ubuntu first-run initialization did not finish.' }
    $linuxUser = ((& $wslExe --distribution $Distribution --exec id -un) -join '').Trim()
    if ($LASTEXITCODE -ne 0 -or $linuxUser -eq 'root') { throw 'Ubuntu still has no normal default user. Finish account creation and rerun the saved resume command.' }
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
    if ($LASTEXITCODE -ne 0) { throw "Ubuntu Ansible setup failed: $LASTEXITCODE" }
} finally {
    Remove-Item -LiteralPath $tempScript -Force -ErrorAction SilentlyContinue
}
[pscustomobject]@{ ResumeStatus = 'Complete' }
