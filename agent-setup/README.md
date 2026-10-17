# Coding-agent setup reference

This folder is a reference for recreating the native Windows Codex and Claude Code setup. It is not a dotfiles payload, an installer, or an instruction to change the machine merely because an agent reads it.

Audit date: 2026-10-17. Observed CLI versions: Codex 0.163.0; Claude Code 2.1.302. These are snapshot versions, not claims about the latest releases.

## Start here

- [Codex audit and setup recipe](codex.md): plugins, marketplaces, loose skills, local compatibility adapters, settings, hooks, MCP prerequisites, and verification.
- [Claude Code audit and setup recipe](claude.md): plugins, skills, commands, agents, scoped settings, hooks, MCP prerequisites, and verification.
- [Skill name index](skills.md): human-readable names grouped by harness, owning plugin, and registration class.
- [Codex inventory](codex-inventory.json) and [Claude inventory](claude-inventory.json): sanitized, enumerated observations for comparison on a future machine. These JSON files are evidence, not configuration to import.

The Markdown documents explain the setup; the inventories list individual components. Read both for the harness being configured. Upstream packages supply the actual plugin/skill files. Do not turn this folder into an automatically loaded global instruction set.

## Audit overview

| Native Windows harness | Installed / user-enabled plugins | Physical skill files | Static skill candidates |
| --- | ---: | ---: | ---: |
| Codex | 11 / 11 | 163 | 136 within plugin manifest roots, plus 10 loose/system files |
| Claude Code | 5 / 5 | 129 | 97 registered plugin candidates, plus 2 standard loose candidates |

These totals are computed from the delivered inventories. Physical-file totals include supporting/alternate-host files, and Claude's total includes 13 host-managed synced files. They are not counts of active workflows or installation requirements.

Main findings:

- Shared engineering tooling includes Matt Pocock skills, pstack, and Ponytail. Codex additionally has a local Matt extras adapter and seven account-backed OpenAI plugin entries. Claude additionally has Chrome DevTools and the native Epic Unreal plugin.
- The local Codex pstack/Matt extras adaptations lack complete pinned upstream-and-patch reconstruction recipes. Treat this as a reproduction gap, not a reason to replace them silently with upstream packages.
- Ponytail versions differ: Codex 5.3.2 and Claude 5.3.1. This audit did not update or align them.
- Claude reports all five plugins user-enabled, but `projectEnabled` differs between the user home and this repository. No explicit override explaining it was found; effective loading in a live project session remains unverified.
- Chrome DevTools reports a dependency-install warning. Blender's local provenance notes an animation compatibility limitation. Neither issue was repaired or runtime-tested by this audit.
- Codex retains Smart approval. Hook trust, MCP reachability, account-backed tools, and active session discovery remain separate from installed-file evidence.

## What this reference is for

The intended workflow is to point an agent at this folder and ask it to inspect the destination machine, compare it with the recorded setup, and propose a selective recreation plan. It replaces the old repository-managed `claude/` and `codex/` configuration bundles, not their contents one-for-one.

There are three different things here:

1. Observed state: what this Windows installation reported on the audit date, including local overrides, disabled or unavailable components, and machine-specific dependencies.
2. Candidate setup: the native installation and selective configuration steps documented for future use. An installed component is not automatically a requirement on every new machine.
3. Approved changes: only the actions the user authorizes for that destination machine. Reading this guide does not approve installation, hook execution, account access, permissions expansion, or project trust.

Do not recreate old machine history, credentials, project trust records, broad permission exceptions, or private connection details. Do not promote a cached plugin to installed/enabled status because its files happen to exist.

## Suggested future-agent prompt

> Read `agent-setup/README.md` and the guide/inventory for your harness. Audit the destination read-only first. Compare installed versions, marketplaces, plugins, loose skills, entry instructions, hooks, permissions, and MCP prerequisites with this reference. Report what matches, what is missing, what is machine-specific, and what cannot be reproduced from the documented sources. Propose a minimal native-installation plan and wait for approval before changing anything. Do not use symlinks or junctions, add Ansible/bootstrap wiring, copy an entire profile, migrate credentials/history, grant broad permissions, or trust hooks automatically. Keep existing unrelated configuration. After approved changes, verify native listings and discovery, then use a separately approved bounded smoke test; distinguish installed, enabled, discovered, trusted, and actually exercised.

To audit without making changes, append: “Report only; do not install, edit settings, reload plugins, start MCP servers, or execute hooks.”

## Recreation boundaries

