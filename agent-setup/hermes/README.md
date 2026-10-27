# Set up Hermes

Read the [shared guide](../universal/README.md). Hermes uses the same 25 Agent Skills and the standalone `unslop` skill. Its manifest adapter adds only the `$schema` field required by the installed native validator. Skill bodies and shared checklists stay unchanged.

## Stage the files

Run from the repository root with a new output directory:

```sh
hermes_stage="$HOME/.local/share/agent-setup/hermes"
python3 agent-setup/refactor.py --stage hermes --output "$hermes_stage"
```

The result contains `plugins/agent-skills/` and `skills/unslop/`. Keep the Agent Skills package intact so its root references resolve. Use the installed `hermes plugins --help` and native install/enable commands for the plugin. Place the standalone skill under `${HERMES_HOME:-$HOME/.hermes}/skills/unslop/` as ordinary files. Preserve existing skills, models, providers, permissions, and hooks.

## Review before activation

The installed guard flags quoted hostile-input examples and shell-test/documentation snippets in revision `aeac41d4d005999432bb7312f7ff06383a91d59d`. Review the exact local package and native guard report. Keep the guard enabled. A reviewed package-specific activation does not approve helper execution, hooks, later revisions, or different payload hashes.

The user approved native activation of the existing full-source copy with fingerprint `5a683d143863f9da39b18af598390d4d0b5dc2e73630ee680b26d319ae0de31d`. This approval does not transfer to a newly staged package. Current migration state is recorded in [inventory.json](inventory.json).

## Verify

Use the native plugin list and skills list to confirm Agent Skills activation, all 25 names, and standalone `unslop`. Confirm the shared references open from a skill directory and that no Pstack routing remains. Start a fresh Hermes session after profile changes.
