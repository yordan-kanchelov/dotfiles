#Requires -Version 5.1
# Full launcher regression with isolated paths, native WSL stub and elevation/reboot seams.
$ErrorActionPreference = 'Stop'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-wsl-launcher-' + [guid]::NewGuid().ToString('N'))
$original = @{}
foreach ($name in @('ProgramFiles', 'WINDIR', 'LOCALAPPDATA', 'DOTFILES_WSL_CALLS', 'DOTFILES_WSL_VERSION_EXIT')) { $original[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$state = [pscustomobject]@{ InstallState = 2; Elevations = 0; Restarts = 0; HelperExit = 0; HelperResult = '{"RestartRequired":true}'; RejectElevation = $false }
New-Item -ItemType Directory -Path (Join-Path $fixture 'WSL') -Force | Out-Null
try {
    $env:ProgramFiles = $fixture
    $env:WINDIR = $fixture
    $env:DOTFILES_WSL_VERSION_EXIT = '1'
    $env:LOCALAPPDATA = Join-Path $fixture 'local'
    $env:DOTFILES_WSL_CALLS = Join-Path $fixture 'native.calls'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'setup-wsl.ps1') -Destination (Join-Path $fixture 'setup-wsl.ps1')
    $registerStub = @'
function Register-WslResume {
    param([hashtable]$Options)
    $path = Join-Path $env:LOCALAPPDATA 'options.json'
    New-Item -ItemType Directory -Path $env:LOCALAPPDATA -Force | Out-Null
    [IO.File]::WriteAllText($path, ($Options | ConvertTo-Json))
    $path
}
'@
    [IO.File]::WriteAllText((Join-Path $fixture 'wsl-resume-state.ps1'), $registerStub)
    $native = @'
using System;
using System.IO;
public class WslLauncherFixture {
    public static int Main(string[] args) {
        File.AppendAllText(Environment.GetEnvironmentVariable("DOTFILES_WSL_CALLS"), string.Join(" ", args) + "\n");
        if (args.Length > 0 && args[0] == "--version") { return int.Parse(Environment.GetEnvironmentVariable("DOTFILES_WSL_VERSION_EXIT")); }
        if (args.Length > 0 && args[0] == "--list") { return 0; }
        if (args.Length > 0 && args[0] == "--install") { return 3010; }
        Console.WriteLine("OPTIONAL_COMPONENT_REQUIRED"); return 1;
    }
}
'@
    $source = Join-Path $fixture 'wsl.cs'
    [IO.File]::WriteAllText($source, $native)
    & (Join-Path $original.WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe') /nologo /target:exe (('/out:') + (Join-Path $fixture 'WSL\wsl.exe')) $source
    if ($LASTEXITCODE -ne 0) { throw 'Cannot compile isolated WSL fixture.' }
    New-Item -ItemType Directory -Path (Join-Path $fixture 'System32') | Out-Null
    Copy-Item -LiteralPath (Join-Path $fixture 'WSL\wsl.exe') -Destination (Join-Path $fixture 'System32\wsl.exe')
    function Get-CimInstance { param($ClassName) [pscustomobject]@{ Name = 'VirtualMachinePlatform'; InstallState = $state.InstallState } }
    function Get-WindowsOptionalFeature { param([switch]$Online, $FeatureName) [pscustomobject]@{ State = 'Disabled' } }
    function Start-Process {
        param($FilePath, $ArgumentList, $Verb, [switch]$Wait, [switch]$PassThru)
        if ($state.RejectElevation) { throw 'Fixture elevation was rejected.' }
        if ($Verb -ne 'RunAs' -or -not $Wait -or -not $PassThru -or ($ArgumentList -join ' ') -notmatch 'enable-wsl-platform.ps1') { throw 'Unexpected elevation request.' }
        if ($env:DOTFILES_WSL_VERSION_EXIT -eq '1' -and '-InstallPackage' -notin $ArgumentList) { throw 'Missing WSL package must be installed in the elevated helper.' }
        $match = [regex]::Match(($ArgumentList -join ' '), '-ResultPath "([^"]+)"')
        if (-not $match.Success) { throw 'Missing isolated feature result path.' }
        [IO.File]::WriteAllText($match.Groups[1].Value, $state.HelperResult)
        $state.Elevations++
        [pscustomobject]@{ ExitCode = $state.HelperExit }
    }
    function Restart-Computer { param($ErrorAction) $state.Restarts++ }
    $launcher = Join-Path $fixture 'setup-wsl.ps1'
    & $launcher -WhatIf
    if ($state.Elevations -or $state.Restarts -or (Test-Path $env:LOCALAPPDATA)) { throw 'WSL preview changed state.' }
    if ((Test-Path $env:DOTFILES_WSL_CALLS) -and @(Get-Content $env:DOTFILES_WSL_CALLS | Where-Object { $_ -ne '--version' }).Count) { throw 'Preview performed more than a read-only version query.' }
    $manualOutput = @(& $launcher -Ref 'feat/windows-setup' 6>&1)
    $result = $manualOutput | Where-Object { $_.PSObject.Properties['ResumeStatus'] } | Select-Object -Last 1
    $manualText = ($manualOutput | ForEach-Object { $_.ToString() }) -join "`n"
    if ($manualText -notmatch '(?s)Manual resume command:.*resume-wsl.ps1.*-StateFile') { throw 'Manual resume command was not printed.' }
    if ($state.Elevations -ne 1) { throw 'Default WSL setup did not enable the missing platform feature.' }
    if ($state.Restarts -or $result.ResumeStatus -ne 'RestartRequired') { throw 'Default WSL setup rebooted or lost restart-required status.' }
    if (@(Get-Content $env:DOTFILES_WSL_CALLS -ErrorAction SilentlyContinue | Where-Object { $_ -ne '--version' }).Count) { throw 'WSL distro was accessed before the feature restart.' }
    $options = Get-Content (Join-Path $env:LOCALAPPDATA 'options.json') -Raw | ConvertFrom-Json
    if ($options.Ref -ne 'feat/windows-setup' -or $options.RestartAndResume) { throw 'Manual resume lost ref or granted automatic-reboot consent.' }
    $result = & $launcher -Ref 'feat/windows-setup' -RestartAndResume | Where-Object { $_.PSObject.Properties['ResumeStatus'] } | Select-Object -Last 1
    if ($state.Restarts -ne 1 -or $result.ResumeStatus -ne 'RestartScheduled') { throw 'Explicit automatic restart was not honored.' }
    $options = Get-Content (Join-Path $env:LOCALAPPDATA 'options.json') -Raw | ConvertFrom-Json
    if (-not $options.RestartAndResume -or $options.RestartAttempt -ne 1) { throw 'Automatic resume lost restart consent or attempt counter.' }
    $state.InstallState = 1
    $env:DOTFILES_WSL_VERSION_EXIT = '0'
    $result = & $launcher | Where-Object { $_.PSObject.Properties['ResumeStatus'] } | Select-Object -Last 1
    if ($state.Elevations -ne 2 -or $state.Restarts -ne 1) { throw 'Enabled platform requested elevation or reboot.' }
    if ($result.ResumeStatus -ne 'RestartRequired') { throw 'Distro install exit 3010 was not handled.' }
    $state.InstallState = 2
    $savedOptions = [IO.File]::ReadAllText((Join-Path $env:LOCALAPPDATA 'options.json'))
    foreach ($case in @('rejected', 'nonzero', 'malformed', 'missing', 'limit')) {
        $state.HelperExit = 0
        $state.HelperResult = '{"RestartRequired":true}'
        $state.RejectElevation = $case -eq 'rejected'
        $arguments = @{}
        switch ($case) {
            'rejected' { $expected = 'Fixture elevation was rejected' }
            'nonzero' { $state.HelperExit = 5; $expected = 'WSL platform enablement failed' }
            'malformed' { $state.HelperResult = 'not JSON'; $expected = 'JSON|Json|json' }
            'missing' { $state.HelperResult = '{}'; $expected = 'no usable result' }
            'limit' { $arguments = @{ RestartAndResume = $true; RestartAttempt = 2 }; $expected = 'Automatic restart limit reached' }
        }
        try {
            & $launcher @arguments | Out-Null
            throw "Expected failure for $case was not propagated."
        } catch {
            if ($_.Exception.Message -notmatch $expected) { throw }
        }
        if ($state.Restarts -ne 1 -or [IO.File]::ReadAllText((Join-Path $env:LOCALAPPDATA 'options.json')) -cne $savedOptions) { throw "Failure case $case changed restart or saved options." }
    }
    Write-Host 'PASS: WSL preview, platform initialization, restart consent, enabled-platform path and failure propagation.'
} finally {
    foreach ($name in $original.Keys) { [Environment]::SetEnvironmentVariable($name, $original[$name], 'Process') }
    foreach ($name in @('Get-CimInstance', 'Get-WindowsOptionalFeature', 'Start-Process', 'Restart-Computer')) { Remove-Item ('Function:\' + $name) -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $fixture -Recurse -Force
}
