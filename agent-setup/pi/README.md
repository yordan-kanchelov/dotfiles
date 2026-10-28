# Set up Pi

Read the [shared guide](../universal/README.md). Install Pi and Python 3.9 or later. Preserve existing packages, provider settings, and credentials when merging this setup.

## Installed extensions

Observed on this Mac on 2026-10-28 with Pi 1.0.0. The list comes from `pi list`, installed package manifests, and the user profile's `extensions/` directory.

| Extension | Installed version | Purpose |
| --- | --- | --- |
| [pi-mcp-adapter](https://github.com/nicobailon/pi-mcp-adapter) | 5.0.0 | MCP server connections and tool discovery |
| [pi-web-access](https://github.com/nicobailon/pi-web-access) | 0.35.0 | Web search and content extraction |
| [pi-vimmode](https://github.com/pekochan069/pi-vimmode) | 0.9.0 | Vim-style prompt editing |
| [Ponytail](https://github.com/DietrichGebert/ponytail) | 5.3.2 | Ponytail mode and status indicator |
| Herdr bridge, `herdr-agent-state.ts` | Integration revision 9 | Reports Pi session identity and activity to Herdr |

The three npm sources in the live profile are unversioned. The commands below pin the versions observed in this snapshot. Ponytail is already pinned to commit `09c434ab73ca43761c5d8b0c5d341926c2fba710`.

## Recreate the extensions

On a new profile, install the recorded package versions:

```sh
pi install npm:pi-mcp-adapter@5.0.0
pi install npm:pi-web-access@0.35.0
pi install npm:pi-vimmode@0.9.0
pi install git:github.com/DietrichGebert/ponytail@09c434ab73ca43761c5d8b0c5d341926c2fba710
```

In `${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/settings.json`, replace the matching Ponytail package entry with the object below and merge the extension setting. Retain all other package entries and extension settings.

```json
{
  "packages": [
    {
      "source": "git:github.com/DietrichGebert/ponytail@09c434ab73ca43761c5d8b0c5d341926c2fba710",
      "skills": []
    }
  ],
  "extensions": ["-builtin:mcp"]
}
```

The empty `skills` array keeps Ponytail's extension enabled while its packaged skills stay disabled. The current profile supplies those skills separately. `-builtin:mcp` disables Pi's built-in MCP extension while `pi-mcp-adapter` handles MCP. Configure server connections and provider credentials on the destination machine.

With Herdr installed, generate its bridge using the installed CLI:

```sh
herdr integration install pi
```

Herdr owns `extensions/herdr-agent-state.ts`; regenerate it through the CLI after Herdr updates. These extensions are installed through their native tools and are separate from the packages staged by the bundle script.

## Install Sloptrim and Unslop

Stage the prose skills from the repository root into a new directory:

```sh
pi_stage="$HOME/.local/share/agent-setup/pi"
python3 scripts/agent-setup-bundle.py --stage pi --output "$pi_stage"
```

Copy `$pi_stage/skills/sloptrim/` into `${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/skills/sloptrim/` as ordinary files. Preserve existing packages and settings. Keep the detector, pattern reference, and license files together. Also copy `$pi_stage/skills/unslop/` into the same profile's `skills/unslop/` directory. Use `unslop` to revise prose before checking it with Sloptrim. Pi loads these as skills; Claude hooks are not registered.

Merge the prose rule from [Codex's AGENTS.md](../codex/AGENTS.md) into `${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/AGENTS.md`. Preserve other user guidance. Restart Pi or use `/reload`, then confirm `/skill:sloptrim` is available. Run `python3 "$HOME/.pi/agent/skills/sloptrim/scripts/detect.py" README.md`, adjusting for a redirected profile, and confirm a numeric `_metrics.ai_tell_score`.

## Verify and refresh the inventory

Run `pi list` to check the four package declarations. Check installed versions in each package's `package.json`; `pi list` shows configured sources. Confirm the Herdr bridge exists in the profile's `extensions/` directory. After restarting Pi or running `/reload`, check the loaded extension list and try `/mcp-adapter`, `/vimmode`, and `/ponytail`. Confirm Sloptrim and Unslop are available as skills.

When refreshing this snapshot, update its date, observed versions, and install commands together. Record source identifiers and resource filters. Keep machine-specific paths, npm registry settings, MCP credentials, and session data on the destination machine.
