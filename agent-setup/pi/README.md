# Set up Sloptrim for Pi

Read the [shared guide](../universal/README.md#sloptrim). Install Pi and Python 3.9 or later, then stage Sloptrim and Unslop from the repository root into a new directory:

```sh
pi_stage="$HOME/.local/share/agent-setup/pi"
python3 agent-setup/refactor.py --stage pi --output "$pi_stage"
```

Copy `$pi_stage/skills/sloptrim/` into `${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/skills/sloptrim/` as ordinary files. Preserve existing packages and settings. Keep the detector, pattern reference, and license files together. Also copy `$pi_stage/skills/unslop/` into the same profile's `skills/unslop/` directory. Use `unslop` to revise prose before checking it with Sloptrim. Pi loads these as skills; Claude hooks are not registered.

Merge the prose rule from [Codex's AGENTS.md](../codex/AGENTS.md) into `${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/AGENTS.md`. Preserve other user guidance. Restart Pi or use `/reload`, then confirm `/skill:sloptrim` is available. Run `python3 "$HOME/.pi/agent/skills/sloptrim/scripts/detect.py" README.md`, adjusting for a redirected profile, and confirm a numeric `_metrics.ai_tell_score`.
