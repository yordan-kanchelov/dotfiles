#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param([switch]$OutputJson)
$ErrorActionPreference = 'Stop'
if (-not (Get-AppxPackage Microsoft.WindowsTerminal)) { throw 'Install Windows Terminal before selecting it as the default.' }
$startup = 'HKCU:\Console\%%Startup'
$values = @{
    DelegationConsole = '{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}'
    DelegationTerminal = '{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}'
}
$selected = Get-ItemProperty -LiteralPath $startup -ErrorAction SilentlyContinue
$changed = $false
$planned = @()
foreach ($name in $values.Keys) {
    if ($selected.$name -eq $values[$name]) { continue }
    $planned += "Set Windows Terminal $name"
    if ($PSCmdlet.ShouldProcess($name, 'Select Windows Terminal as default')) {
        if (-not (Test-Path -LiteralPath $startup)) { New-Item -Path $startup | Out-Null }
        New-ItemProperty -LiteralPath $startup -Name $name -Value $values[$name] -PropertyType String -Force | Out-Null
        $changed = $true
    }
}
$result = [pscustomobject]@{ changed = $changed; planned = $planned; tools = @(); default_terminal = 'Windows Terminal' }
if ($OutputJson) { $result | ConvertTo-Json -Depth 4 -Compress } else { $result }
