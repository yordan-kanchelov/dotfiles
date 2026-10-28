# Headroom and RTK

This optional setup routes ordinary `claude` and `codex` sessions through a local Headroom service. RTK filters selected shell commands through native hooks. The Ansible playbook and staged skill bundles do not install this setup. The recorded versions are Headroom 0.42.0, RTK OSS 1.1.0, and Python 3.13.

The [dashboard](http://127.0.0.1:8787/dashboard) belongs to the proxy service. On macOS, launchd starts the service after login and restarts it if it exits. No shell aliases, PATH shims, or wrapper commands are needed. Hermes, Pi, and OpenCode keep their existing setup.

## Install the tools

Run from the repository root. Export the reviewed settings before invoking Headroom. Sourcing the file expands the log path's `~` to your home directory:

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

Merge [rtk.toml](rtk.toml) into the destination configuration. Back up an existing regular file first. The macOS path is `~/Library/Application Support/rtk/config.toml`; Linux uses `~/.config/rtk/config.toml`. Keep other destination settings. Recovery output and command history remain local and use seven-day retention in this setup.

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

## Keep request logs private

[headroom.env](headroom.env) enables full request logging at `~/.headroom/logs/requests.jsonl`. These logs can contain prompts, source, tool results, and secrets. Keep them outside Git and review them before sharing. Disabling outbound reporting does not prevent local content storage.

`HEADROOM_LOG_MESSAGES=1` requests message logging. Installed Headroom 0.42.0 records the request and compressed request, but leaves `response_content` empty in its [unified logging path](https://github.com/headroomlabs-ai/headroom/blob/17d38e5699b7d7c69ac6addcd762f39e42dd7f00/headroom/proxy/outcome.py#L774-L808). The live smoke checks confirmed this limitation. Treat reply capture as unavailable pending an upstream fix.

On macOS, render [newsyslog.conf.in](newsyslog.conf.in) and [logrotate.plist.in](logrotate.plist.in) with the standard library. This recipe backs up existing rendered files and sets private permissions:

```sh
python3 - <<'PY'
from datetime import datetime
from html import escape
import os
from pathlib import Path
import plistlib
import shutil

home = Path.home()
if any(char.isspace() for char in str(home)):
    raise SystemExit("newsyslog requires a log path without whitespace")
workspace = home / ".headroom"
logs = workspace / "logs"
logs.mkdir(parents=True, exist_ok=True)
workspace.chmod(0o700)
logs.chmod(0o700)
log = logs / "requests.jsonl"
if log.is_symlink():
    raise SystemExit(f"Refusing to open symlink: {log}")
log.touch(exist_ok=True)
log.chmod(0o600)
templates = Path("agent-setup/context-tools")
stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
for source, target, values in (
    ("newsyslog.conf.in", workspace / "newsyslog.conf",
     {"@LOG_FILE@": str(log), "@UID@": str(os.getuid()), "@GID@": str(os.getgid())}),
    ("logrotate.plist.in", home / "Library/LaunchAgents/com.dotfiles.headroom-logrotate.plist",
     {"@HOME@": escape(str(home))}),
):
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.is_symlink():
        raise SystemExit(f"Refusing to replace symlink: {target}")
    if target.exists():
        shutil.copy2(target, target.with_name(target.name + ".backup-" + stamp))
    text = (templates / source).read_text()
    for key, value in values.items():
        text = text.replace(key, value)
    if target.suffix == ".plist":
        plistlib.loads(text.encode())
    target.write_text(text)
    target.chmod(0o600)
PY

launchctl bootout "gui/$(id -u)/com.dotfiles.headroom-logrotate" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.dotfiles.headroom-logrotate.plist"
```

The job runs `/usr/sbin/newsyslog -r -f ~/.headroom/newsyslog.conf` hourly. It rotates at 10,240 KiB or 24 hours and retains seven gzip archives. The active log can exceed the size threshold between hourly checks. This is not a hard disk quota. The request log uses mode 600; its directories use 700.

## Start Headroom and its dashboard

Source the environment file as shown above before this Bash or zsh block. To update a running profile, stop it with `headroom install stop --profile evaluation` and confirm it has stopped before applying. Read each exported value rather than passing the unexpanded assignment text to the service:

```sh
headroom_env_args=()
while IFS='=' read -r headroom_name _; do
  headroom_env_args+=(--env "$headroom_name=$(printenv "$headroom_name")")
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

Omit every `--target` argument. Configure agent routing with the small merge snippets below instead. The native installer manages only the persistent service here. It does not write shell exports or introduce a custom Codex provider.

[headroom.env](headroom.env) enables cache mode and lossless compaction. It preserves source reads and system instructions. Image compression, outbound usage reporting, subscription polling, cross-session memory, traffic learning, and output shaping are off. Local dashboard metrics and full request logging are on. Built-in local compression-feedback statistics remain separate from traffic learning.

CCR is disabled with `HEADROOM_NO_CCR=1`, so no retrieval MCP is needed. To test lossy compression later, set `HEADROOM_LOSSLESS=0` and `HEADROOM_NO_CCR=0`, reapply the service, and register Headroom retrieval tools together. The one-hour `HEADROOM_CCR_TTL_SECONDS` value applies when CCR is enabled. It does not control request-log or RTK retention.

Store future setting changes in this repository first, then reapply the matching live configuration. Treat dashboard changes as temporary experiments. Mirror any setting you want to keep into `headroom.env` and reapply the service. Service environment values can override dashboard settings. There is no automatic dashboard-to-Git sync.

## Route ordinary agent sessions

Back up the active `settings.json` and `config.toml` before merging [claude.json](claude.json) and [codex.toml](codex.toml). Resolve redirected profiles through `CLAUDE_CONFIG_DIR` and `CODEX_HOME`; their defaults are `~/.claude` and `~/.codex`.

For Claude, merge the two `env` entries into the existing `settings.json` environment map. For Codex, add `openai_base_url` at the root of `config.toml`, before any table header. Preserve all other fields. Keep the built-in provider, account, selected model, permissions, hooks, and existing MCP tools. Do not run `headroom init` or replace the profile with a snippet.

Restart into fresh sessions after merging. Ordinary `claude` and `codex` now use Headroom plus RTK, including direct launches from Herdr. Codex keeps its shared app-server behavior because no wrapper adds command-line configuration overrides. Existing sessions may need to finish before their processes reload configuration.

These are user-level defaults. Project, command-line, or managed settings can override them. Check effective routing when a session behaves differently.

Claude's custom API endpoint disables Remote Control on affected versions. The original account and model settings remain in place. Use a direct session below when Remote Control is needed.

## Compare sessions

Use the same model and comparable tasks. The direct Codex URL below is for this Mac's ChatGPT account. API-key users must use `https://api.openai.com/v1` instead.

| Mode | Claude Code | Codex with ChatGPT login |
| --- | --- | --- |
| Both | `claude` | `codex` |
| Headroom only | `RTK_DISABLED=1 claude` | `RTK_DISABLED=1 codex` |
| RTK only | `claude --settings '{"env":{"ANTHROPIC_BASE_URL":"https://api.anthropic.com"}}'` | `codex -c 'openai_base_url="https://chatgpt.com/backend-api/codex"'` |
| Neither | `RTK_DISABLED=1 claude --settings '{"env":{"ANTHROPIC_BASE_URL":"https://api.anthropic.com"}}'` | `RTK_DISABLED=1 codex -c 'openai_base_url="https://chatgpt.com/backend-api/codex"'` |

The direct Codex overrides run those comparison sessions in embedded mode. Ordinary sessions keep the shared server. Do not add Headroom MCP, Serena, memory, learning, or code-graph features during the lossless comparison.

Check `rtk gain` and the dashboard alongside task completion, elapsed time, retries, and missing evidence. Output reduction is not the same as bill reduction. Headroom cannot recover content that RTK discarded before it reached the proxy. Local recovery databases can contain source or secrets even though outbound reporting is off.

## Roll back

Restore the prior Claude and Codex routing settings before stopping Headroom. Preserve any unrelated changes made since the backups. Otherwise ordinary agent launches will still point at a stopped proxy. Remove only the added RTK hook commands to disable automatic filtering permanently, or use `RTK_DISABLED=1` for one session.

```sh
headroom install stop --profile evaluation
# To resume the service:
headroom install start --profile evaluation
# To remove it after restoring routing:
headroom install remove --profile evaluation
```

Remove the rotation job separately if it is no longer needed:

```sh
launchctl bootout "gui/$(id -u)/com.dotfiles.headroom-logrotate"
```

Keep or delete local logs and recovery data according to their contents. Removing the service does not erase them.

## Checks

```sh
python3 scripts/test-context-tools.py
shellcheck agent-setup/context-tools/rtk-hook.sh
```

The [Headroom settings review](../../docs/research/2026-10-28-headroom-settings.md) and [RTK evaluation](../../docs/research/2026-10-28-rtk-evaluation.md) explain the tradeoffs. Local checks covered health endpoints and synthetic content. One small live request through each ordinary CLI also completed and produced a request-log record. These smoke checks do not establish coding quality or savings. Their records remain in Headroom's lifetime history; use the current Session view for new comparisons.
