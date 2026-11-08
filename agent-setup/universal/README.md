# Shared skills

Shared plugin payloads live under `plugins/`; standalone `unslop` and Sloptrim live under `skills/`. Each harness supplies its native manifests separately. Keep each package intact so relative references, agent prompts, and licenses remain available.

| Payload | Version | Skills | Used by |
| --- | --- | --- | --- |
| `plugins/agent-skills/` | 0.6.13 | 25 | Claude, Codex, and Hermes |
| `plugins/mattpocock-skills/` | 1.3.1 | 27 | Claude and Codex |
| `plugins/ponytail/` | 5.3.2 | 6 | Claude and Codex |
| `skills/unslop/` | pinned from 1.16.0 | 1 | Claude, Codex, Hermes, and Pi |
| `skills/sloptrim/` | 0.9.6 | 1 | Claude, Codex, Hermes, and Pi |

[Agent Skills](https://github.com/addyosmani/agent-skills) replaces Open Pstack. It is pinned to `aeac41d4d005999432bb7312f7ff06383a91d59d`. Its root `references/` directory is retained because per-skill copies alone lose shared checklists. Native manifests do not wire the standalone SessionStart helper. Keep the `using-agent-skills` body out of always-on instructions.

[skills.md](skills.md) lists bundled names, including harness additions. [sources.json](sources.json) records upstream commits, download hashes, retained payloads, and integrity hashes. Third-party skill bodies remain unchanged. Standalone `unslop` retains its MIT license and source provenance; no Pstack plugin or router is retained.

## Prepare the tools

Install the chosen agent CLI, Python 3.9 or later, Node.js, Git, and ripgrep. Python checks and stages this bundle. Node runs Ponytail's existing hooks. Check individual workflows for additional prerequisites.

Keep existing model choices, native permission boundaries, and hook trust. Workflow instructions do not authorize commits, external agent launches, or deployments on their own.

## Global instructions

Merge all global rules from the harness guide into the destination's instructions. Claude and Codex templates include prose, context, and external agent rules. Preserve other user guidance. Skills use native discovery; keep obsolete Pstack routing out of the profile.

Ponytail defaults to full mode. Its task ledger and optional webhook remain destination settings; this bundle contains no user configuration or data.

## Sloptrim

[Sloptrim](https://github.com/seyedehsanhadi/sloptrim) is pinned at `9b3e2efe6ab64d9b60c214ad1213b2b30bbddb27` (0.9.6). The package keeps the upstream skill, Python detector, pattern reference, Claude hooks and marketplace, command wrapper, Cursor rule, and license files unchanged. Tests, recordings, images, and research tools are omitted. Source and payload hashes are in `sources.json`.

Every harness stages it at `skills/sloptrim/`. Claude registers that directory as a native marketplace. Codex, Hermes, and Pi copy it into their loose skill directories. Those loose installs use the skill and global prose rule to run the detector; they do not register Claude hooks. The detector accepts a file path:

```sh
python3 /absolute/path/to/sloptrim/scripts/detect.py README.md
```

Read `_metrics.ai_tell_score` and the flagged spans. Revise only prose that needs it, preserve facts and code, and score the saved file again. When writing docs, READMEs, or skills, pair the `unslop` skill with Sloptrim. Use `unslop` to revise prose, then score the saved files with Sloptrim before committing or sharing them. Instruction files and skills need this explicit check because the Claude save hook exempts them. Keep third-party skill bodies unchanged.

## External agents

When the user requests another agent, use the requested harness and model. Choose the Herdr backend before launching it, as described below. For App/core, read `hc --skill` and follow its interactive-agent workflow, including Codex `--no-daemon`. For standalone terminal Herdr and work outside App/core, prefer the harness's native headless CLI for reviews, second opinions, and results to parse. Keep review isolation on each headless invocation; the Codex profile's interactive approval and sandbox defaults stay unchanged.

The following flow was tested with Codex 0.166.0 and Herdr 0.9.5 on macOS in November 2026. Check the installed CLI help before using it on another version.

Write `prompt.md` with the question, repository, review base, scope, relevant files, and constraints. Ask for concise findings with file and line evidence and checks run. Require substantive text followed by a final line containing only `REVIEW_COMPLETE`, including when there are no findings. An empty prompt can exit 0, so exit status alone does not prove a review happened.

Run from Bash. Replace the repository and model values. Use the user's requested reasoning effort when specified. Each turn needs fresh result, log, and status files:

```sh
review_repo=/absolute/path/to/repo
review_model=MODEL
review_dir=$(mktemp -d)
review_status=0
codex exec --ignore-user-config --ignore-rules \
  -c 'approval_policy="never"' -c 'model_reasoning_effort="high"' \
  --sandbox read-only -C "$review_repo" -m "$review_model" \
  -o "$review_dir/result.md" --color never - < prompt.md \
  > "$review_dir/run.log" 2>&1 || review_status=$?
printf '%s\n' "$review_status" > "$review_dir/exit-code"
```

The isolation flags kept project config and execution rules from overriding review policy in the test. Login still worked. They do not disable instruction files. Put the review boundaries in the prompt. Ignoring config dropped reasoning effort to `none`, so set it explicitly. The read-only sandbox blocked writes by the agent; Codex still writes its own session and result files. The web tool remained available.

Read `run.log` and save its `session id:` value. Omit `--ephemeral` when follow-ups need the earlier context. Resume the exact ID from the same repository. `resume` has no `--sandbox` or `-C` option, so set the sandbox through `-c`:

```sh
review_session=SESSION_ID
review_next_prompt="$PWD/next.md"
review_status=0
(
  cd "$review_repo" || exit
  codex exec resume --ignore-user-config --ignore-rules \
    -c 'approval_policy="never"' -c 'model_reasoning_effort="high"' \
    -c 'sandbox_mode="read-only"' -m "$review_model" \
    -o "$review_dir/follow-up.md" "$review_session" - < "$review_next_prompt"
) > "$review_dir/follow-up.log" 2>&1 || review_status=$?
printf '%s\n' "$review_status" > "$review_dir/follow-up-exit-code"
```

Require exit code 0, a final `REVIEW_COMPLETE` line, and substantive text before it for every turn. Read the final response file and summarize the findings. Missing files, a missing marker, or a marker alone mean the review is incomplete. Use fresh paths again for later turns so stale results cannot pass this check.

With standalone terminal Herdr selected and `HERDR_ENV=1`, use the installed `herdr` skill for caller resolution and pane commands. Create a sibling pane with `herdr pane split --current --cwd "$PWD" --no-focus` and the direction chosen by the skill. Run the same headless command through `herdr pane run <returned-pane-id> "bash <script>"`. Have the script write the exit status to a file. If output goes through `tee`, enable `set -o pipefail` before the pipeline and capture its status. A successful `pane run` only confirms command submission. Read the result files for completion; narrow panes can wrap interactive screen output badly.

## Herdr

Standalone terminal Herdr and Herdr App/core use separate servers. Their terminal and pane IDs are not interchangeable.

| Target | CLI and installed guide | Caller context |
| --- | --- | --- |
| Standalone terminal TUI | `herdr`, installed `herdr` skill from `herdr --skill` | `HERDR_ENV=1`, `HERDR_PANE_ID` and the selected socket/session |
| App terminals and agents | `hc`, `hc --skill` | `HC_TERMINAL_ID` and the selected core/machine |
| App window, spaces, layouts and mods | `herdr-app`, `herdr-app --skill` | App IDs from `herdr-app ls`; `HERDR_APP_HOME` selects the window |

Use App/core only when requested or when the verified caller is a core terminal. Use the requested backend. When choosing from caller context, verify the caller on that backend before changing panes. Markers can be inherited or stale, including when both sets are present. A missing target or failed connection is not a reason to switch servers. Pass new agents the backend, server/machine, returned IDs and working directory.

Keep generated skills and guides unchanged. The Claude and Codex global templates hold the routing rule; the selected backend's installed manual owns syntax and lifecycle handling. The App's guide at `${HERDR_APP_HOME:-$HOME/.config/herdr-app}/AGENTS.md` is rewritten on startup. Read it before customizing the App. The [App bundle](../herdr-app/README.md) installs mods and a layout, with no bridge to the TUI server.

The shared `herdr-core` skill is an unchanged upstream router, pinned in `universal/sources.json` and staged for Claude and Codex. Install it with the matching global routing rules, as described in the [App guide](../herdr-app/README.md#install-the-agent-skill). It reads the current manuals rather than carrying copied API documentation. The standalone `herdr` skill remains a separate CLI-managed install.

## Refresh the standalone TUI skill

From the repository root, refresh every installed Claude, Codex, Pi and Hermes profile:

```sh
bash scripts/install-herdr.sh
```

Run this after upgrading standalone Herdr, or run `ansible-playbook setup.yml --tags herdr`. The updater reads `herdr --skill` and uses Herdr's native integration installer. It respects `CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `PI_CODING_AGENT_DIR` and `HERMES_HOME`. It does not install App/core skills or integrations. Windows keeps its existing Claude/Codex setup. OpenCode's instruction and skill loading remain unverified.

Inspect planned changes without writing:

```sh
bash scripts/install-herdr.sh --check
```

The check reports drift with `changed:` lines; its exit code alone is not a drift check. For exact skill verification, compare each generated `SKILL.md` with `herdr --skill` output. Use `herdr integration status` to check native integration revisions. After an upgrade, check `herdr status` for client/server compatibility. The installed skill matches the client binary; the running server may still be older.

Pass new agents the IDs and working directory returned by Herdr, scoped to the same server and machine. Keep this snapshot in the conversation. Inherited environment variables can be stale when tools run through a shared daemon. If caller identity remains unclear, ask before changing panes. Automatic startup context needs a separate, verified integration for each harness.
