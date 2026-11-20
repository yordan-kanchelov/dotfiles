# 0003. Playbook and installer script conventions

Status: Accepted, 2026-11-20

## Context

`setup.yml` runs on macOS, Debian-family Linux, Omarchy and Ubuntu under WSL. A second run must report `changed=0`. Several helper scripts run inside the play and also on their own.

## Decision

### Facts and environment (`setup.yml`)

- `home` comes from `ansible_facts['env']['HOME']`, not `~`, because become tasks would expand `~` to `/root`.
- Omarchy is detected from `ID=omarchy` in `/etc/os-release`, because Ansible reports it as plain Archlinux.
- `tool_env` puts brew, fnm and tmux on PATH for the tasks that call them. Those tools are needed during this run, not only after the next login.

### Symlinks (`setup.yml`, `tasks/symlinks.yml`)

- `dotfile_links` is an explicit allowlist. Never glob `~/.claude` or `~/.codex`: they hold machine state, caches and credentials.
- Each `links` entry is `src` relative to the repository and `dest` relative to `$HOME`. The same task file is imported from `setup.yml` and again from `tasks/desktop.yml`.
- Parent directories are created without a `mode`. Most of them already exist and must keep their current mode, and the umask default suits the rest.
- Anything at the destination that is not already the exact link is moved into a timestamped backup first. That covers a file, a directory, and a dangling or wrong link. This step must run before `file state=link`, which refuses to replace a real directory. The `mkdir` of the backup directory sits inside the gated task, so a no-op run leaves no empty backup directory behind.

### Secrets (`setup.yml`, `files/secrets.template`)

- `~/.secrets` is copied only when it is missing (`force: false`). Every template entry is commented out, so no tool ever picks up a placeholder as a real credential.
- A separate task enforces mode 0600. `force: false` never touches an existing file, so a `~/.secrets` that was already world-readable would otherwise stay that way.

### Privilege (`tasks/become.yml`, `bootstrap.sh`)

- Ubuntu 26.04 defaults to sudo-rs, and some packaged Ansible versions do not recognise its PAM prompt. On hosts that ship `/usr/bin/sudo.ws`, the play uses the classic binary for Ansible only. It leaves update-alternatives and the user's normal `sudo` untouched. `bootstrap.sh` makes the same choice for its own sudo calls, without changing the system default.
- `bootstrap.sh` checks for passwordless sudo with `sudo -n -k true`, which ignores cached credentials, because Ansible may run outside the bootstrap's sudo session. Only sudo that is truly passwordless may skip the become password prompt.
- `bootstrap.sh` installs `community.general` when it is missing: pip and pipx `ansible-core` ship without it, while the apt and brew `ansible` packages bundle it.

### Ordering and gating (`setup.yml`)

- fnm chooses its own data directory (legacy `~/.fnm`, `XDG_DATA_HOME`, or a per-OS default), so the play asks fnm what is installed instead of guessing a path for `creates`. `fnm default` runs unconditionally, so a default that has drifted gets repaired, not only fresh installs.
- sync-worktrees needs Node 24+. `scripts/install-sync-worktrees.sh` gives it its own Node through fnm, next to `node_version`, and leaves the default alone. It then registers the MCP server with the installed Claude Code and Codex through their own CLIs. It runs after "Node via fnm", because the first Node that fnm installs becomes the default.
- TPM's installer shells out to tmux. A configs-only run (`--skip-tags packages`) on a machine without tmux must skip it, not fail.
- `tasks/desktop.yml` is tagged `never` and runs only with `--tags desktop`: a launcher and global hotkeys mean nothing outside a graphical session. The file asserts a graphical session, so an explicit `--tags desktop` over SSH fails loudly instead of skipping every task and reporting success.
- Older setups linked `~/.claude` and `~/.codex` paths into the retired `claude/` and `codex/` bundles. `scripts/migrate-agent-links.sh` replaces each such link with a local copy restored from Git history, so harness configuration survives the upgrade. At HEAD the path no longer exists, so the last commit that touched it is the one that removed it, and that commit's parent has the content. Content still present at the target, such as ignored synced skills, takes precedence over history. `.gitignore` keeps `claude/skills/synced/` and `claude/skills/session-start-hook/` because the old links let Claude sync skills into the checkout; leftovers there are not ours.

### Omarchy (`tasks/omarchy.yml`)

- Omarchy keeps its own Bash, prompt, theme and tmux defaults. Each personal layer is a repository file linked under `~/.config/dotfiles` and sourced from a marked block at the end of the file Omarchy owns. Omarchy updates to those files keep working, and removing the block undoes the layer.
- Omarchy creates `~/.config/tmux/tmux.conf` on install, and the play restores it if it has gone missing.
- TPM's `install_plugins` asks the running tmux server where plugins go. The play therefore starts a private server that loads the config fresh, instead of using the server the user is working in. Its `TMUX_TMPDIR` is a short `mktemp` path, because socket paths are limited to about 100 characters.

### Shell scripts (`scripts/`, `bootstrap.sh`)

- Where a check pipes a producer into `grep` under `pipefail`, `grep` runs without `-q`, so it drains the pipe and the producer never dies of EPIPE (`bootstrap.sh`, `scripts/install-sync-worktrees.sh`, the "Node via fnm" task). This is a known workaround: [yordan-kanchelov/dotfiles#24](https://github.com/yordan-kanchelov/dotfiles/issues/24).
- Bash 3.2 (macOS) treats an empty array as unset under `nounset`, so array expansions use the `${a[@]+"${a[@]}"}` form.
- `scripts/install-sync-worktrees.sh` reports only `changed:` lines on stdout and sends installer output to stderr. Its launchers use absolute paths, because a client started outside a login shell has neither Homebrew nor `~/.local/bin` on PATH. The fallback path matters only for `--check` before the install. Both CLIs exit non-zero from `mcp get` when no server has that name, and the script relies on that. A copy of sync-worktrees already on PATH, such as a dev checkout linked there, is left alone.
- `scripts/agent-setup-bundle.py` raises explicit errors instead of using `assert`, because `python -O` strips asserts and would skip the integrity checks.
- `.gitignore` lists AI tool machine state (`auth.json`, `.credentials*`, `settings.local.json`, history, sessions), so none of it can be committed even if it gets copied in by accident.

## Consequences

Every task has to stay idempotent under these rules. CI checks this on macOS and Ubuntu by running the playbook twice and requiring `changed=0` on the second run.
