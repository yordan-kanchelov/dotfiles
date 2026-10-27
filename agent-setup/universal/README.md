# Shared skills and defaults

Shared plugin payloads live under `plugins/`; standalone `unslop` lives under `skills/unslop/`. Each harness supplies its native manifests separately. Keep each package intact so relative references, agent prompts, and licenses remain available.

| Payload | Version | Skills | Used by |
| --- | --- | --- | --- |
| `plugins/agent-skills/` | 0.6.13 | 25 | Claude, Codex, and Hermes |
| `plugins/mattpocock-skills/` | 1.3.1 | 27 | Claude and Codex |
| `plugins/ponytail/` | 5.3.2 | 6 | Claude and Codex |
| `skills/unslop/` | pinned from 1.16.0 | 1 | Claude, Codex, and Hermes |

[Agent Skills](https://github.com/addyosmani/agent-skills) replaces Open Pstack. It is pinned to `aeac41d4d005999432bb7312f7ff06383a91d59d`. Its root `references/` directory is retained because per-skill copies alone lose shared checklists. Native manifests do not wire the standalone SessionStart helper. Keep the `using-agent-skills` body out of always-on instructions.

[skills.md](skills.md) lists bundled names, including harness additions. [sources.json](sources.json) records upstream commits, download hashes, retained payloads, and integrity hashes. Third-party skill bodies remain unchanged. Standalone `unslop` retains its MIT license and source provenance; no Pstack plugin or router is retained.

## Prepare the tools

Install the chosen agent CLI, Python 3.9 or later, Node.js, Git, and ripgrep. Python checks and stages this bundle. Node runs Ponytail's existing hooks. Check individual workflows for additional prerequisites.

Keep existing model choices, native permission boundaries, and hook trust. Workflow instructions do not authorize commits, external agent launches, or deployments on their own.

## Install shared instructions

Follow your harness guide to place [engineering-defaults.md](engineering-defaults.md) beside its global instructions file. Merge the harness template into existing instructions rather than replacing unrelated guidance. Remove obsolete Pstack routing when replacing that package.

Ponytail defaults to full mode. Its task ledger and optional webhook remain destination settings; this bundle contains no user configuration or data.

## Get Herdr from its CLI

Herdr owns its skill and agent integrations. Inspect the installed CLI with:

```sh
herdr --version
herdr --skill
herdr integration install --help
```

Use `herdr --skill` output to create the harness's loose `herdr` skill. Use `herdr integration install <target>` for managed hooks, after checking the destination profile. Regenerate from the installed CLI after updates instead of maintaining a second skill copy here.
