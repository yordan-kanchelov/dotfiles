# Dotfiles

Terminal setup for macOS, Debian/Ubuntu (incl. Linux Mint) and Omarchy, installed and kept in sync by one Ansible playbook.

## Features

- 🚀 **One-command setup** - `./bootstrap.sh` installs Ansible and runs the playbook
- 🛡️ **Safe installation** - Automatic backups before overwriting existing configs
- 🔁 **Idempotent** - Re-run any time; a second run reports `changed=0`
- 📦 **Modern CLI tools** - Curated collection of productivity-enhancing utilities
- 🎨 **Beautiful terminal** - Pre-configured with Nerd Fonts and modern themes
- ⚡ **Performance focused** - Fast shell startup with lazy-loaded plugins
- 📝 **LazyVim IDE** - Full-featured Neovim setup with LSP, debugging, and more

## Quick Start

### Native Windows

Clone into your user folder, then run from Windows PowerShell or PowerShell 7:

```powershell
git clone https://github.com/yordan-kanchelov/dotfiles.git "$HOME\dotfiles"
cd "$HOME\dotfiles"
.\bootstrap.ps1 -WhatIf   # preview without installing or writing files
.\bootstrap.ps1
```

The Windows installer uses WinGet (Microsoft App Installer), installs the core tools in
`windows/packages.json`, and adds a managed block to PowerShell 7's current-user, all-hosts
profile. Existing profile content is preserved. Conflicting configs are backed up under
`~/.dotfiles_backup/windows-<timestamp>/`. Re-running keeps existing packages and unchanged configs.
If script execution is disabled, invoke the trusted local script using
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1`; this applies only to that process.
The Dotfiles Terminal profile (and Yazi's PowerShell shell) uses process-only `RemoteSigned`,
so local profile scripts can load even when the Windows default is `Restricted`.
This does not change the machine or user execution policy; downloaded unsigned scripts remain restricted.
For other PowerShell launchers, use `pwsh -ExecutionPolicy RemoteSigned`, or explicitly choose
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` if you want that policy for all your shells.

Open a new Windows Terminal tab using **Dotfiles PowerShell**. Select that profile as the default
in Terminal Settings if desired. Its per-user JSON fragment supplies Catppuccin Macchiato,
0xProto Nerd Font, 14pt text, block cursor, padding and 90% opacity. Fully restart Terminal
if the new fonts/profile do not appear immediately.

PowerShell includes vi editing, local history suggestions, Starship, zoxide (`z`), fnm,
`lg`, `vim`, `l`, `fvim` and the `y` directory-changing Yazi wrapper. PowerShell's existing
`ls` and `cat` commands are preserved. Starship reads the shared config directly; directory
junctions connect `%LOCALAPPDATA%\nvim` and `%APPDATA%\yazi\config` to the repository, without
requiring Developer Mode. Keep this checkout in place. Yazi Git-root navigation works on both
Windows and Unix; `!` opens PowerShell on Windows.

Node 22 is installed through fnm to match the Unix setup, but an existing default version is
preserved. Use `fnm use 22` or `fnm default 22` explicitly if wanted. Use `-SkipPackages`,
`-SkipNode`, `-SkipFonts`, or `-SkipTerminal` to omit individual steps. A configs-only run is
`.\bootstrap.ps1 -SkipPackages -SkipNode`.

The core packages include tree-sitter CLI and WinLibs GCC for Neovim's native parsers.
Language-specific toolchains, advanced Yazi preview dependencies,
Ollama and GUI applications are separate choices. Run `:checkhealth` in Neovim to see the
requirements for enabled plugins. Zsh, Sheldon, tmux, Atuin and Linux desktop customizations
remain in the Unix/WSL setup. The Windows installer does not modify Claude/Codex configuration,
secrets, cleanup commands or WSL installations.

