#Requires -Version 5.1
# Test persistence without scheduling a real login action or restarting Windows.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'wsl-resume-state.ps1')
$id = [guid]::NewGuid().ToString('N')
$stateDirectory = Join-Path ([IO.Path]::GetTempPath()) ('wsl-resume-' + $id)
$registryPath = 'HKCU:\Software\DotfilesWslTest-' + $id
$options = @{ Distribution = 'Ubuntu'; Repository = 'https://github.com/yordan-kanchelov/dotfiles.git'; Ref = 'feat/windows-setup'; IncludeOllama = $false; RestartAttempt = 1; RestartAndResume = $true }
New-Item -Path $registryPath | Out-Null
New-ItemProperty -LiteralPath $registryPath -Name 'Unrelated' -Value 'keep' -PropertyType String | Out-Null
try {
    Register-WslResume -Options $options -StateDirectory $stateDirectory -RegistryPath $registryPath -WhatIf | Out-Null
    if (Test-Path -LiteralPath $stateDirectory) { throw 'Resume dry run wrote state.' }
    if ((Get-Item -LiteralPath $registryPath).GetValueNames().Count -ne 1) { throw 'Resume dry run changed registry.' }
    foreach ($run in 1..2) {
        $stateFile = Register-WslResume -Options $options -StateDirectory $stateDirectory -RegistryPath $registryPath
        $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
        if ($state.Ref -ne $options.Ref -or $state.RestartAttempt -ne 1 -or $state.IncludeOllama) { throw 'Incorrect saved resume options.' }
        $key = Get-Item -LiteralPath $registryPath
        if ($key.GetValue('Unrelated') -ne 'keep') { throw 'Unrelated login entry was lost.' }
        if ($key.GetValue('DotfilesWslSetup') -notlike '*resume-wsl.ps1*') { throw 'Missing resume command.' }
        if ($key.GetValueNames().Count -ne 2) { throw 'Duplicate resume entries.' }
    }
    # Exercise the actual resume loader against an isolated setup stub, never real WSL/reboot.
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'resume-wsl.ps1') -Destination (Join-Path $stateDirectory 'resume-wsl.ps1')
    $stub = @'
param($Distribution, $Repository, $Ref, [switch]$IncludeOllama, [switch]$RestartAndResume, [int]$RestartAttempt, [switch]$Resume)
$expectedAutoRestart = [bool]::Parse([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'expected-auto.txt')))
if ([bool]$RestartAndResume -ne $expectedAutoRestart -or -not $Resume -or $RestartAttempt -ne 1 -or $Ref -ne 'feat/windows-setup') {
    throw 'Resume loader lost its original arguments.'
}
$status = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'status.txt'))
[pscustomobject]@{ ResumeStatus = $status }
'@
    [IO.File]::WriteAllText((Join-Path $stateDirectory 'setup-wsl.ps1'), $stub)
    [IO.File]::WriteAllText((Join-Path $stateDirectory 'expected-auto.txt'), 'True')
    [IO.File]::WriteAllText((Join-Path $stateDirectory 'status.txt'), 'RestartScheduled')
    & (Join-Path $stateDirectory 'resume-wsl.ps1') -StateFile $stateFile
    if (-not (Test-Path -LiteralPath $stateFile)) { throw 'Resume state was removed before the next scheduled restart.' }
    [IO.File]::WriteAllText((Join-Path $stateDirectory 'status.txt'), 'Complete')
    & (Join-Path $stateDirectory 'resume-wsl.ps1') -StateFile $stateFile
    if (Test-Path -LiteralPath $stateFile) { throw 'Completed resume left stale state.' }
    $options.RestartAndResume = $false
    $stateFile = Register-WslResume -Options $options -StateDirectory $stateDirectory -RegistryPath $registryPath
    [IO.File]::WriteAllText((Join-Path $stateDirectory 'expected-auto.txt'), 'False')
    [IO.File]::WriteAllText((Join-Path $stateDirectory 'status.txt'), 'RestartRequired')
    & (Join-Path $stateDirectory 'resume-wsl.ps1') -StateFile $stateFile
    if (-not (Test-Path -LiteralPath $stateFile)) { throw 'Manual restart resume state was removed early.' }
    [IO.File]::WriteAllText((Join-Path $stateDirectory 'status.txt'), 'Complete')
    & (Join-Path $stateDirectory 'resume-wsl.ps1') -StateFile $stateFile
    if (Test-Path -LiteralPath $stateFile) { throw 'Completed manual resume left stale state.' }
    Write-Host 'PASS: resume dry run, saved options, automatic-restart consent, login-entry preservation and repeatability; no restart performed.'
} finally {
    Remove-Item -LiteralPath $registryPath -Force
    if (Test-Path -LiteralPath $stateDirectory) {
        foreach ($name in @('wsl-resume.json', 'resume-wsl.ps1', 'setup-wsl.ps1', 'status.txt', 'expected-auto.txt')) {
            $path = Join-Path $stateDirectory $name
            if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
        }
        Remove-Item -LiteralPath $stateDirectory
    }
}
