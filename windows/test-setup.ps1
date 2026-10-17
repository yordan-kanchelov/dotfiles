#Requires -Version 5.1
# Integration check: conflicting configs, profile preservation, repeatability, dry run.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-windows-' + [guid]::NewGuid().ToString('N'))
$testHome = Join-Path $testRoot 'home'
$testLocal = Join-Path $testRoot 'local'
$testRoaming = Join-Path $testRoot 'roaming'
$testProfile = Join-Path $testHome 'PowerShell\profile.ps1'
$arguments = @{
    SkipPackages = $true; SkipNode = $true; SkipFonts = $true; SkipWsl = $true
    HomeDirectory = $testHome; LocalAppDataDirectory = $testLocal
    RoamingAppDataDirectory = $testRoaming; ProfilePath = $testProfile
}
New-Item -ItemType Directory -Path (Join-Path $testLocal 'nvim'), (Split-Path -Parent $testProfile) -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $testLocal 'nvim\existing.txt'), 'keep me')
[IO.File]::WriteAllText($testProfile, '# personal profile')

& (Join-Path $repo 'bootstrap.ps1') @arguments -WhatIf
if ([IO.File]::ReadAllText($testProfile) -ne '# personal profile') { throw 'Dry run changed profile.' }
if (Test-Path -LiteralPath (Join-Path $testHome '.dotfiles_backup')) { throw 'Dry run wrote backups.' }
if (Test-Path -LiteralPath $testRoaming) { throw 'Dry run created configuration.' }

& (Join-Path $repo 'bootstrap.ps1') @arguments
if ((Get-Item -LiteralPath (Join-Path $testLocal 'nvim')).LinkType -ne 'Junction') { throw 'Missing junction.' }
if ([IO.File]::ReadAllText((Join-Path $testRoaming 'herdr\config.toml')) -cne [IO.File]::ReadAllText((Join-Path $repo '.config\herdr\config.toml'))) { throw 'Herdr config not deployed.' }
$profileOnce = [IO.File]::ReadAllText($testProfile)
if (-not $profileOnce.StartsWith('# personal profile')) { throw 'Personal profile lost.' }
$backups = @(Get-ChildItem -LiteralPath (Join-Path $testHome '.dotfiles_backup') -Recurse -File)
if (-not ($backups | Where-Object { $_.Name -eq 'existing.txt' })) { throw 'Config backup missing.' }
$backupCount = $backups.Count
$fragment = Join-Path $testLocal 'Microsoft\Windows Terminal\Fragments\dotfiles\terminal.json'
$fragmentHash = (Get-FileHash -LiteralPath $fragment).Hash
& (Join-Path $repo 'bootstrap.ps1') @arguments
if ([IO.File]::ReadAllText($testProfile) -cne $profileOnce) { throw 'Second run changed profile.' }
if (([regex]::Matches($profileOnce, '# >>> dotfiles Windows >>>')).Count -ne 1) { throw 'Duplicate managed blocks.' }
if (@(Get-ChildItem -LiteralPath (Join-Path $testHome '.dotfiles_backup') -Recurse -File).Count -ne $backupCount) { throw 'Second run made backups.' }
if ((Get-FileHash -LiteralPath $fragment).Hash -ne $fragmentHash) { throw 'Second run changed terminal config.' }
Write-Host "PASS: dry run, backup, junction, profile preservation and second-run stability. Fixtures: $testRoot"
# Leave fixtures in Temp: do not recursively delete a tree containing repo junctions.
