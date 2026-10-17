# Native Windows Codex reference

Source snapshot **2026-10-17**, native **Codex CLI 0.163.0**. Profile `<USER_HOME>/.codex`. Executable `<USER_HOME>/AppData/Local/Programs/OpenAI/Codex/bin/codex.exe`.

This records observed state, not approved future desired state. Defaults are candidates for reviewed recreation only. The deleted repository `codex/` bundle was excluded. This worker owns only this document and [codex-inventory.json](codex-inventory.json). Existing repository edits and the ahead commit were preserved. No commit or push was performed.

## Evidence and counts

The coordinator's native `codex plugin list --json`, run from the user home, reports **11 installed, 11 enabled, 0 disabled**. Its sanitized handoff is identified as `<AUDIT_SCRATCH>/agent-audit-native-lists.json`. This worker's sandbox returned only four local/Git plugins because the remote catalog request failed. Visibility depends on execution context. Both contexts report three configured marketplace roots.

User TOML was safely parsed with Python 3.12 standard-library `tomllib`. Skills were enumerated by code under the exact installed-version directories and loose skill roots. Marketplace source copies and uninstalled cached versions were excluded from counts.

| Inventory category | Count |
|---|---:|
| Installed plugins / enabled / disabled | 11 / 11 / 0 |
| Configured marketplaces | 3 |
| Installed-plugin `SKILL.md` files | 153 |
| Plugin skill files within manifest roots | 136 |
| Plugin skill files outside manifest roots | 17 |
| Loose skill files, including system skills | 10 |
| All enumerated physical skill files | 163 |
| Manifest roots plus loose files, static candidates | 146 |
| Manual-only files by metadata | 116 |
| Files without an explicit implicit-invocation restriction | 47 |
| Agent prompt files / Cursor rule artifacts | 2 / 1 |
| Configured MCP servers / persisted hook-trust records | 2 / 4 |

The JSON contains every skill's exact placeholder-normalized path, name, complete description, source/plugin grouping, version, policy metadata, policy-file path, manifest containment, and SHA-256. `counts.policy_by_group` contains computed subtotals. No skill bodies or configuration files are copied into the repository.

**Installed** and **enabled** come from native CLI evidence. **File-enumerated** means a file exists. **Manifest-registered** means its path falls inside a selected native manifest's declared skill roots. These static counts are not runtime-discovered counts. **Active** requires session evidence. **Untested** includes skill behavior, hook execution, MCP connectivity, app authorization, and model availability. This session contains Ponytail full instructions, but the audit does not establish which hook originally supplied them.

Live installed CLI help is the authority for observed command syntax. OpenAI's canonical [skills and plugins reference](https://learn.chatgpt.com/docs/skills-and-plugins) and [hooks reference](https://learn.chatgpt.com/docs/hooks) were opened during the audit.

## Installed plugins and provenance

All entries below are installed and enabled. Exact cache roots follow `<USER_HOME>/.codex/plugins/cache/<marketplace>/<name>/<version>/`. Each exact root and selected manifest path is recorded in JSON.

| Plugin ID | Version | Skill files / within manifest roots |
|---|---|---:|
| `mattpocock-skills@mattpocock` | `1.3.1` | 38 / 27 |
| `ponytail@ponytail` | `5.3.2` | 12 / 6 |
| `pstack@engineering-adaptations` | `0.15.25-codex.1` | 57 / 57 |
| `mattpocock-extras@engineering-adaptations` | `1.3.1-codex.1` | 9 / 9 |
| `github@openai-curated-remote` | `0.1.12-5f7cd798dc99` | 0 / 0 |
| `cloud-environment@openai-curated-remote` | `0.1.2` | 1 / 1 |
| `openai-templates@openai-curated-remote` | `0.1.6` | 27 / 27 |
| `pages@openai-curated-remote` | `0.1.23` | 4 / 4 |
| `sites@openai-curated-remote` | `1.0.0` | 1 / 1 |
| `plugin-management@openai-curated-remote` | `0.1.0` | 1 / 1 |
| `work-pets@openai-curated-remote` | `0.1.6` | 3 / 3 |

Matt's upstream bundle contains 11 experimental/misc skill files outside its native manifest roots. Ponytail contains six alternate OpenClaw skill files outside its native `skills/` root. They are individually enumerated as physical files, not additional native registrations.

