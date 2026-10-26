# Run with pwsh -NoLogo -File .\windows\test-profile.ps1 after installation.
$ErrorActionPreference = 'Stop'
$packages = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'packages.json') -Raw | ConvertFrom-Json
foreach ($package in $packages) {
    $command = Get-Command $package.command -ErrorAction Stop
    Write-Host "OK: $($package.command) -> $($command.Source)"
}
foreach ($name in @('lg', 'vim', 'l', 'fvim', 'y', 'reload')) {
    if ((Get-Command $name).CommandType -ne 'Function') { throw "Missing profile function: $name" }
}
if (-not (Test-Path -LiteralPath $env:STARSHIP_CONFIG)) { throw 'Missing Starship config.' }
if (-not (Test-Path -LiteralPath $env:YAZI_FILE_ONE)) { throw 'Missing Yazi file.exe.' }
& node --version
if ($LASTEXITCODE -ne 0) { throw 'fnm did not initialize Node.' }

# Exercise the Yazi wrapper with a path containing spaces, without launching a TUI.
$previousDirectory = Get-Location
$destination = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles cwd ' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $destination | Out-Null
$global:DotfilesTestDestination = $destination
function global:yazi {
    $cwdArgument = [Array]::IndexOf($args, '--cwd-file')
    [IO.File]::WriteAllText($args[$cwdArgument + 1], $global:DotfilesTestDestination + "`r`n")
}
try {
    y
    if ((Get-Location).Path -ne $destination) { throw 'Yazi wrapper did not change directory.' }
} finally {
    Set-Location -LiteralPath $previousDirectory.Path
    Remove-Item Function:\yazi
    Remove-Variable DotfilesTestDestination -Scope Global
    Remove-Item -LiteralPath $destination
}
Write-Host 'PASS: installed commands, profile functions, Node and Yazi directory wrapper.'
