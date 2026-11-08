# Float Space

A floating scratch window over whatever Herdr shows: terminal tabs of its own
and one Notes page shared by every space. Ctrl+Shift+Space shows it in any
layout without changing that layout, and hides it again with its shells and
their programs still running, returning the keyboard to the pane underneath.

![Float Space](preview.png)

## What you see

- **The window**, 50% of the app's width and 60% of its height by default,
  opened centered. No Herdr frame: 10px corners, the `background` color and
  a 1px border in the theme's `input` color (`#404449` in Atom One Dark) that
  turns `accent` while the keyboard is in the window (below).
- **The header**, 30px, on `background`, 6px side padding, 6px gaps, 12px
  type, a 1px bottom line in `border`. Left to right:
  - **Notes**, a tab with the 14px notes icon and the word "Notes". It can't
    be closed.
  - A 1px × 14px divider in `border`, shown only when there are terminal tabs.
  - **Terminal tabs**, a strip that scrolls sideways, 2px apart. Each tab is
    a 22px pill with 8px side padding, 6px gaps and 6px corners: the program's
    14px icon from the app's program table (an agent's own icon in full color,
    a shell's `>_` tinted `muted`), then the name truncated at 135px. An agent
    shows its program's name ("Codex", "Claude Code"); a shell keeps its tab
    title, "Terminal 2": the lowest number no open tab uses. The selected tab is `foreground` on `raised` with a
    1px `border` outline and a 12px × (`dim`, `foreground` on hover) at its
    end; the others are `muted` on `background` with no outline. Every tab gets
    the `hover` background under the pointer.
  - Three 22px icon buttons with 6px corners and 14px icons in `dim`
    (`foreground` on `hover`): **+** New terminal, diagonal arrows Window
    size, **−** Hide. Each has a tooltip; Hide's reads "Hide ·
    Ctrl+Shift+Space".
- **The body** fills the rest: the selected terminal, or Notes.
- **Notes** is a full-size textarea with 16px side and 14px vertical
  padding, in the terminals' font and size from Herdr's settings (JetBrains
  Mono 14 by default), placeholder "Notes shared across your spaces…".
- **Window size**, a 280px popup on `popover` opened under its button, 14px
  padding, 10px gaps, 12px type:
  - "Window size" in medium weight.
  - Three presets side by side, each a 6px-corner box with the name and an
    11px `dim` size: Small 20 × 50, Normal 50 × 60, Large 85 × 88. The one
    matching the current size has an `accent` outline on `selected`; the
    others an `input` outline on `raised`.
  - Width (20–95%) and Height (30–95%), each a label with its value ("50%",
    `muted`) on the right and a native slider below: a 4px groove in
    `border`, the filled part in `accent`, a 12px `foreground` thumb centered
    on the groove.
  - Reset (raised, `input` outline) and Apply (solid primary), 26px tall with
    12px side padding, at either end of the last row.
- **Optional button**, for a personal layout's status bar: a 32px block on
  `chrome` with the status bar's top border, holding a 22px rounded button
  with the 14px float icon in `muted`, tooltip "Float Space ·
  Ctrl+Shift+Space".

## How it behaves

- **Agent statuses** on terminal tabs: working shows a 12px spinner in the
  `working` color turning once every 900 ms; blocked and done show a 6px dot
  in the `blocked` or `done` color; idle shows nothing.
- **Alerts** (Herdr alerts only for agents in its spaces): while the window
  is open, the header checks its agents once a second. Working → idle or done
  posts `notify` "<name> finished", body "In Float Space", level success;
  becoming blocked "<name> needs you" (warning), error "<name> stopped with
  an error" (error). Then `playSound("done")`, or `"blocked"` when any needs
  the person, unless `settings().sounds.enabled` is false. Nothing for the
  agent being watched: `window().active`, the keyboard in the window and that
  tab shown. Statuses live in the window's shared memory so one header copy
  reports each change; after a gap of over 3 s (hidden, reloaded) the first
  check only takes note.
- **Ctrl+Shift+Space** shows or hides the window from anywhere, also while a
  terminal or the window has the keyboard. The optional button does the
  same. Changing spaces or tabs keeps it open; switching layouts closes it,
  and the shortcut opens it again there. Clicks beside it don't close it.
- The first opening starts a shell in the live folder of the terminal the
  open space is showing (where a new Herdr tab starts; the space's stored
  folder only if that terminal has none). Later openings show the tab that
  was selected, with its program as it was. **+** starts another shell in
  the folder of the space open at that moment (at most 12). A space on
  another machine starts at home. A tab click shows that terminal; Notes
  shows Notes.
- **×** ends the selected tab's terminal at once, like closing a tab in
  Herdr. When the shown terminal ends (×, `exit`, or ended elsewhere), the
  window shows the next tab, or Notes after the last one. A last terminal
  that ended while the window was hidden opens Notes next time, not a new
  shell.