| Configured marketplace | Source | Root under `<USER_HOME>/.codex/` |
|---|---|---|
| `mattpocock` | `https://github.com/mattpocock/skills.git` | `.tmp/marketplaces/mattpocock` |
| `ponytail` | `https://github.com/DietrichGebert/ponytail.git`, ref `main` | `.tmp/marketplaces/ponytail` |
| `engineering-adaptations` | Local marketplace | `plugins/local-marketplaces/engineering-adaptations` |

`openai-curated-remote` is an account-backed source group, not a fourth configured local marketplace. Connector IDs were omitted. Remote manifest repository declarations are recorded in JSON, but are not proof of public accessibility or a sufficient reinstall source.

Matt's marketplace snapshot HEAD is `49dd158d1076134a641b33efb035946536778336`. Ponytail's is `16352ac229eb08a9598dcae48fe9f2b342567d86`. Snapshot revisions do not establish cached-payload equivalence. Remote version suffixes are not independently verified commits.

## Loose skills and local adaptations

All loose paths below are under `<USER_HOME>/.codex/skills/`. `<USER_HOME>/.agents/skills` does not exist.

| Skill path | Source and policy |
|---|---|
| `.system/imagegen/SKILL.md` | Codex-managed; implicit-eligible metadata |
| `.system/openai-docs/SKILL.md` | Codex-managed; implicit-eligible metadata |
| `.system/review-agent/SKILL.md` | Codex-managed; manual-only `agents/openai.yaml` |
| `.system/skill-creator/SKILL.md` | Codex-managed; implicit-eligible metadata |
| `.system/skill-installer/SKILL.md` | Codex-managed; implicit-eligible metadata |
| `blender-skill/SKILL.md` | Local Windows adaptation; implicit-eligible metadata |
| `epic-unreal-create-toolset/SKILL.md` | Epic skill-only port; implicit-eligible metadata |
| `epic-unreal-mcp/SKILL.md` | Epic skill-only port; implicit-eligible metadata |
| `epic-unreal-skill/SKILL.md` | Epic skill-only port; implicit-eligible metadata |
| `herdr/SKILL.md` | Herdr-managed; implicit-eligible metadata, explicit Herdr context required by instructions |

- **Pstack** derives from `https://github.com/cursor/plugins`, with local version `0.15.25-codex.1`. Its adapter registers 54 main skills and three Benny guides. The local source matches the installed cache across 205 files, with no differing, missing, or source-only files. No pinned upstream commit, complete patch series, or reproducible adapter build recipe was found.
- **Matt extras** derives from `https://github.com/mattpocock/skills.git`, with local version `1.3.1-codex.1`. Its nine experimental/misc skills are manual-only. Claude handoff and Claude-specific guardrails are excluded from this adapter's manifest. Local source and installed cache match across 22 files. A pinned upstream commit and complete patch recipe remain unresolved.
- **Blender** provenance records `https://github.com/kajisho5/blender-skill` at `39547d9e118451891c3ff68e087e20c5bde1599c`, version `0.31.0`. It records a labeled Windows note as the only skill change and unchanged source scripts, references, license, and inert MCP sources. The note addresses Python Store aliases, explicit interpreter selection, Blender discovery, and headless use. It records an animation limitation involving `Action.fcurves`; that historical claim was not retested.
- **Epic ports** record `https://github.com/EpicGames/unreal-engine-skills-for-claude-code-plugin` at `a6aa73ada02a9fb1f5415bec491f9942c519b297`, plugin version `3.1.1`. Changes include namespaced names, a labeled Codex/Hermes adapter, corrected companion routing, and conditional existing-MCP mappings. References and MIT license are retained. Upstream Claude manifests and startup hook are inactive. All three current skill hashes match their provenance records.
- **Herdr** has a managed hook script marked integration version 10. Its loose skill upstream URL and revision are not established by inspected metadata. Managed integration updates can overwrite the script.

Blender and Epic provenance lives beside each skill as `INSTALL-PROVENANCE.json`; only selected nonsecret fields were retained in JSON. Those are local provenance claims, not fresh upstream-diff results. Recreating the ports requires pinned source plus reviewed changes and destination-specific paths. The two engineering adapter trees are not archived here, so their unresolved source/patch gaps must be resolved before reproduction. System skills and remote payloads may differ across distributions or accounts.

## Instructions, agents, and routing

`<USER_HOME>/.codex/AGENTS.md` supplies user-scope entry instructions. Nontrivial engineering work explicitly reads pstack `poteto-mode/SKILL.md`; its manual metadata does not make it implicitly invocable. Matching reusable Matt workflows may be implicit. Orchestration/setup flows and every extras skill require user invocation. Ponytail full is the observed default, subject to user opt-outs.

