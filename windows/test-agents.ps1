# Run after installation. Checks real native tools using only persistent Windows PATH.
$ErrorActionPreference = 'Stop'
$userPathBefore = [Environment]::GetEnvironmentVariable('Path', 'User')
foreach ($run in 1..2) {
    $result = & (Join-Path $PSScriptRoot 'install-agents.ps1') -OutputJson | Select-Object -Last 1 | ConvertFrom-Json
    if ($result.changed) { throw "Agent installer was not stable on run $run" }
    if ($result.tools.Count -ne 3) { throw 'Expected three individually reported Windows CLIs.' }
    foreach ($name in @('codex', 'claude', 'herdr')) {
        $tool = $result.tools | Where-Object { $_.name -eq $name }
        if (-not $tool -or -not $tool.version -or -not $tool.path.EndsWith('.exe')) { throw "Invalid Windows CLI result: $name" }
    }
}
$preview = & (Join-Path $PSScriptRoot 'install-agents.ps1') -WhatIf -OutputJson | Select-Object -Last 1 | ConvertFrom-Json
if (-not $preview.check_mode -or $preview.changed) { throw 'Invalid dry-run result.' }
if ([Environment]::GetEnvironmentVariable('Path', 'User') -cne $userPathBefore) { throw 'Repeat/dry run changed persistent PATH.' }
Write-Host 'PASS: all three native Windows CLIs, fresh-process PATH, repeatability and dry run.'
