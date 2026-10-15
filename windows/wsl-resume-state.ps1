# Shared by the launcher and its isolated registry/file regression test.
function Register-WslResume {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][hashtable]$Options,
        [string]$StateDirectory = (Join-Path $env:LOCALAPPDATA 'dotfiles'),
        [string]$RegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
    )
    $stateFile = Join-Path $StateDirectory 'wsl-resume.json'
    $resumeScript = Join-Path $PSScriptRoot 'resume-wsl.ps1'
    $command = 'powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -NoExit -File "' + $resumeScript + '" -StateFile "' + $stateFile + '"'
    if ($command.Length -gt 260) { throw 'The resume command exceeds the Windows RunOnce length limit. Use a shorter checkout path.' }
    if ($PSCmdlet.ShouldProcess($stateFile, 'Save WSL options and resume setup at next Windows login')) {
        New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null
        [IO.File]::WriteAllText($stateFile, ($Options | ConvertTo-Json), (New-Object Text.UTF8Encoding $false))
        if (-not (Test-Path -LiteralPath $RegistryPath)) { New-Item -Path $RegistryPath | Out-Null }
        New-ItemProperty -LiteralPath $RegistryPath -Name 'DotfilesWslSetup' -Value $command -PropertyType String -Force | Out-Null
    }
    return $stateFile
}