The guidance maps Cursor task/question/rule concepts to available Codex capabilities, preserves the parent's model and reasoning, and forbids launching Cursor. Missing automation, IDE control, deslop, and other capabilities remain limitations. Benny guides are not evidence of scheduled services. Most pstack metadata is manual-only; `setup-pstack` is the exception.

Two pstack agent prompt files exist at its installed root's `agents/poteto-agent.md` and `agents/comment-sicko.md`. They are prompt guidance, not registered native custom agent types. No user `.codex/agents` directory or `[agents]` setting was observed. The system `review-agent` skill is separate. Ponytail's `.cursor/rules/ponytail.mdc` is a Cursor artifact, not an active native Codex rule. No user `.codex/rules` or `instructions.md` was found.

No repository-root `.agents`, `.codex`, `AGENTS.md`, or `AGENTS.override.md` was found. No ancestor AGENTS guidance was found in the user home, its parent, or drive root. Repository search found no descendant-specific AGENTS overrides. Prompt-supplied AGENTS instructions remain applicable session instructions. The deleted repository bundles were excluded.

## Permissions, hooks, and MCP

| User setting | Observed value |
|---|---|
| `approval_policy` | `on-request` |
| `approvals_reviewer` | `auto_review` |
| `sandbox_mode` | `workspace-write` |
| `windows.sandbox` | `unelevated` |
| `features.hooks` | `true` |
| Project trust | One trusted project entry; identity omitted |
| Model / reasoning effort | Not explicitly set in user TOML |

These settings preserve **Smart Approve-for-me**. Live help documents `--approve-for-me` as automatic approval review with workspace-write. Model UI history was excluded and does not establish a default model. Host-selected defaults, organization policy, and launch arguments can differ. No named profile TOML appeared in the user-profile top-level listing. Machine policy was not independently audited.

Four persisted hook-trust records cover one user SessionStart hook and three Ponytail events. Trust hashes were omitted. Their presence does not prove execution or a current hash match. No hook was invoked or trusted by this audit.

| Hook source | Events and prerequisites |
|---|---|
| `<USER_HOME>/.codex/hooks.json` | SessionStart invokes `<USER_HOME>/.codex/herdr-agent-state.ps1` using PowerShell, timeout 10 seconds. It guards on session action, `HERDR_ENV=1`, `HERDR_PANE_ID`, and valid session input, then reports session identity to Herdr. |
| Ponytail root `hooks/claude-codex-hooks.json` | SessionStart, UserPromptSubmit, SubagentStart use Node and host-supplied `CLAUDE_PLUGIN_ROOT`, timeout 5 seconds. Targets are `ponytail-activate.js`, `ponytail-mode-tracker.js`, and `ponytail-subagent.js`. They inject instructions and maintain state. |

The Ponytail marker exists at `<USER_HOME>/.codex/plugins/data/ponytail-ponytail/.ponytail-active`; its contents were not read. Source fallback is `full`. Neither `<USER_HOME>/AppData/Roaming/ponytail/config.json` nor `<USER_HOME>/.config/ponytail/config.json` exists. Environment overrides were not inspected. Hooks can affect shared preferences and require separate source review and trust approval on the destination.

Two URL-based MCP servers are configured, with endpoints redacted as `<PRIVATE_ENDPOINT>`.

| Name | Prerequisites and overrides |
|---|---|
| `unreal-engine` | Existing Unreal editor project and matching unreal-mcp integration/service, destination endpoint, and current schemas. `tools.list_toolsets.approval_mode = "approve"` is configured. Ports identify existing host prefix `mcp__unreal_engine__`, still requiring destination verification. |
| `blender` | Existing compatible Blender MCP integration/service and destination endpoint. No per-tool override observed. The separate loose headless pipeline's bundled MCP source is unregistered. |

Neither server has an explicit disabled flag. Neither was contacted. Configuration does not establish connectivity or usable tools. All seven remote plugins declare app manifests; account authorization and available tools were not tested. An installed cloud-environment plugin does not establish a managed cloud runtime.

## Candidate recreation procedure

This procedure is reference-only and was not executed.