Validate Windows config installation with `powershell.exe -NoProfile -File .\windows\test-setup.ps1`.
This checks dry runs, backup preservation, junctions and repeated installation in temporary folders.
`windows/test-fonts.ps1` checks font registration in an isolated HKCU key, preserving unrelated
values across repeated runs. After installing, run
`pwsh -ExecutionPolicy RemoteSigned -File .\windows\test-profile.ps1` for the installed-tool and shell smoke test.
The path override parameters are independent: `HomeDirectory` sets the backup location;
use `ProfilePath`, `LocalAppDataDirectory`, `RoamingAppDataDirectory` and `FontRegistryPath`
explicitly to isolate a test installation.

### macOS and Linux

```bash
# Clone the repository
git clone https://github.com/yordan-kanchelov/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Installs Ansible (and Homebrew on macOS), then runs setup.yml.
# On Linux it asks for your sudo password (apt/pacman, login shell).
./bootstrap.sh
```

Afterwards, re-run the playbook directly:

```bash
ansible-playbook setup.yml -K    # Linux
ansible-playbook setup.yml       # macOS
```

### Ubuntu on WSL 2

From Windows PowerShell, use the launcher to install WSL/Ubuntu and run the Linux
Ansible playbook, followed by native Windows agent provisioning through `windows.yml`:

```powershell
.\windows\setup-wsl.ps1 -WhatIf
.\windows\setup-wsl.ps1
# Optional: restart automatically when required and continue after Windows login
.\windows\setup-wsl.ps1 -RestartAndResume
```

Windows may require a restart after enabling WSL. Rerun the same command afterwards.
`-RestartAndResume` saves these options under `%LOCALAPPDATA%\dotfiles`, registers one
per-user RunOnce action, and restarts without forcibly closing applications. After login,
a visible PowerShell console resumes setup. It permits at most two automatic restarts.
Ubuntu account creation and sudo passwords remain interactive. Account creation opens in
a separate Ubuntu window; setup detects the normal user and continues automatically.
No passwords are stored.
Open Ubuntu once to create your normal Linux username and password if requested, then rerun.
The launcher clones the repo into Ubuntu's own `~/dotfiles` filesystem (not `/mnt/c`),
and calls `bootstrap.sh`, which installs Ansible and runs `setup.yml`. Existing clean
checkouts are fast-forwarded; local changes or another branch are never discarded.
Use `-Ref feat/windows-setup` to test this PR before it is merged.

Ansible detects WSL, preserves existing `/etc/wsl.conf` settings while enabling systemd
and setting the default Linux user, and installs the Ubuntu Zsh/tmux/Atuin stack.
If WSL settings change, close Ubuntu after setup and run `wsl --terminate Ubuntu` to apply them.
The launcher skips the large Ollama download by default; use `-IncludeOllama` to include it.
Linux desktop applications remain opt-in via the existing `--tags desktop` workflow.

### Native Windows coding-agent CLIs

Codex, Claude Code and herdr are installed **on Windows**, using their upstream Windows
installers. Existing working native installations are preserved. The installer repairs
the user's persistent Windows PATH and checks each command from a fresh Windows PowerShell
process. It does not install Linux agents, npm globals or bubblewrap.

```powershell
.\windows\install-agents.ps1 -WhatIf
.\windows\install-agents.ps1
```

Ansible can manage the same Windows tools from Ubuntu/WSL without configuring WinRM:

```bash
ansible-playbook windows.yml          # installs/verifies native Windows tools via powershell.exe
ansible-playbook windows.yml --check  # previews changes
```

This uses WSL interop to run the Windows installer as your Windows user; Ansible itself
runs inside Ubuntu. It requires Windows interop to be enabled in WSL. Linux terminal tools
remain managed by `setup.yml`. Sign in to each CLI separately; no credentials are copied.

**Tailscale** is included by default in the native Windows package list and `windows.yml`.
Installation verifies `tailscale.exe` on the persistent Windows PATH. Sign in to your tailnet
separately; setup does not automatically authenticate or change tailnet preferences.

The run also creates `~/.secrets` (mode 600) from a template of placeholder tokens, which `.zprofile`
sources on login — fill in the ones you use. It is written only when missing, so re-runs never
overwrite it.

## Omarchy

Omarchy keeps its own Bash, prompt, theme, Neovim, terminal and tmux defaults. The playbook only layers
personal config on top, so Omarchy updates keep working:

