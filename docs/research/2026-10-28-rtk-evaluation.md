# RTK evaluation for Claude Code and Codex

Reviewed on 2026-10-28 against stable v1.1.0, released October 25, at commit `753a3b0e939f2e4490fc24e3a1984010f40a103c`. RTK was not found on this shell's PATH. No software was installed or agent profile changed. [Release](https://github.com/rtk-ai/rtk/releases/tag/v1.1.0).

For our command-heavy work, classic RTK filtering is a smaller first experiment than a provider proxy. Start with explicit commands and inspect the results. Keep Ansible verification, complete code reviews, exhaustive searches, and interpreter-sensitive tests unfiltered. Do not enable the Engine or RTK Proxy merely to try the command filters.

This qualifies the earlier comparison with Headroom. The command filter is narrow, but the current RTK product also includes a pipeline engine and an optional API proxy. Those features already ship in stable v1.1.0.

| Download | What it includes | Recommendation |
| --- | --- | --- |
| `rtk-oss` | Apache-2.0 command filters, hooks, recall, and local analytics. Installs an executable named `rtk`. | Best fit for a filter-only trial. |
| Full `rtk` | Same filters plus a BUSL-1.1 pipeline engine. | Use only if the extra pipeline capabilities are needed. |
| `rtk-proxy` | Separate BUSL-1.1 API daemon. | Skip initially. Stable compression targets Anthropic, not Codex Responses. |

