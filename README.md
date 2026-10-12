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
- `macos_formulae:` is added only on Darwin. `optional_formulae:` and `optional_casks:` document host-specific
  choices and are never installed by the playbook. Existing unmanaged apps can conflict with casks: adopt
  only provably identical artifacts using `brew install --cask --adopt`, never force replacement.
- `vars/Debian.yml` — the apt package list, plus the formulae brew must not install on Linux.

### Developer tool ownership

- fnm owns user-shell Node/npm/npx. The default policy is Node 26 (the cleanup reused installed 26.5.1,
  rather than upgrading); local sync-worktrees 7.2.0 needs Node >=24. Older fnm project versions remain.
  `.zshrc.tools` initializes Brew/PATH/fnm once per shell, before interactive plugins, including non-login
  shells. It does not modify inherited assistant/service environments or Hermes's private runtimes.
  Brew `node` may remain as Wrangler's dependency, but is not a requested standalone runtime; nvm is not requested.
- Brew owns general Git, Bun (macOS), bw, ccusage, Codex CLI, OpenCode, Ollama, AWS, Kubernetes/Helm/Minikube,
  Wrangler/cloudflared, gws and the macOS Google Cloud SDK. Package installation does not start services.
  Apple Git, vendor AWS installations and OrbStack's Docker/kubectl integrations are not deleted.
- Python's requested language version is Brew 3.13, with uv and pipx for environments/CLI isolation.
  Brew's unversioned `python3` can follow dependency versions; other Brew Pythons and uv-managed 3.11 are
  separate intentional owners. Legacy Python 2.7 is a later audit, not an automatic removal.
  Brew Rust remains primary; standalone rustup/project toolchains are preserved pending a usage audit.
- `sync-worktrees`, `ntn` and `stremio-addon-sdk` remain local npm-managed exceptions under `~/.local`.
  Changing the fnm default does not reinstall or move them. pnpm/yarn/corepack are not automatically added.
- Hermes CLI/desktop, private bundled Node/browser tools, custom Jarvis launchers and CuaDriver retain
  their current owners. `hermes-agent`, `hermes-desktop`, `agent-browser` and `pi-coding-agent` are alternatives,
  not default migrations. Standalone Bun can remain where managed runtime discovery may use `~/.bun/bin`.
  VS Code's Dev Containers CLI stays extension-owned rather than adding a second `devcontainer` formula.
- Claude Code and desktop remain suspended and unchanged; their casks are documented only as future choices.
  Gemini CLI, Aider, Cursor, Zed and extra package managers are not installed merely because available.
- VS Code, Codex desktop and Termius are optional existing-app adoption candidates. Bitwarden desktop is
  already a default cask; no vault data is migrated. OrbStack is the preferred host-specific container
  platform; Docker Desktop is an optional alternative. VirtualBox/Home Assistant requires a privileged
  installer and is deliberately outside automatic setup. Xcode remains Apple-managed.
- Duplicate user entrypoints should be quarantined only after replacement validation, preserving packages,
  sessions and state. Broken CodeWhisperer links are eligible individually; functional/custom wrappers are not.
  Host cleanup is a separate explicitly authorized operation, never part of bootstrap.

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
ansible-playbook .github/tool-policy.yml # Nonmutating ownership/package regression checks
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
