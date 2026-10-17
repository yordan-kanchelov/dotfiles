# Loaded by the managed block in PowerShell 7's current-user, all-hosts profile.
$dotfilesRoot = Split-Path -Parent $PSScriptRoot
$env:STARSHIP_CONFIG = Join-Path $dotfilesRoot '.config\starship.toml'
$env:EDITOR = 'nvim'
$env:VISUAL = 'nvim'

# Yazi needs Git for Windows' file.exe for MIME detection.
if (-not $env:YAZI_FILE_ONE) {
    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCommand) {
        $gitRoot = Split-Path -Parent (Split-Path -Parent $gitCommand.Source)
        $fileExe = Join-Path $gitRoot 'usr\bin\file.exe'
        if (Test-Path -LiteralPath $fileExe) { $env:YAZI_FILE_ONE = $fileExe }
    }
}

if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}
$interactiveTerminal = -not [Console]::IsOutputRedirected -and $env:TERM -ne 'dumb'
if ($interactiveTerminal -and (Get-Module -ListAvailable PSReadLine)) {
    Import-Module PSReadLine
    Set-PSReadLineOption -EditMode Vi
    # History suggestions stay local; no account or history sync is configured.
    if ((Get-Module PSReadLine).Version -ge [version]'2.2') {
        Set-PSReadLineOption -PredictionSource History
    }
}
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    zoxide init powershell | Out-String | Invoke-Expression
}
if ($interactiveTerminal -and (Get-Command starship -ErrorAction SilentlyContinue)) {
    starship init powershell | Out-String | Invoke-Expression
}

# Familiar tmux shortcuts, backed by native Herdr on Windows.
function global:tn {
    param([Parameter(Mandatory, Position = 0)][ValidateNotNullOrEmpty()][string]$Name)
    & herdr --session $Name
}

function global:ta {
    param([Parameter(Mandatory, Position = 0)][ValidateNotNullOrEmpty()][string]$Name)
    & herdr session attach $Name
}
function global:tls { & herdr session list }
function global:tk {
    param([Parameter(Mandatory, Position = 0)][ValidateNotNullOrEmpty()][string]$Name)
    & herdr session stop $Name
}
function global:tkill {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param()
    if ($PSCmdlet.ShouldProcess('Current Herdr server and its pane processes', 'Stop')) {
        & herdr server stop
    }
}
function global:tren {
    throw 'Herdr does not support session renaming in this version. Use tn <new-name> for a new session.'
}
function global:tnw {
    if ($env:HERDR_ENV -ne '1' -or -not $env:HERDR_WORKSPACE_ID) {
        throw 'Run tnw inside Herdr to target your current workspace.'
    }
    & herdr tab create --workspace $env:HERDR_WORKSPACE_ID --cwd (Get-Location).Path --focus
}
function global:th {
    if ($env:HERDR_ENV -ne '1') { throw 'Run th inside Herdr to split your current pane.' }
    & herdr pane split --current --direction right --cwd (Get-Location).Path --focus
}
function global:tv {
    if ($env:HERDR_ENV -ne '1') { throw 'Run tv inside Herdr to split your current pane.' }
    & herdr pane split --current --direction down --cwd (Get-Location).Path --focus
}
function global:tkp { exit }

function global:lg { & lazygit @args }
function global:vim { & nvim @args }
function global:l { & eza -l -b --all --header --git --icons --group-directories-first @args }
function global:fvim {
    $selected = & fzf --preview 'bat --color=always -- {}'
    if ($selected) { & nvim -- $selected }
}
function global:y {
    $cwdFile = [IO.Path]::GetTempFileName()
    try {
        & yazi @args --cwd-file $cwdFile
        $nextDirectory = [IO.File]::ReadAllText($cwdFile).TrimEnd("`r", "`n", [char]0)
        if ($nextDirectory -and (Test-Path -LiteralPath $nextDirectory -PathType Container)) {
            Set-Location -LiteralPath $nextDirectory
        }
    } finally {
        Remove-Item -LiteralPath $cwdFile -Force -ErrorAction SilentlyContinue
    }
}
function global:reload { . $PROFILE.CurrentUserAllHosts }
