# AGENTS.md

This file provides guidance to coding agents (Claude Code, Codex, etc.) when working with code in this repository.

## Live machine updates

When changing a configuration or instruction in this repo, apply the matching change to the current machine unless the user asks for repo-only changes. Use the existing install or symlink workflow. Merge agent instructions and settings into the active user profile. Back up regular files before editing. Preserve credentials, permissions, model choices, and unrelated settings. Verify the live result and report anything that could not be applied.

## Shared agent tooling

For shared tooling, proxies, hooks, logging, or agent configuration, inspect every installed harness, including Claude Code, Codex, Pi, Hermes, and OpenCode. Apply and verify supported integrations within the user's requested scope. Report which harnesses were configured, excluded, unsupported, or untested.

## Repository Overview

Dotfiles for macOS, Debian/Ubuntu-based Linux (incl. Linux Mint) and Omarchy. Setup is an
Ansible playbook run against localhost; `bootstrap.sh` installs Ansible (and
Homebrew on macOS) and then runs it.

## Essential Commands

```bash
./bootstrap.sh                                    # First run: installs Ansible, runs setup.yml (adds -K on Linux)
ansible-playbook setup.yml -K                     # Re-run on Linux (apt/usermod need sudo)
ansible-playbook setup.yml                        # Re-run on macOS
ansible-playbook setup.yml --skip-tags packages   # Configs only
ansible-playbook setup.yml -K --skip-tags ollama  # Skip the 1.4 GB ollama build
ansible-playbook setup.yml -K --tags desktop      # Linux desktop (Ulauncher, Ghostty, Bitwarden, draw.io, Cinnamon, xbindkeys); never runs unless asked
ansible-playbook setup.yml --check --diff         # Dry run (already set-up machine; -K on Linux)
ansible-playbook setup.yml --syntax-check
ansible-lint                                      # With ansible-core: ansible-galaxy collection install -r requirements.yml first
shellcheck bootstrap.sh
```

Verify = run the playbook again and expect `changed=0`.

## Architecture & Key Components

- `setup.yml` — the play. Holds the symlink allowlist (`dotfile_links`), the backup dir, the per-task
  `tool_env` (brew/fnm/tmux on PATH within the run), and the ordered tasks with their tags. Per-OS values come
  from `vars/{{ ansible_os_family }}.yml` (or `vars/Omarchy.yml`) via an `include_vars` pre_task.
- `vars/Darwin.yml`, `vars/Debian.yml` — brew prefix, fonts dir, the flattened formula list. Debian
  also holds the apt package list and the formulae brew must not install on Linux.
- `tasks/symlinks.yml` — `stat` → move anything in the way to `~/.dotfiles_backup/<timestamp>/` → `file state=link`.
  Parametrised on `links`; imported from `setup.yml` and again from `tasks/desktop.yml` for the xbindkeys files.
- `tasks/debian.yml` — apt, zsh as login shell, Homebrew on Linux (the prefix is pre-created user-owned so the
  installer never calls sudo), ollama upstream build + systemd user unit (tag `ollama`).
- `tasks/omarchy.yml` — Omarchy only (detected from `ID=omarchy` in `/etc/os-release`; Ansible itself reports
  Archlinux). Keeps Omarchy's Bash/prompt/theme/nvim/tmux defaults and layers on top: pacman `atuin` +
  `bash-preexec`, links `omarchy/bash/personal.bash` and `omarchy/tmux/tmux.conf` under `~/.config/dotfiles/`,
  and sources them from `blockinfile` blocks at the end of `~/.bashrc` and `~/.config/tmux/tmux.conf`. TPM
  lives in `~/.config/tmux/plugins`. The legacy tasks are gated on `is_legacy_platform`.
- `tasks/desktop.yml` — Ulauncher (PPA), Ghostty (apt or community .deb), Bitwarden and draw.io (upstream
  .deb), Flameshot/xbindkeys/rofi/wmctrl, Cinnamon hot corners and custom hotkeys via `gsettings`, xbindkeys
  restart. Tagged `[desktop, never]`.
- `brew_packages.yml` — `formulae:` grouped by category plus `casks:`; used on both OSes.
- `scripts/install-herdr.sh` and `windows/install-herdr.ps1` — release-matched Herdr skills and integrations for Claude/Codex. Linux setup detects installed harnesses; Windows agent setup includes both.
- `.config/` (nvim, ghostty, atuin, sheldon, yazi, herdr/config.toml, starship.toml), `zsh/`, `tmux/`, `xbindkeys/`, `fonts/` — the linked/copied content.

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
`~/.secrets` (mode 600, sourced by `.zprofile` and `personal.bash`) is copied only when missing.

Setup does not deploy repository Claude or Codex configuration. CLI installation and Herdr skills
and integrations remain supported. Herdr setup migrates older settings and skills links to local
copies before installing integrations. `scripts/migrate-agent-links.sh` (tags `symlinks`, `herdr`) first
replaces any `~/.claude`/`~/.codex` link into the retired `claude/`/`codex/` bundles with a local copy
restored from Git history, so upgraded machines keep their configuration.

### Sudo
Play default is `become: false`. Only the apt, login-shell and Linuxbrew-prefix tasks (and the desktop apt
tasks) use `become: true`; run with `-K` on Linux. macOS needs no sudo.

### Tags
`packages`, `ollama` (subset of packages), `fonts`, `tmux`, `secrets`, `symlinks`, `desktop` (+ `never`).
`--skip-tags packages` is the configs-only run.

### Testing
`bash scripts/test-agent-config.sh` runs only the symlink tasks against temporary homes and
checks that Claude and Codex configuration stays absent or unchanged. The Windows workflow's
Ansible syntax job runs this regression check without installing tools through setup.

CI (`.github/workflows/test-setup-ci.yml`) runs `bootstrap.sh` + the playbook on `macos-latest` and
`ubuntu-latest` with `--skip-tags ollama`, then runs the playbook again and fails unless the recap shows
`changed=0`. A third job runs `.github/mint-release.yml`, which asserts the release
resolution the desktop tasks rely on against fixtured Linux Mint 22.3 identity files (no runner ships Mint,
and the official container reports `ID=ubuntu` — it carries Mint's package base, not its identity). A lint job runs `ansible-lint` and `shellcheck`. The desktop and ollama tasks are not exercised in CI.

## Important Notes

- Fonts in `fonts/` are copied (not linked) to `~/Library/Fonts` on macOS or `~/.local/share/fonts` (plus
  `fc-cache`) on Linux
- On Linux, Homebrew supplies current builds of the CLI tools; apt covers the base system and build deps.
  `ollama` comes from the upstream tarball because brew's Linux bottle is CPU-only
- Shell configs carry their own runtime OS branching (`zsh/.zprofile` probes the brew prefixes); the playbook
  does not template them
