#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$StateFile)
$ErrorActionPreference = 'Stop'
try {
    $saved = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
    $options = @{
        Distribution = [string]$saved.Distribution
        Repository = [string]$saved.Repository
        Ref = [string]$saved.Ref
        IncludeOllama = [bool]$saved.IncludeOllama
        # Resume never grants reboot permission that the initial run did not save.
        RestartAndResume = [bool]$saved.RestartAndResume
        RestartAttempt = [int]$saved.RestartAttempt
        Resume = $true
    }
    Write-Host 'Resuming dotfiles setup. If an Ubuntu account-creation window opens, finish it there; setup continues automatically.'
    $resumeStatus = $null
    & (Join-Path $PSScriptRoot 'setup-wsl.ps1') @options | ForEach-Object {
        if ($_.PSObject.Properties['ResumeStatus']) { $resumeStatus = $_.ResumeStatus } else { $_ | Out-Host }
    }
    if ($resumeStatus -eq 'Complete') {
        Remove-Item -LiteralPath $StateFile -Force
        Write-Host 'Ubuntu and native Windows setup completed.'
    }
} catch {
    Write-Host "Setup stopped: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Saved options remain at $StateFile. Fix the problem and run this resume script again with -StateFile."
    throw
}
