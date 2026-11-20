# 0007. Interactive shell configuration

Status: Accepted, 2026-11-20

## Context

macOS and Debian use zsh (`zsh/.zprofile`, `.zshrc`, `.zshrc.core`). Omarchy keeps its own Bash and gets a personal layer on top (`omarchy/bash/personal.bash`). The same files must work after a full install, after a configs-only run (`--skip-tags packages`), and on machines where installers have appended lines of their own.

## Decision

### File roles

- `.zprofile` runs once per login, before `.zshrc`. It holds Homebrew, PATH, environment variables, fnm and the `~/.secrets` source.
- `.zshrc` sources `.zshrc.core` and is where tools append their own lines. `.zshrc.core` holds plugins, prompt, aliases and functions.
- `personal.bash` is sourced from a managed block at the end of `~/.bashrc`. Omarchy's rc (starship, fzf, zoxide, mise, aliases) has already run by then, so anything in the file wins. Omarchy owns `ls`, `c` and the prompt.

### Robustness

- Every tool init is guarded with `command -v`. After a configs-only run, a missing tool must not print an error in every new shell.
- `ls` is aliased to eza only when eza is present. An unconditional alias would leave no working `ls`.
- The `cat` wrapper acts like plain cat when its output is piped or redirected, which avoids bat's pager and colour escapes. Without bat, every branch falls back to cat. In Bash the function is not exported, so scripts never see it. It uses glow for markdown and viu for images. viu is optional and is not in `brew_packages.yml`, so the wrapper says it is missing instead of printing "command not found".
- `.zprofile` probes the Homebrew prefixes in order: Apple Silicon, Intel Mac, then Linuxbrew.
- `PNPM_HOME` follows pnpm's per-platform default. Hardcoding the macOS default put a nonexistent `~/Library` path on Linux's PATH.
- Lines that installers appended on macOS with an absolute `/Users` path are rewritten relative to `$HOME` and guarded on the directory existing, so each machine picks up only what it has. They use `if` blocks, not `[ -d ] &&`: a bare `&&` chain as the file's last statement makes `.zshrc` return 1 when the directory is absent, and starship then draws the first prompt of every shell as an error.
- `FORCE_HYPERLINK` is set inside Herdr. Herdr passes OSC 8 links through, but supports-hyperlinks does not recognise its `TERM_PROGRAM`, so Claude Code would print each link's URL after the link.

### Completion and key bindings (zsh)

- zsh history stays on, although Atuin keeps its own database: zsh history feeds zsh-autosuggestions.
- `compinit` rebuilds the dump only when it is more than 24 hours old. The `(#q...)` glob qualifier expands only under `extendedglob`; without it the test is a literal non-empty string, always true, and every shell start pays for a full rebuild. An anonymous function keeps the `setopt` local. `compinit -u` is a known workaround: [yordan-kanchelov/dotfiles#27](https://github.com/yordan-kanchelov/dotfiles/issues/27).
- fzf and Atuin initialise after zsh-vi-mode has finished recreating its keymaps, through `zvm_after_init_commands`, because otherwise their bindings get overwritten. The array form lets several hooks compose. Without the plugin they initialise directly.
- `fzf --zsh` arrived in fzf 0.48. On older builds it aborts startup with "unknown option: --zsh" and silently loses Ctrl-T and Alt-C, so the shell falls back to the integration scripts, which live in a different place for each layout (Debian's doc examples, Homebrew's opt prefix). It uses `HOMEBREW_PREFIX` from `.zprofile` and calls `brew --prefix` only when a non-login shell left it unset, and only after the flag has already failed. Whether the fallback is still needed: [yordan-kanchelov/dotfiles#26](https://github.com/yordan-kanchelov/dotfiles/issues/26).
- `reload` uses `exec zsh`. Sourcing the config again would initialise the plugins twice.

### Bash on Omarchy

- Omarchy's rc binds its inputrc in emacs mode. `personal.bash` binds it again into vi-insert, so TAB completion and prefix Up/Down history keep working after the switch to vi mode.
- Atuin initialises last, because it has to bind Ctrl-R and Up after fzf and the vi-mode inputrc.
- `clear` also drops tmux scrollback, so an old error cannot be scrolled back into view.
- `clean_project` runs its body in a subshell. Job control is off in subshells, so the background `rm` jobs do not print `[1] PID` and `Done` lines (zsh used `setopt no_monitor no_notify` for the same effect).

### Agent wrappers

- `claude` pins a session id per tmux pane, so tmux-resurrect restores each pane into its own conversation. A bare `claude` creates a new id. Resurrect types `claude --session-id <uuid>` again. If that transcript already exists, the wrapper resumes it, because claude itself resumes only through `--resume`, not `--session-id`. Anything else passes straight through (`c`/`-c`, `-r`, `-p`, and subcommands such as `claude mcp`).
- The CLIProxyAPI aliases route through the local stack in `agent-setup/cliproxyapi`. Plain `claude`, `codex`, `pi` and `hermes` stay direct. The client key is read from the local stack's config and never stored in the dotfiles. `.localhost` resolves to loopback without a hosts entry, and port 80 comes from `docker-compose.port80.yml`. Override the endpoint with `CPA_URL`.
- Claude Code on the GPT model receives its environment through `--settings`, so it takes precedence over the `env` in the user's `settings.json`.

## Consequences

When you add a tool init, add the `command -v` guard too. A change to the `claude` wrapper or the `cat` wrapper has to be made in both `.zshrc.core` and `personal.bash`.
