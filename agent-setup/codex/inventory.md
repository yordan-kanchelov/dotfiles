# Codex on macOS

Refreshed 2026-10-27 with Codex CLI 0.164.0. [inventory.json](inventory.json) records native listings, exact local roots, selected settings, and separately identified remote caches. Shared recreation and verification guidance is in the [setup README](README.md).

## Installed local plugins

Native `codex plugin list --json` reports these local installations in this execution context:

<!-- BEGIN plugins -->
| Plugin | Version | User state | Skill files / candidates | Installed revision |
| --- | --- | --- | --- | --- |
| `agent-skills@agent-skills` | 0.6.13 | enabled | 25 / 25 | `aeac41d4d005999432bb7312f7ff06383a91d59d` |
| `mattpocock-extras@engineering-adaptations` | 1.3.1-codex.1 | enabled | 9 / 9 | not recorded for payload |
| `mattpocock-skills@mattpocock` | 1.3.1 | enabled | 38 / 27 | not recorded for payload |
| `ponytail@ponytail` | 5.3.2 | enabled | 12 / 6 | not recorded for payload |
<!-- END plugins -->

Agent Skills 0.6.13 is installed and enabled from the pinned local source. Both Pstack plugins, their cache/source registrations, and the Pstack-only marketplace were removed.

The configured marketplaces are `agent-skills`, `mattpocock`, `ponytail`, and local `engineering-adaptations`. The shared engineering-adaptations catalog now contains only Matt extras. Native listing also returns `personal` and `openai-curated` catalog roots.

## Account-managed remote caches

The following exact payload directories exist under `~/.codex/plugins/cache/openai-curated-remote/`. The native listing above omits them in this context, so their installed and enabled state is not inferred from cache presence.

<!-- BEGIN cached-remote -->
| Plugin | Version | Skill files / candidates |
| --- | --- | --- |
| `cloud-environment@openai-curated-remote` | 0.1.2 | 1 / 1 |
| `github@openai-curated-remote` | 0.1.12-5f7cd798dc99 | 0 / 0 |
| `openai-templates@openai-curated-remote` | 0.1.1 | 20 / 20 |
| `pages@openai-curated-remote` | 0.1.26 | 4 / 4 |
| `plugin-management@openai-curated-remote` | 0.1.0 | 1 / 1 |
| `sites@openai-curated-remote` | 1.1.2 | 2 / 2 |
| `work-pets@openai-curated-remote` | 0.1.6 | 3 / 3 |
<!-- END cached-remote -->

Their skill files are recorded separately from installed local-plugin files. Remote entitlements, app authorization, and source accessibility were not tested.

## Skills and guidance

`~/.codex/AGENTS.md` carries no skill routing; Matt Pocock, Ponytail, and Agent Skills use native discovery without a preloaded meta-router or new startup hook. Multi-agent support and current model settings are unchanged.

The loose skills are `blender-skill`, the three namespaced Epic Unreal ports, `herdr`, and standalone `unslop`. The five system skills include manual-only `review-agent`; installed availability does not establish session exposure. These machine-managed files are recorded in the inventory and excluded from the portable bundle.

Matt extras retains nine manual-only skills in a local adaptation. A pinned adapter patch recipe is unresolved. No `INSTALL-PROVENANCE.json` or `UPSTREAM.md` exists beside the current Blender or Epic copies. Herdr's loose skill has no pinned revision in the inspected metadata.

## Settings, hooks, and MCP

The current selected user settings are:

```toml
approval_policy = "on-request"
approvals_reviewer = "auto_review"
sandbox_mode = "workspace-write"
model = "gpt-6.1-sol"
model_reasoning_effort = "high"

[features]
hooks = true
multi_agent = true
```

These preserve Smart approval. Launch context and higher-priority policy can affect effective settings.

The user SessionStart hook invokes `~/.codex/herdr-agent-state.sh` using Bash, timeout 10 seconds, integration version 10. It requires Python 3 and Herdr's pane/socket context. Ponytail's selected Codex manifest declares three Node hooks with 15-second timeouts. Persisted hook-trust hashes and plugin user data were not read or copied.

Two stdio MCP servers are configured. `sync-worktrees` uses the local `sync-worktrees-mcp` executable. `chrome-devtools` uses local `npx` with `-y chrome-devtools-mcp@latest --no-usage-statistics`; this is an unpinned package declaration, distinct from Claude's pinned plugin. Neither server was launched or contacted.
