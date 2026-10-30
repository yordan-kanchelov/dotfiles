# Headroom and RTK

This optional setup routes Claude Code, Codex, and the configured Pi and Hermes models through a local Headroom service. RTK filters selected shell commands through native hooks in Claude and Codex only. The Ansible playbook and staged skill bundles do not install this setup. The recorded versions are Headroom 0.42.0, RTK OSS 1.1.0, and Python 3.13.

The [dashboard](http://127.0.0.1:8787/dashboard) belongs to the proxy service. On macOS, launchd starts the service after login and restarts it if it exits. No shell aliases, PATH shims, or wrapper commands are needed. OpenCode remains unchanged under the current requested scope.

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
headroom_python="$(uv tool dir)/headroom-ai/bin/python"
uv pip install --python "$headroom_python" --no-deps --reinstall-package dotfiles-headroom-rtk ./agent-setup/context-tools/headroom-rtk
rtk --version
headroom --version
```

RTK OSS installs an executable named `rtk`. The full RTK edition conflicts with it. Keep RTK Engine, RTK Proxy, and delegated models out of this comparison.

## Show Before and After in the dashboard

The Transforms view compares the request before compression with the compressed request sent upstream. It needs both snapshots. The default in [settings.json](settings.json) keeps message logging on. The other managed settings remain in [headroom.env](headroom.env).

Headroom 0.42.0 needs local fixes for this view. The [capture patch](patches/headroom-0.42.0-transformations-capture.patch) records native Codex HTTP and WebSocket requests, including `input`, `instructions`, and `tools`, only when message logging is on. The [display patch](patches/headroom-0.42.0-transformations-ui.patch) reads the compressed request for After and formats structured Anthropic and Responses content as JSON. It keeps line breaks and a 2,000-character preview cap, with a truncation marker.

An ambiguous WebSocket error, cancellation, or more than 100 pending turns stops snapshots for that connection to avoid assigning content to the wrong request. Reconnecting resumes capture. Forwarding and request metrics continue.

The separate [settings-origin patch](patches/headroom-0.42.0-settings-origin.patch) lets the dashboard edit file-loaded settings after startup. This is a convenience for the logging toggle. Compression and snapshot capture do not depend on it.

After installing Headroom and before applying its service, run the guarded [patcher](../../scripts/apply-headroom-fixes.py) with the installed tool's Python. It checks the version and source hashes, keeps private backups, and accepts patches already applied. Re-run it after reinstalling Headroom. It refuses unknown versions or source changes.

```sh
headroom_python="$(uv tool dir)/headroom-ai/bin/python"
"$headroom_python" scripts/apply-headroom-fixes.py
unset HEADROOM_LOG_MESSAGES

"$headroom_python" - <<'PY'
from datetime import datetime
import json
from pathlib import Path
import shutil
from headroom import paths, settings_store

target = paths.settings_path()
if target.is_symlink():
    raise SystemExit(f"Refusing to replace symlink: {target}")
if target.exists():
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    backup = target.with_name(target.name + ".backup-" + stamp)
    shutil.copy2(target, backup)
    backup.chmod(0o600)
settings_store.save(json.loads(Path("agent-setup/context-tools/settings.json").read_text()))
target.chmod(0o600)
PY
```

The merge preserves other stored keys. The `unset` removes the older setup's logging export from this terminal. Any explicit `HEADROOM_LOG_MESSAGES` export still locks that setting; remove it from service or shell configuration if GUI control is intended.

In the dashboard, change message logging, then use Save + Restart to apply it. Mirror a lasting default into the repository's `settings.json`, then merge that file again. Dashboard changes do not update Git automatically.

## RTK savings in the dashboard

The local [RTK extension](headroom-rtk/) adds an RTK command-output card to Headroom's dashboard. `HEADROOM_PROXY_EXTENSIONS=dotfiles-rtk` in [headroom.env](headroom.env) enables it. Reinstall the extension with the command above after changing its source or reinstalling Headroom.

The card reads `rtk gain --all --format json` and refreshes every 15 seconds. It shows RTK's estimated tokens saved, raw and filtered output totals, command count, and output-reduction percentage. These cover RTK's global tracking history. They stay independent of Headroom's Session, Lifetime, and Historical switches. RTK excludes oversized command outputs from these headline figures.

RTK estimates tokens from output bytes divided by four. Its figures remain separate from Headroom compression and provider-cache discounts. Automatic RTK filtering currently covers Claude Code and Codex; Pi and Hermes use Headroom only.

Only aggregate counters are exposed. Command text, recall payloads, and subprocess errors stay out of the endpoint. The native analytics command may perform its normal database maintenance. Missing RTK or failed reads display unavailable rather than a fabricated zero. Both extension endpoints require a local caller and reject remote browser origins.

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

[settings.json](settings.json) enables message logging by default; [headroom.env](headroom.env) sets its path to `~/.headroom/logs/requests.jsonl`. These logs can contain prompts, source, tool results, and secrets. Keep them outside Git and review them before sharing. Disabling outbound reporting does not prevent local content storage.

With the capture and display fixes applied, Before shows `request_messages` and After shows `compressed_messages`. Complete captured snapshots remain in the private JSONL log and `/transformations/feed`, beyond the dashboard's preview cap. These snapshots contain request content, not authentication headers. Prompts or tool results can still contain secrets.

Control requests such as `GET /api/hello` and bodyless metrics records have no message snapshots. Their cards show a neutral placeholder. Older records cannot recover content that was never captured, so start fresh requests after applying the fixes.

Headroom 0.42.0 still leaves `response_content` empty in its [unified logging path](https://github.com/headroomlabs-ai/headroom/blob/17d38e5699b7d7c69ac6addcd762f39e42dd7f00/headroom/proxy/outcome.py#L774-L808). This field is the model's reply. The Before/After comparison uses request snapshots and does not need it.

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

Source the environment file as shown above before this Bash or zsh block. A proxy restart drops active Codex connections. Finish connected harness sessions and run service changes from an independent terminal. To update a running profile, stop it with `headroom install stop --profile evaluation` and confirm it has stopped before applying. Read each exported value rather than passing the unexpanded assignment text to the service:

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

[headroom.env](headroom.env) enables cache mode and CCR compression. It preserves source reads and system instructions. Image compression, outbound usage reporting, subscription polling, cross-session memory, traffic learning, and output shaping are off. Local dashboard metrics are on. Message logging defaults to on through `settings.json`. Built-in local compression-feedback statistics remain separate from traffic learning.

CCR is enabled with `HEADROOM_NO_CCR=0` and `HEADROOM_LOSSLESS=0`. Headroom 0.42 suppresses CCR markers and tool injection in lossless mode. Originals remain available for one hour through `HEADROOM_CCR_TTL_SECONDS=3600`. This value does not control request-log or RTK retention. Compression can omit details, so each routed harness needs a working retrieval tool.

Register retrieval for Claude Code and Codex with `headroom mcp install --agent claude --agent codex`. Merge [headroom-mcp.json](headroom-mcp.json) into Pi's `mcp.json`, and merge the `mcp_servers.headroom` entry from [hermes.yaml](hermes.yaml) into Hermes's configuration. Resolve `command` to the installed Headroom executable if the harness's PATH does not include it. Keep Pi's retrieval tool directly exposed. Restart harness sessions to load the tools. OpenCode's routing remains unchanged.

To return to lossless compression, set `HEADROOM_LOSSLESS=1` and `HEADROOM_NO_CCR=1`, then reapply the service. Leave retrieval configured while existing conversations still contain CCR references.

Store future defaults in this repository, then reapply the matching live configuration. Use `settings.json` for message logging and `headroom.env` for the other managed settings. Dashboard logging changes need Save + Restart; mirror a lasting choice into the repository. Service environment exports can lock dashboard settings. There is no automatic dashboard-to-Git sync.

## Route ordinary agent sessions

Back up the active `settings.json` and `config.toml` before merging [claude.json](claude.json) and [codex.toml](codex.toml). Resolve redirected profiles through `CLAUDE_CONFIG_DIR` and `CODEX_HOME`; their defaults are `~/.claude` and `~/.codex`.

For Claude, merge the two `env` entries into the existing `settings.json` environment map. For Codex, add `openai_base_url` at the root of `config.toml`, before any table header. Preserve all other fields. Keep the built-in provider, account, selected model, permissions, hooks, and existing MCP tools. Do not run `headroom init` or replace the profile with a snippet.

Restart into fresh sessions after merging. Ordinary `claude` and `codex` now use Headroom plus RTK, including direct launches from Herdr. Codex keeps its shared app-server behavior because no wrapper adds command-line configuration overrides. Existing sessions may need to finish before their processes reload configuration.

These are user-level defaults. Project, command-line, or managed settings can override them. Check effective routing when a session behaves differently.

Claude's custom API endpoint disables Remote Control on affected versions. The original account and model settings remain in place. Use a direct session below when Remote Control is needed.

### Pi

Back up an existing `${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/models.json`, then merge [pi-models.json](pi-models.json) into it. Keep other providers and fields. The snippet changes only the built-in `xai` provider's URL and adds Headroom's upstream header. It preserves credentials, model metadata, and the selected `xai/grok-4.7` model. Use mode 600 for a new file.

Keep `baseUrl` at `http://127.0.0.1:8787/v1` and `x-headroom-base-url` at the origin `https://api.x.ai`. Adding `/v1` to that header produces a duplicated `/v1/v1/responses` path and a 404 in Headroom 0.42.0. Open `/model` to reload the file or start a fresh session.

Ordinary Pi sessions on xAI now use Headroom. Other Pi providers keep their existing routes. Headroom labels these xAI Responses records as provider `openai`; that label describes the protocol, while the upstream remains xAI. Pi has no RTK hook in this setup.

### Hermes

[hermes.yaml](hermes.yaml) contains the routing field to merge into the active profile's `config.yaml`. Apply it through Hermes's native command, which keeps a private backup and preserves other settings:

```sh
hermes config set model.base_url http://127.0.0.1:8787/v1
```

The verified profile uses `openai-codex` with `gpt-6.1-sol` and its existing ChatGPT login. Start a fresh Hermes session after changing the URL. Keep credentials and account state on the machine. Hermes has no RTK hook in this setup.

`HERMES_CODEX_BASE_URL` takes precedence over `model.base_url`. Explicitly custom credential-pool URLs can also keep their own route. Other profiles or provider selections need separate verification. Proxy routing disables Hermes's direct-host transport compression; residency-restricted accounts and alternate pool endpoints remain untested.

Store future Pi and Hermes routing defaults in these snippets, then merge them into the active profiles. Preserve provider and model selections when applying a routing change.

## Compare sessions

Use the same model and comparable tasks. The direct Codex URL below is for this Mac's ChatGPT account. API-key users must use `https://api.openai.com/v1` instead.

| Mode | Claude Code | Codex with ChatGPT login |
| --- | --- | --- |
| Both | `claude` | `codex` |
| Headroom only | `RTK_DISABLED=1 claude` | `RTK_DISABLED=1 codex` |
| RTK only | `claude --settings '{"env":{"ANTHROPIC_BASE_URL":"https://api.anthropic.com"}}'` | `codex -c 'openai_base_url="https://chatgpt.com/backend-api/codex"'` |
| Neither | `RTK_DISABLED=1 claude --settings '{"env":{"ANTHROPIC_BASE_URL":"https://api.anthropic.com"}}'` | `RTK_DISABLED=1 codex -c 'openai_base_url="https://chatgpt.com/backend-api/codex"'` |

The direct Codex overrides run those comparison sessions in embedded mode. Ordinary sessions keep the shared server. Do not add Headroom MCP, Serena, memory, learning, or code-graph features during the lossless comparison.

For one direct Hermes session with the current ChatGPT account, run:

```sh
HERMES_CODEX_BASE_URL=https://chatgpt.com/backend-api/codex hermes
```

Pi 1.4 has no CLI base-URL bypass flag. For a direct comparison, change only `providers.xai.baseUrl` in the active `models.json` to `https://api.x.ai/v1` and remove only its `x-headroom-base-url` header. Reload through `/model` or restart. Restore the repository snippet afterward. Neither Pi nor Hermes needs `RTK_DISABLED` because their sessions have no RTK hooks here.

Check `rtk gain` and the dashboard alongside task completion, elapsed time, retries, and missing evidence. Output reduction is not the same as bill reduction. Headroom cannot recover content that RTK discarded before it reached the proxy. Local recovery databases can contain source or secrets even though outbound reporting is off.

## Roll back or uninstall

Restore direct routing before stopping Headroom. In Claude's user `settings.json`, remove only `env.ANTHROPIC_BASE_URL` if it points at this proxy. Remove only Codex's root `openai_base_url` override. Preserve other settings and credentials. For Pi, restore `providers.xai.baseUrl` to `https://api.x.ai/v1` and remove its `x-headroom-base-url` header. This Hermes profile previously had an empty base URL; restore it with:

```sh
hermes config set model.base_url ''
```

Finish existing CCR conversations before removing retrieval. Start fresh harness sessions and verify direct requests work, then remove the Headroom MCP entries:

```sh
headroom mcp uninstall --agent claude --agent codex
```

Remove only `mcpServers.headroom` from Pi's `mcp.json` and `mcp_servers.headroom` from Hermes's `config.yaml`. OpenCode was not routed or changed by this setup. Keep other MCP servers. Otherwise ordinary agent launches may still point at a stopped proxy.

RTK is independent. To remove it too, remove only the added Claude and Codex RTK hook commands and `~/.local/bin/dotfiles-rtk-hook`. Keep other hooks. `RTK_DISABLED=1` disables filtering for a single session.

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
rm "$HOME/Library/LaunchAgents/com.dotfiles.headroom-logrotate.plist"
```

After removing the service and retrieval entries, uninstall the binaries if desired:

```sh
uv tool uninstall headroom-ai
# Optional, if also removing RTK installed through Homebrew:
brew uninstall rtk
```

Uninstalling Headroom also removes the RTK dashboard extension from its isolated environment. Logs, recovery databases, and evaluation metrics remain under `~/.headroom`; RTK's data remains separate. Keep these for comparison or delete them manually after checking their contents. Removing the service does not erase them. Repository snippets are opt-in; keeping them does not reinstall either tool through the main Ansible playbook.

## Checks

```sh
python3 scripts/test-context-tools.py
python3 scripts/test-headroom-fix-installer.py
node --test agent-setup/context-tools/headroom-rtk/tests/test-panel.js
shellcheck agent-setup/context-tools/rtk-hook.sh
headroom_python="$(uv tool dir)/headroom-ai/bin/python"
"$headroom_python" scripts/test-headroom-settings-origin.py
"$headroom_python" scripts/test-headroom-transformations-capture.py
"$headroom_python" -m unittest discover -s agent-setup/context-tools/headroom-rtk/tests -p 'test_*.py'
headroom_root="$("$headroom_python" -c 'import headroom; from pathlib import Path; print(Path(headroom.__file__).parent)')"
node scripts/test-headroom-transformations-ui.js --source "$headroom_root/dashboard/templates/dashboard.html"
```

The [Headroom settings review](../../docs/research/2026-10-28-headroom-settings.md) and [RTK evaluation](../../docs/research/2026-10-28-rtk-evaluation.md) explain the tradeoffs. Before the capture and display fixes, health checks and one small live request through each ordinary CLI passed and produced request-log records. Those checks found Claude request content but missing Codex snapshots. The settings-origin patch also passed an off/restart/on/restart logging cycle.

Fresh Claude and Codex requests now pass live Before/After checks. The browser renders both snapshots without object coercion or the old enable-logging hint. The Codex sample's compressed snapshot differs from its original.

Small live Pi and Hermes requests also passed on their existing models and logins. Pi's xAI request and Hermes's main and auxiliary requests produced both snapshots. These smoke checks do not establish coding quality or savings. Their records remain in Headroom's lifetime history; use the current Session view for new comparisons.