1. Consult this `agent-setup/` folder, its coordinator README, this guide, and the JSON. Inspect the destination's real instructions, native version, installed plugins, marketplaces, safely parsed configuration, skills, hooks, and trust state. Do not read credentials or transcripts.
2. Present a concrete comparison and plan for review and approval. Separate observed source state from desired destination state. Include every proposed write, unresolved source/patch gap, version difference, and prerequisite. Install natively only as explicitly authorized. Disabled entries stay disabled; destination-disabled entries must not be silently enabled.
3. Use an approved native Windows Codex distribution and native plugin commands. Never use symlinks, junctions, Ansible, or blind profile copying. Do not copy authentication, history, sessions, project trust, or hook-trust hashes.
4. Preserve Smart Approve-for-me, workspace-write, and the independent hook-trust gate. Review model and reasoning choices rather than inventing a pinned default. Review each destination project's trust separately.
5. Recover pinned sources and reviewed adapter patches before proposing the local engineering marketplace. Recreate authorized loose ports as ordinary directories with reviewed modifications and licenses. Do not link another harness's skill tree or infer missing patches from a version suffix.
6. Review hook commands, dependencies, state writes, and shared-setting effects. **Ask separately for hook trust.** Installation approval is not hook-trust approval. Do not use sandbox or hook-trust bypass flags.
7. Add MCP settings only if separately authorized, using destination endpoints and existing prerequisites. Inventory verification must not start editors, services, proxies, remote execution, or MCP tools. App authorization is a separate account operation.
8. Verify versions, enabled states, source provenance, skill paths/policies, and preserved approval settings read-only. Report static enumeration separately from runtime discovery. Obtain authorization before tests that launch coding requests, hooks, MCP, or services.

These exact inspection forms were confirmed against live 0.163.0 help. Network-dependent lists can be incomplete; retain warnings and compare the intended native launch context.

```powershell
codex --version
codex --help
codex plugin --help
codex plugin list --help
codex plugin list --json
codex plugin marketplace --help
codex plugin marketplace list --help
codex plugin marketplace list --json
codex plugin marketplace add --help
codex plugin add --help
codex mcp --help
```

The following are **future mutations requiring explicit authorization of the reviewed plan**. None was executed. The local marketplace must first be reconstructed and reviewed.

```powershell
codex plugin marketplace add https://github.com/mattpocock/skills.git
codex plugin marketplace add https://github.com/DietrichGebert/ponytail.git
codex plugin marketplace add '<REVIEWED_LOCAL_MARKETPLACE>'
codex plugin add mattpocock-skills@mattpocock
codex plugin add ponytail@ponytail
codex plugin add pstack@engineering-adaptations
codex plugin add mattpocock-extras@engineering-adaptations
```

Marketplace add supports `--ref <REF>`, `--sparse <PATH>`, and `--json`. Plugin add supports `PLUGIN@MARKETPLACE` or `PLUGIN --marketplace MARKETPLACE`, and `--json`. Neither help surface supplies a payload-version selector or dedicated plugin-enable command. Top-level `--enable` changes feature flags, not a plugin's enabled state. Do not invent version or enable flags. Inspect the destination's account-backed catalog before proposing remote installs; matching names do not guarantee availability or pinning.

## Verification and limits

Checks cover JSON parsing, unique plugin IDs and skill paths, complete names/descriptions, per-group counts, current skill hashes, manifest containment, and local adapter source/cache equality. Sanitization checks exclude raw user paths, the source username, configured private endpoint values, and common secret assignments. No skill bodies, raw configuration/environment, auth files, credentials, tokens, transcripts, or project/user history were exported.

This artifact-only check neither launches Codex nor executes hooks.

```powershell
$inventory = Get-Content -Raw -LiteralPath ./agent-setup/codex-inventory.json | ConvertFrom-Json
$inventory.counts
$inventory.skills | Group-Object group | Select-Object Name, Count
if ($inventory.skills.Count -ne $inventory.counts.skills_total) { throw 'Skill count mismatch' }
if (($inventory.skills.path | Sort-Object -Unique).Count -ne $inventory.skills.Count) { throw 'Duplicate skill paths' }
```

The first shell read loaded the existing PowerShell startup profile, which attempted `fnm` multishell setup and received access denied. Subsequent commands used no-profile execution. Codex list/help also emitted access-denied warnings for temporary alias creation and stale-temp cleanup. No cleanup or repair was attempted. Git inspection used a command-local safe-directory override after ownership checks blocked ordinary status, without changing global Git configuration.

Runtime behavior, services, entitlements, host-selected defaults, and complete machine policy remain untested. Local provenance claims were not independently checked against fresh upstream sources. Unresolved pstack/extras patches and Herdr skill provenance remain recreation gaps. Only the two owned Codex documents were written by this worker.
