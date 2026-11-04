# Herdr App mods

Four third-party mods for Herdr App, pinned and vendored unchanged, plus one local mod for prefix keys. Each folder under `mods/` holds the upstream `mods/<name>/` payload, its `LICENSE`, `README.md`, `RECIPE.md` and any `keys*.json`.

| Folder | Upstream | License | Opens with |
| --- | --- | --- | --- |
| `herdr-float-space` | [thuanlm215/herdr-float-space](https://github.com/thuanlm215/herdr-float-space) | MIT | prefix, then Ctrl+Shift+P |
| `herdr-t3-focus` | [JinJieBeWater/herdr-t3-focus](https://github.com/JinJieBeWater/herdr-t3-focus) | Apache-2.0 | a left dock; no key requested |
| `herdr-open-vscode` | [CacaoRick/herdr-open-vscode](https://github.com/CacaoRick/herdr-open-vscode) | MIT | prefix, then Ctrl+Shift+C |
| `herdr-git-graph` | [rabeeh-ta/herdr-git-graph](https://github.com/rabeeh-ta/herdr-git-graph) | MIT | prefix, then Ctrl+Shift+G |

The mods target Herdr App, the desktop app, not the `herdr` terminal client that `.config/herdr/config.toml` configures. The two are separate installs.

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

## Prefix keys

`ctrl+space`, the prefix from `.config/herdr/config.toml`, opens the local `prefix` mod. It shows a bar under the pane header and takes your next key, with no time limit. An unknown key or Esc closes it, and neither reaches the terminal. [local-mods/prefix/keys.js](local-mods/prefix/keys.js) holds the key map, which mirrors the TUI's navigation. tmux inside Herdr also uses `C-Space` in this repo's `tmux/.tmux.conf`, so the app takes that key first.

Run the key map's tests with `node --test agent-setup/herdr/local-mods/prefix.test.mjs`.

TUI keys with no matching app command stay unbound: `d` detach, `;` last pane, `tab` and `shift+tab` pane cycling, `[` copy mode, `e` edit scrollback, `r` resize mode, `o` notification target, `shift+g` new worktree, `shift+p` rename pane and `shift+r` reload config.

The mod keys are the prefix followed by `ctrl+shift+p`, `ctrl+shift+c` or `ctrl+shift+g`, each running `mod.open` for that mod. `t3-focus` has no key. It is a sidebar, so [layouts/focus.json](layouts/focus.json) is a copy of the app's `main.json` with the `agents` block replaced by `{ "mod": "t3-focus" }`. It won't pick up later changes to `main.json`. Switch with `layout.switch --name focus` or `ctrl-shift-l`; the original `main` layout stays as it was.

What the mods run: `float-space` starts shells through `hc`. `open-vscode` runs `code` or `open` and reads `hosts.json` in its folder. `git-graph` runs `git`, writes to repositories when you confirm a menu action, and asks GitHub's releases API once a day for a newer version; set `CHECK = false` in `update.js` to stop that, which breaks the pinned hashes, so prefer its "Stop checking" button.

## Update

`sources.json` records each repo's commit, archive hash and payload tree hash. `python3 scripts/agent-setup-bundle.py` fails on any drift.

To take a newer upstream:

1. Review the upstream diff since the pinned `revision`, license included.
2. Download `download_url` with the new commit, replace the folder with the same files (`mods/`, `LICENSE`, `README*`, `RECIPE*`, `keys*.json`), and keep them byte-for-byte.
3. Update `version`, `revision`, `download_url`, `archive_sha256`, `tree_sha256` and `file_count`, as in [../AGENTS.md](../AGENTS.md).
4. Run the checker and the tests.
