# Set up Claude Code

Read the [shared setup](../universal/README.md) first. This folder adds Claude manifests and command wrappers for the shared plugins, plus the pinned Chrome DevTools plugin. [inventory.md](inventory.md) records the current Mac; [sources.json](sources.json) records the Chrome DevTools payload.

## Stage and install plugins

Run from the repository root. Choose a new, stable staging directory because native marketplace registrations refer to it:

```sh
claude_catalogs="$HOME/.local/share/agent-setup/claude"
python3 agent-setup/refactor.py --stage claude --output "$claude_catalogs"
```

The command refuses an existing output directory. It assembles three marketplaces with ordinary copies of the payloads and Claude manifests. It does not run hooks or install packages.

On a new profile, register and install them:

```sh
claude plugin marketplace add "$claude_catalogs/addy-agent-skills" --scope user
claude plugin marketplace add "$claude_catalogs/reviewed-agent-pins" --scope user
claude plugin marketplace add "$claude_catalogs/ponytail" --scope user
claude plugin install agent-skills@addy-agent-skills --scope user
claude plugin install mattpocock-skills@reviewed-agent-pins --scope user
claude plugin install chrome-devtools-mcp@reviewed-agent-pins --scope user
claude plugin install ponytail@ponytail --scope user
```

On an existing profile, keep matching installs and inspect differences before replacing a marketplace. Remove the old Pstack plugin and its Pstack-only marketplace when replacing it. Keep unrelated marketplace entries. The Chrome DevTools manifest declares `npx chrome-devtools-mcp@1.12.0`; it needs Node, npm, Chrome, and package access.

## Merge profile instructions

Resolve the profile with `claude_config_home="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"`. Place `universal/engineering-defaults.md` at `$claude_config_home/engineering-defaults.md`, then merge [CLAUDE.md](CLAUDE.md) into `$claude_config_home/CLAUDE.md`. The template imports the shared file and adds Claude-specific routing.

Keep the destination's model and permission settings. Agent Skills adds native commands and skills, with no wired startup hook. Review Ponytail's existing hooks and task-board module through native trust prompts. Keep the meta-skill body out of always-on context.

## Install standalone unslop

Copy `universal/skills/unslop/` (also staged at `skills/unslop/`) into `$claude_config_home/skills/unslop/` using ordinary files. Keep its license and provenance beside SKILL.md. It is a loose skill, so no plugin registration or startup hook is needed.

## Add Herdr

With Herdr installed, create its skill from the CLI:

```sh
mkdir -p "$claude_config_home/skills/herdr"
herdr --skill > "$claude_config_home/skills/herdr/SKILL.md"
herdr integration install claude
```

The integration command updates managed hook settings. For a redirected profile, verify that Herdr targets that profile before installing the integration.

## Verify

Run `claude plugin list --json` and compare versions, namespaces, and user-enabled state with the staged selection. Start a fresh Claude session and confirm that shared defaults and plugin skills are available. Runtime hook execution, Chrome connectivity, and external providers need separate checks in their intended environment.
