# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Dotfiles for macOS and Debian/Ubuntu-based Linux (incl. Linux Mint). Setup is an
Ansible playbook run against localhost; `bootstrap.sh` installs Ansible (and
Homebrew on macOS) and then runs it.

## Essential Commands

```bash
./bootstrap.sh                                    # First run: installs Ansible, runs setup.yml (adds -K on Linux)
ansible-playbook setup.yml -K                     # Re-run on Linux (apt/usermod need sudo)
ansible-playbook setup.yml                        # Re-run on macOS
ansible-playbook setup.yml --skip-tags packages   # Configs only
ansible-playbook setup.yml -K --skip-tags ollama  # Skip the 1.4 GB ollama build
ansible-playbook setup.yml -K --tags desktop      # Linux desktop (Ulauncher, Ghostty, Cinnamon, xbindkeys); never runs unless asked
ansible-playbook setup.yml --check --diff         # Dry run (already set-up machine; -K on Linux)
ansible-playbook setup.yml --syntax-check
ansible-lint                                      # With ansible-core: ansible-galaxy collection install -r requirements.yml first
shellcheck bootstrap.sh
```

Verify = run the playbook again and expect `changed=0`.

## Architecture & Key Components

- `setup.yml` — the play. Holds the symlink allowlist (`dotfile_links`), the backup dir, the per-task
  `tool_env` (brew/fnm/tmux on PATH within the run), and the ordered tasks with their tags. Per-OS values come
  from `vars/{{ ansible_os_family }}.yml` via `vars_files`.
- `vars/Darwin.yml`, `vars/Debian.yml` — brew prefix, fonts dir, the flattened formula list. Debian
  also holds the apt package list and the formulae brew must not install on Linux.
- `tasks/symlinks.yml` — `stat` → move anything in the way to `~/.dotfiles_backup/<timestamp>/` → `file state=link`.
  Parametrised on `links`; imported from `setup.yml` and again from `tasks/desktop.yml` for the xbindkeys files.
- `tasks/debian.yml` — apt, zsh as login shell, Homebrew on Linux (the prefix is pre-created user-owned so the
  installer never calls sudo), ollama upstream build + systemd user unit (tag `ollama`).
- `tasks/desktop.yml` — Ulauncher (PPA), Ghostty (apt or community .deb), Flameshot/xbindkeys/rofi/wmctrl,
  Cinnamon hot corners and custom hotkeys via `gsettings`, xbindkeys restart. Tagged `[desktop, never]`.
- `brew_packages.yml` — `formulae:` grouped by category plus `casks:`; used on both OSes.
- `.config/` (nvim, ghostty, atuin, sheldon, yazi, starship.toml), `zsh/`, `tmux/`, `xbindkeys/`, `claude/`,
  `codex/`, `fonts/` — the linked/copied content.

## Key Implementation Details

### Symlink Strategy
Symlinks from `$HOME` into the repo with absolute targets, e.g. `~/.zshrc → ~/dotfiles/zsh/.zshrc`,
`~/.config/nvim → ~/dotfiles/.config/nvim`. The list is an explicit allowlist — never glob `~/.claude` or
`~/.codex`, they are dominated by machine state and credentials.

### Conflict Handling
Always backup-then-link; there are no interactive or append modes. A target that already is the exact
symlink is left alone, so a no-op run creates no backup directory. Parent directories are created without a
`mode` so pre-existing dirs keep theirs.

### Copy-if-absent Files
`~/.secrets` (mode 600, sourced by `.zprofile`) and `~/.codex/config.toml` (codex appends project trust
entries at runtime) are copied only when missing, never overwritten.

### Sudo
Play default is `become: false`. Only the apt, login-shell and Linuxbrew-prefix tasks (and the desktop apt
tasks) use `become: true`; run with `-K` on Linux. macOS needs no sudo.

### Tags
`packages`, `ollama` (subset of packages), `fonts`, `tmux`, `secrets`, `symlinks`, `desktop` (+ `never`).
`--skip-tags packages` is the configs-only run.

### Testing
CI (`.github/workflows/test-setup-ci.yml`) runs `bootstrap.sh` + the playbook on `macos-latest` and
`ubuntu-latest` with `--skip-tags ollama`, then runs the playbook again and fails unless the recap shows
`changed=0`. A lint job runs `ansible-lint` and `shellcheck`. The desktop and ollama tasks are not exercised in CI.

## Important Notes

- Fonts in `fonts/` are copied (not linked) to `~/Library/Fonts` on macOS or `~/.local/share/fonts` (plus
  `fc-cache`) on Linux
- On Linux, Homebrew supplies current builds of the CLI tools; apt covers the base system and build deps.
  `ollama` comes from the upstream tarball because brew's Linux bottle is CPU-only
- Shell configs carry their own runtime OS branching (`zsh/.zprofile` probes the brew prefixes); the playbook
  does not template them
