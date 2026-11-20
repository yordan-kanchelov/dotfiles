#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param([ValidateSet('claude', 'codex')][string[]]$Targets = @('claude', 'codex'), [switch]$OutputJson)
$ErrorActionPreference = 'Stop'
$herdr = (Get-Command herdr.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$savedEncoding = [Console]::OutputEncoding
try { [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false } catch { $savedEncoding = $null }
try {
    $skill = (& $herdr --skill | Out-String).TrimEnd() + "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Could not read the bundled Herdr skill.' }
    $status = @(& $herdr integration status)
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect Herdr integrations.' }
} finally {
    if ($savedEncoding) { [Console]::OutputEncoding = $savedEncoding }
}
$changed = $false
$planned = @()
$profiles = @{ claude = $env:CLAUDE_CONFIG_DIR; codex = $env:CODEX_HOME }
foreach ($target in $Targets) {
    $profileDirectory = $profiles[$target]
    if (-not $profileDirectory) { $profileDirectory = Join-Path $env:USERPROFILE ".$target" }
    $skillsDirectory = Join-Path $profileDirectory 'skills'
    if ((Test-Path -LiteralPath $skillsDirectory) -and (Get-Item -LiteralPath $skillsDirectory).LinkType) {
        $planned += "Make $target skills a local directory"
        if ($PSCmdlet.ShouldProcess($skillsDirectory, 'Replace directory link with a local copy')) {
            $temporary = Join-Path $profileDirectory ('.dotfiles-skills-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $temporary | Out-Null
            $stagedSkills = Join-Path $temporary 'skills'
            Copy-Item -LiteralPath $skillsDirectory -Destination $stagedSkills -Recurse
            [IO.Directory]::Delete($skillsDirectory)
            Move-Item -LiteralPath $stagedSkills -Destination $skillsDirectory
            Remove-Item -LiteralPath $temporary
            $changed = $true
        }
    }
    $destination = Join-Path $skillsDirectory 'herdr\SKILL.md'
    $current = if (Test-Path -LiteralPath $destination) { [IO.File]::ReadAllText($destination) } else { '' }
    if ($current -cne $skill) {
        $planned += "Install $target Herdr skill"
        if ($PSCmdlet.ShouldProcess($destination, 'Install bundled Herdr skill')) {
            New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
            [IO.File]::WriteAllText($destination, $skill, (New-Object Text.UTF8Encoding $false))
            $changed = $true
        }
    }
    if (-not ($status -match "^${target}: current\b")) {
        $planned += "Install $target Herdr integration"
        if ($PSCmdlet.ShouldProcess($target, 'Install Herdr integration')) {
            $configName = if ($target -eq 'claude') { 'settings.json' } else { 'config.toml' }
            $config = Join-Path $profileDirectory $configName
            if ((Test-Path -LiteralPath $config) -and (Get-Item -LiteralPath $config).LinkType) {
                $content = [IO.File]::ReadAllBytes($config)
                Remove-Item -LiteralPath $config -Force
                [IO.File]::WriteAllBytes($config, $content)
            }
            $message = & $herdr integration install $target 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) { throw "Herdr integration failed for ${target}: $message" }
            $changed = $true
        }
    }
}
$result = [pscustomobject]@{ changed = $changed; check_mode = [bool]$WhatIfPreference; planned = $planned }
if ($OutputJson) { $result | ConvertTo-Json -Compress } else { $result }