- **Hide** (− or the shortcut) never ends a terminal; the pane that had the
  keyboard before gets it back.
- **Focus.** Opening focuses the header, so typing doesn't reach the agent
  underneath; click the terminal to type in it. Herdr keeps drawing the pane
  underneath as focused while the header or Notes has the keyboard, so the
  window marks it: its whole border turns `accent` while typing goes into the
  window (header, Notes or its terminal) and goes back to `input` when it
  leaves: a click anywhere outside the window, or Herdr focusing another
  pane. A press on the header (a tab, a button or free space) puts the
  keyboard in the header. Escape is left to the terminal programs.
- **Notes** save on their own 400 ms after typing pauses, and when Notes
  closes (another tab, hiding). They are the same in every space.
- **Window size**: a preset applies at once and closes the popup. The
  sliders show their value while dragging but change nothing until Apply;
  Reset puts 50 × 60 in the sliders; Escape or a click outside cancels.
  Pressing the size button again closes the popup. A new size opens centered
  the first time and afterwards wherever it was last dropped, so a Small
  window can stay in a corner while Normal stays in the middle.
- Pressing on free header space and dragging moves the window; Herdr keeps
  the spot. Tabs, buttons and Notes don't start a drag.
- Errors show as a Herdr notification titled "Float Space".
- Notes, tabs, the selected page and the size survive restarts. After a
  reboot the shells come back as shells; running programs and agents don't.

## Built from

