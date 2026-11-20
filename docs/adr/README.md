# Architecture decision records

The code in this repository has no comments ([0001](0001-no-code-comments.md)). Rationale that is not obvious from the code lives here, grouped by area. When you change an area, update its record in the same change.

| ADR | Area | Covers |
| --- | --- | --- |
| [0001](0001-no-code-comments.md) | No code comments | The ban, the ratchet in `scripts/check-comments.py`, what counts as a directive |
| [0002](0002-package-sources.md) | Package sources | Homebrew and apt split, ollama, tap formulae, macOS default apps, fonts |
| [0003](0003-playbook-and-installer-conventions.md) | Playbook and installers | Facts, symlinks, secrets, sudo, ordering, Omarchy layering, shell script portability |
| [0004](0004-debian-host.md) | Debian host | Login shell, Linuxbrew prefix, ollama user unit |
| [0005](0005-linux-desktop.md) | Linux desktop | Mint release handling, upstream `.deb`s, daemons, Cinnamon settings |
| [0006](0006-x11-window-management.md) | X11 window management | Mouse buttons, Mission Control, App Exposé, tiling geometry |
| [0007](0007-shell-configuration.md) | Shell configuration | zsh and Omarchy Bash, completion, fzf, agent wrappers |
| [0008](0008-tmux.md) | tmux | Plugin order, bindings, Omarchy layer |
| [0009](0009-neovim.md) | Neovim | Clipboard, langmap, lazy.nvim versions |
| [0010](0010-herdr-and-agent-extras.md) | Herdr and agent extras | Herdr TUI, Herdr App prefix mod, open-in-editor mod, CLIProxyAPI edge |
| [0011](0011-windows-setup.md) | Windows and WSL | PowerShell 5.1 compatibility, PATH, data safety, WSL install |
| [0012](0012-tests-and-ci.md) | Tests and CI | Isolation rules for regression scripts, workflow choices |

## Format

Each record has a status line, Context, Decision and Consequences. A record that covers an area lists one decision per bullet, naming the file it applies to. To reverse a decision, change its bullet and say why, or mark the whole record `Superseded by NNNN`.
