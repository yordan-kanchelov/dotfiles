# Dotfiles

Terminal setup for macOS, Debian/Ubuntu (including Linux Mint), and opt-in Omarchy, kept in sync by one Ansible playbook.

## Features

- 🚀 **One-command legacy setup** - `./bootstrap.sh` installs Ansible and runs the playbook on macOS/Debian
- 🛡️ **Safe installation** - Automatic backups before overwriting existing configs
- 🔁 **Idempotent** - Re-run any time; a second run reports `changed=0`
- 📦 **Modern CLI tools** - Curated collection of productivity-enhancing utilities
- 🎨 **Beautiful terminal** - Pre-configured with Nerd Fonts and modern themes
- ⚡ **Performance focused** - Fast shell startup with lazy-loaded plugins
- 📝 **LazyVim IDE** - Full-featured Neovim setup with LSP, debugging, and more

## Quick Start

```bash
# Clone the repository
git clone https://github.com/yordan-kanchelov/dotfiles.git ~/dotfiles
cd ~/dotfiles

# macOS/Debian only: installs prerequisites, then runs setup.yml.
# Omarchy users should continue with the guided section below.
./bootstrap.sh
```

On macOS/Debian, re-run the playbook directly:

```bash
ansible-playbook setup.yml -K    # Linux
ansible-playbook setup.yml       # macOS
```

The macOS/Debian run also creates `~/.secrets` (mode 600) from a template of placeholder tokens, which `.zprofile`
sources on login — fill in the ones you use. It is written only when missing, so re-runs never
overwrite it.

## Omarchy (guided and opt-in)

Omarchy uses a two-step flow. `bootstrap.sh` detects `ID=omarchy`, ensures only Ansible through the public
Omarchy CLI, installs the existing `community.general` requirement when missing, prints the next command,
and exits without running `setup.yml`. The existing macOS/Debian bootstrap behavior is unchanged.

```bash
./bootstrap.sh
./install-omarchy.sh
./install-omarchy.sh --dry-run
./install-omarchy.sh --non-interactive --yes
./install-omarchy.sh --non-interactive --yes \
  --components zsh,yazi \
  --optional-tools shellcheck,git-lfs,glow \
  --node-manager mise --config yes
```

The guided installer uses Gum and prints a complete plan before confirmation. Deterministic runs accept only
the documented component, tool, Node-manager, config, backup, confirmation, and dry-run flags; arbitrary
package names are rejected.

### Defaults and optional tools

The default plan selects the Zsh overlay, Yazi, and ShellCheck, preserves the active Mise-managed Node, and
applies config. The fixed optional trusted-repository tools are `git-lfs`, `glow`, `viu`, `act`, and
`pandoc-cli`. Packages already listed in the local Omarchy base manifest or already installed are skipped.
All missing selected packages are passed in stable order to one `omarchy pkg add` call.

The repository Starship file is linked to `~/.config/dotfiles/starship.toml` and selected only in Zsh through
`STARSHIP_CONFIG`; Omarchy's canonical `~/.config/starship.toml` remains untouched. The official Omarchy
environment and Zsh loaders run before the personal overlay. Yazi is the only overlapping application config
directory linked by the adapter.

### Why fnm is not the default

Omarchy already owns Node through Mise. The default preserves the active Mise Node instead of replacing it
with the repository's historical Node 22 choice. `fnm` is visible only as an advanced, mutually exclusive
selection. The installer refuses fnm while `mise where node` resolves, and refuses the Mise path while fnm is
present. Switching to fnm is a separate manual boundary: back up Mise config, obtain explicit approval before
running the printed `mise unuse --global node@VERSION --no-prune` command, start a fresh shell, verify
`mise where node` fails, and rerun with `--node-manager fnm --fnm-node 22`.

### Configuration, receipt, and rollback

Ansible is config-only on Omarchy. The `omarchy_config` tag remains paired with `never`; the installer passes component booleans
and a validated backup directory:

```bash
ansible-playbook setup.yml --tags omarchy_config
```

A confirmed run writes `$backup_dir/omarchy-install.receipt` before mutation. It records selections, package
planning, Node detection/action, Ansible variables, exact commands, and statuses. `--dry-run` prints the same
plan and receipt content plus the Ansible `--check --diff` command, but writes no receipt and runs no mutating
command.

Configuration rollback removes only `.zshrc`, `.zprofile`,
`.config/dotfiles/zsh/personal.zsh`, `.config/dotfiles/starship.toml`, and `.config/yazi`, then restores the
corresponding `.bak` entries from the receipt's backup directory where a pre-install target existed. There is
no automated package or Node rollback.

Zsh activation remains manual. The installer never runs `omarchy-setup-zsh` or `chsh`; if separately
approved, back up `.bashrc` and `.inputrc`, run the official setup, then rerun the config-only Ansible tag
because the official setup replaces `.zshrc`.