- **Files** (`mods/float-space/`): `main.js` (views and the Herdr calls),
  `controller.js` (the window's lifecycle), `model.js` (saved state and the
  window's layout), `mod.json`, and its icons `float.svg`, `notes.svg`,
  `plus.svg`, `size.svg`, `hide.svg`, `close.svg`, `spinner.svg`.
- **mod.json**: `{"place": "none", "title": "Float Space", "overlay":
  {"kind": "window", "frame": "none", "width": 1, "height": 1}}`. No layout.
- **keys.json**: `ctrl-shift-space` → `mod.open:float-space` in `global`,
  `terminal` and `mod:float-space`.
- **Copies by role** (`props().role`):
  - none with an `overlay` id (from `mod.open`), or `"run"` with a `command`:
    an invisible 1×1 window that runs one command (default `toggle`) and
    closes itself.
  - `"bar"` with a `generation`: the header.
  - `"edge"` with a `side` (`left`, `right`, `bottom`): the border beside and
    under the body.
  - `"notes"`: Notes. `"size"`: the size popup.
  - none in a layout, or `"launcher"`: the optional button.
- **The window**: `openOverlay({kind: "window", key:
  "float-space.window.<W>x<H>", frame: "none", width, height, layout})`,
  W and H in percent; the layout is a column with `radius: 10` and no
  border: the 30px `bar` block; a row of the 1px `left` edge, a `{terminal}`
  block or the `notes` block, and the 1px `right` edge; then the 10px
  `bottom` edge. The header draws the border's top with `rounded_t(10)`,
  the side edges fill with the border color, the bottom band draws
  `border_b`, `border_l`, `border_r` and `rounded_b(10)`.
- **Commands** run by the controller: `toggle`, `show`, `hide`, `new`,
  `notes`, `select-<address>`, `end-<address>`, `resize-<W>-<H>`,
  `reconcile`. The header, the popup and the button start them with
  `openOverlay({mod: "float-space", kind: "window", frame: "none", width: 1,
  height: 1, props: {role: "run", command}})`.
- **One controller** for all copies, in `globalThis.__herdr_float_space_window_v1`
  with a lease so commands run one at a time; its prototype is reset to the
  running build's class on every use.
- **herdr**: `appHome`, `home`, `hc`, `focused`, `panes`, `terminals`,
  `shared`, `setShared`, `settings`, `props`, `theme`, `run("pane.focus")`,
  `openOverlay`, `closeOverlay`, `notify`. **gpui**: `View`, `div`, `svg`,
  `image`, `h_flex`, `v_flex`, `TextareaState`, `Textarea`, `SliderState`,
  `Slider`, `SliderTrack`, `SliderIndicator`, `SliderThumb`.
- **Programs**: `hc run --bg --keep --no-parent --cwd <focused terminal, else space folder, else home> --json`,
  `hc ls --json`, `hc kill <address>`, always with the labels
  `herdr.mod=float-space` and `herdr.float-space=<app home>`.
- **Saved state**: shared key `float-space.v1`, `{version: 2, tabs:
  [{address, title}], active, notes, page: "terminal" | "notes", size:
  {width, height}, sequence}`.

## Watch out

- `<mod>.<command>` reaches shown copies only, which would need a block in
  the person's layout. `mod.open` needs none; it starts a new copy on every
  call. `globalThis` is shared by all copies of the mod.
- Herdr stops a copy's tasks when it closes or reloads. A command has to run
  in a copy that outlives it: not in the header (every remount closes it)
  and not in the popup. A promise queue shared by copies stalls for good once
  a stopped copy is in it; a lease that expires (15 s) doesn't.
- A window closes itself when its terminal ends, with no notice to
  `openOverlay`'s caller, and before `terminals()` drops that terminal. The
  header's `close()` reports it; a mount `generation` tells Herdr's close from
  a remount or a hide, and hiding forgets the window before closing it.
  `close()` gets 250 ms: ask core there directly (`hc ls`, tens of ms). Work
  handed from `close()` to another copy is cancelled with it.
- Every change of what the window shows (a tab, Notes, a new or closed
  terminal, a size) replaces the window: there is no call to swap the
  terminal in an open overlay, so Herdr rebuilds the terminal view and the
  mod's blocks, which shows as a flicker. Closing the shown tab replaces the
  window with the next tab first and only then ends the terminal: ending it
  first makes Herdr close the window, and closing then reopening flickers
  more. A failed kill puts the tab back.
- Herdr reopens a window key where it was dropped even when a taller size
  doesn't fit there, so each size has its own key; a remount with a new key
  opens the new window before closing the old one.
- `pane.focus` doesn't reach overlay terminals in Herdr 0.1.10 (it shows a
  failed-command toast), so the terminal can't be focused for the person.
  `focused()` doesn't report one either: after a click into the window's
  terminal it still names the pane underneath. The header's
  `on_mouse_down_out` sees every press outside the header; a press inside
  the window (the header's bounds widened by the 1px border, down to the
  window's height, `size.height × window.viewport_size().height`) means the
  terminal has the keyboard until a press outside it, or until `focused()`
  changes. The tabs and buttons stop mouse-down propagation (or they'd drag
  the window), so they focus the header themselves.
- A layout's `border` can't change color without replacing the window,
  which rebuilds the terminal view and loses the keyboard, so the mod draws
  the border with its own blocks. Presses update it at once (the header's
  `on_mouse_down_out` and its own controls); a 150 ms check catches the rest.
  The answer lives in the shared `globalThis` entry, and the header and the
  three edge blocks each wait on one shared promise in a `cx.spawn` task and
  `cx.notify()` when it resolves, so all four redraw together. Polling in
  each block let the sides change before the header, and calling another
  view's `cx.notify()` from the header's call redrew it about a second late.
  A header closed by a remount must not clear the answer for the new one.
- Herdr's terminal right-click menu comes from the shown layout's
  `terminal_menu`; an overlay layout's own is ignored. In the window its pane
  items (Split, Zoom, Close pane) fail with `no pane
  "<overlay>/float-space-terminal"`; "Send right-clicks to pane" works.
- A press outside a popup closes it before the opening button's click
  arrives. The popup records itself in `globalThis.__herdr_float_space_size_v1`;
  the size button checks it on press, so a second press only closes it.
- The slider shell places the thumb's left edge only: `ml(-6).mt(-4)` for a
  12px thumb on a 4px groove. Stop mouse-down propagation on tabs, buttons and
  Notes, or they drag the window. A layout `shadow` is clipped to a window's
  bounds.
- `setShared` redraws every mod in the app: save Notes after a pause, never
  write unchanged state, and keep the window's runtime state in memory.
- `terminals()` can lag or come back empty: confirm with `hc ls` before
  treating a terminal as gone, and list owned terminals again right before
  `hc kill`. Never add `herdr.space` or `herdr.tab` labels, which would put
  these terminals into the person's spaces.
- Renaming the mod: the name is in its folder, the `mods/float-space/*.svg`
  paths, `mod: "float-space"` in the overlay specs, the `herdr.mod` label, the
  `float-space.v1` key, the two `globalThis` names and `keys.json`.
- Built on Herdr 0.1.10, core 0.1.15; tested on 0.1.11, core 0.1.16, Linux. It runs `hc` and
  local shells, keeps Notes as plaintext in `shared.json`, makes no network
  requests and reads no files outside the app.

## Done when

- `herdr-app check mods/float-space` passes; `npm test` and
  `python3 -m unittest discover -s tests -p 'test_*.py'` pass.
- Ctrl+Shift+Space opens the window in the shipped `main` layout with no
  layout file changed, and again after switching layouts.
- The first opening starts one shell in the live folder of the open space's
  terminal (home when that space is remote); hiding and showing again shows
  the same terminal with the same process.
- + adds a shell, tab clicks switch, × ends only that terminal, and killing
  the shown terminal from outside shows the next tab at once.
- Notes typed in one space appear in another and survive a restart.
- Small, Normal and Large apply in one click and fit inside the app; the
  sliders change nothing until Apply.
- The border is `accent` all the way round after clicking the window's
  terminal, Notes or a header tab, and `input` after clicking a pane outside.
- Rapid presses never start an extra shell, also right after the mod
  reloads; `herdr-app status` shows no errors.