- **Bash** — `omarchy/bash/personal.bash`, linked to `~/.config/dotfiles/bash/` and sourced from a marked
  block at the end of `~/.bashrc`: vi mode (with Omarchy's inputrc re-bound for it), the tmux aliases
  (`ta tn tls tk tkill tren tnw th tv tkp`), `l`, `lg`, `vim`, `sw`, `:q`, `reload`, `y`, `fvim`, `cat`
  (bat/glow/viu), `clear` (also drops tmux scrollback), the `claude` session-id wrapper tmux-resurrect relies
  on, `cleanc`/`cleanp`, `PNPM_HOME`, `~/.secrets`, and Atuin on Ctrl-R and Up (via `bash-preexec`).
  Omarchy's `ls`, `c` and prompt are left alone.
- **tmux** — `omarchy/tmux/tmux.conf`, linked to `~/.config/dotfiles/tmux/` and sourced from a marked block
  at the end of Omarchy's `~/.config/tmux/tmux.conf`. It adds the plugins (TPM in
  `~/.config/tmux/plugins`: sensible, yank, open, vim-tmux-navigator, thumbs, fzf, fzf-url, floax,
  resurrect, continuum) and the personal bindings (prefix `h/j/k/l` panes, `H/J/K/L` resize, `| - " %`
  splits, `Tab`, `S`, `X`, `o`, `e`) without touching the status bar or theme. Omarchy's own bindings (`v`,
  `x`, `q`, `r`, `?`, the Alt keys) still work; its prefix `h`/`k` are replaced by pane navigation.
- **Atuin** — `.config/atuin` is linked; `atuin` and `bash-preexec` are installed with pacman.

`./bootstrap.sh` detects `ID=omarchy`, installs Ansible with `omarchy pkg add` if needed, and runs the same
playbook (`-K` for pacman). Open a new shell afterwards. Omarchy's *Update → Config → Tmux* resets
`~/.config/tmux/tmux.conf`; re-run `ansible-playbook setup.yml --tags tmux` to put the block back.
To undo a layer, delete its marked block.

## What's Included

### Terminal & Shell
- **ZSH** with sheldon plugin manager
  - Syntax highlighting
  - Auto-suggestions
  - Vi-mode with visual feedback
  - Directory jumping with zoxide
  - Command history sync with atuin
- **Starship** prompt - Fast, customizable, cross-shell prompt
- **Tmux** with sensible defaults and plugin manager

### Development Tools
- **Neovim** with **LazyVim** - Modern vim with pre-configured IDE features
  - LSP support for intelligent code completion
  - Treesitter for advanced syntax highlighting
  - Telescope for fuzzy finding
  - Custom keybindings and plugins
- **Lazygit** - Terminal UI for git
- **GitHub CLI** (`gh`) - GitHub from the command line
- **fnm** - Fast Node.js version manager
- Language support: Go, Python, Rust

### Modern CLI Utilities
- **bat** - `cat` with syntax highlighting
- **eza** - Modern `ls` replacement
- **ripgrep** (`rg`) - Fast file search
- **fzf** - Fuzzy finder for everything
- **yazi** - Terminal file manager with shell drop-in, Git-root jump, Quick Look, and tab-safe quit
- **atuin** - Sync shell history across machines
- **zoxide** - Smarter `cd` command

### Fonts
- 0xProto Nerd Font
- FiraCode Nerd Font
- RobotoMono Nerd Font

## Running the Playbook

| Want | Run |
|---|---|
| Everything | `ansible-playbook setup.yml -K` (`-K` only on Linux) |
| Configs only, no packages | `ansible-playbook setup.yml --skip-tags packages` |
| Just the symlinks / fonts / tmux / secrets | `ansible-playbook setup.yml --tags symlinks` (or `fonts`, `tmux`, `secrets`) |
| Skip the 1.4 GB ollama build (Linux) | `ansible-playbook setup.yml -K --skip-tags ollama` |
| Linux desktop: Ulauncher, Ghostty, Bitwarden, draw.io, Flameshot, Cinnamon hot corners/hotkeys, xbindkeys | `ansible-playbook setup.yml -K --tags desktop` (never runs unless asked; needs a graphical session) |
| Dry run (on an already set-up machine; `-K` on Linux) | `ansible-playbook setup.yml --check --diff` |
| Verify | Run it again and expect `changed=0` |

