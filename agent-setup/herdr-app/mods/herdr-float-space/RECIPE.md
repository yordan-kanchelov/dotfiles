# Float Space

A floating scratch window over whatever Herdr shows: terminal tabs of its own
and up to five named notes shared by every space. Ctrl+Shift+Space shows it in any
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
  - **Notes**, a tab with the 14px notes icon, the open note's name and a
    12px chevron in `dim` (`foreground` under the pointer). It can't be
    closed.
  - A 1px × 14px divider in `border`, shown only when there are terminal tabs.
  - **Terminal tabs**, a strip that scrolls sideways, 2px apart. Each tab is
    a 22px pill with 8px side padding, 6px gaps and 6px corners: the program's
    14px icon from the app's program table (an agent's own icon in full color,
    a shell's `>_` tinted `muted`), then the name truncated at 135px. An agent
    shows its program's name ("Codex", "Claude Code"); a shell keeps its tab
    title, "Terminal 2": the lowest number no open tab uses. Once the agent
    quits, the tab is the shell again: `>_`, its tab title, no status. The selected tab is `foreground` on `raised` with a
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
  Typing past the bottom scrolls one row at a time: the caret may sit on the
  last row, and the text never scrolls past its end.
  Until the notes file has been read it is empty; a file that can't be read
  shows why, in 12px `muted`, and the file's path in `dim`.
- **The notes menu**, a 248px popup on `popover` opened under the Notes tab
  at its left edge, 5px padding, 12.8px type, like Herdr's menus. One 31px
  row per note with 7px corners: a 14px check for the open note (a blank
  14px slot otherwise), the name truncated, then a 22px color button (a 12px
  dot in the note's color, or a `dim` ring on `background` for the theme's;
  `hover` under the pointer) and 22px rename (pencil) and
  delete (×) buttons with 13px icons in `dim` (`foreground` under the
  pointer); no delete when only one note is left. Rows get `hover` under the
  pointer and `selected` for the keyboard's row. A 1px `border` line, then
  **+ New note** with "<n> of 5" in 11px `dim` on the right, `dim` all over
  once there are five. Renaming or naming a new note puts a 25px input in
  the row (6px corners, `accent` outline, `background`). Deleting a note
  with text asks in the row: "Delete this note?" with a solid **Delete** and
  a raised **Cancel**, 22px tall. Choosing a color puts the colors in the
  row on `selected`, 4px apart: Theme, then White `#d1d4d9`, Black
  `#2c2f33`, Red `#fac9c7`, Orange `#f6cdb1`, Yellow `#e2d4a8`, Green
  `#bcddc2`, Blue `#bcd7f0`, Pink `#f2cadb` (pastels of one brightness,
  Black aside), each a 14px dot in a 20px 2px
  ring: `accent` for the note's color, `dim` for the keyboard's, otherwise
  invisible (`foreground` under the pointer); each has its name as tooltip.
- **A colored note**: the Notes page and the window's 10px bottom band take
  its fill, the text its ink (`#2a2c31` on White, `#d5d8de` on Black, a dark
  shade of the fill on the others), the same in light and dark themes. The
  caret and the selection are Herdr's (a mod can't set them): in a dark
  theme a near-white caret and a 40% white selection, faint on every pastel
  (contrast 1.3 and 1.18). The
  Notes tab shows the color as an 8px square with 2px corners before the
  chevron. The header and the window border keep the theme's colors.
- **Window size**, a 300px popup on `popover` opened under its button, 14px
  padding, 10px gaps, 12px type:
  - "Window size" in medium weight.
  - Three presets and Custom side by side, each a 6px-corner box with the
    name and an 11px `dim` size: Small 25 × 50, Normal 50 × 60, Large
    85 × 88, and Custom with the last size used that is no preset, or "—"
    with a `dim` name before there is one. The one matching the current size
    has an `accent` outline on `selected`; the others an `input` outline on
    `raised`.
  - Width and Height (15–95%), each a label with its value ("50%",
    `muted`) on the right and a native slider below: a 4px groove in
    `border`, the filled part in `accent`, a 12px `foreground` thumb centered
    on the groove.
  - Reset (raised, `input` outline) and Apply (solid primary), 26px tall with
    12px side padding, at either end of the last row.
