#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param([switch]$OutputJson)
$ErrorActionPreference = 'Stop'
$terminal = (Get-Command wt.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
$shortcutPath = Join-Path $startup 'Herdr.lnk'
# Resolve Herdr from the login PATH instead of pinning a versioned installation.
$arguments = '-w new new-tab --startingDirectory "' + $env:USERPROFILE + '" powershell.exe -NoLogo -NoProfile -Command herdr'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$planned = @()
$changed = $false
if ($shortcut.TargetPath -ne $terminal -or $shortcut.Arguments -ne $arguments -or $shortcut.WorkingDirectory -ne $env:USERPROFILE) {
    $planned += 'Start Herdr in Windows Terminal at Windows sign-in'
    if ($PSCmdlet.ShouldProcess($shortcutPath, 'Configure Herdr autostart')) {
        New-Item -ItemType Directory -Path $startup -Force | Out-Null
        $shortcut.TargetPath = $terminal
        $shortcut.Arguments = $arguments
        $shortcut.WorkingDirectory = $env:USERPROFILE
        $shortcut.Description = 'Open Herdr and restore the default session at sign-in'
        $shortcut.Save()
        $changed = $true
    }
}
$result = [pscustomobject]@{ changed = $changed; planned = $planned; shortcut = $shortcutPath }
if ($OutputJson) { $result | ConvertTo-Json -Compress } else { $result }
