#Requires -Version 5.1
# Exercise the real font installer without touching the user's font registry key.
# Default: a local fixture archive, no network. -Download fetches the real Nerd Fonts archive.
param([switch]$Download)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$id = [guid]::NewGuid().ToString('N')
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-fonts-' + $id)
$registryPath = 'HKCU:\Software\DotfilesFontTest-' + $id
$arguments = @{
    SkipPackages = $true; SkipNode = $true; SkipTerminal = $true; SkipWsl = $true
    HomeDirectory = (Join-Path $fixtureRoot 'home')
    LocalAppDataDirectory = (Join-Path $fixtureRoot 'local')
    RoamingAppDataDirectory = (Join-Path $fixtureRoot 'roaming')
    ProfilePath = (Join-Path $fixtureRoot 'profile.ps1')
    FontRegistryPath = $registryPath
}
$archiveFiles = @()
if (-not $Download) {
    # Outside $fixtureRoot: the dry run below must leave that directory absent.
    $archiveSource = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-font-archive-' + $id)
    New-Item -ItemType Directory -Path $archiveSource | Out-Null
    foreach ($style in @('Bold', 'Italic', 'Regular')) {
        $face = Join-Path $archiveSource "0xProtoNerdFont-$style.ttf"
        [IO.File]::WriteAllText($face, "fixture $style")
        $archiveFiles += $face
    }
    $arguments.FontArchive = $archiveSource + '.zip'
    Compress-Archive -Path $archiveFiles -DestinationPath $arguments.FontArchive
}
New-Item -Path $registryPath | Out-Null
New-ItemProperty -LiteralPath $registryPath -Name 'Unrelated font (TrueType)' -Value 'sentinel.ttf' -PropertyType String | Out-Null
try {
    & (Join-Path $repo 'bootstrap.ps1') @arguments -WhatIf
    if ((Get-Item -LiteralPath $registryPath).GetValueNames().Count -ne 1) { throw 'Font dry run changed registry.' }
    if (Test-Path -LiteralPath $fixtureRoot) { throw 'Font dry run created files.' }
    foreach ($run in 1..2) {
        & (Join-Path $repo 'bootstrap.ps1') @arguments
        $key = Get-Item -LiteralPath $registryPath
        if ($key.GetValue('Unrelated font (TrueType)') -ne 'sentinel.ttf') { throw 'Unrelated font registration was lost.' }
        foreach ($style in @('Bold', 'Italic', 'Regular')) {
            $fontPath = $key.GetValue("0xProto Nerd Font $style (TrueType)")
            if (-not $fontPath -or -not (Test-Path -LiteralPath $fontPath)) { throw "Missing font after run ${run}: $style" }
        }
        if ($key.GetValueNames().Count -ne 4) { throw 'Unexpected font registrations.' }
    }
    if (Test-Path -LiteralPath (Join-Path $fixtureRoot 'home\.dotfiles_backup')) { throw 'Second run changed installed fonts.' }
    Write-Host 'PASS: font dry run, unrelated registration preservation and repeated font installation.'
} finally {
    # Only this generated leaf key is removed; no recursive registry removal.
    Remove-Item -LiteralPath $registryPath -Force
    # The fixture archive and its three source files, one by one; nothing recursive.
    if ($archiveFiles.Count) {
        Remove-Item -LiteralPath (@($archiveFiles) + $arguments.FontArchive) -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $archiveSource -ErrorAction SilentlyContinue
    }
}