- **Optional button**, for a personal layout's status bar: a 32px block on
  `chrome` with the status bar's top border, holding a 26×22 rounded button
  (as wide as the status bar's other 26px buttons) with the 14px float icon
  (two stacked windows: the back one's outline stops short of the front one)
  in `muted`. Resting the pointer on it for 1000 ms shows the label
  "Float Space · Ctrl+Shift+Space": a `HoverCard` with `open_delay(1000)`,
  since `.tooltip()` always shows after 500 ms. When an agent finished and
  hasn't been seen, an 8px round dot in `working` (Herdr's yellow) with a
  1px `chrome` ring sits at the icon's top right (3px above it, 4px past its
  right edge, where the front window leaves room); no dot otherwise.

## How it behaves

- **Agent statuses** on terminal tabs: working shows a 12px spinner in the
  `working` color turning once every 900 ms; blocked shows a 6px dot in the
  `blocked` color; done a 6px dot in the `done` color, only while that
  finish is unseen (below), since an agent may keep reporting done after
  you've looked; idle shows nothing.
- **Alerts** (Herdr alerts only for agents in its spaces): the header while
  the window is open, and the optional button always (it stays in its
  layout while the window is hidden), check the agents once a second.
  Working → idle or done posts Herdr's agent toast: `notify` "<name>
  finished", level info; becoming blocked or hitting an error (one need, so
  blocked ↔ error doesn't alert again) "<name> needs you", level error. No
  body (a Float Space terminal has no space or tab) and no timeout, so the
  toast mod's defaults apply (5 s info, 8 s error). Then `playSound("done")`,
  or `"blocked"` when any needs the person, unless
  `settings().sounds.enabled` is false. Nothing for the agent being watched:
  the window open, `window().active`, the keyboard in the window and that
  tab shown. A terminal not adopted as a tab yet is named after its
  program. Statuses live in the window's shared memory so one copy reports
  each change; after a gap of over 3 s (hidden with no button, reloaded) the
  first check only takes note. Clicking a toast opens its own terminal tab,
  even after hiding the window. Core must still confirm that terminal's
  ownership; a stale toast reports that it is gone and never starts another
  shell.
- **Unseen finishes** light the button's dot and keep a tab's done dot: a
  "finished" alert leaves its terminal unseen until its tab shows in the
  open window while `window().active`, as Herdr keeps a tab "done" until you
  look at it; working, blocked or error again clears it. Working and needing
  the person never light the button.
- **Ctrl+Shift+Space** shows or hides the window from anywhere, also while a
  terminal or the window has the keyboard. The optional button does the
  same. Changing spaces or tabs keeps it open; switching layouts closes it,
  and the shortcut opens it again there. Clicks beside it don't close it.
- **Header/Notes shortcuts**: Ctrl+Tab goes to the next page,
  Ctrl+Shift+Tab to the previous, wrapping through Notes and the terminals
  in header order. Ctrl+Shift+T adds a shell; Ctrl+Shift+N opens Notes.
  Bind these only under `mod:float-space`. Embedded terminals have Herdr's
  `Terminal` key context, not the mod's, so their existing bindings remain.
  Click the header before using Float Space's shortcuts from a terminal.
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
- **Focus.** Notes immediately takes keyboard focus when opened or switched to.
  In Herdr 0.1.12, overlay terminals do not take keyboard focus on open and
  require a click to focus. The window marks keyboard focus: its whole border
  turns `accent` when typing goes into the window (Notes, header, or after
  clicking into an embedded terminal) and stays `input` otherwise. Hiding the
  window restores focus to the pane that held it before opening. Escape is left
  to the terminal programs.
- **Notes** take keyboard focus when opened and save 400 ms after typing
  pauses, when the editor loses the keyboard, and when Notes closes (another
  tab, hiding). They are the same in every space.
