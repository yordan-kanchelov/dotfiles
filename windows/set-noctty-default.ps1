#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param([switch]$OutputJson)
$ErrorActionPreference = 'Stop'
$startup = 'HKCU:\Console\%%Startup'
# Noctty 1.3.131's published terminal handoff CLSID.
$nocttyClsid = '{33368C6F-D328-410C-B225-26DC9F12C728}'
$selected = Get-ItemProperty -LiteralPath $startup -ErrorAction SilentlyContinue
$changed = $false
$planned = @()
if ($selected.DelegationTerminal -ne $nocttyClsid) {
    $planned += 'Select Noctty as the Windows default terminal (experimental)'
    $terminal = Get-AppxPackage Microsoft.WindowsTerminal | Select-Object -First 1
    if (-not $terminal -or [version]$terminal.Version -lt [version]'1.24') {
        throw 'Noctty default-terminal handoff requires Windows Terminal 1.24 or newer.'
    }
    $command = Get-Command noctty.com -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $cli = if ($command) { $command.Source } else { Join-Path $env:ProgramFiles 'noctty\noctty.com' }
    if (-not (Test-Path -LiteralPath $cli)) { throw 'Install Noctty before selecting it as the default terminal.' }
    if ($PSCmdlet.ShouldProcess('Current Windows user', 'Back up terminal selection and register Noctty default terminal')) {
        $stateDir = Join-Path $env:LOCALAPPDATA 'dotfiles'
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
        $backup = Join-Path $stateDir 'terminal-before-noctty.json'
        if (-not (Test-Path -LiteralPath $backup)) {
            @{ DelegationConsole = $selected.DelegationConsole; DelegationTerminal = $selected.DelegationTerminal } |
                ConvertTo-Json | Set-Content -LiteralPath $backup -Encoding UTF8
        }
        if (-not (Test-Path -LiteralPath $startup)) { New-Item -Path $startup | Out-Null }
        try {
            # Noctty provides the terminal half; Windows Terminal supplies OpenConsole.
            if (-not $selected.DelegationConsole -or $selected.DelegationConsole -in @('{00000000-0000-0000-0000-000000000000}', '{B23D10C0-E52E-411E-9D5B-C09FDF709C7D}')) {
                New-ItemProperty -LiteralPath $startup -Name DelegationConsole -Value '{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}' -PropertyType String -Force | Out-Null
                New-ItemProperty -LiteralPath $startup -Name DelegationTerminal -Value '{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}' -PropertyType String -Force | Out-Null
            }
            # This release's CLI uses positional stdout writes, which fail on pipes.
            $stdout = Join-Path $stateDir 'noctty-register.stdout'
            $stderr = Join-Path $stateDir 'noctty-register.stderr'
            $process = Start-Process -FilePath $cli -ArgumentList '+register-default-terminal' -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -Wait -PassThru
            if ($process.ExitCode -ne 0) { throw "Noctty registration failed: $(Get-Content -LiteralPath $stderr -Raw)" }
            if ((Get-ItemProperty -LiteralPath $startup).DelegationTerminal -ne $nocttyClsid) { throw 'Noctty terminal selection verification failed.' }
            $changed = $true
        } catch {
            foreach ($name in @('DelegationConsole', 'DelegationTerminal')) {
                if ($selected.$name) { New-ItemProperty -LiteralPath $startup -Name $name -Value $selected.$name -PropertyType String -Force | Out-Null }
                else { Remove-ItemProperty -LiteralPath $startup -Name $name -ErrorAction SilentlyContinue }
            }
            throw
        }
    }
}
$result = [pscustomobject]@{ changed = $changed; planned = $planned; tools = @(); default_terminal = 'noctty'; experimental = $true }
if ($OutputJson) { $result | ConvertTo-Json -Depth 4 -Compress } else { $result }
