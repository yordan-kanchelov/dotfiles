# Shared skills

Shared plugin payloads live under `plugins/`; standalone `unslop` and Sloptrim live under `skills/`. Each harness supplies its native manifests separately. Keep each package intact so relative references, agent prompts, and licenses remain available.

| Payload | Version | Skills | Used by |
| --- | --- | --- | --- |
| `plugins/agent-skills/` | 0.6.13 | 25 | Claude, Codex, and Hermes |
| `plugins/mattpocock-skills/` | 1.3.1 | 27 | Claude and Codex |
| `plugins/ponytail/` | 5.3.2 | 6 | Claude and Codex |
| `skills/unslop/` | pinned from 1.16.0 | 1 | Claude, Codex, Hermes, and Pi |
| `skills/sloptrim/` | 0.9.6 | 1 | Claude, Codex, Hermes, and Pi |

[Agent Skills](https://github.com/addyosmani/agent-skills) replaces Open Pstack. It is pinned to `aeac41d4d005999432bb7312f7ff06383a91d59d`. Its root `references/` directory is retained because per-skill copies alone lose shared checklists. Native manifests do not wire the standalone SessionStart helper. Keep the `using-agent-skills` body out of always-on instructions.

[skills.md](skills.md) lists bundled names, including harness additions. [sources.json](sources.json) records upstream commits, download hashes, retained payloads, and integrity hashes. Third-party skill bodies remain unchanged. Standalone `unslop` retains its MIT license and source provenance; no Pstack plugin or router is retained.

## Prepare the tools

Install the chosen agent CLI, Python 3.9 or later, Node.js, Git, and ripgrep. Python checks and stages this bundle. Node runs Ponytail's existing hooks. Check individual workflows for additional prerequisites.

Keep existing model choices, native permission boundaries, and hook trust. Workflow instructions do not authorize commits, external agent launches, or deployments on their own.

## Global instructions

Merge the global rules from the harness guide into the destination's instructions. Claude and Codex templates include both prose and context rules. Preserve other user guidance. Skills use native discovery; keep obsolete Pstack routing out of the profile.

Ponytail defaults to full mode. Its task ledger and optional webhook remain destination settings; this bundle contains no user configuration or data.

## Sloptrim

[Sloptrim](https://github.com/seyedehsanhadi/sloptrim) is pinned at `9b3e2efe6ab64d9b60c214ad1213b2b30bbddb27` (0.9.6). The package keeps the upstream skill, Python detector, pattern reference, Claude hooks and marketplace, command wrapper, Cursor rule, and license files unchanged. Tests, recordings, images, and research tools are omitted. Source and payload hashes are in `sources.json`.

Every harness stages it at `skills/sloptrim/`. Claude registers that directory as a native marketplace. Codex, Hermes, and Pi copy it into their loose skill directories. Those loose installs use the skill and global prose rule to run the detector; they do not register Claude hooks. The detector accepts a file path:

```sh
python3 /absolute/path/to/sloptrim/scripts/detect.py README.md
```

Read `_metrics.ai_tell_score` and the flagged spans. Revise only prose that needs it, preserve facts and code, and score the saved file again. When writing docs, READMEs, or skills, pair the `unslop` skill with Sloptrim. Use `unslop` to revise prose, then score the saved files with Sloptrim before committing or sharing them. Instruction files and skills need this explicit check because the Claude save hook exempts them. Keep third-party skill bodies unchanged.

## Get Herdr from its CLI

Herdr owns its skill and agent integrations. Inspect the installed CLI with:

```sh
herdr --version
herdr --skill
herdr integration install --help
```

Use `herdr --skill` output to create the harness's loose `herdr` skill. Use `herdr integration install <target>` for managed hooks, after checking the destination profile. Regenerate from the installed CLI after updates instead of maintaining a second skill copy here.