The two CLI editions install the same executable name and cannot coexist. The Engine/proxy license grants production use without charge, with restrictions on offering the licensed work or derivatives as a paid or hosted third-party product. The root Apache license alone does not describe the full binary. [Editions](https://github.com/rtk-ai/rtk/blob/v1.1.0/docs/guide/resources/editions.md), [Engine license](https://github.com/rtk-ai/rtk/blob/v1.1.0/engine/LICENSE), [proxy routes](https://github.com/rtk-ai/rtk/blob/v1.1.0/docs/guide/proxy/configuration.md).

RTK's basic hook rewrites commands such as `git status` into `rtk git status`. The wrapper executes the tool and returns filtered output before it enters the agent's conversation. This needs no model API key or endpoint change. It can fit subscription logins without modifying authentication. Native file, search, and MCP tools do not pass through this shell-rewrite path. Engine posthooks and API proxying are separate capabilities. [Tagged overview](https://github.com/rtk-ai/rtk/blob/v1.1.0/README.md), [default pipeline](https://github.com/rtk-ai/rtk/blob/v1.1.0/engine/builtin/default.toml).

| Workload | Benefit | Recommendation and limits |
| --- | --- | --- |
| Git status and routine summaries | Reduces repeated status output. | Good explicit-command trial. |
| Noisy builds, lint, and passing tests | Collapses progress, passing cases, and repeated diagnostics. | Try selected commands. Read raw logs when investigating failures. |
| Ansible playbooks | Built-in filter removes routine success lines. | Exclude verification and `--check --diff`; the filter can hide the recap. |
| Full diffs and history | Shortens changes and commit listings. | Bypass for review and merge investigation. |
| Exhaustive searches | Groups and caps matches. | Keep raw when proving every caller or occurrence was inspected. |
| Source reads | Optional structural filtering. | Preserve complete content for edits. Default `rtk read` level is `none`. |
| Unreal build/editor output | Generic filters may help some surrounding commands. | No dedicated Unreal filter was found. Keep unfamiliar diagnostics raw. |

The Ansible filter removes lines beginning with `ok: [` and `skipping: [`, then retains at most 60 surviving lines. It retains task headings, so a long playbook can push `PLAY RECAP` and `changed=0` beyond the cap. A debug payload on an `ok:` line also disappears. The generic filter runner does not classify line stripping alone as recoverable loss. Its truncation snapshot is already line-filtered, so recall does not guarantee restoration of every original Ansible line. [Ansible filter](https://github.com/rtk-ai/rtk/blob/v1.1.0/src/filters/ansible-playbook.toml), [filter runner](https://github.com/rtk-ai/rtk/blob/v1.1.0/src/core/toml_filter.rs).

Default Git diff rendering caps each hunk at 100 lines and its overall compact representation at 500 lines. Git log defaults to ten commits and excludes merges unless the caller requests them or a count. Use `rtk git diff --no-compact` or bypass for a full review. [Git implementation](https://github.com/rtk-ai/rtk/blob/v1.1.0/src/cmds/git/git_cmd.rs).

Pytest filtering adds short-output flags when absent, removes captured sections, and bounds detailed failures. Rewriting `python3 -m pytest` can also change which executable runs. The wrapper selects `pytest` on PATH or falls back to `python -m pytest`. This matters when the original interpreter selects a particular environment. [Pytest implementation](https://github.com/rtk-ai/rtk/blob/v1.1.0/src/cmds/python/pytest_cmd.rs), [rewrite rules](https://github.com/rtk-ai/rtk/blob/v1.1.0/src/discover/registry.rs).

| Integration | What it changes | Recommendation |
| --- | --- | --- |
| Explicit `rtk git status` or a selected test command | Filters one invocation. | Start here. No agent setup is needed. |
| Claude native hook | Global init merges a hook and awareness files into the Claude profile. | Consider after the explicit trial; preserve existing Herdr/Ponytail settings. |
| Codex native hook | Init writes hook config, `RTK.md`, and an instruction reference at the chosen scope. | Current official hook format supports it; verify trust and approval behavior locally. |
| Engine posthooks and delegation | Can process more tool outputs or send work to another model. | Leave off initially. Host output-replacement support varies. |
| RTK Proxy | Redirects provider traffic through a daemon. | Evaluate as an alternative to Headroom, not an extra first layer. |

Current Codex documentation normalizes `exec_command` to hook name `Bash` and `tool_input.command`, including nested code-mode calls. RTK's handler matches that contract. Its `allow` plus `updatedInput` response is the documented rewrite format. This does not establish approval transparency. Native rules inspect the rewritten `rtk ...` command, which can affect classification and prompts. Avoid broad `rtk *` allow rules. [Official OpenAI hooks documentation](https://learn.chatgpt.com/docs/hooks), [RTK Codex notes](https://github.com/rtk-ai/rtk/blob/v1.1.0/hooks/codex/README.md).

Claude's hook reads user/project Bash permission rules. It leaves denied commands unrewritten and can emit an allow when it finds an explicit allow. It cannot see every managed or command-line permission source. Preview initialization with `--dry-run -v`; `--no-patch` is not a universal read-only switch. [Permission reader](https://github.com/rtk-ai/rtk/blob/v1.1.0/src/hooks/permissions.rs), [Claude init](https://github.com/rtk-ai/rtk/blob/v1.1.0/src/hooks/init/claude.rs), [Codex init](https://github.com/rtk-ai/rtk/blob/v1.1.0/src/hooks/init/codex.rs).

| Setting | Stable default | Recommendation |
| --- | --- | --- |
| `awareness.level` | `default` | Use `high` with hooks so the agent knows recovery and bypass. |
| `hooks.exclude_commands` | Empty | Start with Ansible, full diff/history, exhaustive search, and interpreter-sensitive exclusions. Verify matching. |
| `hooks.wrap_fish_scripts` | False | Leave off for our zsh/bash setup. |
| `retriever.mode` | `sqlite` | Keep recovery available. It does not cover every discarded detail. |
| `retriever.max_entry_bytes` | 10 MiB | Keep initially; larger captured outputs can exceed this cap. |
| `retriever.max_entries` | 200 | Bounded FIFO storage, not permanent history. |
| `retriever.retention_days` | 30 | Consider shorter retention for work repositories. |
| `retriever.compression` | True | Keep gzip. It is not encryption. |
| `tracking.enabled`, `tracking.history_days` | True, 90 | Useful during the trial; command/path history stays local. |
| `telemetry.enabled` | False | Keep off. `RTK_TELEMETRY_DISABLED=1` forces it off. |
| Custom filters | Require content-hash trust | Review the rules before trusting them. |
| API proxy and delegated models | Optional | Leave disabled during the filter-only comparison. |

Use `rtk bypass <command> <args>` for an unfiltered invocation. `RTK_DISABLED=1` skips automatic rewriting. `rtk recall <hash>` retrieves retained captured output when a filter supplies a hint. The deprecated `rtk proxy` command means bypass; the API daemon is controlled by `rtk llm-proxy`. [Configuration](https://github.com/rtk-ai/rtk/blob/v1.1.0/docs/guide/getting-started/configuration.md).

Recall and analytics databases contain local plaintext command/output data. Output can include secrets. Turning telemetry off does not disable these stores. Telemetry itself is opt-in and sends aggregate metrics at most daily. [Privacy](https://www.rtk-ai.app/docs/resources/telemetry/), [retriever source](https://github.com/rtk-ai/rtk/blob/v1.1.0/src/core/retriever.rs).

RTK and Headroom can operate at different points. RTK filters output before the agent records it; Headroom transforms later provider requests. Headroom can retain only the output it receives from RTK. Missing details require RTK recall or a raw rerun. This is an inference from their data paths, not a tested incompatibility. Compare normal sessions, RTK alone, and Headroom alone before combining them.

RTK's reported savings estimate tokens from output bytes divided by four. A smaller command result does not establish the same reduction in total tokens or bills. Measure task success, missing evidence, retries, and elapsed time alongside the byte reduction. [Savings definition](https://www.rtk-ai.app/docs/resources/savings-explained/).

Verification covered source, configuration, and existing tests. A Python reproduction of the checked Ansible rules confirmed that a 65-task example loses its recap after the 60-line cap and loses debug payloads during stripping. This did not execute the RTK binary. Live hook, approval, recall, and coding-outcome tests remain outstanding.
