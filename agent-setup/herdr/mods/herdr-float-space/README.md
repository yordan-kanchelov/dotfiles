# Herdr Float Space

A floating scratch window for the [Herdr](https://herdr.dev) desktop app:
terminal tabs of its own and autosaved Notes shared across all your spaces.
Press **Ctrl+Shift+Space**, run a side task or jot something down, press it
again and you're back where you were. Your layout stays as it is.

![Float Space](preview.png)

## Use

- **Ctrl+Shift+Space** shows/hides it, in any layout.
- Click a terminal to type. **+** adds another shell, starting in the folder
  the open space's terminal is in now (up to 12), the same place a new Herdr
  tab starts. A space on another machine starts in your home directory.
  Shells are numbered like Herdr's tabs: the lowest number no open tab uses.
- Switch tabs inside the window without touching the space behind it. Agents
  show their own name and icon, with Herdr's working spinner and
  blocked/done dots.
- While the window is open, an agent in it that finishes or needs you posts
  a toast ("Codex finished · In Float Space") and plays Herdr's done or
  blocked sound, unless you're watching it: Herdr is the active app, the
  keyboard is in Float Space and that tab is shown. The sounds follow
  `sounds` in Herdr's settings (your own files, or off). While the window is
  hidden nothing runs to notice, so there's no alert; the tab's dot still
  shows it when you reopen.
- While the keyboard is in Float Space (its terminal, Notes or header), its
  border turns your theme's accent color; clicking outside turns it back.
  Herdr keeps drawing the pane underneath as focused too; Float's border is
  the one to trust.
- **Notes** leads the header and can't be closed: one scratchpad shared
  across spaces, in your terminal font and size. It saves once you pause
  typing, and when you switch tabs or hide the window.
- **Window size** (diagonal arrows) has three presets: **Small** (20% × 50%,
  for notes or a quick command), **Normal** (50% × 60%, the default) and
  **Large** (85% × 88%, room for an agent). Sliders set any other size;
  **Apply** keeps it. Each size opens centered the first time and then
  wherever you last dragged it. Drag free header space to move the window.
- **−** hides the window and leaves shells and their programs running. The
  selected tab's **×** ends its terminal at once, like closing a tab in
  Herdr. When a terminal ends, the window shows the next tab, or Notes after
  the last one.

## Install

Requires the Herdr desktop app and `hc`. Tested on Linux with Herdr
**0.1.11** and core **0.1.16** (first built on 0.1.10 / 0.1.15); macOS and
Windows have not been tested.

Float Space runs `hc` to start, list and end its own shells, and keeps Notes
as plaintext in Herdr's `shared.json`. It makes no network requests.

**With your Herdr agent:** ask it to add this mod from
`https://github.com/thuanlm215/herdr-float-space`. It copies
`mods/float-space` into the app and merges `keys.json`, as described in the
app's `AGENTS.md`.

**With the script**, from a clone of this repository:

```sh
python3 scripts/install.py --dry-run
python3 scripts/install.py
```

It copies the mod into `~/.config/herdr-app/mods/`, adds the shortcut
without replacing any binding you already use, and backs up `keys.json`
under `~/.config/herdr-app/backups/float-space/`. It never touches a layout.
`--update` installs a newer checkout over a previous install and refuses to
overwrite files you edited. `--app-home <folder>` picks another Herdr home.
No restart is needed.

**By hand:** copy `mods/float-space` into `~/.config/herdr-app/mods/` and add
the bindings from `keys.json` to yours.

**Optional status-bar button**, if you keep a personal layout (a clone made
with "Duplicate layout"): put this block beside its `status` block.

```json
{
  "id": "float-space-launcher",
  "type": "block",
  "size": { "px": 32 },
  "content": { "mod": "float-space", "props": { "role": "launcher" } }
}
```

## State and terminal ownership

Notes, tabs, the selected tab and the window size are saved under the
shared key `float-space.v1`, so they survive restarts. Herdr saves where
each window size was dropped in `windows.json`. Don't hand-edit
`shared.json` while Herdr runs.

Hiding Float Space or closing Herdr leaves its shells running while the
machine stays up. After a reboot, core brings them back as shells in their
last folder (`--keep`); a program or agent that was running is not
restarted. Resume an agent through its own commands.

Its terminals carry the labels `herdr.mod=float-space` and
`herdr.float-space=<app home>`. Float Space asks core for terminals with
both labels before showing or ending one, so it never ends a terminal that
isn't its own, and it finds its shells again if its saved tab list is lost.

## Current limits

- Herdr 0.1.10 can't focus an overlay terminal for a mod, so opening the
  window focuses its header: click the terminal before typing.
- Switching layouts closes the window; the shortcut opens it again with the
  same terminals and notes.
- Mods can't add entries to the command palette (Ctrl+Shift+P) yet; use the
  shortcut.
- Right-clicking a Float Space terminal shows Herdr's pane menu, and its
  Split, Zoom and Close pane items don't work there (a mod can't replace that
  menu for its own window). Use **+** and the tab's **×**; "Send right-clicks
  to pane" works.
- Mods can't resize a window by its edges; use **Window size**.

## Development

```sh
npm test
python3 -m unittest discover -s tests -p 'test_*.py'
herdr-app check mods/float-space
```

No npm packages or build step. `model.js` holds saved state and the window's
layout, `controller.js` the window's lifecycle, `main.js` the views and Herdr
calls. [RECIPE.md](RECIPE.md) is the brief to rebuild it from scratch;
[docs/validation.md](docs/validation.md) records the checks run on the real
app. See [CONTRIBUTING.md](CONTRIBUTING.md) before sending a change.

## Remove

Hide Float Space, remove its `ctrl-shift-space` bindings from `keys.json`
(and the button block, if you added one), then delete
`~/.config/herdr-app/mods/float-space`. Notes and shells stay. To end the
shells too, close their tabs first, or list them with
`hc ls --json --label herdr.mod=float-space` and end only the ones whose
`herdr.float-space` label is your app home.

MIT licensed. An independent community project, not affiliated with Herdr.
