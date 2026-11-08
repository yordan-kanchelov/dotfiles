# Herdr App mods

Four third-party mods for Herdr App, pinned and vendored unchanged, plus one local mod for prefix keys. Each folder under `mods/` holds the upstream `mods/<name>/` payload, its `LICENSE`, `README.md`, `RECIPE.md` and any `keys*.json`.

| Folder | Upstream | License | Opens with |
| --- | --- | --- | --- |
| `herdr-float-space` | [thuanlm215/herdr-float-space](https://github.com/thuanlm215/herdr-float-space) | MIT | prefix, then Ctrl+Shift+P |
| `herdr-t3-inbox` | [JinJieBeWater/herdr-t3-inbox](https://github.com/JinJieBeWater/herdr-t3-inbox) | Apache-2.0 | a left dock; no key requested |
| `herdr-open-vscode` | [CacaoRick/herdr-open-vscode](https://github.com/CacaoRick/herdr-open-vscode) | MIT | prefix, then Ctrl+Shift+C |
| `herdr-git-graph` | [rabeeh-ta/herdr-git-graph](https://github.com/rabeeh-ta/herdr-git-graph) | MIT | prefix, then Ctrl+Shift+G |

The mods target Herdr App. Its terminals run in `herdr-core`, controlled by `hc`. Standalone `herdr`, configured by `.config/herdr/config.toml`, runs a separate server. These mods do not connect the two servers; pane and terminal IDs belong to their own backend.

For agents, read `herdr-app --skill` for window changes and `hc --skill` for terminals and agent coordination. The installed `herdr` skill and `scripts/install-herdr.sh` cover the standalone TUI. The [shared guide](../universal/README.md#herdr) describes routing between them.

## Install

1. Install Herdr App and its core, then open the app once so it creates `~/.config/herdr-app`:

   ```sh
   curl -fsSL https://releases.herdr.dev/app/install.sh | sh
   open ~/Applications/Herdr.app
   ```

   The installer downloads a checksummed build into `~/Applications/Herdr.app`, links `herdr-app` into `~/.local/bin`, and installs `herdr-core` and `hc` if missing. Apple Silicon only on macOS. It downloads and runs code, so read it first if you prefer: `curl -fsSL https://releases.herdr.dev/app/install.sh | less`.
2. Read `~/.config/herdr-app/AGENTS.md`. It is the installed guide to mods and keys.
3. Copy each `mods/<name>/` folder from the payload into `~/.config/herdr-app/mods/`. Leave out the README, RECIPE and preview. Never overwrite an existing folder.
4. Copy [local-mods/prefix/](local-mods/prefix/) to `~/.config/herdr-app/mods/prefix`.
   Copy [layouts/focus.json](layouts/focus.json) to `~/.config/herdr-app/layouts/focus.json`, then run `herdr-app do layout.switch --name focus`.
5. Merge [keys.json](keys.json) into `~/.config/herdr-app/keys.json` after backing it up. Ask before replacing a key already in use.
6. Run `herdr-app check ~/.config/herdr-app/mods/<name>` for each mod.

## Install the agent skill

The shared [herdr-core skill](../universal/skills/herdr-core/SKILL.md) is the upstream router for App terminals and agent coordination. It also points to `herdr-app --skill` for window changes. Both manuals come from the installed binaries.

For Claude or Codex, install the staged `skills/herdr-core/` directory into that profile's `skills/herdr-core/` using ordinary copies. Back up any existing directory first. Merge the matching [Claude](../claude/CLAUDE.md) or [Codex](../codex/AGENTS.md) rules at the same time; they scope the router to requested App/core work or a verified core caller. Preserve the separate `herdr` skill for the TUI. Restart the agent to discover the new skill.

## Prefix keys

`ctrl+space`, the prefix from [`.config/herdr/config.toml`](../../.config/herdr/config.toml), opens the local `prefix` mod. It shows a bar under the pane header and takes your next key, with no time limit. An unknown key or Esc closes it, and neither reaches the terminal. [local-mods/prefix/keys.js](local-mods/prefix/keys.js) holds the key map, which mirrors the TUI's navigation. tmux inside Herdr also uses `C-Space` in this repo's `tmux/.tmux.conf`, so the app takes that key first.

Run the key map's tests with `node --test agent-setup/herdr-app/local-mods/prefix.test.mjs`.

TUI keys with no matching app command stay unbound: `d` detach, `;` last pane, `tab` and `shift+tab` pane cycling, `[` copy mode, `e` edit scrollback, `r` resize mode, `o` notification target, `shift+g` new worktree, `shift+p` rename pane and `shift+r` reload config.

The mod keys are the prefix followed by `ctrl+shift+p`, `ctrl+shift+c` or `ctrl+shift+g`, each running `mod.open` for that mod. `t3-inbox` has no key in this bundle. It is a sidebar, so [layouts/focus.json](layouts/focus.json) is a copy of the app's `main.json` with the `agents` block replaced by `{ "mod": "t3-inbox" }`. It won't pick up later changes to `main.json`. Switch with `layout.switch --name focus` or `ctrl-shift-l`; the original `main` layout stays as it was.

What the mods run: `float-space` starts shells through `hc`. `open-vscode` runs `code` or `open` and reads `hosts.json` in its folder. `git-graph` runs `git`, writes to repositories when you confirm a menu action, and asks GitHub's releases API once a day for a newer version; set `CHECK = false` in `update.js` to stop that, which breaks the pinned hashes, so prefer its "Stop checking" button.

## Update App and core

The App's native updater downloads the next release before restarting the window:

```sh
herdr-app do app.check_updates
# Once the update has downloaded:
herdr-app do app.update
herdr-app --version
hc --version
```

The App restarts into the downloaded release while core terminals keep running. On macOS, an older core may ask you to run `hc update` to finish installing its signed app bundle. Run that command without `--version`; the minimum-version check can return before bundle completion. Existing terminals keep their old privacy behavior until recreated.

Read `hc --skill` and `herdr-app --skill` again after updating. Each binary supplies its matching manual. See the [skill comparison](../../docs/research/2026-11-08-herdr-skills.md) for the upstream packages and their boundaries.

## Update vendored mods

`sources.json` records each repo's commit, archive hash and payload tree hash. `python3 scripts/agent-setup-bundle.py` fails on any drift.

Run native checks on temporary copies of pinned mod folders. The checker writes `gpui-kit.d.ts` and `jsconfig.json` beside the entrypoint. Use a temporary `HERDR_APP_HOME` to keep checks away from saved App state.

T3 Focus became T3 Inbox upstream. When upgrading an existing install, back up the mod and its data. Rename `data/t3-focus` to `data/t3-inbox`, update layout references and any `t3-focus.settle` binding to `t3-inbox.settle`, then remove the old mod after the new one passes `herdr-app check`. Preserve existing `data/t3-inbox` rather than overwriting it if both names exist. See its [migration guide](mods/herdr-t3-inbox/README.md#update).

To take a newer upstream:

1. Review the upstream diff since the pinned `revision`, license included.
2. Download `download_url` with the new commit, replace the folder with the same files (`mods/`, `LICENSE`, `README*`, `RECIPE*`, `keys*.json`), and keep them byte-for-byte.
3. Update `version`, `revision`, `download_url`, `archive_sha256`, `tree_sha256` and `file_count`, as in [../AGENTS.md](../AGENTS.md).
4. Run the checker and the tests.
