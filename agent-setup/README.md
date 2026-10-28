# Set up coding agents

For adding skills or maintaining this bundle, follow [AGENTS.md](AGENTS.md).

For an agent preparing a machine, start with [universal/](universal/README.md), then follow [claude/](claude/README.md), [codex/](codex/README.md), [hermes/](hermes/README.md), or [pi/](pi/README.md). This folder contains the selected skills, their support files, native plugin manifests, and setup instructions.

1. Read the shared guide and the guide for your harness. Inspect the destination's installed plugins, instructions, settings, and CLI help before changing them.
2. Run `python3 scripts/agent-setup-bundle.py` from the repository root to verify the bundled sources and generated references.
3. Stage the plugins and standalone skills using the command in your harness guide. Staging combines shared payloads with native manifests in a new directory; it does not install anything.
4. Register the staged marketplaces, install missing plugins, and merge the harness settings into the destination profile. Preserve unrelated settings and existing permissions.
5. Install Sloptrim and standalone `unslop` as described in the harness guide. Get Herdr's skill from the installed CLI and configure its integration for the chosen harness. Verify native plugin listings and start a fresh agent session.

Use ordinary files and native plugin management. Keep credentials, account connections, transcripts, project trust, and hook-trust records on the destination. Model choices and external provider setup remain user decisions.

## Folder layout

```text
agent-setup/
  universal/                 Shared plugin payloads and source pins
    plugins/                 Agent Skills, Matt Pocock, and Ponytail
    skills/                  Standalone unslop and Sloptrim packages
    sources.json             Revisions and payload integrity hashes
    skills.md                Generated index of bundled skills
  claude/                    Claude setup, manifests, hooks, and Chrome DevTools
    README.md                Setup steps
    CLAUDE.md                Global prose instructions template
    inventory.json           Sanitized machine inventory
    inventory.md             Machine reference
  codex/                     Codex setup, manifests, and Matt extras
    README.md                Setup steps
    AGENTS.md                Global prose instructions template
    config.toml              Settings to merge
    inventory.json           Sanitized machine inventory
    inventory.md             Machine reference
  hermes/                    Hermes plugin setup and manifest adaptation
  pi/                        Pi Sloptrim setup
scripts/
  agent-setup-bundle.py       Verify, regenerate references, or stage marketplaces
  test-agent-setup-bundle.py  Bundle and staging checks
```

Blender and Unreal are excluded from this setup. Herdr supplies its own skill through `herdr --skill`; no separate Herdr payload is maintained here. Account-managed plugins, synced skills, and Codex system skills remain managed by their hosts.

## Maintain this bundle

Source revisions, download hashes, and selected payload hashes are in each folder's `sources.json`. Third-party skill bodies are kept unchanged. After updating a source or a machine inventory, update its manifest and the affected setup prose, then run:

```sh
python3 scripts/agent-setup-bundle.py --write
python3 scripts/agent-setup-bundle.py
python3 scripts/test-agent-setup-bundle.py
```

The default command checks without writes. `--write` regenerates inventory counts, reference tables, and the bundled skill index. `--stage` assembles ordinary plugin directories without running their code or changing a profile.

## Machine inventory

The inventories record this Mac on 2026-10-27, including installed components outside the selected bundle. They are reference data, not settings to import.

<!-- BEGIN overview -->
| Harness | CLI | Installed / enabled / disabled plugins | Skill files | Enabled plugin candidates |
| --- | --- | --- | --- | --- |
| Claude Code | 2.1.311 | 5 / 4 / 1 | 114 | 65 |
| Codex | 0.164.0 | 4 / 4 / 0 | 126 | 67 |
<!-- END overview -->
