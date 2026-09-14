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
  --components bash,yazi \
  --optional-tools shellcheck,git-lfs,glow \
  --config yes
```

The guided installer uses Gum and prints a complete plan before confirmation. Deterministic runs accept only
the documented component, tool, config, backup, confirmation, and dry-run flags; arbitrary
package names are rejected.

### Defaults and optional tools

The default plan selects **Bash shortcuts + vi**, **Yazi**, and **ShellCheck**, then applies config after
confirmation. Open a new Bash shell to activate it. Bash adds no shell package. Yazi is package-only:
its `y` directory-navigation wrapper comes with the Bash component when Yazi is available; selecting Yazi
without Bash does not change shell startup. Existing Yazi config, keymaps, plugins and appearance remain intact.

ShellCheck statically checks scripts and is default-selected but optional. The only other optional tools are
`git-lfs` (large Git assets), `glow` (terminal Markdown reader), and `viu` (terminal image viewer).
Installation does not invoke these tools, initialize Git LFS filters, touch repositories or start services.
Base-manifest and already-present packages are skipped; a missing base-owned package requires repairing
Omarchy separately. All other missing selections use at most one `omarchy pkg add` batch.

### Preserve appearance and runtime

Runtime policy is unconditional **KEEP**: no Node detection, provisioning, activation or switching, even
when a configured Mise version is unavailable. Existing fnm/Mise startup stays byte-identical. Zsh switching
and runtime choices are deferred; legacy macOS/Debian Zsh setup is unchanged.

Why not default to Zsh in this revision? Independent sandbox QA ran genuine Bash/fnm → official Zsh
activation: initial Node v24.20.0 survived, but entering a project pinned to v26.8.1 left Zsh on v24.20.0
while Bash switched correctly. That is lost on-cd behavior, not a missing-Zsh-executable problem. It does
not mean Zsh/fnm can never coexist; a compatible runtime integration needs a separate approved design.
KEEP preserves existing resolution, status and project switching/failure behavior, not just initial version.

No repository Starship selection or sidecar is created. Current prompt, cursor, colors, theme, fonts,
Foot, bar, Hyprland/window/tiling/keybindings, tmux config and Yazi appearance remain owned by Omarchy/user.
This installs selected personal shortcuts, not all legacy helpers or a replacement terminal environment.

### Selected shortcuts and intentional omissions

| Names | Meaning / dependency |
|---|---|
| `lg`, `vim`, `sw` | `lazygit`, `nvim`, `sync-worktrees`, only if already available |
| `l`, `ls` | eza long/all/header/Git/icons listing; explicitly overrides Omarchy's shorter `ls` output and affects aliases using `ls` |
| `ta`, `tn`, `tls` | tmux attach-session `-t`, new `-s`, list-sessions |
| `tren`, `tnw`, `th`, `tv` | tmux rename-session `-t`, new-window, split-window `-h` / `-v` |
| `tk`, `tkill` | **Destructive when explicitly invoked:** kill selected tmux session / entire tmux server (all sessions) |
| `tkp`, `:q` | Exit this shell; `tkp` is **not** kill-pane |
| `reload` | `exec bash`; starts a replacement Bash and rereads startup |
| `y` | Yazi with cd-on-quit; blank selection is a no-op, failures propagate, temporary file cleaned on normal return; caller traps untouched |
| `fvim` | fzf picker with bat preview, then `nvim -- filename`; cancellation never starts editor; requires all three tools |

The full legacy inventory has 22 aliases and 8 functions. Every omission is deliberate:
`ghcs` needs independently verified Copilot capability; `cleanc`, `cleanp`, `clean_dev_caches` and
`clean_project` are unsafe cleaners; `supd` needs the excluded Sheldon; `_init_fzf` duplicates official
integration; `cat` and `clear` would change native behavior/erase scrollback; `claude` inspects private
session state. The conflicting `c=claude -c` is omitted so Omarchy's `c` stays authoritative. A user can
personally opt in to `alias c='claude -c'` after the managed block; this installer never adds it.

Native Bash vi starts in insert mode. Escape switches to command mode (motions, `cw`, `i`, etc.). The
packaged Omarchy inputrc is loaded into vi-insert to retain TAB/Shift-TAB cycling and prefix Up/Down.
Official fzf Ctrl-R/Ctrl-T/Alt-C bindings remain; no duplicate fzf initialization. No new cursor/prompt
sequences, global shortcuts, terminal bindings or tmux key tables are installed.

### Configuration, receipt, and rollback

Ansible is config-only on Omarchy. The `omarchy_config` tag remains paired with `never`; the installer passes component booleans
and a validated backup directory:

```bash
ansible-playbook setup.yml --tags omarchy_config
```

A confirmed run writes `$backup_dir/omarchy-install.receipt` before mutation. It records selections, package
planning, runtime KEEP, Ansible variables, exact commands, and statuses. `--dry-run` prints the same
plan and receipt content plus the Ansible `--check --diff` command, but writes no receipt and runs no mutating
command. It does not actually execute Ansible check mode. Use a fresh backup directory for each installer
receipt; existing receipts are never overwritten.

The Bash component links only `~/.config/dotfiles/bash/personal.bash` and
`~/.config/dotfiles/shell/aliases.sh`, then appends one guarded block to `.bashrc` after existing user
content. Everything outside that block is byte-preserved, including a missing final newline. A known
official env-bootstrap → interactive guard → rc prelude is required; unfamiliar layouts, duplicate/changed
markers, symlink ancestors and symlink/shared `.bashrc` are refused rather than overwritten. Existing
sidecar files/links and `.bashrc` are backed up before config changes. No-op runs create no component backup.

`bash-component.json` and `bash-component/` under the receipt directory record only this component's
changes. After reviewing that receipt, roll back with:

```bash
python3 omarchy/config.py rollback --home "$HOME" --repo "$PWD" \
  --backup "$HOME/.dotfiles_backup/REPLACE_WITH_RECEIPT_DIRECTORY"
