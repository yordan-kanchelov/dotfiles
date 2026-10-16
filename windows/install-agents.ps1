#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param([switch]$OutputJson)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$windowsPowerShell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$changed = $false
$planned = @()
$tools = @()
$candidates = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\OpenAI\Codex\bin'),
    (Join-Path $env:USERPROFILE '.local\bin'),
    (Join-Path $env:USERPROFILE '.herdr\bin'),
    (Join-Path $env:USERPROFILE '.herdr\current')
)
function Update-AgentSessionPath {
    $env:Path = [Environment]::ExpandEnvironmentVariables((@([Environment]::GetEnvironmentVariable('Path', 'Machine'),
        [Environment]::GetEnvironmentVariable('Path', 'User'), ($candidates -join ';'), $env:Path) -join ';'))
}
foreach ($agent in @(
    @{ name = 'codex'; url = 'https://chatgpt.com/codex/install.ps1' },
    @{ name = 'claude'; url = 'https://claude.ai/install.ps1' },
    @{ name = 'herdr'; url = 'https://herdr.dev/install.ps1' }
)) {
    Update-AgentSessionPath
    $command = Get-Command ($agent.name + '.exe') -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $working = $false
    if ($command) {
        try {
            $version = (& $command.Source --version 2>&1 | Out-String).Trim()
            $working = $LASTEXITCODE -eq 0
        } catch {
            # Windows PowerShell 5 can turn native stderr into a terminating error.
            $working = $false
        }
    }
    if (-not $working) {
        $planned += "Install $($agent.name)"
        if (-not $PSCmdlet.ShouldProcess($agent.name, 'Install native Windows CLI from upstream')) { continue }
        $installer = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-agent-' + [guid]::NewGuid().ToString('N') + '.ps1')
        $installLog = $installer + '.log'
        $previousNonInteractive = $env:CODEX_NON_INTERACTIVE
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $agent.url -OutFile $installer
            $env:CODEX_NON_INTERACTIVE = '1'
            & $windowsPowerShell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $installer *> $installLog
            if ($LASTEXITCODE -ne 0) { throw "$($agent.name) installation failed. See $installLog" }
        } finally {
            $env:CODEX_NON_INTERACTIVE = $previousNonInteractive
            Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
        }
        $changed = $true
        Update-AgentSessionPath
        $command = Get-Command ($agent.name + '.exe') -CommandType Application -ErrorAction Stop | Select-Object -First 1
        $version = (& $command.Source --version 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { throw "$($agent.name) failed its post-install version check." }
    }
    $directory = Split-Path -Parent $command.Source
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $persistentEntries = @(($userPath + ';' + $machinePath).Split(';') | ForEach-Object {
        [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\')
    })
    if ($directory.TrimEnd('\') -notin $persistentEntries) {
        $planned += "Add $directory to Windows user PATH"
        if ($PSCmdlet.ShouldProcess($directory, 'Add CLI directory to persistent user PATH')) {
            $newPath = (@(([string]$userPath).TrimEnd(';'), $directory) | Where-Object { $_ }) -join ';'
            [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
            $changed = $true
        }
    }
    $tools += [pscustomobject]@{ name = $agent.name; path = $command.Source; version = $version }
}
$herdrCommand = Get-Command herdr.exe -CommandType Application -ErrorAction SilentlyContinue
if ($herdrCommand) {
    $integration = & (Join-Path $PSScriptRoot 'install-herdr.ps1') -WhatIf:$WhatIfPreference -OutputJson | Select-Object -Last 1 | ConvertFrom-Json
    $changed = $changed -or $integration.changed
    $planned += @($integration.planned)
    if (Get-Command wt.exe -CommandType Application -ErrorAction SilentlyContinue) {
        $autostart = & (Join-Path $PSScriptRoot 'set-herdr-autostart.ps1') -WhatIf:$WhatIfPreference -OutputJson | Select-Object -Last 1 | ConvertFrom-Json
        $changed = $changed -or $autostart.changed
        $planned += @($autostart.planned)
    }
}
if (-not $WhatIfPreference) {
    $verification = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'verify-agents.ps1') -OutputJson
    if ($LASTEXITCODE -ne 0) { throw 'Fresh Windows PATH verification failed.' }
    $tools = @($verification | ConvertFrom-Json | ForEach-Object { foreach ($tool in $_) { $tool } })
}
$result = [pscustomobject]@{ changed = $changed; check_mode = [bool]$WhatIfPreference; planned = $planned; tools = $tools }
if ($OutputJson) { $result | ConvertTo-Json -Depth 5 -Compress } else { $result.tools | Format-Table -AutoSize; Write-Host "Changed: $changed" }