### Ownership and deferred scope

Omarchy retains Hyprland, tiling and all bindings, shell/bar JSON and Quickshell, the current theme, Foot,
Ghostty, Neovim/LazyVim, tmux, Atuin, Sheldon, fonts, and the Bash loader. Nothing writes beneath
`/usr/share/omarchy`. The installer does not port Mint, apt, Homebrew/Linuxbrew, font, TPM, broad legacy-link,
secrets, Ollama, or Cinnamon/X11 behavior.

Explicitly deferred are AWS, Ollama, terminal switching, AUR/API/load tools, arbitrary packages, other dev
environments, Atuin/Sheldon, Ghostty config, and package removal.

Repository validation:

```bash
bash tests/omarchy-boundaries.sh
REQUIRE_ANSIBLE=1 bash tests/omarchy-integration.sh
bash tests/omarchy-installer.sh
ansible-playbook setup.yml --syntax-check
zsh -n omarchy/zsh/.zshrc omarchy/zsh/.zprofile omarchy/zsh/personal.zsh
```

Tests use fixture Omarchy paths, command mocks, and disposable HOME directories. They do not prove live
Hyprland/compositor behavior, graphical key dispatch, login/reboot behavior, or compatibility after a future
Omarchy update.

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
| Guided Omarchy setup | `./bootstrap.sh`, then `./install-omarchy.sh` |
| Omarchy config only | `ansible-playbook setup.yml --tags omarchy_config` |
| Dry run (on an already set-up machine; `-K` on Linux) | `ansible-playbook setup.yml --check --diff` |
| Verify | Run it again and expect `changed=0` |

On macOS/Debian, `./bootstrap.sh` passes extra arguments through, so `./bootstrap.sh --tags symlinks` works.
The Omarchy prerequisite-only path rejects arguments and points to `install-omarchy.sh`.

Existing files in the way of a symlink are moved to `~/.dotfiles_backup/<timestamp>/` first. There is no interactive prompting — the playbook always backs up, then links.

## Configuration

### Adding New Packages
- `brew_packages.yml` — Homebrew `formulae:` (grouped by category) and `casks:`. Used on both macOS and Linux
  (casks are macOS-only; the GUI apps that have a Linux build are installed from upstream .debs by `tasks/desktop.yml`).
- `vars/Debian.yml` — the apt package list, plus the formulae brew must not install on Linux.

### Directory Structure
```
.
├── bootstrap.sh          # Legacy setup; Omarchy prerequisite-only path
├── install-omarchy.sh    # Guided Omarchy package/Node/config installer
├── setup.yml             # The playbook: symlink allowlist, package/font/tmux/secrets tasks
├── requirements.yml      # The community.general collection the playbook needs
├── tasks/
│   ├── symlinks.yml      # Backup-then-link
│   ├── debian.yml        # apt, zsh login shell, Homebrew on Linux, ollama
│   ├── omarchy.yml       # Opt-in Omarchy config-only adapter
│   └── desktop.yml       # Linux desktop apps and Cinnamon settings (--tags desktop)
├── vars/
│   ├── Darwin.yml        # macOS paths
│   ├── Debian.yml        # Linux paths, apt packages, brew exclusions
│   └── Omarchy.yml       # Exact config managed-path allowlist
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
├── omarchy/zsh/          # Official-loader integration and personal overlay
├── tests/                # Omarchy policy and disposable-HOME checks
├── tmux/                 # .tmux.conf
├── claude/               # Linked into ~/.claude: CLAUDE.md, AGENTS.md, settings, commands, skills
├── codex/                # Linked into ~/.codex: AGENTS.md, instructions, rules, keybindings
├── xbindkeys/            # Linux mouse-button / tiling bindings
└── fonts/                # Nerd Font collections
```

### Backup Location
Existing files are backed up to `~/.dotfiles_backup/` with timestamps.

## Requirements

- macOS, Debian/Ubuntu-based Linux (apt), or Omarchy; sudo on Linux
- Internet connection for package downloads

## Development

```bash
ansible-playbook setup.yml --syntax-check
ansible-lint                     # with ansible-core: ansible-galaxy collection install -r requirements.yml first
shellcheck bootstrap.sh install-omarchy.sh tests/omarchy-*.sh
bash tests/omarchy-boundaries.sh
bash tests/omarchy-installer.sh
```

CI runs `bootstrap.sh` and the playbook on macOS and Ubuntu, then runs the playbook a second time and fails
unless it reports `changed=0`. Other jobs check Linux Mint release resolution, static Omarchy boundaries,
and the Omarchy adapter/installer against disposable HOME directories and mock commands. No hosted runner provides a live
Omarchy/Hyprland session, so compositor, key-dispatch, theme, and reboot/login checks remain real-host gates.

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
