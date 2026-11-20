# AGENTS.md

This file provides guidance to coding agents (Claude Code, Codex, etc.) when working with code in this repository.

## Live machine updates

When changing a configuration or instruction in this repo, apply the matching change to the current machine unless the user asks for repo-only changes. Use the existing install or symlink workflow. Merge agent instructions and settings into the active user profile. Back up regular files before editing. Preserve credentials, permissions, model choices, and unrelated settings. Verify the live result and report anything that could not be applied.

## No code comments

Code in this repository carries no comments ([ADR 0001](docs/adr/0001-no-code-comments.md)). Put the *why* in the
ADR for the area (index: `docs/adr/README.md`) and update it in the same change. File a GitHub issue for a
workaround instead of writing a comment that excuses it. `python3 scripts/check-comments.py` enforces this as a ratchet
against `scripts/comment-baseline.json`. The `/delete-comment` skill (`.claude/skills/delete-comment/`) triages any
comments that remain.

## Shared agent tooling

For shared tooling, proxies, hooks, logging, or agent configuration, inspect every installed harness, including Claude Code, Codex, Pi, Hermes, and OpenCode. Apply and verify supported integrations within the user's requested scope. Report which harnesses were configured, excluded, unsupported, or untested.

## Repository Overview

Dotfiles for macOS, Debian/Ubuntu-based Linux (incl. Linux Mint) and Omarchy. Setup is an
Ansible playbook run against localhost; `bootstrap.sh` installs Ansible (and
Homebrew on macOS) and then runs it.

Native Windows is set up by `bootstrap.ps1` (WinGet packages, profile, fonts, Terminal fragment), which then
installs Ubuntu on WSL 2 and runs the same playbook there. `agent-setup/` is a separate bundle of agent
plugins, skills and setup guides that the playbook does not deploy; it has its own `agent-setup/AGENTS.md`.

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
python3 scripts/check-comments.py                 # Comment ratchet; --list shows what is left
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
- `tasks/become.yml` — imported as a pre_task (tag `always`): on Debian-family hosts that ship
  `/usr/bin/sudo.ws` (Ubuntu 26.04, where plain `sudo` is sudo-rs) it points Ansible's become at the classic
  binary. `bootstrap.sh` makes the same choice for its own sudo calls.
- `tasks/wsl.yml` — WSL only (tag `wsl`): systemd and the default user in `/etc/wsl.conf`, other settings kept.
- `tasks/omarchy.yml` — Omarchy only (detected from `ID=omarchy` in `/etc/os-release`; Ansible itself reports
  Archlinux). Keeps Omarchy's Bash/prompt/theme/nvim/tmux defaults and layers on top: pacman `atuin` +
  `bash-preexec`, links `omarchy/bash/personal.bash` and `omarchy/tmux/tmux.conf` under `~/.config/dotfiles/`,
  and sources them from `blockinfile` blocks at the end of `~/.bashrc` and `~/.config/tmux/tmux.conf`. TPM
  lives in `~/.config/tmux/plugins`. The legacy tasks are gated on `is_legacy_platform`.
- `tasks/desktop.yml` — Ulauncher (PPA), Ghostty (apt or community .deb), Bitwarden and draw.io (upstream
  .deb), Flameshot/xbindkeys/rofi/wmctrl, Cinnamon hot corners and custom hotkeys via `gsettings`, xbindkeys
  restart. Tagged `[desktop, never]`.
- `brew_packages.yml` — `formulae:` grouped by category plus `casks:`; used on both OSes.
- `bootstrap.ps1`, `windows/` — native Windows setup and its tests; `windows/setup-wsl.ps1` installs
  WSL/Ubuntu and runs `windows/bootstrap-wsl.sh` (clone, `bootstrap.sh`, then `windows.yml`).
- `windows.yml` — run from Ubuntu/WSL; drives `windows/install-agents.ps1`, `install-tailscale.ps1` and
  `set-terminal-default.ps1` through `powershell.exe` interop.
- `agent-setup/` — pinned agent plugins/skills, per-harness guides, Herdr App mods and the CLIProxyAPI
  notes. `scripts/agent-setup-bundle.py` verifies the pins and stages marketplaces.
- `scripts/install-sync-worktrees.sh` (tags `packages`, `sync-worktrees`) — installs `sync-worktrees` on its
  own Node 24 through fnm, with launchers in `~/.local/bin`, because the CLI needs a newer Node than
  `node_version`. Registers its MCP server through `claude mcp add` and `codex mcp add` when those CLIs
  are installed. A copy already on `PATH` is left alone. Pi, Hermes and OpenCode are not configured.
