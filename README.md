# Dotfiles

Terminal setup for macOS and Debian/Ubuntu (incl. Linux Mint), installed and kept in sync by one Ansible playbook.

## Features

- 🚀 **One-command setup** - `./bootstrap.sh` installs Ansible and runs the playbook
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

# Installs Ansible (and Homebrew on macOS), then runs setup.yml.
# On Linux it asks for your sudo password (apt, login shell).
./bootstrap.sh
```

Afterwards, re-run the playbook directly:

```bash
ansible-playbook setup.yml -K    # Linux
ansible-playbook setup.yml       # macOS
```

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
| Linux desktop: Ulauncher, Ghostty, Bitwarden, draw.io, Flameshot, Cinnamon hot corners/hotkeys, xbindkeys, xremap | `ansible-playbook setup.yml -K --tags desktop` (never runs unless asked; needs a graphical session) |
| Dry run (on an already set-up machine; `-K` on Linux) | `ansible-playbook setup.yml --check --diff` |
| Verify | Run it again and expect `changed=0` |

`./bootstrap.sh` passes extra arguments through, so `./bootstrap.sh --tags symlinks` works too.

Existing files in the way of a symlink are moved to `~/.dotfiles_backup/<timestamp>/` first. There is no interactive prompting — the playbook always backs up, then links.

The desktop tag installs an app-aware, MX Mechanical-only xremap configuration
for macOS-style Command shortcuts. It adds the account to the `input` group,
which grants input-device access equivalent to keylogging; sign out and back in
after the first run. Stop `xremap` to disable the remapping immediately.

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
├── tasks/
│   ├── symlinks.yml      # Backup-then-link
│   ├── debian.yml        # apt, zsh login shell, Homebrew on Linux, ollama
│   └── desktop.yml       # Linux desktop apps and Cinnamon settings (--tags desktop)
├── vars/
│   ├── Darwin.yml        # macOS paths
│   └── Debian.yml        # Linux paths, apt packages, brew exclusions
├── brew_packages.yml     # Homebrew formulae & casks
├── .config/              # Modern tool configs
│   ├── nvim/             # LazyVim configuration
│   ├── starship.toml     # Starship prompt
│   ├── ghostty/          # Ghostty terminal
│   ├── atuin/            # Shell history
│   └── yazi/             # Terminal file manager
├── zsh/                  # .zprofile, .zshrc, .zshrc.core
├── tmux/                 # .tmux.conf
├── xbindkeys/            # Linux mouse-button / tiling bindings
├── xremap/               # MX keyboard macOS-style Command shortcuts
└── fonts/                # Nerd Font collections
```

### Backup Location
Existing files are backed up to `~/.dotfiles_backup/` with timestamps.

## Requirements

- macOS, or a Debian/Ubuntu-based Linux (apt); sudo on Linux
- Internet connection for package downloads

## Development

```bash
ansible-playbook setup.yml --syntax-check
ansible-lint                     # with ansible-core: ansible-galaxy collection install -r requirements.yml first
shellcheck bootstrap.sh
```

CI runs `bootstrap.sh` and the playbook on macOS and Ubuntu, then runs the playbook a second time and fails unless it reports `changed=0`.

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