`./bootstrap.sh` passes extra arguments through, so `./bootstrap.sh --tags symlinks` works too.

Existing files in the way of a symlink are moved to `~/.dotfiles_backup/<timestamp>/` first. There is no interactive prompting — the playbook always backs up, then links.

## Configuration

### Adding New Packages
- `brew_packages.yml` — Homebrew `formulae:` (grouped by category) and `casks:`. Used on both macOS and Linux
  (casks are macOS-only; the GUI apps that have a Linux build are installed from upstream .debs by `tasks/desktop.yml`).
- `vars/Debian.yml` — the apt package list, plus the formulae brew must not install on Linux.

### Directory Structure
```
.
├── bootstrap.sh          # Installs Ansible, runs setup.yml
├── setup.yml             # The playbook: symlink allowlist, package/font/tmux/secrets tasks
├── requirements.yml      # The community.general collection the playbook needs
├── tasks/
│   ├── symlinks.yml      # Backup-then-link
│   ├── debian.yml        # apt, zsh login shell, Homebrew on Linux, ollama
│   ├── omarchy.yml       # Omarchy: pacman packages, Bash/tmux layers, TPM
│   └── desktop.yml       # Linux desktop apps and Cinnamon settings (--tags desktop)
├── vars/
│   ├── Darwin.yml        # macOS paths
│   ├── Debian.yml        # Linux paths, apt packages, brew exclusions
│   └── Omarchy.yml       # Omarchy links
├── brew_packages.yml     # Homebrew formulae & casks
├── .github/              # CI workflow, plus the Mint release-resolution play it runs
├── .config/              # Modern tool configs
│   ├── nvim/             # LazyVim configuration
│   ├── starship.toml     # Starship prompt
│   ├── ghostty/          # Ghostty terminal
│   ├── atuin/            # Shell history
│   ├── sheldon/          # Zsh plugin manager
│   └── yazi/             # Terminal file manager
├── zsh/                  # .zprofile, .zshrc, .zshrc.core
├── omarchy/              # Bash and tmux layers on top of Omarchy's defaults
├── tmux/                 # .tmux.conf
├── claude/               # Linked into ~/.claude: CLAUDE.md, AGENTS.md, settings, commands, skills
├── codex/                # Linked into ~/.codex: AGENTS.md, instructions, rules, keybindings
├── xbindkeys/            # Linux mouse-button / tiling bindings
└── fonts/                # Nerd Font collections
```

### Backup Location
Existing files are backed up to `~/.dotfiles_backup/` with timestamps.

## Requirements

- macOS, a Debian/Ubuntu-based Linux (apt), or Omarchy; sudo on Linux
- Internet connection for package downloads

## Development

```bash
ansible-playbook setup.yml --syntax-check
ansible-lint                     # with ansible-core: ansible-galaxy collection install -r requirements.yml first
shellcheck bootstrap.sh
```

CI runs `bootstrap.sh` and the playbook on macOS and Ubuntu, then runs the playbook a second time and fails
unless it reports `changed=0`. A third job checks the Linux Mint release resolution the desktop tasks depend
on, which no runner can cover directly.

## Customization

1. **Shell Configuration**: Edit `zsh/.zshrc.core` for ZSH customizations
2. **Neovim/LazyVim**: Customize in `.config/nvim/lua/plugins/` for additional plugins
3. **Tmux**: Modify `tmux/.tmux.conf` for tmux settings
4. **Starship Prompt**: Customize `.config/starship.toml`
5. **Package List**: Update `brew_packages.yml` (and `vars/Debian.yml` for apt) with your preferred tools

## Troubleshooting

### Setup Issues
- Check `~/.dotfiles_backup/` for backed up files
- `-K` prompts for your sudo password; without it the apt and login-shell tasks fail
- Run with `-v` for module output, `--check --diff` to see what would change

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Acknowledgments

This setup is inspired by the dotfiles community and includes configurations adapted from various sources. Special thanks to all the creators of the amazing tools included in this setup.
