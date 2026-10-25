# Native Windows Claude Code reference

Snapshot 2026-10-17. Native Claude Code **2.1.302**. This is an observation record, not an approved desired configuration or deployment source. The exhaustive, sanitized component listing is [claude-inventory.json](claude-inventory.json). It includes names, frontmatter descriptions, invocation policy, provenance, scope, registration eligibility, and file SHA-256 values. No skill instructions or configuration bodies are reproduced.

## Installed plugins

Native CLI output and the current install registry identify five installed plugins. All five are user-enabled; zero are user-disabled. Marketplace catalogs and old cache directories are not installation evidence.

| Plugin and marketplace | Version | Source | Installed revision | Skill files / registered candidates |
| --- | --- | --- | --- | --- |
| chrome-devtools-mcp@claude-plugins-official | 1.11.0 | [ChromeDevTools/chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) | a878bcad39584337e055778353246820deafa7c0 | 7 / 7 |
| mattpocock-skills@claude-plugins-official | 1.3.1 | [mattpocock/skills](https://github.com/mattpocock/skills) | 49dd158d1076134a641b33efb035946536778336 | 38 / 27 |
| pstack@cursor-plugins | 0.15.25 | [cursor/plugins](https://github.com/cursor/plugins), marketplace source ./harness/pstack/claude-code | cdb3c41c9f2f6d41f050e3dc25e15e325493d499 | 54 / 54 |
| ponytail@ponytail | 5.3.1 | [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail), marketplace source ./ | 6f1c2bfff0c837d268929a7c4e490918eb4fab29 | 12 / 6 |
| unreal-engine-skills-for-claude-code@claude-plugins-official | 3.1.1 | [EpicGames/unreal-engine-skills-for-claude-code-plugin](https://github.com/EpicGames/unreal-engine-skills-for-claude-code-plugin) | a6aa73ada02a9fb1f5415bec491f9942c519b297 | 3 / 3 |

**Desired change:** replace `pstack@cursor-plugins` with `pstack@open-pstack` from [Open Pstack](https://github.com/ericlitman/open-pstack) (1.16.0, commit `b4c5e3d63318308b7e11f26b2bc156e7793d834a`, tracking pstack 0.15.29). Both register skills under the `pstack:` prefix, so uninstall the Cursor package before installing Open Pstack. The table above remains the observed snapshot.

The three configured marketplace sources are [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official), [cursor/plugins](https://github.com/cursor/plugins), and [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail). Marketplace source revisions can differ from the installed payload revision. No refresh was run.

The coordinator's native list from <USER_HOME> reports projectEnabled=true for all five. This audit's native list from <REPO> reports projectEnabled=false for all five while enabled=true remains unchanged. These are separate scope-dependent fields. No explicit plugin override was found in the selected home/repo project records, and no repo .claude/settings.json or settings.local.json exists. The cause of the projectEnabled difference is unresolved. It does not mean that the plugins are globally disabled. Runtime session loading was not tested.

## Component counts and policy

| Category | Exact count |
| --- | ---: |
| Installed plugin SKILL.md files | 114 |
| Registered plugin skill candidates | 97 |
| Supporting or undeclared plugin SKILL.md files | 17 |
| Loose SKILL.md files | 15 |
| Standard loose skill candidates | 2 |
| Reserved synced skill files | 13 |
| Total SKILL.md files inventoried | 129 |
| Custom commands | 0 |
| Custom agents | 2 |
| Hook command declarations | 5 |
| Hook module registrations | 1 |
| Configured MCP names | 3 |
| Runtime-verified active components | 0 |

Registered candidates use explicit manifest skill directories where present, otherwise immediate skills/<name>/SKILL.md entries. All exact SKILL.md files in the five registered install roots are listed, including supporting files. Matt's 11 in-progress/misc entries are not manifest-listed callable entries. Ponytail's six .openclaw duplicates are not Claude skill entries. No stale version or uninstalled plugin is counted.

Among the 99 standard candidates, 69 declare disable-model-invocation=true and 30 do not. This describes metadata eligibility, not automatic execution. User guidance further limits selection. The two custom agents are pstack:comment-sicko, a comment/code review delegate, and pstack:poteto-agent, a helper for poteto workflows. No user or repo commands, agents, or rules directories were found.

The standard loose skills are blender-skill and herdr. Both are ordinary local directories, not links. The shared <USER_HOME>/.agents/skills directory is absent. The 13 discovered skills under <USER_HOME>/.claude/skills/synced/<SYNCED_BUNDLE>/ are grouped separately in the inventory. Their exact names remain intact. They are host-managed content with unverified live discovery and unknown portable source revisions. Their presence does not authorize account-service connections or copying the synced bundle.

## Guidance, settings, and entry routes

<USER_HOME>/.claude/CLAUDE.md routes nontrivial engineering work through pstack poteto-mode and its Claude adapter, permits one or two matching Matt skills, reserves user-only Matt workflows for explicit invocation, and delegates Ponytail activation to its hooks. Trivial tasks skip poteto-mode. These instructions grant no permissions and yield to explicit user choices and project guidance.

<REPO>/CLAUDE.md supplies repository conventions and says setup does not deploy Claude or Codex configuration. No repo CLAUDE.local.md, .claude settings, skills, commands, agents, rules, or .mcp.json was found. Selected home and repo project records both have hasTrustDialogAccepted=true, empty allowedTools lists, no project MCP entries, and empty enabled/disabled MCP JSON lists. Workspace trust does not establish approval of each hook.

The selected settings contain permissions.defaultMode=auto, skipDangerousModePermissionPrompt=true, autoUpdatesChannel=latest, and no explicit model or statusLine. The global non-secret fields identify a native installation, completed onboarding, and autoUpdates=false. These updater observations are recorded separately; their runtime interaction was not tested. No resolved model was inferred. PONYTAIL_DEFAULT_MODE and the existing Ponytail mode marker both say full. A marker is historical state, not proof that a hook ran during this audit.

remote-settings.json is empty. Selected policy-limits fields record web-search MCP isolation allowed=false and remote-control-at-startup=false. Enterprise registry policies, process launch options, and environment overrides were not audited. No live profile changes occurred. Native executable resolution reports claude.exe version 2.1.302.0.

Live help distinguishes --permission-mode, --dangerously-skip-permissions, --restricted, --safe-mode, --bare, --setting-sources, and --strict-mcp-config. Session options can change effective behavior. Help says print/non-TTY operation skips the workspace trust dialog. No prompt session, print session, doctor, or evaluation was run.

## Hooks and trust

| Source | Entry points | Static behavior and prerequisites |
| --- | --- | --- |
| User settings | SessionStart, startup/resume/clear/compact/fork | PowerShell NoProfile invokes <USER_HOME>/.claude/hooks/herdr-agent-state.ps1 with session, timeout 10 seconds. Herdr-managed integration version 11. It exits unless HERDR_ENV=1 and a pane ID exists, rejects Cursor/subagent events, and reports session identity and optional transcript path to Herdr. No transcript was read. |
| Ponytail plugin | SessionStart, SubagentStart, UserPromptSubmit | Node loads activation, subagent, and mode-tracker JavaScript, each timeout 5 seconds. Activation can write a mode marker, inject rules, run its map helper, and emit a statusline setup notice. |
| Ponytail plugin | Module registration | hooks/claude-band.json declares ./band/register.tsx. The plugin manifest exposes ledger and optional webhook settings. User configuration values and keychain data were not read; ledger, outbound delivery, and module loading remain unverified. |
| Unreal plugin | SessionStart, startup/resume/clear | Bash runs hooks/unreal-context.sh, timeout 5 seconds. It scans parent directories for Unreal project markers and emits a short context note. Git Bash or another compatible Bash is required on native Windows. |

All entries are configured or declared, with execution untested. No hook, trust, reload, or activation operation was invoked. PowerShell ExecutionPolicy Bypass in a hook command is distinct from Claude permission bypass. Neither is a recommended migration default. A future operator must approve hooks separately after source and side-effect review.

## MCP configuration and prerequisites

| Name | Configuration | Prerequisite and limitation |
| --- | --- | --- |
| unreal-engine | User global HTTP server at <PRIVATE_ENDPOINT> | A running Unreal Editor with the relevant MCP plugin and a matching reviewed endpoint. The installed skill refers to unreal-mcp or unreal-mcp-proxy, so alias and transport compatibility need deliberate validation. |
| blender | User global HTTP server at <PRIVATE_ENDPOINT> | A running compatible Blender MCP bridge. This connection is independent from the local headless blender-skill. |
| chrome-devtools | Plugin stdio declaration, npx chrome-devtools-mcp@1.11.0 | Node.js, npm/npx, compatible Chrome, and reviewed package acquisition. Native plugin list reports dependencies-refused because package overrides were not applied during install. |

These are configured names, not verified connections. No MCP command or service connection was run. Endpoints, headers, credential values, and account identifiers are omitted.

## Local sources and reproducibility

Blender's local UPSTREAM.md records [kajisho5/blender-skill](https://github.com/kajisho5/blender-skill), v0.31.0, commit 39547d9e118451891c3ff68e087e20c5bde1599c, MIT. It describes a manual copy of the upstream payload and a single local Windows note in SKILL.md. The note replaces Store-stub Python assumptions with an explicit interpreter, identifies local Blender discovery, distinguishes conservative budgets from official limits, and records animation failure on Blender 5.2.2. Tests, evals, examples, installer, and plugin manifest were not copied. Generated bytecode caches are not upstream payload. The upstream-byte-identity assertion and earlier runtime results come from that note and were not independently rechecked here. A future reconstruction needs the pinned source, a reviewed equivalent note using destination-local paths, and targeted verification before animation use.

Unreal's three installed skills come from Epic's native plugin at the revision above. Their frontmatter, manifest, context hook, and setup/operations references were inspected. They cover live editor operations, AI-callable toolset authoring, and Unreal Agent Skill authoring. No separate loose Unreal adapter was found in the scoped Claude directories. No local delta ledger or byte comparison against a fresh pinned upstream checkout was available, so byte-for-byte reproducibility is unproven. The configured HTTP server is separate local connection state; installing the skills does not configure or validate it.

pstack is the native Claude payload from cursor/plugins, including docs/harness/claude-code.md. That adapter maps Cursor task, question, model, path, and workflow names to Claude equivalents and identifies unsupported capabilities. Its presence does not prove every Cursor workflow works on native Windows. Global routing selects the newest cached pstack version, whereas this inventory follows the installed registry version. A future review should reconcile those selectors before changing anything. The desired setup replaces this payload with Open Pstack, which ships its own Claude startup instruction and model registry; global routing that names the Cursor adapter path must be updated to Open Pstack's `poteto-mode` when the swap is made.

Herdr's loose skill is release-provided. The repo's windows/install-herdr.ps1 obtains the installed binary's skill and installs integrations. The copied skill has no pinned release revision; the hook identifies integration version 11. This is a reproduction gap, not permission to run the installer.

## Future-agent review recipe

A future agent starts by reading this folder's claude.md and claude-inventory.json from <REPO>/agent-setup/. These files are reference evidence only.

1. Inspect the destination's native CLI version and live help, installed/enabled lists, marketplace sources, selected settings, guidance, project overrides, and prerequisites. Exclude secrets and transcripts.
2. Compare observed state with the user's desired state. Prepare a concrete list of reviewed native marketplace/plugin installs and selective configuration edits. Preserve disabled plugins as disabled. Do not treat this snapshot as approval.
3. Propose only missing approved native installs. Live 2.1.302 help supports claude plugin marketplace add <source> --scope user and claude plugin install <plugin>@<marketplace> --scope user. Recheck help on the destination and verify resulting version/revision. Do not install every catalog entry, accept marketplace commands blindly, or assume current marketplace heads reproduce these pins. Install the commits in the README's [target revisions](README.md#target-revisions), not the observed ones above, and only after each source passes the README's [security audit](README.md#security-audit-before-installing).
   For pstack, the approved target is Open Pstack rather than the observed Cursor package. Inside Claude Code, Open Pstack documents `/plugin marketplace add ericlitman/open-pstack`, `/plugin install pstack@open-pstack` and `/reload-plugins`; the CLI equivalents are `claude plugin marketplace add ericlitman/open-pstack --scope user` and `claude plugin install pstack@open-pstack --scope user`. If `pstack@cursor-plugins` is installed, uninstall it first (`claude plugin uninstall pstack@cursor-plugins --scope user`; recheck help). Then run `/pstack:setup-pstack` to save the model sheet. The default three-model panel also needs authenticated Codex and Grok CLIs and [Bun](https://bun.sh); fewer models still work.
4. Review local Blender, Herdr, and Unreal provenance gaps before proposing replacement files or connections. Use ordinary native files with reviewed destination-specific changes. Do not copy account-managed synced bundles.
5. Preserve destination permission choices. Review auto mode and prompt suppression independently. Do not carry over bypassPermissions, dangerous CLI flags, trust flags, or broad allowlists by imitation.
6. Present hook code, entry points, writes, data movement, prerequisites, and the exact proposed trust change. Ask separately for hook trust approval. Workspace trust or plugin installation alone is insufficient.
7. After separately authorized changes, verify lists and sanitized selected fields first. Runtime sessions, hooks, MCP connections, and app services require their own authorized validation scope.

No symlinks, junctions, Ansible deployment, blind profile copying, or copying an entire Claude home is part of this recipe. No commit or push is authorized by this reference.

## Verification and evidence limits

The inventory was generated programmatically from the current five installed roots, their manifests and marketplace entries, and selected loose directories. Frontmatter extraction supports quoted and folded descriptions and keeps only selected metadata. Counts distinguish exact files from registration candidates. JSON parsing, count reconciliation, component uniqueness, hashes, and sanitization were checked against the delivered artifacts.

Read-only evidence includes native version/help/list commands, current plugin registries, selected non-secret settings/global fields, global and repo guidance, and inspected hook/provenance source. The coordinator's sanitized home list was read and compared with the repo list. Git inspection used a per-command safe.directory exception without altering Git configuration. HEAD was aec9f74, one commit ahead and zero behind upstream. Existing repo changes belong to their owners and were preserved.

The first shell loaded the existing PowerShell profile and attempted an fnm multishell symlink, which failed with access denied. Subsequent audit commands used profile-free execution. The Python command resolved to a Store stub and failed; Node performed the inventory scan. No Python or fnm setup was changed.

The [plugin overview](https://code.claude.com/docs/en/plugins/overview), [skills reference](https://code.claude.com/docs/en/skills), and [hooks reference](https://code.claude.com/docs/en/hooks) were supplied as coordinator-verified official references. They describe namespaces, synced skills, live detection, and hooks. This audit did not independently fetch them. Installed CLI output and local manifests take priority for this version's observed state.

No actual coding session, hook, MCP connection, app service, install, update, reload, trust action, credential read, or runtime test was performed. Zero verified-active components means untested, not disabled. Artifact writes are limited to this guide and claude-inventory.json.
