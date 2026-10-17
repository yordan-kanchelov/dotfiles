#Requires -Version 5.1
# Exercise the real Herdr binary against an isolated profile, without touching user hooks.
$ErrorActionPreference = 'Stop'
$original = @{}
foreach ($name in @('USERPROFILE', 'HOME', 'APPDATA', 'LOCALAPPDATA')) {
    $original[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
$taskProfile = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-herdr-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskProfile | Out-Null
try {
    $env:USERPROFILE = $taskProfile
    $env:HOME = $taskProfile
    $env:APPDATA = Join-Path $taskProfile 'Roaming'
    $env:LOCALAPPDATA = Join-Path $taskProfile 'Local'
    $installer = Join-Path $PSScriptRoot 'install-herdr.ps1'
    $preview = & $installer -WhatIf -OutputJson | Select-Object -Last 1 | ConvertFrom-Json
    if ($preview.changed -or $preview.planned.Count -ne 4) { throw 'Invalid initial preview.' }
    if (Test-Path (Join-Path $taskProfile '.claude')) { throw 'Preview wrote to the profile.' }
    $fixtureSkills = Join-Path $taskProfile 'repo-skills'
    New-Item -ItemType Directory -Path $fixtureSkills | Out-Null
    [IO.File]::WriteAllText((Join-Path $fixtureSkills 'existing.txt'), 'preserve')
    New-Item -ItemType Directory -Path (Join-Path $taskProfile '.claude') | Out-Null
    New-Item -ItemType Junction -Path (Join-Path $taskProfile '.claude\skills') -Target $fixtureSkills | Out-Null
    $first = & $installer -OutputJson | ConvertFrom-Json
    if (-not $first.changed) { throw 'First install reported no change.' }
    if ((Get-Item (Join-Path $taskProfile '.claude\skills')).LinkType) { throw 'Skills link was not migrated.' }
    if (Test-Path (Join-Path $fixtureSkills 'herdr')) { throw 'Installer wrote through the skills link.' }
    if (-not (Test-Path (Join-Path $taskProfile '.claude\skills\existing.txt'))) { throw 'Migration lost existing skills.' }
    foreach ($target in @('claude', 'codex')) {
        if (-not (Test-Path (Join-Path $taskProfile ".$target\skills\herdr\SKILL.md"))) { throw "Missing $target skill" }
    }
    foreach ($run in 1..2) {
        $repeat = & $installer -OutputJson | ConvertFrom-Json
        if ($repeat.changed -or $repeat.planned.Count) { throw "Repeat run $run changed the profile." }
    }
    Write-Host 'PASS: isolated real Herdr install, skills, repeatability and preview.'
} finally {
    foreach ($name in $original.Keys) { [Environment]::SetEnvironmentVariable($name, $original[$name], 'Process') }
    # Leave the isolated profile available for inspection; never recursively delete a computed path.
    Write-Host "Test profile: $taskProfile"
}