- No symlinks, junctions, hard links, stow, or other filesystem-link deployment from this repository.
- No Ansible, bootstrap, scheduled synchronization, or automatic profile reconciliation for this folder.
- Use the harness's native marketplace/plugin management where supported. For standalone skills, obtain the documented source and place an ordinary local copy only after approval; retain its relative assets, license, and provenance.
- Do not copy `~/.codex` or `~/.claude` wholesale. Do not import these JSON inventories as settings.
- Do not copy authentication files, API keys, OAuth tokens, environment values, conversation history, auto-memory, plugin user data, or saved account connections.
- Inspect existing settings before making a narrow change. Back up affected files without exposing secrets; never overwrite an unrelated settings section.
- Keep Codex Smart “Approve for me” rather than Full Access. For Claude, review the recorded mode against destination capabilities and user policy; do not infer permission to enable bypass or suppress security prompts.
- Hook installation, hook trust, workspace trust, account authorization, and MCP registration are separate decisions. Obtain the appropriate approval for each. Do not use bypass flags to avoid trust prompts.
- Preserve manual-only skill policies. An entry-point routing instruction is not permission to run every workflow or invoke every sibling skill.
- Do not update or migrate an existing running session merely to make a listing look current. Document whether a fresh session or explicit reload is needed, and ask before disrupting user sessions.
- Never assume a Windows path, engine location, Blender executable, Python interpreter, port, username, or project root from this snapshot is valid on another host.

## Portable sources versus local adaptations

The per-harness guides distinguish upstream plugins, standalone skills, and local adaptations. In particular, the Codex engineering adaptations are not interchangeable with the upstream Claude/Cursor packages. Their local marketplace names and version suffixes identify compatibility work, not a public upstream release.

Do not substitute an upstream plugin for a locally adapted package and claim parity. Where an adaptation or loose skill lacks a portable pinned source, report the gap and obtain the original reviewed source or reconstruct and review the adapter explicitly. No local package bodies or full profile configurations are vendored by this audit.

Herdr integration remains separate from this documentation. The existing setup scripts may install Herdr's own skill/hooks. This folder does not modify those scripts, reintroduce repository-managed Claude/Codex bundles, or claim all agent configuration is untouched by every existing installer.

## How to read the evidence

| Evidence | What it establishes | What it does not establish |
| --- | --- | --- |
| Native plugin listing | Installed identity/version and the reported enabled state in that execution context | A plugin ran successfully or is enabled in every project |
| Marketplace/config/manifest inspection | Registered source, candidate components, declared settings and hooks | Authentication, network availability, successful service connection, or hook execution |
| Skill files and metadata | Source-present skill inventory and declared invocation policy | Every skill was discovered or used in an existing session |
| Saved hook trust record | Persisted trust evidence for the recorded content | Portable approval for different content or a different machine |
| Bounded runtime test | Only the behavior actually exercised in that test | General model quality or all plugin workflows |

CLI outputs can differ by working directory, project-local overrides, account/network access, sandbox, and process environment. Compare like with like. The guides record known differences; a restricted worker's shorter list must not replace a successful native account-backed listing.

This audit did not test coding workflows, execute application-hosted MCP calls, authenticate connectors, install/update plugins, grant hook trust, or reload the user's running Claude session. Native read-only commands may maintain their own caches; no deliberate profile configuration changes are part of this task.

## Validation on a future machine

1. Record CLI versions and effective profile/config roots without dumping secrets.
2. Run the read-only listing commands in the relevant guide from both a neutral directory and the intended project.
3. Compare identities, versions, source revisions, enabled states, and skill invocation policies with the sanitized inventory. Explain differences instead of silently fixing them.
4. Inspect custom adapters and hook commands before installing or trusting them. Confirm Windows-native interpreter paths in the new agent's own shell.
5. After separately approved installation/configuration, read back the exact destination settings and native listings. Check runtime discovery and trust state separately.
6. Only after permission, run a small disposable smoke test with bounded turns/time and reviewed hooks. Test routing both with an explicit skill request and a relevant task that does not name it; the former alone does not prove automatic routing.
7. Record what was exercised, what remains untested, the source revisions used, and rollback steps. Do not claim equivalence based only on matching plugin counts.

## Refreshing this reference

Update the guides and inventories together after a new read-only audit. Retain the audit date, evidence scope, source revisions, disabled state, and reproducibility limitations. Keep secrets and machine history out of version control. A change to this reference must never trigger installation or configuration changes by itself.

## Upstream documentation

These links describe the products; the installed CLI's `--help` and local evidence determine which commands and fields were available for this snapshot.

- [OpenAI skills and plugins](https://learn.chatgpt.com/docs/skills-and-plugins)
- [OpenAI hooks](https://learn.chatgpt.com/docs/hooks)
- [Claude Code plugins overview](https://code.claude.com/docs/en/plugins/overview)
- [Claude Code skills](https://code.claude.com/docs/en/skills)
- [Claude Code hooks](https://code.claude.com/docs/en/hooks)
- [Claude Code settings](https://code.claude.com/docs/en/settings)
