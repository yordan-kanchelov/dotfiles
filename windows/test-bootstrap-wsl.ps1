#Requires -Version 5.1
# Exercise the real bootstrap only in a copied repository with a harmless WSL stub.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-bootstrap-wsl-' + [guid]::NewGuid().ToString('N'))
$fixtureRepo = Join-Path $fixtureRoot 'repo'
New-Item -ItemType Directory -Path (Join-Path $fixtureRepo '.config\nvim'), (Join-Path $fixtureRepo '.config\yazi'), (Join-Path $fixtureRepo '.config\herdr'), (Join-Path $fixtureRepo 'windows') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'bootstrap.ps1') -Destination $fixtureRepo
Copy-Item -LiteralPath (Join-Path $repo '.config\herdr\config.toml') -Destination (Join-Path $fixtureRepo '.config\herdr')
[IO.File]::WriteAllText((Join-Path $fixtureRepo 'windows\terminal.json'), '{}')
$stub = @'
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Distribution = 'Ubuntu',
    [string]$Repository = 'https://github.com/yordan-kanchelov/dotfiles.git',
    [string]$Ref = 'main',
    [switch]$RestartAndResume,
    [switch]$IncludeOllama
)
if (-not $WhatIfPreference) {
    foreach ($path in @('local\nvim', 'roaming\yazi\config', 'roaming\herdr\config.toml', 'profile.ps1', 'local\Microsoft\Windows Terminal\Fragments\dotfiles\terminal.json')) {
        if (-not (Test-Path -LiteralPath (Join-Path $env:DOTFILES_BOOTSTRAP_CASE_ROOT $path))) {
            throw "WSL invoked before native configuration: $path"
        }
    }
}
[IO.File]::WriteAllText((Join-Path $env:DOTFILES_BOOTSTRAP_CASE_ROOT 'invocation.json'), (@{
    Distribution = $Distribution; Repository = $Repository; Ref = $Ref
    RestartAndResume = [bool]$RestartAndResume; IncludeOllama = [bool]$IncludeOllama
    WhatIf = [bool]$WhatIfPreference
} | ConvertTo-Json))
Write-Host 'WSL host progress'
Write-Output 'WSL pipeline progress'
[pscustomobject]@{ Progress = 'WSL unrelated object' }
if ($env:DOTFILES_BOOTSTRAP_STATUS -eq 'Throw') { throw 'WSL fixture failure sentinel' }
if ($env:DOTFILES_BOOTSTRAP_STATUS -eq 'WriteError') { Write-Error 'WSL fixture failure sentinel' }
if ($env:DOTFILES_BOOTSTRAP_STATUS -eq 'CompleteThenThrow') {
    [pscustomobject]@{ ResumeStatus = 'Complete' }
    throw 'WSL fixture failure sentinel'
}
if ($env:DOTFILES_BOOTSTRAP_STATUS -eq 'Duplicate') {
    [pscustomobject]@{ ResumeStatus = 'RestartRequired' }
    [pscustomobject]@{ ResumeStatus = 'Complete' }
} elseif ($env:DOTFILES_BOOTSTRAP_STATUS -ne 'Missing') {
    [pscustomobject]@{ ResumeStatus = $env:DOTFILES_BOOTSTRAP_STATUS }
}
Write-Output 'WSL trailing progress'
'@
[IO.File]::WriteAllText((Join-Path $fixtureRepo 'windows\setup-wsl.ps1'), $stub)
$savedCaseRoot = $env:DOTFILES_BOOTSTRAP_CASE_ROOT
$savedStatus = $env:DOTFILES_BOOTSTRAP_STATUS
$env:DOTFILES_BOOTSTRAP_STATUS = 'Complete'
$savedPath = $env:Path
function Invoke-BootstrapCase([string]$Name, [hashtable]$Options = @{}, [switch]$AllowFailure) {
    $caseRoot = Join-Path $fixtureRoot $Name
    New-Item -ItemType Directory -Path $caseRoot -Force | Out-Null
    $env:DOTFILES_BOOTSTRAP_CASE_ROOT = $caseRoot
    $arguments = @{
        SkipPackages = $true; SkipNode = $true; SkipFonts = $true
        HomeDirectory = (Join-Path $caseRoot 'home'); LocalAppDataDirectory = (Join-Path $caseRoot 'local')
        RoamingAppDataDirectory = (Join-Path $caseRoot 'roaming'); ProfilePath = (Join-Path $caseRoot 'profile.ps1')
    }
    foreach ($key in $Options.Keys) { $arguments[$key] = $Options[$key] }
    $output = New-Object System.Collections.ArrayList
    $failure = $null
    try {
        & (Join-Path $fixtureRepo 'bootstrap.ps1') @arguments *>&1 | ForEach-Object { [void]$output.Add($_) }
    } catch {
        $failure = $_
        if (-not $AllowFailure) { throw }
    }
    $invocationPath = Join-Path $caseRoot 'invocation.json'
    $invocation = if (Test-Path -LiteralPath $invocationPath) { Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json } else { $null }
    [pscustomobject]@{ Invocation = $invocation; Output = ($output | Out-String); Root = $caseRoot; Failure = $failure }
}
function Assert-True($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
try {
    $result = Invoke-BootstrapCase 'default'
    Assert-True ($null -ne $result.Invocation) 'Default bootstrap did not invoke WSL.'
    Assert-True ($result.Invocation.Distribution -eq 'Ubuntu') 'Default distribution is not Ubuntu.'
    Assert-True ($result.Invocation.Repository -eq 'https://github.com/yordan-kanchelov/dotfiles.git') 'Default repository changed.'
    Assert-True ($result.Invocation.Ref -eq 'main') 'Default ref is not main.'
    Assert-True (-not $result.Invocation.RestartAndResume) 'Default bootstrap permits automatic restart.'
    Assert-True (-not $result.Invocation.IncludeOllama) 'Default bootstrap includes Ollama.'
    Assert-True ($result.Output -match 'WSL pipeline progress') 'Lost WSL pipeline output.'
    Assert-True ($result.Output -match 'WSL host progress') 'Lost WSL host output.'
    Assert-True ($result.Output -match 'WSL trailing progress') 'Lost trailing WSL output.'
    Assert-True ($result.Output -match 'WSL unrelated object') 'Lost unrelated WSL pipeline object.'
    Assert-True ($result.Output -match 'Setup complete') 'Complete status did not report full completion.'
    Write-Host 'PASS: default WSL invocation follows native configuration and preserves human output.'

    $result = Invoke-BootstrapCase 'skip' @{ SkipWsl = $true }
    Assert-True ($null -eq $result.Invocation) 'SkipWsl invoked WSL.'
    Assert-True ($result.Output -match 'Native Windows setup complete') 'SkipWsl did not report native-only completion.'
    $result = Invoke-BootstrapCase 'skip-preview' @{ SkipWsl = $true; WhatIf = $true; RestartAndResume = $true }
    Assert-True ($null -eq $result.Invocation) 'SkipWsl preview invoked WSL.'
    Write-Host 'PASS: SkipWsl is native-only.'

    $options = @{
        WslDistribution = 'Ubuntu-24.04'; WslRepository = 'https://example.invalid/custom/dotfiles.git'
        WslRef = 'feat/windows-setup'; RestartAndResume = $true; IncludeOllama = $true
    }
    $result = Invoke-BootstrapCase 'forward' $options
    Assert-True ($result.Invocation.Distribution -eq $options.WslDistribution) 'Distribution was not forwarded.'
    Assert-True ($result.Invocation.Repository -eq $options.WslRepository) 'Repository was not forwarded.'
    Assert-True ($result.Invocation.Ref -eq $options.WslRef) 'Ref was not forwarded.'
    Assert-True ($result.Invocation.RestartAndResume -and $result.Invocation.IncludeOllama) 'Opt-in switches were not forwarded.'
    Assert-True (-not $result.Invocation.WhatIf) 'Actual run unexpectedly enabled WhatIf.'
    Write-Host 'PASS: explicit WSL options forwarded.'

    $options.WhatIf = $true
    $result = Invoke-BootstrapCase 'preview' $options
    Assert-True ($result.Invocation.WhatIf) 'WhatIf was not forwarded to WSL.'
    Assert-True ($result.Invocation.Ref -eq $options.WslRef -and $result.Invocation.RestartAndResume) 'Preview lost WSL options.'
    foreach ($path in @('home', 'local', 'roaming', 'profile.ps1')) {
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $result.Root $path))) "Preview wrote native configuration: $path"
    }
    Assert-True ($result.Output -match 'Preview complete' -and $result.Output -notmatch '(?i)setup complete') 'Preview claimed setup completion.'
    Write-Host 'PASS: WhatIf reaches WSL without native configuration writes.'

    foreach ($status in @('RestartRequired', 'RestartScheduled')) {
        $env:DOTFILES_BOOTSTRAP_STATUS = $status
        $result = Invoke-BootstrapCase $status @{ RestartAndResume = ($status -eq 'RestartScheduled') }
        Assert-True ($result.Output -notmatch '(?i)setup complete') "$status falsely claimed full completion."
        Assert-True ($result.Output -match 'Native Windows configuration complete') "$status did not identify finished native configuration."
        Assert-True ($result.Output -match $status) "$status was not reported."
        if ($status -eq 'RestartRequired') {
            Assert-True ($result.Output -match 'manually' -and $result.Output -match 'resume') 'Manual restart/resume guidance missing.'
        } else {
            Assert-True ($result.Output -match 'login') 'Scheduled restart omitted login/resume guidance.'
        }
    }
    Write-Host 'PASS: restart-required/scheduled never claim full completion.'

    foreach ($status in @('Missing', 'Unknown', 'Duplicate')) {
        $env:DOTFILES_BOOTSTRAP_STATUS = $status
        $result = Invoke-BootstrapCase $status @{} -AllowFailure
        Assert-True ($null -ne $result.Failure) "$status WSL status did not fail."
        Assert-True ($result.Failure.ToString() -match 'ResumeStatus') 'Unrecognized status failure was not clear.'
        Assert-True ($result.Output -notmatch '(?i)setup complete') "$status WSL status claimed completion."
    }
    # Real setup-wsl intentionally emits no ResumeStatus for a dry run.
    $env:DOTFILES_BOOTSTRAP_STATUS = 'Missing'
    $result = Invoke-BootstrapCase 'preview-no-status' @{ WhatIf = $true }
    Assert-True ($result.Output -match 'Preview complete') 'Preview requires a real-run status.'
    Write-Host 'PASS: actual runs require a recognized ResumeStatus; preview does not.'

    foreach ($status in @('Throw', 'WriteError', 'CompleteThenThrow')) {
        $env:DOTFILES_BOOTSTRAP_STATUS = $status
        $result = Invoke-BootstrapCase $status @{} -AllowFailure
        Assert-True ($null -ne $result.Failure) "$status WSL failure did not propagate."
        Assert-True ($result.Failure.ToString() -match 'WSL fixture failure sentinel') 'WSL failure lost original error context.'
        Assert-True ($result.Output -notmatch '(?i)setup complete') "$status WSL failure claimed completion."
        Assert-True ($result.Output -match 'WSL pipeline progress') 'WSL failure lost preceding human output.'
    }
    Write-Host 'PASS: WSL terminating/nonterminating failures propagate, including failure after Complete.'
    Write-Host "Fixtures: $fixtureRoot"
} finally {
    $env:DOTFILES_BOOTSTRAP_CASE_ROOT = $savedCaseRoot
    $env:DOTFILES_BOOTSTRAP_STATUS = $savedStatus
    $env:Path = $savedPath
}
# Leave generated fixtures in Temp; never recursively delete trees containing junctions.