- **The notes menu** opens from the Notes tab's chevron, or from a click on
  the tab while Notes shows; a second press closes it. Picking a note shows
  it on the Notes page, with the keyboard in it, and closes the menu; so
  does **New note**, after its name (prefilled "Note <n>", selected) is
  confirmed with Enter. Rename (Enter saves) and delete keep the menu open.
  An empty note goes at once; one with text asks first. Deleting the open
  note shows the next one, or the one before it at the end. ↑/↓ move the
  keyboard's row, Enter picks it (or confirms a delete), Esc closes the
  menu and drops an unfinished rename (Herdr closes a popup on Esc). A name
  is one line of at most 40 characters; a blank one keeps the old name
  ("Note <n>" for a new note).
  At most five notes; the last one can't be deleted. Header shortcuts do
  nothing while the menu is open.
- **Note colors**: the dot on a row shows the note's colors in place of the
  row, the menu staying open. Picking one (click, or ←/→ then Enter)
  saves it as the note's `color` in the notes file and shows the row again;
  **Theme** removes it. A note without a color, or with one this version
  doesn't know, follows the theme.
- **Outside edits**: the notes file is read again whenever Notes or the menu
  opens and nothing typed is waiting to be saved, so a change made by an
  agent or an editor shows then. A save that finds the file changed by
  something other than this app keeps the notes shown here and says so in a
  "Float Space" warning, at most one every 10 s (save errors too).
- **Window size**: a preset applies at once and closes the popup. The
  sliders show their value while dragging but change nothing until Apply;
  Reset puts 50 × 60 in the sliders; Escape or a click outside cancels.
  Any size applied that is no preset becomes Custom, which then applies in
  one click like a preset; Custom does nothing until there is one.
  Pressing the size button again closes the popup. A new size opens centered
  the first time and afterwards wherever it was last dropped, so a Small
  window can stay in a corner while Normal stays in the middle.
- Pressing on free header space and dragging moves the window; Herdr keeps
  the spot. Tabs, buttons and Notes don't start a drag.
- Errors show as a Herdr notification titled "Float Space".
- Notes, tabs, the selected page and the size survive restarts. After a
  reboot the shells come back as shells; running programs and agents don't.
- **Moving old notes**: the first read of the notes file in an app run
  moves the single Notes page an earlier version left in shared state into
  the file, as the note "Notes" (or as one more note when a file already
  exists and has room), and removes it from shared state only once the file
  holds it.

## Built from

