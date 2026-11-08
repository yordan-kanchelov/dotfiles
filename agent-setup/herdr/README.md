# Herdr TUI

The `herdr` terminal client reads [`.config/herdr/config.toml`](../../.config/herdr/config.toml). That file is the single source for its prefix, keybindings, UI and session settings. Herdr App is separate; see [../herdr-app/](../herdr-app/README.md).

## Apply on a machine

- macOS and Linux: `setup.yml` symlinks `~/.config/herdr/config.toml` to the repo file (tag `symlinks`). Run `ansible-playbook setup.yml --tags symlinks`.
- Windows: [`bootstrap.ps1`](../../bootstrap.ps1) copies it to `%APPDATA%\herdr\config.toml`.
- Manual: back up any existing `~/.config/herdr/config.toml`, then run `ln -s "$PWD/.config/herdr/config.toml" ~/.config/herdr/config.toml` from the repo root.

Reload a running server with prefix, then `shift+r`, or restart Herdr. Skills and agent integrations are installed separately by `scripts/install-herdr.sh`; see the main [README](../../README.md).

## Keys

The prefix is `ctrl+space`, the same as tmux in [`tmux/.tmux.conf`](../../tmux/.tmux.conf). The bindings follow tmux habits, with a tab standing in for a tmux window and a workspace for a session.

| After prefix | Action |
| --- | --- |
| `p` | Toggle sidebar |
| `b` | Previous tab |
| `,` | Rename tab |
| `&` | Close tab |
| `v` or `%` | Split vertically |
| `-` or `"` | Split horizontally |
| `$` | Rename workspace |
| `d` | Detach |
| `;` | Last pane |
| `(` / `)` | Previous / next workspace |
| `s` | Go to |
| `shift+s` | Settings |

Every other key keeps the Herdr default. Edit the TOML, not this table, when a binding changes.
