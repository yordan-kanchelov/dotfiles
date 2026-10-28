# Evaluate Headroom and RTK

This optional setup installs RTK command filters and a local Headroom service. The Ansible playbook and staged skill bundles do not install them. Tested on this Mac with Headroom 0.42.0, RTK OSS 1.1.0, and Python 3.13.

The [Headroom dashboard](http://127.0.0.1:8787/dashboard) belongs to the proxy service. It does not need a separate dashboard process. Headroom routing is opt-in. RTK hooks apply to fresh Claude/Codex sessions and can be disabled for a session with the gate below.

## Install the tools

Run from the repository root. Export the reviewed settings in this terminal before invoking Headroom. They contain no provider base URLs:

```sh
set -a
. agent-setup/context-tools/headroom.env
set +a

brew tap rtk-ai/tap
```

Review the tap's `Formula/rtk-oss.rb`, then trust and install that formula:

```sh
brew trust --formula rtk-ai/tap/rtk-oss
brew install rtk-ai/tap/rtk-oss
uv tool install --python "$(brew --prefix python@3.13)/bin/python3.13" 'headroom-ai[proxy]==0.42.0'
rtk --version
headroom --version
```

RTK OSS installs an executable named `rtk`. The full RTK edition conflicts with it. Keep RTK Engine, RTK Proxy, and delegated models out of this comparison.

## Configure RTK

Merge [rtk.toml](rtk.toml) into the destination configuration. Back up an existing regular file first. The macOS path is `~/Library/Application Support/rtk/config.toml`; Linux uses `~/.config/rtk/config.toml`. Keep other destination settings. Recovery output and command history remain local and expire after seven days in this setup.

Preview native agent setup before applying it. Run from the repository root:

```sh
RTK_TELEMETRY_DISABLED=1 RTK_ONRAMP_DISABLED=1 rtk -v init -g --dry-run --no-trust-filters
RTK_TELEMETRY_DISABLED=1 RTK_ONRAMP_DISABLED=1 rtk -v init -g --codex --dry-run --no-trust-filters
```

Back up the affected instruction and hook files, then apply:

```sh
RTK_TELEMETRY_DISABLED=1 RTK_ONRAMP_DISABLED=1 rtk init -g --auto-patch --no-trust-filters
RTK_TELEMETRY_DISABLED=1 RTK_ONRAMP_DISABLED=1 rtk init -g --codex --no-trust-filters
install -m 755 agent-setup/context-tools/rtk-hook.sh "$HOME/.local/bin/dotfiles-rtk-hook"
```

Replace only the newly added RTK `PreToolUse` command in each host with the absolute installed gate path followed by `claude` or `codex`. Preserve existing hooks, models, permissions, and instructions. Claude stores this entry in its `settings.json`; Codex uses `hooks.json` beside its active `config.toml`.

The [gate](rtk-hook.sh) makes `RTK_DISABLED=1` work for an entire session. RTK 1.1.0's native hook only checks the flag inside individual command text. Re-running native RTK init can replace the gate command, so reapply this step afterward.

Restart the agent and review its native hook prompts. In Codex, use `/hooks` to review the new definition. Do not copy trust records or add an unrestricted `rtk *` permission rule.

The exclusions preserve Ansible verification, complete Git reviews, exhaustive searches, and interpreter-sensitive commands. RTK's Ansible filter can hide `PLAY RECAP`; use the original output to verify `changed=0`. `rtk bypass <command>` runs a specific command unfiltered. `rtk recall <hash>` retrieves retained output when a filter supplies a recovery hint.

## Start Headroom and its dashboard

Run this Bash or zsh block from the repository root. The environment file contains plain assignments, one per line:

```sh
headroom_env_args=()
while IFS= read -r setting; do
  headroom_env_args+=(--env "$setting")
done < agent-setup/context-tools/headroom.env

headroom install apply \
  --profile evaluation \
  --preset persistent-service --runtime python \
  --scope provider --providers manual \
  --port 8787 --mode cache --telemetry --no-rate-limit \
  "${headroom_env_args[@]}"

headroom install status --profile evaluation
headroom dashboard --port 8787
```

Omit every `--target` argument. Manual provider selection with no targets installs the service without writing global agent routing or shell exports. The native installer uses launchd on macOS. The service stays available after the setup terminal closes.

Stop or remove the evaluation service with:

```sh
headroom install stop --profile evaluation
headroom install start --profile evaluation
# Remove the service when the evaluation is over:
headroom install remove --profile evaluation
```

[headroom.env](headroom.env) enables cache mode and lossless compaction. It preserves source reads and system instructions. Image compression, outbound usage reporting, subscription polling, cross-session memory, traffic learning, and output shaping are off. Local dashboard metrics are on. Built-in local compression-feedback statistics remain separate from traffic learning.

To compare normal CCR compression later, change `HEADROOM_LOSSLESS=1` to `0` and reapply the service command. Keep retrieval available. The four-hour CCR retention setting matters in that mode. Service environment values can override dashboard settings, so reapply the service when changing this file.

The initial lossless comparison skips Headroom MCP registration. For a later CCR comparison, remove `--no-mcp` from the wrapper commands to register retrieval tools. Native MCP removal can also remove legacy Headroom code-memory registrations; inspect the host before using it. Stop routing sessions before removing their retrieval tools.

## Compare sessions

Use the same model and comparable tasks. Start fresh sessions after installing hooks. In each new terminal, export `headroom.env` with the `set -a` block above. This also disables Headroom's wrapper-added test flags, including its quiet pytest option.

| Mode | Claude Code | Codex |
| --- | --- | --- |
| Normal | `RTK_DISABLED=1 claude` | `RTK_DISABLED=1 codex` |
| RTK only | `claude` | `codex` |
| Headroom only | `RTK_DISABLED=1 headroom wrap claude --no-proxy --port 8787 --no-mcp --code-memory none` | `RTK_DISABLED=1 headroom wrap codex --no-proxy --port 8787 --no-mcp --code-memory none` |
| Both | `headroom wrap claude --no-proxy --port 8787 --no-mcp --code-memory none` | `headroom wrap codex --no-proxy --port 8787 --no-mcp --code-memory none` |

Pass agent arguments after `--`. These lossless wrappers skip Headroom MCP and Serena, leaving the original tool selection available in all four modes. Routing stays scoped to the launched process. Omit memory, learning, and code-graph flags. Wrapped Codex sessions use embedded operation rather than its shared background server.

Check `rtk gain` and the dashboard alongside task completion, elapsed time, retries, and missing evidence. Output reduction is not the same as bill reduction. Headroom cannot recover content that RTK discarded before it reached the proxy. Local recovery databases can contain source or secrets even though outbound reporting is off.

The [Headroom settings review](../../docs/research/2026-10-28-headroom-settings.md) and [RTK evaluation](../../docs/research/2026-10-28-rtk-evaluation.md) explain the tradeoffs. No provider inference is needed to check local health and hook rewriting.

The hook gate has a local regression check:

```sh
python3 scripts/test-context-tools.py
shellcheck agent-setup/context-tools/rtk-hook.sh
```

Setup smoke checks used local synthetic content without provider inference. Their records remain in Headroom's lifetime history. Use the current Session view for new comparisons.
