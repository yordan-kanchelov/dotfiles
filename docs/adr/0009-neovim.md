# 0009. Neovim configuration

Status: Accepted, 2026-11-20

## Context

`.config/nvim` started from the LazyVim starter. LazyVim loads `lua/config/options.lua` before lazy.nvim starts and loads `autocmds.lua` and `keymaps.lua` on `VeryLazy`. Its defaults are documented upstream in `lazyvim/config/`.

## Decision

- Deletes and changes stay off the system clipboard. LazyVim defaults `clipboard` to `unnamedplus`, which overwrites the OS clipboard on every `d`/`c`/`x`. `options.lua` clears that, and a `TextYankPost` autocmd in `autocmds.lua` mirrors only yanks to `+`. `TextYankPost` also fires for deletes and changes, so the autocmd checks the operator.
- `langmap` maps the Bulgarian Traditional Phonetic layout, so Normal mode commands work without switching the keyboard layout.
- lazy.nvim uses `version = false` (latest git commit), as LazyVim recommends: many plugins that support versioning have outdated releases that can break Neovim. Custom plugins load at startup (`lazy = false`). The update checker runs without notifications.

## Consequences

Upstream LazyVim changes to clipboard handling need checking against this override.
