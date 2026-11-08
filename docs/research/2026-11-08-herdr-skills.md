# Herdr skills and this branch

Reviewed on 2026-11-08. Standalone Herdr and Herdr App use separate servers. App window commands belong to `herdr-app`; its terminals and agents belong to herdr-core through `hc`. The dotfiles branch adds App mods and host workflow rules. It does not bridge those servers.

| Product | Published version checked | Source reference |
| --- | --- | --- |
| Standalone `herdr` | GitHub release `v0.9.5`, 2026-10-14 | Latest master skill matches the release byte-for-byte. |
| `herdr-core`, CLI `hc` | Updater channel 0.1.18 | Tag commit `3965a46caae095a3ead01de237fa13955e52b8c6`. |
| `herdr-app` | Updater channel 0.1.13 | Tag commit `93b097f6e29fcb2d90a30dea2f03ce4e5dee7981`. |

Sources: [standalone release](https://github.com/herdrdev/herdr/releases/tag/v0.9.5), [core updater manifest](https://releases.herdr.dev/core/latest.json), [published core manual](https://github.com/herdrdev/herdr-core/blob/3965a46caae095a3ead01de237fa13955e52b8c6/crates/herdr-core/src/SKILL.md), [App updater manifest](https://releases.herdr.dev/app/latest.json), [published App manual](https://github.com/herdrdev/herdr-app/blob/93b097f6e29fcb2d90a30dea2f03ce4e5dee7981/src/SKILL.md). Manifest versions describe the updater channels when checked, not permanent pins.

Latest source differs from those channels. Standalone `master` is `ee5bfb5041bb3e4a49d591c72308aae3c81ecdde`, dated 2026-10-29. Core `master` and tag `v0.1.19` point to `2e8ebb3cdc236a679d4e9ccdaa3a28c5098b8fe9`, dated 2026-11-07. Its [versioned manifest](https://releases.herdr.dev/core/0.1.19/manifest.json) returned 404, while the updater channel serves 0.1.18. App `master` is `7fe7ac34fef8a3ee76cb5d2f17bc8d6331e50bd8`, dated 2026-11-07; Cargo still says 0.1.13. GitHub Releases `latest` returned 404 for core and App despite published updater builds. [Standalone skill](https://github.com/herdrdev/herdr/blob/ee5bfb5041bb3e4a49d591c72308aae3c81ecdde/skills/herdr/SKILL.md), [core changelog](https://github.com/herdrdev/herdr-core/blob/2e8ebb3cdc236a679d4e9ccdaa3a28c5098b8fe9/CHANGELOG.md), [App version](https://github.com/herdrdev/herdr-app/blob/7fe7ac34fef8a3ee76cb5d2f17bc8d6331e50bd8/Cargo.toml).

| Default guide | What it provides | Boundary |
| --- | --- | --- |
| `herdr --skill` | Workspace, tab and pane control; agent startup, prompts, reads and waits; remote-machine targeting; caller IDs and lifecycle safeguards | Requires `HERDR_ENV=1`. Talks to the standalone server. |
| `hc --skill` | Persistent terminals; interactive agent delegation; child reports and waits; remote commands/files; terminal cleanup | Caller address is `HC_TERMINAL_ID`. Controls herdr-core. Codex needs `--no-daemon`. |
| `herdr-app --skill` | Window inspection; spaces, tabs and splits; layouts, keys, mods and screenshots | Delegates terminal and agent work to `hc`. A core terminal ID is not an App pane ID. |

Sources: [standalone skill](https://github.com/herdrdev/herdr/blob/ee5bfb5041bb3e4a49d591c72308aae3c81ecdde/skills/herdr/SKILL.md), [core manual](https://github.com/herdrdev/herdr-core/blob/3965a46caae095a3ead01de237fa13955e52b8c6/crates/herdr-core/src/SKILL.md), [App manual](https://github.com/herdrdev/herdr-app/blob/93b097f6e29fcb2d90a30dea2f03ce4e5dee7981/src/SKILL.md).

The branch now bundles the unchanged upstream [herdr-core routing skill](../../agent-setup/universal/skills/herdr-core/SKILL.md) and license for Claude/Codex. It is pinned to core `2e8ebb3`; its bytes also match the published 0.1.18 router. Upstream prefers `hc` over host subagents, shell background jobs and tmux. Outside `HC_TERMINAL_ID`, it asks once whether to use hc. The host rules narrow that broad trigger to requested App/core work or a verified core caller. [Pinned upstream router](https://github.com/herdrdev/herdr-core/blob/2e8ebb3cdc236a679d4e9ccdaa3a28c5098b8fe9/skills/herdr-core/SKILL.md), [published router](https://github.com/herdrdev/herdr-core/blob/3965a46caae095a3ead01de237fa13955e52b8c6/skills/herdr-core/SKILL.md).

Core 0.1.18 adds longer startup readiness, retained first-message failures, stricter child-task completion checks and current-directory reporting. Its manual covers macOS app-bundle installation and privacy ownership. App 0.1.13 adds terminal search. [Core manual](https://github.com/herdrdev/herdr-core/blob/3965a46caae095a3ead01de237fa13955e52b8c6/crates/herdr-core/src/SKILL.md), [App manual](https://github.com/herdrdev/herdr-app/blob/93b097f6e29fcb2d90a30dea2f03ce4e5dee7981/src/SKILL.md).

Beyond those published versions, core 0.1.19 documents environment preservation across restart and detached-process survival on Unix. App `master` adds pane swapping, deleted-folder fallback and checks that leave saved shared state untouched. Do not assume the current updater installs these source changes. [Core master manual](https://github.com/herdrdev/herdr-core/blob/2e8ebb3cdc236a679d4e9ccdaa3a28c5098b8fe9/crates/herdr-core/src/SKILL.md), [App master manual](https://github.com/herdrdev/herdr-app/blob/7fe7ac34fef8a3ee76cb5d2f17bc8d6331e50bd8/src/SKILL.md).

The original branch additions, reviewed against `c3e6add`, are separate from those defaults:

- `b07f312` adds four pinned App mods, a local prefix-key mod, a focus layout and bundle checks. See [App setup](../../agent-setup/herdr-app/README.md).
- `13a9599` adds host instructions for headless external reviews, fresh sessions and panes, and result-file checks. See [shared review workflow](../../agent-setup/universal/README.md#external-agents).
- The standalone installers obtain `herdr --skill` from the binary. They do not install App/core integration. See [Unix installer](../../scripts/install-herdr.sh) and [Windows installer](../../windows/install-herdr.ps1).

The final portable bundle also refreshes the four App payloads. Source records retain archive and payload hashes in [sources.json](../../agent-setup/herdr-app/sources.json).

| Payload | Updated pin |
| --- | --- |
| Float Space 0.2.0 | [6ffd377](https://github.com/thuanlm215/herdr-float-space/tree/6ffd377cf126301a5e61b19395aba939ae39131c) |
| T3 Inbox, renamed from T3 Focus | [c954053](https://github.com/JinJieBeWater/herdr-t3-inbox/tree/c95405318db41645cc7901f147af00d0c1ffb15e) |
| Open VS Code, documentation update | [1dfa209](https://github.com/CacaoRick/herdr-open-vscode/tree/1dfa20974f6da63b195660b68dd120bed2412184) |
| Git Graph 0.3.2 | [2f4fe0f](https://github.com/rabeeh-ta/herdr-git-graph/tree/2f4fe0fc22e7cc726f3c1a2a654887c96227c37b) |

The focus layout now names `t3-inbox`. Host rules choose the server before loading a guide and keep IDs within that server. Headless pane workflows apply to standalone Herdr; core's native guide expects interactive agents. The new skill loads `hc --skill` or `herdr-app --skill` on demand. The bundle does not copy those version-specific manuals. See the [Claude rules](../../agent-setup/claude/CLAUDE.md) and [Codex rules](../../agent-setup/codex/AGENTS.md).
