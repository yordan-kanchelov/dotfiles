# RTK command filter

Model routing and gateway setup: see ../cliproxyapi/README.md.

This optional setup filters selected shell command output through RTK OSS native hooks in Claude Code and Codex. Pi and Hermes have no RTK hooks here. The Ansible playbook and staged skill bundles do not install it. The recorded version is RTK OSS 1.1.0.

## Install RTK

```sh
brew tap rtk-ai/tap
```

Review the tap's `Formula/rtk-oss.rb`, then trust and install that formula:

```sh
brew trust --formula rtk-ai/tap/rtk-oss
brew install rtk-ai/tap/rtk-oss
rtk --version
```

RTK OSS installs an executable named `rtk`. The full RTK edition conflicts with it. Keep RTK Engine, RTK Proxy, and delegated models out of this setup.

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

## Check savings

Run `rtk gain` to see estimated tokens saved. RTK estimates tokens from output bytes divided by four. Judge the filter by task completion, elapsed time, retries, and missing evidence as well. Output reduction is not the same as bill reduction. Local recovery databases can contain source or secrets even though outbound reporting is off.

To compare, run a comparable session with `RTK_DISABLED=1 claude` or `RTK_DISABLED=1 codex`.

## Remove RTK

Remove only the added Claude and Codex RTK hook commands and `~/.local/bin/dotfiles-rtk-hook`. Keep other hooks. Then uninstall the binary if desired:

```sh
brew uninstall rtk
```

RTK's data stays under its own config and data directories. Keep it for comparison or delete it after checking its contents. Repository snippets are opt-in; keeping them does not reinstall RTK through the main Ansible playbook. `RTK_DISABLED=1` disables filtering for a single session.

## Checks

```sh
python3 scripts/test-context-tools.py
shellcheck agent-setup/context-tools/rtk-hook.sh
```

The [RTK evaluation](../../docs/research/2026-10-28-rtk-evaluation.md) explains the tradeoffs.
