# herdr-open-vscode

A [Herdr](https://herdr.dev) mod: open the folder of your focused terminal in VS Code with a key or a button.

Works with:

- Folders on this computer
- Folders on any machine connected to Herdr over SSH, through the [Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh) extension
- Folders in WSL, when it's connected to Herdr over SSH like any other machine

![Open in VS Code](preview.png)

The mod adds no button of its own. This is one place to put it: a row in the + menu, set up as [below](#add-it-to-the--menu).

**Tested so far:** local folders on macOS and Windows, and from Windows to a Mac and to WSL over Remote - SSH, with capitalized Hosts. The default keys are tested too: `cmd-g` on macOS and `ctrl-shift-g` on Windows. The URIs have unit tests.

## Install

Needs VS Code, plus Remote - SSH for other machines.

Ask your agent to add `https://github.com/CacaoRick/herdr-open-vscode`, or copy `mods/open-vscode/` to `mods/` in your Herdr folder (`~/.config/herdr-app`).

This adds no panel or button. Choose how to start it [below](#use).

### Default key

The default key sits next to Terminal's, with the same modifiers. Merge one file into your own `keys.json`, whether you install by hand or through an agent:

| System | Merge only | Key |
|---|---|---|
| macOS | `keys.macos.json` | `cmd-g` |
| Windows, Linux | `keys.json` | `ctrl-shift-g` |

Never merge both. If the key is already in use, ask before replacing it. Herdr's own agent instructions only mention a mod's `keys.json`, so agents should follow this table instead.

### Update

- `git pull` doesn't change the installed mod. Copy `mods/open-vscode/` to `mods/` again, keeping any `hosts.json` you made.
- Earlier versions bound `ctrl-shift-e` and `cmd-shift-e`. Remove those bindings and merge the file for your system. `ctrl-shift-e` is Herdr's `pane.split:down` on Windows and Linux, so set it back to that if the merge replaced it.
- If your + menu clone already has the row, don't add a second one. Only update its fifth argument (the hint) and sixth (`Boolean(space)`).
- If your menu's height already reads `522` and `198`, don't add 31 again.
- If your + button already points at your clone, skip step 4 of the menu setup.

## Use

The mod runs when something calls `mod.open` with its name, so you can put it wherever suits your layout. Herdr's command palette can't list mods yet.

| Start it from | Set it up | Example |
|---|---|---|
| The + menu | Clone Herdr's menu, then add a row. See [below](#add-it-to-the--menu) | `run("mod.open", { name: "open-vscode" })` |
| A key | Merge the file for your system, see [Default key](#default-key), or add your own binding under `global` | `"ctrl-shift-g": "mod.open:open-vscode"` |
| A button or menu item | Call it from the click handler in your own mod | `.on_click(() => run("mod.open", { name: "open-vscode" }))` |
| A shell or script | Nothing to set up | `herdr-app do mod.open --name open-vscode` |

### Add it to the + menu

The + menu is one of Herdr's own mods, which are read-only, so it needs a clone. Clones don't receive Herdr's updates. These names are examples.

**1. Clone the menu.**

```sh
herdr-app do mod.clone '{"name":"new-menu","as":"my-new-menu"}'
```

**2. Add the row.** In `mods/my-new-menu/main.js`, add this line after the `terminal` row, or between any other two rows, wherever you want it in the menu:

```js
      .child(this.row("vscode", svg("mods/open-vscode/vscode.svg").size(14), "Open in VS Code", () => run("mod.open", { name: "open-vscode" }), shortcut("mod.open:open-vscode"), Boolean(space)))
```

If you bind a key to `mod.open:open-vscode`, the row shows it, like Terminal's. With no key, that side stays empty. `Boolean(space)` greys out the row when there's no space.

Herdr's `shortcut()` shows only one key, and not in the order of your file. If one action has keys for several systems, a row can show the wrong one: with `ctrl-shift-g` and `cmd-shift-e` both bound, Windows showed `Shift+Super+E`. Remove the other system's key, or replace the first three lines of `shortcut()` with:

```js
const mac = window()?.platform === "macos";
const bound = keys().filter(b => b.section === "global" && b.action === name);
const k = bound.find(b => mac === /\b(cmd|super|win)-/i.test(b.keys)) ?? bound[0];
if (!k?.keys.trim()) return "";
```

**3. Make room for it.** In the same `render`, add one row's height (31) to both numbers in the menu's height: `491` becomes `522`, and `167` becomes `198`.

**4. Point the + button at your menu.** This depends on your layout:

- **You use Herdr's `main` layout:** clone the tab bar and the layout. `layout.clone` also switches you to the clone. Then, in `layouts/my-layout.json`, change the block with `"mod": "tabs"` to `"mod": "my-tabs"`.

  ```sh
  herdr-app do mod.clone '{"name":"tabs","as":"my-tabs"}'
  herdr-app do layout.clone '{"name":"main","as":"my-layout"}'
  ```

- **Your layout already uses your own tab bar:** skip the clones and edit that mod.

Then, in `main.js` of your tab bar, change the + button's `openOverlay` call:

```js
openOverlay({ mod: "my-new-menu", kind: "popup", width: 250, height: 543 })
```

**5. Check it.** Run `herdr-app check` on each mod you changed, for example `herdr-app check ~/.config/herdr-app/mods/my-new-menu`.

A passing check doesn't prove the menu shows the right key, so look at it too:

```sh
herdr-app do mod.open --name my-new-menu
herdr-app shot menu.png
herdr-app do overlay.close
herdr-app status
```

In `menu.png`, check the key on the row. In the status, `errors` should be empty. This opens the menu in the middle of the window, not under the + button, so use it only to check the contents. `overlay.close` closes only the top overlay: if you also have a menu open, `status` still lists it, and that isn't a failure.

## If the host doesn't match

The mod uses the machine's ssh target from `hc machine ls`. If VS Code needs another name, or the machine was added with `--via`, create `mods/open-vscode/hosts.json`:

```json
{ "mac": "mac-studio" }
```

The key is the machine's name in Herdr; the value is a Host your ssh config knows.

## If VS Code stays on loading

If the window opens but its Explorer keeps loading, VS Code may be downloading its server on the other machine, which only happens the first time. Check that machine's download speed. On WSL, a slow network can be fixed by setting `networkingMode=mirrored` under `[wsl2]` in `%USERPROFILE%\.wslconfig`, then running `wsl --shutdown`.

## What it touches

It runs `code`, `powershell`, `open` or `xdg-open`, and `hc` on this computer, and reads its own `hosts.json`. It has no network access of its own.

## License

MIT
