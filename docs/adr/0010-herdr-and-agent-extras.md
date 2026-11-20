# 0010. Herdr, Herdr App mods and other agent extras

Status: Accepted, 2026-11-20

## Context

Herdr replaces tmux for agent work, on Unix and on native Windows. `agent-setup/` also holds a few files that are this repository's own rather than pinned upstream payloads: the Herdr App prefix mod, the open-in-editor Claude mod and the CLIProxyAPI edge config.

## Decision

### Herdr TUI (`.config/herdr/config.toml`, `windows/profile.ps1`)

- Key bindings follow tmux muscle memory: prefix `ctrl+space`, a tab is a window and a workspace is a session. On Windows the profile defines the familiar tmux shortcuts as functions backed by native Herdr.
- Herdr saves and restores layout, pane directories and focus by itself. `resume_agents_on_restore` resumes each supported agent's exact conversation through its Herdr integration.
- `pane_history` matches tmux-resurrect's capture-pane-contents behaviour after a server restart. Ordinary commands (dev servers, SSH, Neovim) still need a manual restart.

### Herdr App prefix mod (`agent-setup/herdr-app/local-mods/prefix/`)

- Prefix mode behaves as in the Herdr TUI: it shows a hint and takes the next key. There is no timeout, and no key reaches the terminal. Esc or any unmapped key cancels.
- `keys.js` maps the key after the prefix to `[command, args]`. It repeats `.config/herdr/config.toml` on top of the Herdr TUI's defaults. Keeping the two in sync: [yordan-kanchelov/dotfiles#28](https://github.com/yordan-kanchelov/dotfiles/issues/28).
- Shifted punctuation arrives as, for example, keystroke `shift-5` with `key_char` `%`. Only unmodified or Shift-only keys fall back to `key_char`, so `ctrl-x` cancels instead of matching `x`.

### open-in-editor Claude mod (`agent-setup/claude/mods/open-in-editor/`)

- Only lone-backtick code spans (`` `path` `` or `` `path:12` ``) become links. Spans with two or more backticks, fenced code and existing links (inline, reference, autolink) are left alone. They are blanked rather than removed before matching, so offsets still line up with the original text.
- Paths that were found are cached, because replies redraw on every scroll. Misses are not cached, since the file may appear later.

### CLIProxyAPI edge (`agent-setup/cliproxyapi/`)

- Caddy flushes each chunk as it arrives (`flush_interval -1`), because the API streams its replies.
- `docker-compose.port80.yml` publishes the gateway and its dashboard on `127.0.0.1:80`, routed by hostname. It needs the cliproxyapi-dashboard stack running first. The README documents the routes and the `docker compose` commands.

### Bundle plumbing (`agent-setup/.gitattributes`, `agent-setup/.gitignore`)

- `.gitattributes` keeps pinned payload bytes the same whatever the host's line-ending settings.
- `.gitignore` re-includes the required Claude payloads, which user-level agent-config ignores would otherwise hide.

## Consequences

When you change a Herdr key binding in `config.toml`, change `keys.js` too, until the duplication is removed.
