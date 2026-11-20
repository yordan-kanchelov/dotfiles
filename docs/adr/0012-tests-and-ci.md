# 0012. Tests and CI

Status: Accepted, 2026-11-20

## Context

The regression scripts run on developer machines as well as on CI runners. They must never touch a real profile, run a real package manager, ask for elevation, reboot, or delete anything outside their own fixtures.

## Decision

### Isolation rules for every regression script

- Closed PATH. The test builds its own `bin` directory, and only stubs and links to the specific system tools it needs go on PATH. A missing fixture then fails instead of invoking a real package manager, and host copies of fnm, Herdr, agents or sync-worktrees stay out of the run (`test-bootstrap-sudo.sh`, `test-sync-worktrees.sh`, `test-herdr.sh`).
- Stubs replace provisioning only, never Git: real clones, fetches and merges run (`test-wsl-bootstrap.sh`). Linux CI may run as root, so only the uid check is stubbed. Bootstrap logic is never substituted, only absolute platform paths (`test-bootstrap-sudo.sh`).
- Fixtures run with LF line endings even when a Windows checkout uses CRLF.
- `chmod` follows symlinks named on its command line, so tests never `chmod` the linked system tools. A symlink into the native filesystem stands in for `chmod -x` when `TMPDIR` is a DrvFS mount without Unix permission metadata. On Git Bash, set `TMPDIR` to a native `C:/...` directory.
- Inherited redirect variables are cleared, because they would send an installer outside the fixture profile (`test-herdr.ps1`, `test-herdr-migration.ps1`).
- Nothing is deleted recursively. Fixtures stay in Temp after a run, because a tree with junctions left by a failed run could lead a recursive delete into real data. Only generated leaf registry keys and individual fixture files are removed (`test-setup.ps1`, `test-fonts.ps1`, `test-bootstrap-wsl.ps1`, `test-herdr.ps1`, `test-herdr-migration.ps1`).
- The Windows tests use seams instead of the real thing. That means a WSL stub, elevation and reboot seams, an isolated registry key for fonts, and a resume loader pointed at a setup stub. Nothing enables Windows features, schedules a login action or restarts Windows. `test-fonts.ps1` uses a local fixture archive by default, and `-Download` fetches the real Nerd Fonts archive. The Herdr alias test loads only function definitions, so it does not initialise the developer's prompt. It runs `exit` in a child process, so the runner survives, and it checks that the destructive server shutdown honours ShouldProcess/WhatIf.
- `test-herdr-migration.ps1` enforces profile-local staging without needing a second physical drive. It rejects the old system-temp staging, just as a cross-drive directory move would fail. It compiles a .NET Framework console executable as a stand-in native command that runs under both Windows PowerShell 5.1 and PowerShell 7, because `Add-Type` in PowerShell 7 cannot emit console applications.
- `test-ansible-facts.py` rejects injected `ansible_*` fact aliases and dot-style fact access in every play. It accepts connection settings, magic variables and registered results. Its self-test proves both directions.
- `test-agents.ps1` and `test-profile.ps1` run after a real installation and check the native tools using only the persistent PATH.

### CI workflows

- Playbook steps use `shell: bash`, which runs with `-eo pipefail`, so a failed playbook behind `| tee` fails the step.
- `HOMEBREW_NO_AUTO_UPDATE` is set for the whole job. The playbook's `tool_env` sets it for its own tasks, but `bootstrap.sh` runs `brew install ansible` before that, which would trigger a full update.
- `--skip-tags ollama`: the ollama task is a 1.4 GB download and needs a user systemd instance that runners lack.
- `ANSIBLE_INJECT_FACT_VARS=false` everywhere, so no play can depend on injected facts.
- The smoke test parses `.zshrc.core` explicitly, because `.zshrc` pulls it in through a runtime `source` and parsing `.zshrc` alone proves nothing about it. It runs the sync-worktrees launcher to show it starts the real CLI on its own Node.
- The first headless nvim start bootstraps every LazyVim plugin, Mason and treesitter, so it gets 300 s: compiling the 40 treesitter parsers takes about two minutes on the macOS runner. The limit uses perl's `alarm`, not `timeout(1)`, because macOS has no `timeout`. That this check cannot fail: [yordan-kanchelov/dotfiles#22](https://github.com/yordan-kanchelov/dotfiles/issues/22).
- The lint job pins Node 22 (the playbook's `node_version`) for the prefix mod test. `keys.js` is an ES module without a `package.json`, and older runner defaults do not detect that.
- ShellCheck skips `agent-setup/universal/plugins`, so pinned upstream payloads stay byte-for-byte unchanged. The bundle checks verify them instead.
- A workflow step keeps the PATH the runner started with. The Herdr installer writes Herdr to the persistent user PATH, so the integration step reads that back first.
- The sudo compatibility play runs as a password-protected fixture user in an Ubuntu 26.04 container.

## Consequences

A new regression script has to follow the same isolation rules. Review new tests for anything that deletes recursively or reaches the host PATH.
