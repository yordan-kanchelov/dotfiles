# Set up Hermes

Read the [shared guide](../universal/README.md). Hermes uses the same 25 Agent Skills and the standalone `unslop` and Sloptrim skills. Its manifest adapter adds only the `$schema` field required by the installed native validator. Skill bodies and shared checklists stay unchanged.

## Stage the files

Run from the repository root with a new output directory:

```sh
hermes_stage="$HOME/.local/share/agent-setup/hermes"
python3 scripts/agent-setup-bundle.py --stage hermes --output "$hermes_stage"
```

The result contains `plugins/agent-skills/`, `skills/unslop/`, and `skills/sloptrim/`. Keep the Agent Skills package intact so its root references resolve. Use the installed `hermes plugins --help` and native install/enable commands for the plugin. Place the standalone skill under `${HERMES_HOME:-$HOME/.hermes}/skills/unslop/` as ordinary files. Preserve existing skills, models, providers, permissions, and hooks.

## Herdr

With Herdr installed, run from the repository root:

```sh
bash scripts/install-herdr.sh hermes
```

The script refreshes the CLI-owned skill and integration while preserving unrelated settings. Follow the [shared Herdr guide](../universal/README.md#herdr) after upgrades.

## Install Sloptrim

Copy staged `skills/sloptrim/` into `${HERMES_HOME:-$HOME/.hermes}/skills/sloptrim/` as ordinary files. Keep the detector, references, and license files together. Merge all rules from [Codex's AGENTS.md](../codex/AGENTS.md) into `${HERMES_HOME:-$HOME/.hermes}/SOUL.md`. Preserve existing guidance. Restart Hermes and confirm native skill discovery. Run `python3 "$HOME/.hermes/skills/sloptrim/scripts/detect.py" README.md`, adjusting for `HERMES_HOME`, and check `_metrics.ai_tell_score`. This is a portable skill install; Claude hooks are not registered.

## Review before activation

The installed guard flags quoted hostile-input examples and shell-test/documentation snippets in revision `aeac41d4d005999432bb7312f7ff06383a91d59d`. Review the exact local package and native guard report. Keep the guard enabled. A reviewed package-specific activation does not approve helper execution, hooks, later revisions, or different payload hashes.

The user approved native activation of the existing full-source copy with fingerprint `5a683d143863f9da39b18af598390d4d0b5dc2e73630ee680b26d319ae0de31d`. This approval does not transfer to a newly staged package. Current migration state is recorded in [inventory.json](inventory.json).

## Verify

Use the native plugin list and skills list to confirm Agent Skills activation, all 25 names, and standalone `unslop`. Confirm the shared references open from a skill directory and that no Pstack routing remains. Start a fresh Hermes session after profile changes.