- **Files** (`mods/float-space/`): `main.js` (views and the Herdr calls),
  `controller.js` (the window's lifecycle), `model.js` (saved state and the
  window's layout), `notes.js` (the notes, without Herdr calls), `mod.json`,
  and its icons `float.svg`, `notes.svg`, `plus.svg`, `size.svg`,
  `hide.svg`, `close.svg`, `spinner.svg`, `chevron.svg`, `check.svg`,
  `rename.svg`.
- **mod.json**: `{"place": "none", "title": "Float Space", "overlay":
  {"kind": "window", "frame": "none", "width": 1, "height": 1}}`. No layout.
- **keys.json**: `ctrl-shift-space` → `mod.open:float-space` in `global`,
  `terminal` and `mod:float-space`. In `mod:float-space` only:
  `ctrl-tab` → `float-space.next`, `ctrl-shift-tab` → `float-space.prev`,
  `ctrl-shift-t` → `float-space.new`, `ctrl-shift-n` → `float-space.notes`.
- **Copies by role** (`props().role`):
  - none with an `overlay` id (from `mod.open`), or `"run"` with a `command`:
    an invisible 1×1 window that runs one command (default `toggle`) and
    closes itself.
  - `"bar"` with a `generation`: the header.
  - `"alert"` with an `address`, `title`, `level`: an invisible 2px window
    at the top left that posts a native toast and listens for its unique
    `float-space.alert-<overlay id>` action through `nextCommand()`. It
    handles the reveal itself under the command lease, then closes. It
    expires 250 ms after the toast (the toast mod's 5 s for info, 8 s for error), unless a click has
    started the reveal and it is still waiting for core; closing it also
    dismisses the toast. This keeps an existing toast usable after hiding
    Float Space.
  - `"edge"` with a `side` (`left`, `right`, `bottom`): the border beside and
    under the body.
  - `"notes"`: Notes. `"notes-menu"`: the notes menu. `"size"`: the size
    popup.
  - none in a layout, or `"launcher"`: the optional button, which also runs
    the agent check every second.
- **The window**: `openOverlay({kind: "window", key:
  "float-space.window.<W>x<H>", frame: "none", width, height, layout})`,
  W and H in percent; the layout is a column with `radius: 10` and no
  border: the 30px `bar` block; a row of the 1px `left` edge, a `{terminal}`
  block or the `notes` block, and the 1px `right` edge; then the 10px
  `bottom` edge. The header draws the border's top with `rounded_t(10)`,
  the side edges fill with the border color, the bottom band draws
  `border_b`, `border_l`, `border_r` and `rounded_b(10)`.
- **Commands** run by the controller: `toggle`, `show`, `hide`, `new`,
  `notes`, `next`, `prev`, `reveal-<address>`, `select-<address>`, `end-<address>`, `resize-<W>-<H>`,
  `reconcile`. The header, the popup and the button start them with
  `openOverlay({mod: "float-space", kind: "window", frame: "none", width: 1,
  height: 1, props: {role: "run", command}})`.
  Only the current header generation handles the four navigation commands
  from `nextCommand()`, and only while it or Notes has keyboard focus with
  no size popup or notes menu. A remount must not leave an older header handling them too.
- **Reconciliation**: every 3 s while open, compare owned live addresses with
  saved tabs. Remember a mismatching snapshot only after core confirms it
  successfully. Failed queries retry at the next check; successful queries
  against an unchanged lagging snapshot do not repeat. Clear that memory
  when the snapshot and saved tabs match again.
- **One controller** for all copies, in `globalThis.__herdr_float_space_window_v1`
  with a lease so commands run one at a time; its prototype is reset to the
  running build's class on every use.
- **herdr**: `appHome`, `home`, `hc`, `focused`, `panes`, `terminals`,
  `shared`, `setShared`, `settings`, `props`, `theme`, `window`, `run("pane.focus")`,
  `openOverlay`, `closeOverlay`, `notify`, `playSound`, `nextCommand`,
  `readTextFile`, `writeTextFile`. **gpui**: `View`, `div`, `svg`,
  `image`, `h_flex`, `v_flex`, `TextareaState`, `Textarea`, `InputState`,
  `Input`, `SliderState`, `Slider`, `SliderTrack`, `SliderIndicator`,
  `SliderThumb`.
- **Programs**: `hc run --bg --keep --no-parent --cwd <focused terminal, else space folder, else home> --json`,
  `hc ls --json`, `hc kill <address>`, always with the labels
  `herdr.mod=float-space` and `herdr.float-space=<app home>`.
- **Saved state**: shared key `float-space.v1`, `{version: 2, tabs:
  [{address, title}], active, page: "terminal" | "notes", size:
  {width, height}, custom: {width, height} | null, sequence}`; `custom` is
  the last size used that is no preset (missing in older state: the current
  size when it is no preset). A `notes` string from an earlier version is
  carried along untouched until it has been moved.
- **Notes file**: `<app home>/data/float-space/notes.json` (Herdr makes
  `data/<mod>` for every mod), two-space indented JSON with a trailing
  newline: `{version: 1, active, sequence, notes: [{id, name, text}]}`. Ids
  are `n<number>` from `sequence` and never reused. Reading never drops a
  note's text: a missing or repeated id gets a new one, a missing name
  becomes "Note <n>", and a file with more than five notes keeps them all
  (only adding is refused). A file of a newer `version` or that isn't JSON
  is never written.

## Watch out

- `<mod>.<command>` reaches shown copies only: the current header handles
  keyboard commands, and each toast has its own short-lived receiver.
  `mod.open` starts a new copy without a layout block. `globalThis` is
  shared by all copies of the mod.
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
- `setShared` redraws every mod in the app: never write unchanged state, and
  keep the window's runtime state in memory. Notes stay out of shared state
  for that reason.
- Notes' memory (the notes, the file as last read or written) lives in
  `globalThis.__herdr_float_space_notes_v1`, shared by copies and kept
  across reloads. `writeTextFile` runs on a thread of its own and lands even
  when the copy that called it is stopped, so writes need no lease: each
  passes the file's text as last known, and a stale one reads the file
  again. Text this app wrote recently is no news; anything else is an
  outside edit. One read per app run is shared through a timestamp that
  expires after 3 s, not a promise, for the same reason as the command
  lease. The header, Notes and the menu redraw on one shared promise, as
  the border's blocks do, and the header saves anything left unsaved every
  3 s.
- A press outside the notes menu closes it before the Notes tab's click
  arrives. It records itself in `globalThis.__herdr_float_space_notes_menu_v1`
  like the size popup. A press on the chevron also reaches the tab, whose
  bounds place the menu.
- Notes' textarea is `set_auto_grow(10, 10)`, not `rows: 10`. Both give at
  least 10 rows that fill the window, but the plain mode, once 24 rows fit,
  keeps the caret 3 rows above the bottom and clamps the scroll only after
  painting, so Enter on the last line drew the text 2 rows too high for a
  frame and then dropped it back. Its scrollbar is the base textarea's own;
  a mod can't restyle it.
- The button's dot, the tabs' done dots and the unseen finishes live in that
  memory, not in Herdr's live data, so Herdr doesn't redraw for them: after
  each check the header and the button compare the memory's `marks`
  (`<dot>|<unseen addresses>`) with what they last drew and call their own
  `cx.notify()`. Only the button watches while the window is hidden; a
  layout without it gets no alerts then.
- The core keeps an agent's last 7501 report after the agent quits, so
  `terminals()` goes on giving its `program` (Antigravity) and `status` over
  a bare shell. A tab treats the agent as gone when the foreground is the
  terminal's own process with its own argv (`foreground.pid === pid`, same
  `argv`; `exec agy` keeps the pid, not the argv), and then draws the shell
  entry another listed terminal shows (Herdr's `icons/shell.svg` when none
  does), its tab title and no status, and raises no alert.
- `terminals()` can lag or come back empty: confirm with `hc ls` before
  treating a terminal as gone, and list owned terminals again right before
  `hc kill`. Never add `herdr.space` or `herdr.tab` labels, which would put
  these terminals into the person's spaces.
- Renaming the mod: the name is in its folder, the `mods/float-space/*.svg`
  paths, `mod: "float-space"` in the overlay specs, the `herdr.mod` label, the
  `float-space.v1` key, the two `globalThis` names and `keys.json`.
- Built on Herdr 0.1.10, core 0.1.15; tested on 0.1.11, core 0.1.16, Linux. It runs `hc` and
  local shells, keeps Notes as plaintext in `data/float-space/notes.json`,
  makes no network requests and reads no files outside the app.

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
- Notes typed in one space appear in another and survive a restart. Five
  notes can be added, switched, renamed and deleted from the menu; a sixth
  is refused. A Notes page left in `shared.json` by an earlier version shows
  as the note "Notes" and leaves `shared.json`.
- Small, Normal and Large apply in one click and fit inside the app; the
  sliders change nothing until Apply. Custom brings back the last size
  applied with the sliders, also after a restart.
- The border is `accent` all the way round after clicking the window's
  terminal, Notes or a header tab, and `input` after clicking a pane outside.
- With the window hidden and the button in the layout, an agent probe shows
  no dot while working or blocked, and a yellow dot with a "<name> finished"
  toast after finishing; opening the window on that tab with Herdr active
  clears it.
- Rapid presses never start an extra shell, also right after the mod
  reloads; `herdr-app status` shows no errors.
