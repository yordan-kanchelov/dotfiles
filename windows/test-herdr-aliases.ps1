#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
# Load only function definitions: avoid initializing the developer's prompt/tools.
$profileFile = Join-Path $PSScriptRoot 'profile.ps1'
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($profileFile, [ref]$tokens, [ref]$errors)
if ($errors) { throw ($errors | Out-String) }
$functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
foreach ($node in $functions) { . ([scriptblock]::Create($node.Extent.Text)) }
$script:calls = @()
function global:herdr { $script:calls += ,@($args) }
function Assert-Call([scriptblock]$Action, [string[]]$Expected) {
    $script:calls = @()
    & $Action
    if ($script:calls.Count -ne 1) { throw "Expected one Herdr call, got $($script:calls.Count)" }
    if (($script:calls[0] | ConvertTo-Json -Compress) -cne ($Expected | ConvertTo-Json -Compress)) {
        throw "Unexpected arguments: $($script:calls[0] -join ' | ')"
    }
}
Assert-Call { tn 'my project' } @('--session', 'my project')
Assert-Call { ta 'my project' } @('session', 'attach', 'my project')
Assert-Call { tls } @('session', 'list')
Assert-Call { tk 'my project' } @('session', 'stop', 'my project')
# Destructive server shutdown must honor ShouldProcess / WhatIf.
$script:calls = @()
tkill -WhatIf
if ($script:calls.Count) { throw 'tkill -WhatIf stopped the server.' }
Assert-Call { tkill -Confirm:$false } @('server', 'stop')
$script:calls = @()
try { tren old new; throw 'Expected unsupported rename to fail.' } catch {
    if ($_.Exception.Message -notmatch 'does not support.*renam') { throw }
}
if ($script:calls.Count) { throw 'tren unexpectedly invoked Herdr.' }
$oldEnv = @($env:HERDR_ENV, $env:HERDR_WORKSPACE_ID)
try {
    $env:HERDR_ENV = '1'; $env:HERDR_WORKSPACE_ID = 'w42'
    Assert-Call { tnw } @('tab', 'create', '--workspace', 'w42', '--cwd', (Get-Location).Path, '--focus')
    Assert-Call { th } @('pane', 'split', '--current', '--direction', 'right', '--cwd', (Get-Location).Path, '--focus')
    Assert-Call { tv } @('pane', 'split', '--current', '--direction', 'down', '--cwd', (Get-Location).Path, '--focus')
    $env:HERDR_ENV = $null
    foreach ($name in @('tnw', 'th', 'tv')) {
        $script:calls = @()
        try { & $name; throw 'Expected outside-Herdr guard.' } catch {
            if ($_.Exception.Message -notmatch 'inside Herdr') { throw }
        }
        if ($script:calls.Count) { throw "$name targeted Herdr from outside." }
    }
} finally {
    $env:HERDR_ENV = $oldEnv[0]; $env:HERDR_WORKSPACE_ID = $oldEnv[1]
}
# exit is executed in a child so it cannot terminate the test runner.
$engine = (Get-Process -Id $PID).Path
$exitBody = (Get-Command tkp -CommandType Function -ErrorAction Stop).Definition
& $engine -NoProfile -Command "$exitBody; exit 99"
if ($LASTEXITCODE -ne 0) { throw 'tkp did not exit the child normally.' }
Write-Host 'All Herdr alias tests passed.'
