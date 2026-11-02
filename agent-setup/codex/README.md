# Set up Codex

Read the [shared setup](../universal/README.md) first. This folder adds native manifests for the shared plugins and the local, manual-only Matt extras adapter. [inventory.md](inventory.md) records the current Mac; [sources.json](sources.json) records the adapter's provenance and hashes.

## Stage and install plugins

Run from the repository root. Choose a new, stable staging directory because native marketplace registrations refer to it:

```sh
codex_catalogs="$HOME/.local/share/agent-setup/codex"
python3 scripts/agent-setup-bundle.py --stage codex --output "$codex_catalogs"
```

The command refuses an existing output directory. It assembles four marketplaces with ordinary copies of shared payloads and Codex manifests. Matt's upstream Claude manifest is retained as the compatibility manifest used by the installed Codex package.

On a new profile, register and install them:

```sh
codex plugin marketplace add "$codex_catalogs/agent-skills"
codex plugin marketplace add "$codex_catalogs/mattpocock"
codex plugin marketplace add "$codex_catalogs/ponytail"
codex plugin marketplace add "$codex_catalogs/engineering-adaptations"
codex plugin add agent-skills@agent-skills
codex plugin add mattpocock-skills@mattpocock
codex plugin add ponytail@ponytail
codex plugin add mattpocock-extras@engineering-adaptations
```

On an existing profile, keep matching installs and inspect differences before replacing a marketplace. Remove both Pstack installations and their routing when replacing them. Preserve the shared engineering-adaptations marketplace for Matt extras. The Matt extras payload is an ordinary copy of the installed local adapter, with its license and manual-only policies. Its original patch recipe remains unresolved.

## Merge profile settings and instructions

Resolve the profile with `codex_config_home="${CODEX_HOME:-$HOME/.codex}"`. Merge all rules from the [AGENTS.md](AGENTS.md) template into `$codex_config_home/AGENTS.md`. Remove earlier skill routing, such as the `installed-engineering-skills` block, from that file and delete `$codex_config_home/engineering-defaults.md` if present.

Merge [config.toml](config.toml) into `$codex_config_home/config.toml`. Keep existing model choices and unrelated tables. The snippet preserves on-request approval, automatic approval review, workspace-write, hooks, and multi-agent support. Retain native hook trust; accept source changes only after reviewing the selected hooks.

Agent Skills uses native Codex discovery. Its Claude slash-command wrappers and standalone startup helper are not installed for Codex. Keep the meta-skill body out of always-on instructions.

## Install standalone unslop

Copy `universal/skills/unslop/` (also staged at `skills/unslop/`) into `$codex_config_home/skills/unslop/` using ordinary files. Keep its license and provenance beside SKILL.md. It is a loose skill, so no plugin registration or startup hook is needed.

## Install Sloptrim

Copy staged `skills/sloptrim/` into `$codex_config_home/skills/sloptrim/` as ordinary files. Keep its detector, references, hooks, and license files together. Use the loose skill for prose review and the global rule from [AGENTS.md](AGENTS.md) to check docs, READMEs, and skills before sharing them. This install uses Codex skill discovery and direct detector calls; Claude hooks are not registered.

Start a fresh task to discover the skill. Run `python3 "$codex_config_home/skills/sloptrim/scripts/detect.py" README.md` and confirm a numeric `_metrics.ai_tell_score`.

## Add Herdr

With Herdr installed, run from the repository root:

```sh
bash scripts/install-herdr.sh codex
```

The script refreshes the CLI-owned skill and integration while preserving unrelated settings. Follow the [shared Herdr guide](../universal/README.md#herdr) after upgrades.

## Verify

Run `codex plugin list --json` and `codex plugin marketplace list --json`. Compare enabled states and payload manifest versions. A local install can use `local` as its cache version; check the manifest and source hashes instead of relying on that directory name. See [Codex's marketplace format](https://developers.openai.com/plugins/build/plugins). The commands above were checked against CLI 0.164.0 help.

Start a fresh task and confirm that AGENTS guidance and skills are available.

Account-managed plugins and bundled system skills remain managed by Codex and its account. They are not copied into this setup. Hook execution and external providers require their own runtime checks.
