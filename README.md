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

# Installs Ansible (and Homebrew on macOS), then runs setup.yml.
# On Linux it asks for your sudo password (apt, login shell).
./bootstrap.sh
```

Afterwards, re-run the playbook directly:

```bash
ansible-playbook setup.yml -K    # Linux
ansible-playbook setup.yml       # macOS
```

The run also creates `~/.secrets` (mode 600) from a template of placeholder tokens, which `.zprofile`
sources on login — fill in the ones you use. It is written only when missing, so re-runs never
overwrite it.

## Omarchy (opt-in)

Omarchy support is an adapter, not a replacement desktop configuration. It leaves Omarchy's Hyprland,
keybindings, bar, theme, Foot, Neovim, tmux, Bash loader, and canonical Starship file untouched. The adapter
only installs the allowlisted `omarchy-zsh` and `yazi` packages, adds the official Zsh loaders followed by a
personal overlay, selects this repository's Starship config in Zsh through `STARSHIP_CONFIG`, and links the
Yazi config. The adapter is tagged `never`, so an untagged playbook run cannot apply it.

Do not use `bootstrap.sh` on Omarchy. Ansible is a prerequisite; after separate package-install approval it
can be installed with:

```bash
omarchy pkg add ansible
```

Capture the current Omarchy-owned state and choose a rollback directory before any authorized apply:

```bash
baseline=$(mktemp -d)
omarchy menu keybindings --print > "$baseline/keybindings.before"
sha256sum ~/.config/hypr/hyprland.lua ~/.config/hypr/bindings.lua > "$baseline/hypr.before"
sha256sum ~/.config/omarchy/shell.json ~/.config/foot/foot.ini \
  ~/.config/nvim/init.lua ~/.config/tmux/tmux.conf > "$baseline/owned.before"
omarchy theme current > "$baseline/theme.before"
rollback="$HOME/.dotfiles_backup/omarchy-$(date +%Y%m%d-%H%M%S)"
```

Dry-run first, then apply only after reviewing the diff. The adapter supports the concise forms below:

```bash
ansible-playbook setup.yml -K --tags omarchy --check --diff
ansible-playbook setup.yml -K --tags omarchy
```

For a controlled rollback, use the explicit directory captured above for both runs:

```bash
ansible-playbook setup.yml -K -e backup_dir="$rollback" --tags omarchy --check --diff
ansible-playbook setup.yml -K -e backup_dir="$rollback" --tags omarchy

# Later config-only reruns never perform package actions.
ansible-playbook setup.yml --tags omarchy_config
```

Validate that Omarchy-owned surfaces did not move, the shell tools are available, and a second adapter run
reports `changed=0`:

```bash
omarchy menu keybindings --print > "$baseline/keybindings.after"
cmp "$baseline/keybindings.before" "$baseline/keybindings.after"
sha256sum ~/.config/hypr/hyprland.lua ~/.config/hypr/bindings.lua > "$baseline/hypr.after"
cmp "$baseline/hypr.before" "$baseline/hypr.after"
sha256sum ~/.config/omarchy/shell.json ~/.config/foot/foot.ini \
  ~/.config/nvim/init.lua ~/.config/tmux/tmux.conf > "$baseline/owned.after"
cmp "$baseline/owned.before" "$baseline/owned.after"
omarchy theme current > "$baseline/theme.after"
cmp "$baseline/theme.before" "$baseline/theme.after"
test -z "$(hyprctl configerrors)"
pacman -Q omarchy-zsh yazi
zsh -lic 'test "$STARSHIP_CONFIG" = "$HOME/.config/dotfiles/starship.toml"'
ansible-playbook setup.yml -K -e backup_dir="$rollback" --tags omarchy
```

Zsh activation remains manual and requires separate approval. If `omarchy-setup-zsh` is later chosen, first
back up `.bashrc` and `.inputrc`; the official command replaces `.zshrc`, so rerun
`ansible-playbook setup.yml --tags omarchy_config` afterward. The adapter never runs that command or `chsh`.

### Omarchy rollback

Rollback does not require removing packages. Using the exact directory passed as `backup_dir`, remove only
`.zshrc`, `.zprofile`, `.config/dotfiles/zsh/personal.zsh`, `.config/dotfiles/starship.toml`, and
`.config/yazi`; then restore the corresponding `.bak` entries from that directory only where a pre-apply
target existed. Start a fresh Bash shell and repeat the keybinding, Hyprland, owner-file, and theme
comparisons above. Package removal is a separate approval because dependency removal may be destructive.
If `omarchy-setup-zsh` was run separately, also restore its exact pre-activation `.bashrc` and `.inputrc`
backups.

Repository-only validation is safe on any development host:

```bash
bash tests/omarchy-boundaries.sh
REQUIRE_ANSIBLE=1 bash tests/omarchy-integration.sh
ansible-playbook setup.yml --syntax-check
zsh -n omarchy/zsh/.zshrc omarchy/zsh/.zprofile omarchy/zsh/personal.zsh
```

The integration test uses a disposable HOME, fixture marker paths, and a mock Omarchy command. It never
writes under `/usr/share/omarchy` or invokes a real package manager.

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
| Omarchy adapter | `ansible-playbook setup.yml -K --tags omarchy` (never runs unless asked) |
| Omarchy config only | `ansible-playbook setup.yml --tags omarchy_config` |
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
│   ├── omarchy.yml       # Opt-in Omarchy package/config adapter
│   └── desktop.yml       # Linux desktop apps and Cinnamon settings (--tags desktop)
├── vars/
│   ├── Darwin.yml        # macOS paths
│   ├── Debian.yml        # Linux paths, apt packages, brew exclusions
│   └── Omarchy.yml       # Exact package and managed-path allowlists
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
shellcheck bootstrap.sh
```

CI runs `bootstrap.sh` and the playbook on macOS and Ubuntu, then runs the playbook a second time and fails
unless it reports `changed=0`. Other jobs check Linux Mint release resolution, static Omarchy boundaries,
and the Omarchy adapter against a disposable HOME and mock package command. No hosted runner provides a live
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
