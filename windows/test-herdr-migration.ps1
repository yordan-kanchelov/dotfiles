#Requires -Version 5.1
# Enforce profile-local staging without requiring a second physical drive or Herdr.
$ErrorActionPreference = 'Stop'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-migration-' + [guid]::NewGuid().ToString('N'))
$originalProfile = $env:USERPROFILE
$originalPath = $env:Path
New-Item -ItemType Directory -Path $fixture | Out-Null
try {
    $env:USERPROFILE = Join-Path $fixture 'profile'
    $bin = Join-Path $fixture 'bin'
    $source = Join-Path $fixture 'repo-skills'
    New-Item -ItemType Directory -Path $bin, $source, (Join-Path $env:USERPROFILE '.claude') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $source 'existing.txt'), 'preserve')
    # Exercise real native-command invocation; status is current so no user hooks run.
    $stub = @'
using System;
public class HerdrMigrationFixture {
    public static int Main(string[] args) {
        if (args.Length == 1 && args[0] == "--skill") {
            Console.WriteLine("fixture-skill"); return 0;
        }
        if (args.Length == 2 && args[0] == "integration" && args[1] == "status") {
            Console.WriteLine("claude: current (fixture)");
            Console.WriteLine("codex: current (fixture)"); return 0;
        }
        return 1;
    }
}
'@
    # Compile a .NET Framework executable that runs under both Windows PS 5.1
    # and PS 7; Add-Type in PS 7 cannot emit console applications.
    $sourceFile = Join-Path $fixture 'herdr.cs'
    [IO.File]::WriteAllText($sourceFile, $stub)
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
    & $compiler /nologo /target:exe (('/out:') + (Join-Path $bin 'herdr.exe')) $sourceFile
    if ($LASTEXITCODE -ne 0) { throw 'Could not compile the isolated Herdr fixture.' }
    $env:Path = $bin + ';' + $env:Path
    $skills = Join-Path $env:USERPROFILE '.claude\skills'
    New-Item -ItemType Junction -Path $skills -Target $source | Out-Null
    $moveState = [pscustomobject]@{ Count = 0 }
    function Move-Item {
        param([string]$LiteralPath, [string]$Destination)
        # Reject the old system-temp staging, just as cross-drive directory moves fail.
        $profilePrefix = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\') + '\'
        if (-not [IO.Path]::GetFullPath($LiteralPath).StartsWith($profilePrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Skills migration must stage under USERPROFILE, not system TEMP.'
        }
        $moveState.Count++
        Microsoft.PowerShell.Management\Move-Item -LiteralPath $LiteralPath -Destination $Destination
    }
    $installer = Join-Path $PSScriptRoot 'install-herdr.ps1'
    $preview = & $installer -Targets claude -WhatIf -OutputJson | Select-Object -Last 1 | ConvertFrom-Json
    if (-not (Get-Item -LiteralPath $skills).LinkType -or $moveState.Count -ne 0 -or $preview.changed) { throw 'Preview changed the skills junction.' }
    $first = & $installer -Targets claude -OutputJson | ConvertFrom-Json
    if (-not $first.changed -or $moveState.Count -ne 1) { throw 'Migration did not move the staged directory.' }
    if ((Get-Item -LiteralPath $skills).LinkType) { throw 'Skills remain a junction.' }
    if ([IO.File]::ReadAllText((Join-Path $skills 'existing.txt')) -cne 'preserve') { throw 'Migration lost an existing skill.' }
    if (Test-Path -LiteralPath (Join-Path $source 'herdr')) { throw 'Migration wrote through the junction.' }
    if (@(Get-ChildItem -LiteralPath $env:USERPROFILE -Force).Count -ne 1) { throw 'Temporary staging was not cleaned up.' }
    $repeat = & $installer -Targets claude -OutputJson | ConvertFrom-Json
    if ($repeat.changed -or $repeat.planned.Count -or $moveState.Count -ne 1) { throw 'Repeated migration changed the profile.' }
    Write-Host 'PASS: profile-local migration staging, preview, skill preservation, cleanup and repeatability.'
} finally {
    Remove-Item Function:\Move-Item -ErrorAction SilentlyContinue
    $env:USERPROFILE = $originalProfile
    $env:Path = $originalPath
    # Never recurse through a junction left behind by a failed regression run.
    $link = Join-Path $fixture 'profile\.claude\skills'
    if ((Test-Path -LiteralPath $link) -and (Get-Item -LiteralPath $link).LinkType) { [IO.Directory]::Delete($link) }
    Remove-Item -LiteralPath $fixture -Recurse -Force
}
