# Set up Pi

Read the [shared guide](../universal/README.md). Install Pi 1.4 or later and Python 3.9 or later. Preserve existing packages, provider settings, and credentials when merging this setup.

## MCP and installed extensions

Observed on this Mac on 2026-10-28 with Pi 1.4.0. The list comes from `pi list`, installed package manifests, and the user profile's `extensions/` directory.

| Extension | Installed version | Purpose |
| --- | --- | --- |
| Pi built-in MCP | 1.4.0 | MCP server connections and codemode tool discovery |
| [pi-web-access](https://github.com/nicobailon/pi-web-access) | 0.35.0 | Web search and content extraction |
| [pi-vimmode](https://github.com/pekochan069/pi-vimmode) | 0.9.0 | Vim-style prompt editing |
| [Ponytail](https://github.com/DietrichGebert/ponytail) | 5.3.2 | Ponytail mode and status indicator |
| Herdr bridge, `herdr-agent-state.ts` | Integration revision 9 | Reports Pi session identity and activity to Herdr |

The two npm sources in the live profile are unversioned. The commands below pin the versions observed in this snapshot. Ponytail is already pinned to commit `09c434ab73ca43761c5d8b0c5d341926c2fba710`.

## Recreate the extensions

On a new profile, install the recorded package versions:

```sh
pi install npm:pi-web-access@0.35.0
pi install npm:pi-vimmode@0.9.0
pi install git:github.com/DietrichGebert/ponytail@09c434ab73ca43761c5d8b0c5d341926c2fba710
```

In `${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/settings.json`, replace the matching Ponytail package entry with the object below and add the schema field. Retain all other package entries and extension settings, except the retired adapter settings described below.

```json
{
  "$schema": "https://pi.dev/schemas/settings.schema.json",
  "packages": [
    {
      "source": "git:github.com/DietrichGebert/ponytail@09c434ab73ca43761c5d8b0c5d341926c2fba710",
      "skills": []
    }
  ]
}
```

The empty `skills` array keeps Ponytail's extension enabled while its packaged skills stay disabled. The current profile supplies those skills separately. Configure provider credentials on the destination machine.

## Native MCP

Use [Pi's built-in MCP](https://pi.dev/docs/latest/mcp). Before migrating an existing profile, back up `settings.json` and `mcp.json`. Remove `npm:pi-mcp-adapter` from `packages` and `-builtin:mcp` from `extensions`. Keep the adapter's installed files for rollback.

Keep user servers in `${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/mcp.json`. Preserve their commands, arguments, and credentials. Use `"exposure": "codemode"` to discover tools as needed. Replace adapter-only `"directTools": false` with that setting. Review other adapter options before migrating them. Native MCP connects enabled servers in the background; the adapter started them on demand.

In trusted projects, `.pi/mcp.json` can override a user server's `enabled`, `exposure`, or `toolExposure` without copying its connection settings. Use `/mcp` to enable or disable a server for the current project. Keep credentials in the user profile.

Run `pi mcp list` to check connections. Restart Pi after migration so it loads native MCP and the retained extensions.

## Herdr

With Herdr installed, run from the repository root:

```sh
bash scripts/install-herdr.sh pi
```

The script refreshes the CLI-owned skill and integration while preserving unrelated settings. Follow the [shared Herdr guide](../universal/README.md#herdr) after upgrades.

## Install Sloptrim and Unslop

Stage the prose skills from the repository root into a new directory:

```sh
pi_stage="$HOME/.local/share/agent-setup/pi"
python3 scripts/agent-setup-bundle.py --stage pi --output "$pi_stage"
```

Copy `$pi_stage/skills/sloptrim/` into `${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/skills/sloptrim/` as ordinary files. Preserve existing packages and settings. Keep the detector, pattern reference, and license files together. Also copy `$pi_stage/skills/unslop/` into the same profile's `skills/unslop/` directory. Use `unslop` to revise prose before checking it with Sloptrim. Pi loads these as skills; Claude hooks are not registered.

Merge all rules from [Codex's AGENTS.md](../codex/AGENTS.md) into `${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/AGENTS.md`. Preserve other user guidance. Restart Pi or use `/reload`, then confirm `/skill:sloptrim` is available. Run `python3 "$HOME/.pi/agent/skills/sloptrim/scripts/detect.py" README.md`, adjusting for a redirected profile, and confirm a numeric `_metrics.ai_tell_score`.

## Verify and refresh the inventory

Run `pi list` to check the three package declarations. Check installed versions in each package's `package.json`; `pi list` shows configured sources. Confirm the Herdr bridge exists in the profile's `extensions/` directory. After restarting Pi, check the loaded extension list and try `/mcp`, `/vimmode`, and `/ponytail`. Confirm Sloptrim and Unslop are available as skills.

When refreshing this snapshot, update its date, observed versions, and install commands together. Record source identifiers and resource filters. Keep machine-specific paths, npm registry settings, MCP credentials, and session data on the destination machine.
