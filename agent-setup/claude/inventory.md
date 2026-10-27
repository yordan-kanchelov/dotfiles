# Claude Code on macOS

Refreshed 2026-10-27 with Claude Code 2.1.311. [inventory.json](inventory.json) records the current registry, skill metadata, hashes, and selected nonsecret settings. Shared recreation and verification guidance is in the [setup README](README.md).

## Installed plugins

`~/.claude/plugins/installed_plugins.json` selects the exact payload roots. Native `claude plugin list --json` supplies user-enabled state. Cached directories alone do not establish installation.

<!-- BEGIN plugins -->
| Plugin | Version | User state | Skill files / candidates | Installed revision |
| --- | --- | --- | --- | --- |
| `agent-skills@addy-agent-skills` | 0.6.13 | enabled | 25 / 25 | `aeac41d4d005999432bb7312f7ff06383a91d59d` |
| `chrome-devtools-mcp@reviewed-agent-pins` | 1.12.0 | enabled | 7 / 7 | `ada7963246c0c91eae185125a57aecd13cbe0376` |
| `mattpocock-skills@reviewed-agent-pins` | 1.3.1 | enabled | 38 / 27 | `5beb35b040e3de97e54fa9e386d7e42d15c295c2` |
| `ponytail@ponytail` | 5.3.2 | enabled | 12 / 6 | `09c434ab73ca43761c5d8b0c5d341926c2fba710` |
| `unreal-engine-skills-for-claude-code@claude-plugins-official` | 3.1.1 | disabled | 3 / 3 | `a6aa73ada02a9fb1f5415bec491f9942c519b297` |
<!-- END plugins -->

The native list reports `projectEnabled=false` for every plugin in this repository while preserving the user states above. This is a scoped listing observation, not evidence that enabled plugins are disabled globally. Runtime loading was not tested. Chrome DevTools still reports `dependencies-refused` because installation does not apply its package overrides.

## Marketplaces and sources

Four marketplaces are configured in `~/.claude/plugins/known_marketplaces.json`:

- `claude-plugins-official` uses `anthropics/claude-plugins-official`; the installed Unreal plugin comes from this catalog.
- `ponytail` uses `DietrichGebert/ponytail`.
- `addy-agent-skills` is a local pinned catalog for `agent-skills` 0.6.13.
- `reviewed-agent-pins` is a local catalog that pins Matt Pocock skills and Chrome DevTools at their installed revisions above.

The reviewed-agent-pins catalog lives under `~/.local/state/agent-setup-alignment/`; the new Addy catalog lives under `~/.claude/local-marketplaces/`. Their sanitized exact paths and public source declarations are recorded in JSON. Catalog location is local installation state, not a portable upstream source.

## Skills, agents, and guidance

`~/.claude/CLAUDE.md` preserves Matt Pocock and Ponytail defaults. Pstack routing was removed. Agent Skills is enabled through native discovery with 25 skills, nine command wrappers, four agent prompts, and no registered hooks.

The loose skills are `blender-skill`, `herdr`, and standalone `unslop`. Blender's `UPSTREAM.md` records v0.31.0 at `39547d9e118451891c3ff68e087e20c5bde1599c` with a local macOS note. Its historical Windows animation failure is provenance, not a Mac runtime test. Herdr has no pinned skill revision in the inspected files.

The synced directory contains two bundles with the same 13 names, so the inventory retains 26 physical files. This account-managed content is excluded from the portable bundle. Matt's undeclared experimental files and Ponytail's alternate-host duplicates remain supporting files in JSON.

## Settings, hooks, and MCP

User settings set `permissions.defaultMode` to `auto`. No explicit model is set there.

- Herdr's user SessionStart hook invokes `hooks/herdr-agent-state.sh` with Bash, timeout 10 seconds, integration version 11. It requires Python 3 and Herdr's pane/socket context.
- Ponytail declares SessionStart, SubagentStart, and UserPromptSubmit Node hooks, each with a 15-second timeout, plus the task-board module.
- The disabled Unreal plugin declares its Bash context hook. Its declaration does not imply execution while disabled.

The user MCP configuration contains `sync-worktrees`. The enabled Chrome DevTools plugin declares `npx chrome-devtools-mcp@1.12.0`. No server was started or contacted; private connection details and plugin user configuration were excluded.
