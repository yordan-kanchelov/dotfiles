#Requires -Version 5.1
[CmdletBinding()]
param([switch]$OutputJson)
$ErrorActionPreference = 'Stop'
# Deliberately discard inherited process PATH: this is what a fresh Windows login receives.
$env:Path = [Environment]::ExpandEnvironmentVariables(([Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')))
$tools = foreach ($name in @('codex', 'claude', 'herdr')) {
    $command = Get-Command ($name + '.exe') -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $version = (& $command.Source --version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw "$name failed its version check: $version" }
    [pscustomobject]@{ name = $name; path = $command.Source; version = $version }
}
if ($OutputJson) { ConvertTo-Json -InputObject @($tools) -Depth 4 } else { $tools }
