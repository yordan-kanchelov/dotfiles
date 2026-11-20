# 0005. Linux desktop tasks

Status: Accepted, 2026-11-20

## Context

`tasks/desktop.yml` installs Ulauncher, Ghostty, Flameshot, Bitwarden and draw.io. It also configures Cinnamon and xbindkeys. It targets Linux Mint and Ubuntu, runs only with `--tags desktop`, and no CI runner can run it, since it needs a graphical session.

## Decision

### Safety

- Before anything else, the file asserts a graphical session. Failing loudly is better than the alternative: every task skipping silently on an SSH run that asked for desktop by name.
- Read-only probes set `check_mode: false`. `--check` would skip them otherwise, and the `when` clauses below them read their results.

### Linux Mint

- Mint reports its own codename (`zena`), which no PPA publishes, and keeps the Ubuntu release it is based on in a separate file. Ulauncher's PPA has only Ubuntu series, so the repository task passes the Ubuntu base series explicitly instead of letting `apt_repository` default to `zena`.
- Ghostty's community `.deb` names Ubuntu assets by version, so Mint has to resolve `24.04` from `upstream-release`, never its own `22.3`.
- No runner ships Mint, and the official Mint container reports `ID=ubuntu`: it carries Mint's package base but not its identity. The Mint CI job therefore writes identity files taken from a real 22.3 install and asserts the release resolution against them (`.github/mint-release.yml`). That play asserts copies of the expressions in `tasks/desktop.yml`: [yordan-kanchelov/dotfiles#23](https://github.com/yordan-kanchelov/dotfiles/issues/23). It writes them after the apt install, so apt still sees the image's own identity. The packages themselves are already covered by `ubuntu-latest`, which shares the same noble base.

### Packages

- rofi: Cinnamon has no per-app window overview, so App Exposé uses rofi's window mode filtered to one WM_CLASS (`xbindkeys/app-expose`). wmctrl: `xbindkeys/tile` moves windows through EWMH messages. x11-utils: those scripts also call `xprop` and `xwininfo`, which cinnamon-core does not guarantee. xclip: tmux-yank rebinds copy-mode `y`/`Y` when the plugin loads, and with no clipboard tool on PATH it binds them to an "Error! tmux-yank dependencies not installed!" message.
- Ghostty entered the Ubuntu archive in 26.04. Older bases (Mint 22 sits on 24.04) have no apt candidate, and upstream ships no binaries, so the task falls back to the community `.deb` builds. Those name Ubuntu assets by version (`24.04`) and Debian assets by codename, and spell the version `.ppaN` where the tag says `-ppaN`.
- The apt candidate check does not test `'(none)' not in stdout`. `apt-cache policy` prints `Installed: (none)` for every package that is not installed, and this block runs only for those.
- Bitwarden and draw.io ship no apt repository, so both come from an upstream `.deb`. Both are gated on `package_facts`: their URLs always serve the current build, so an ungated task would download again on every run and reinstall whenever upstream moved. Bitwarden's `/download` endpoint redirects to the current versioned `.deb`. apt follows the redirect, and dpkg reads the file's contents rather than its name. draw.io publishes no "latest" asset URL, so the task resolves the release through the GitHub API (the same way the Ghostty `.deb` is resolved) and picks the asset by arch and `.deb` suffix, because the release also carries an `.AppImage` and an `.rpm`. Pinning and verification: [yordan-kanchelov/dotfiles#25](https://github.com/yordan-kanchelov/dotfiles/issues/25).
- Installed-package names: `bitwarden` in lowercase, because the desktop app is `@bitwarden/desktop`, electron-builder falls back to the product name, and fpm lowercases it. `draw.io` is the package.json name, not the `drawio` that the assets carry.

### Daemons

- Ulauncher and xbindkeys need a live daemon to be useful. Neither the autostart entry nor starting the daemon needs root.
- `pgrep -x` matches the process name exactly. `-f` would also match the play's own command line.
- The spawn discards its output and runs in the background, so it succeeds even when the daemon dies on startup. Only a `pgrep` afterwards proves it came up.
- xbindkeys restarts on every run. It reads `~/.xbindkeysrc` once at startup, so a leftover instance would keep serving stale bindings. `pkill` returns as soon as the signal is sent, not when the process is gone. A new instance spawned into the old one's live grabs comes up bound to nothing, so the task waits for the old process to exit.
- xbindkeys exits on a config it cannot parse, and its output is discarded, so spawning it proves nothing by itself. A retried `pgrep` confirms it.
- xbindkeys holds a grab on the mouse side buttons, which X numbers 8 and 9, because Cinnamon's keyboard panel accepts only key combinations. Under Wayland it starts, binds nothing and reports success, which is worse than not running at all, so the task requires X11.

### Cinnamon settings

- Hot corners: expo is Mission Control and scale is App Exposé. The corners change only while all of them are still off, so a layout tuned by hand survives a re-run.
- Cinnamon binds Alt+Space to the window menu, and the launcher never sees the key until that binding is cleared. The task removes just that element: clearing the whole list would also take out any other binding, such as the Menu key.
- Custom shortcuts live as `custom0`, `custom1`, and so on, under a relocatable schema, plus a list naming the live ones. The task reuses the slot that already holds the command, because re-runs would otherwise stack duplicates. It fills the slot before adding it to `custom-list`, because a failure in between would leave a blank shortcut that nothing can reclaim. The script runs under `set -e`, because otherwise a failed `gsettings set` would fall through to `echo changed` and report success while nothing was written.
- The screenshot shortcut is Shift+Super+4. Super sits where Cmd does, so under a Mac-style remapper it becomes Cmd+Shift+4, and before remapping it does no harm.

## Consequences

CI never runs these tasks. Changes to them need a manual `--tags desktop` run on a real Mint or Ubuntu desktop.