```

Rollback restores `.bashrc` only if its installed hash still matches, and only restores/removes recorded
repository-owned sidecar links. Later edits cause refusal: review and remove only the managed block manually,
never overwrite unrelated changes. Empty sidecar directories and backups are retained. Start a new shell
after rollback; `set -o emacs` alone does not remove aliases. No package removal or runtime rollback is needed
or automated. Existing files from older Zsh/Yazi adapter versions are not deleted or migrated automatically.

### Ownership and deferred scope

Omarchy retains Hyprland, tiling and all bindings, shell/bar JSON and Quickshell, the current theme, Foot,
Ghostty, Neovim/LazyVim, tmux, Atuin, Sheldon, fonts, and the official Bash loader. Nothing writes beneath
`/usr/share/omarchy`. The installer does not port Mint, apt, Homebrew/Linuxbrew, font, TPM, broad legacy-link,
secrets, Ollama, or Cinnamon/X11 behavior.

Explicitly deferred are AWS, Ollama, terminal switching, AUR/API/load tools, arbitrary packages, other dev
environments, Atuin/Sheldon, Ghostty config, and package removal.

Repository validation:

```bash
python3 tests/omarchy-boundaries.py
python3 tests/omarchy-config.py
python3 tests/omarchy-shell.py
python3 tests/omarchy-pty.py
python3 tests/omarchy-integration.py
bash tests/omarchy-installer.sh
ansible-playbook setup.yml --syntax-check
bash -n omarchy/shell/aliases.sh omarchy/bash/personal.bash
```

Tests require Ansible and packaged fzf Bash bindings (missing is failure), with real PTY editing and
fixture Omarchy paths, command stubs, and disposable HOME directories. Login-flag and non-login PTYs load
fixture startup explicitly, excluding system and live profiles. They do not prove live
Hyprland/compositor behavior, graphical key dispatch, login/reboot behavior, or compatibility after a future
Omarchy update.

The supplementary runtime check uses real official Bash loaders, fnm, Mise and two genuine Node binaries
in a network-isolated rootless Bubblewrap sandbox. It compares baseline/candidate startup, pinned-project
entry/nested/exit, overlay re-source, manager init counts and hook fingerprints for fnm, installed/uninstalled/
unconfigured Mise, missing-manager/system Node and mixed ownership, under fresh login and non-login shells.
Runtime layouts are staged offline; this is not an installer/download test. Only `/usr` and the selected
product/runtime executable files are exposed read-only; the real HOME, runtime directories, credentials and
desktop sockets are not mounted. Synthetic consent/rollback results from the earlier Zsh investigation
were not production acceptance. The current Bash component has separate real config-helper/Ansible tests.

On a compatible Omarchy tooling host (mandatory prerequisites must exist; no unsandboxed fallback):

```bash
DOTFILES_TEST_FNM=/absolute/path/to/fnm \
DOTFILES_TEST_NODE24=/absolute/path/to/node-v24.20.0 \
DOTFILES_RUNTIME_EVIDENCE=/absolute/path/to/disposable-evidence \
  python3 tests/omarchy-runtime.py
```

This test requires system Node v26.8.1 and working unprivileged Bubblewrap namespaces. Ordinary Ubuntu CI
does not provide those real Omarchy dependencies; its fixture tests are not a substitute for this matrix.

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
│   └── Omarchy.yml       # Bash/Yazi component defaults
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
├── omarchy/              # Bash entry, shared aliases, byte-preserving config helper
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
python3 tests/omarchy-boundaries.py
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