- `scripts/install-herdr.sh` and `windows/install-herdr.ps1` — release-matched Herdr skills and integrations. Unix setup detects installed Claude, Codex, Pi and Hermes; Windows agent setup includes Claude/Codex.
- `docs/adr/` — architecture decision records, one per area; the rationale that used to live in comments.
- `scripts/check-comments.py` — the comment ratchet. `--list`, `--strip <paths>`, `--update` (lowers only);
  pinned upstream payloads are skipped by reading `agent-setup/*/sources.json`.
- `files/secrets.template` — the `~/.secrets` template that setup copies.
- `.config/` (nvim, ghostty, atuin, sheldon, yazi, herdr/config.toml, starship.toml), `zsh/`, `tmux/`, `xbindkeys/` — the linked content.

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
`~/.secrets` (mode 600, sourced by `.zprofile` and `personal.bash`) is copied from `files/secrets.template` only when missing. Its
template entries are commented out, so no placeholder is ever exported as a credential.

Setup does not deploy repository Claude or Codex configuration. CLI installation and Herdr skills
and integrations remain supported. Herdr setup migrates older settings and skills links to local
copies before installing integrations. `scripts/migrate-agent-links.sh` (tags `symlinks`, `herdr`) first
replaces any `~/.claude`/`~/.codex` link into the retired `claude/`/`codex/` bundles with a local copy
restored from Git history, so upgraded machines keep their configuration.

### Sudo
Play default is `become: false`. Only the apt, login-shell and Linuxbrew-prefix tasks (and the desktop apt
tasks) use `become: true`; run with `-K` on Linux. macOS needs no sudo.

### Tags
`packages`, `ollama` and `sync-worktrees` (subsets of packages), `fonts`, `tmux`, `secrets`, `symlinks`,
`herdr`, `wsl`, `desktop` (+ `never`).
`--skip-tags packages` is the configs-only run.

### Testing
`bash scripts/test-agent-config.sh` runs only the symlink tasks against temporary homes and
checks that Claude and Codex configuration stays absent or unchanged. The Windows workflow's
Ansible syntax job runs this regression check without installing tools through setup.

The other regression scripts need no provisioning either: `scripts/test-herdr.sh` (installer against a mock
`herdr`), `scripts/test-sync-worktrees.sh` (installer against mock `fnm`, `claude` and `codex`),
`scripts/test-agent-migration.sh`, `scripts/test-bootstrap-sudo.sh` and
`scripts/test-wsl-bootstrap.sh` (both need `TMPDIR` set), `scripts/test-ansible-facts.py` (rejects injected
`ansible_*` fact aliases in every play, including the ones under `.github/`), and
`scripts/test-agent-setup-bundle.py` and `scripts/test-check-comments.py`. `windows/test-*.ps1` cover the PowerShell side.

CI (`.github/workflows/test-setup-ci.yml`) runs `bootstrap.sh` + the playbook on `macos-latest` and
`ubuntu-latest` with `--skip-tags ollama`, then runs the playbook again and fails unless the recap shows
`changed=0`. A third job runs `.github/mint-release.yml`, which asserts the release
resolution the desktop tasks rely on against fixtured Linux Mint 22.3 identity files (no runner ships Mint,
and the official container reports `ID=ubuntu` — it carries Mint's package base, not its identity). A lint job runs `ansible-lint`, the agent-setup bundle checks, the comment ratchet and its tests, the Herdr App key-map test and `shellcheck`.
`.github/workflows/test-windows.yml` runs the Windows scripts on `windows-latest`, the sudo compatibility
play in an Ubuntu 26.04 container, and the remaining shell/Python regression scripts. The desktop and ollama
tasks are not exercised in CI.

## Important Notes

- Fonts are not vendored. `setup.yml` unpacks the 0xProto, FiraCode and RobotoMono archives from the Nerd
  Fonts release into `~/Library/Fonts` on macOS or `~/.local/share/fonts` (plus `fc-cache`) on Linux, and
  skips a family that is already there. `bootstrap.ps1` fetches the 0xProto faces on Windows
- On Linux, Homebrew supplies current builds of the CLI tools; apt covers the base system and build deps.
  `ollama` comes from the upstream tarball because brew's Linux bottle is CPU-only
- Shell configs carry their own runtime OS branching (`zsh/.zprofile` probes the brew prefixes); the playbook
  does not template them
