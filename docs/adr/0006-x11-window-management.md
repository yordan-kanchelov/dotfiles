# 0006. macOS-style window management on Cinnamon/X11

Status: Accepted, 2026-11-20

## Context

`xbindkeys/` brings macOS habits to Cinnamon on X11: Mission Control, App Exposé on the mouse side buttons, and Rectangle-style tiling. Cinnamon's D-Bus surface, X button numbering and GTK client-side decorations each behave in surprising ways.

## Decision

### Mouse buttons (`.xbindkeysrc`)

- The back button (the mouse calls it 4; X calls it 8, "Button Side") opens Mission Control: every window, through Cinnamon Scale. The forward button (5/X9, "Button Extra") opens App Exposé: the focused app's windows. Swap the two blocks if your thumb disagrees.
- Both fire on *release*, not press. A mouse grab bound to press fires several times for one physical click (measured: 7 fires from 3 clicks). Each repeat toggles the overview shut again and spawns duplicate rofi processes.

### Mission Control (`mission-control`)

- It runs Cinnamon's Scale (all windows on the current workspace) through `org.Cinnamon.Eval`, which drives the same toggle as the hot corner. `org.Cinnamon.ShowOverview` and `ShowExpo` reply without error and do nothing on this Cinnamon: `Main.overview.visible` stays `false` across the call, so the D-Bus return code tells you nothing.
- `--print-reply` is required. Without it, dbus-send marks the message `NO_REPLY_EXPECTED` and Cinnamon drops the Eval. This was verified by watching `Main.overview.visible` stay `false` across a call that omitted it.

### App Exposé (`app-expose`)

- Cinnamon has no per-app window overview, so rofi's window mode is pre-filtered to the active window's WM_CLASS.

### Tiling (`.xbindkeysrc`, `tile`)

- Tiling uses Ctrl+Super. Rectangle's own Ctrl+Alt is taken: the arrows switch workspace and Ctrl+Alt+T opens a terminal. Ctrl+Super is unbound across the whole gsettings tree, so nothing has to be given up.
- The halves duplicate Cinnamon's native Super+arrows on purpose. The muscle memory matches macOS, and the native bindings keep working.
- Each argument to `tile` is one `X Y W H` position in fractions of the work area (`0 0 .5 1` is the left half), or `center`, which keeps the size and centres the window. Pressing the same binding again moves to the next argument and wraps, the way Rectangle cycles. Keys that lead a group (Left/Right/Up/Down, D, E, U, Z, X) walk the whole group. F, G, I, J, K and T jump directly, since the group leaders already reach those spots. The groups: halves cycle 1/2, 2/3, 1/3. U walks the quarters clockwise. D walks the thirds first, centre, last. E walks the two-thirds. Z walks the sixths from the top right, each row right to left, top row first; X mirrors it.
- The cycle continues only while the same binding keeps hitting the same window. Any other window or binding starts again at the first position. Moving the window by hand in between goes unnoticed, and the next press resumes the cycle.
- The state file name includes the uid. The `/tmp` fallback is shared between users, and a fixed name there is one pre-planted symlink away from overwriting someone else's file.
- A maximized window ignores resize requests, so the script removes the maximized state first. GTK drops its shadow while maximized and takes about 150 ms to grow it back. Reading the extents earlier sizes the window as if it had no shadow. The fixed wait is a known workaround: [yordan-kanchelov/dotfiles#21](https://github.com/yordan-kanchelov/dotfiles/issues/21).
- `_NET_WORKAREA` is the screen minus panels. The script strips xprop's commas before parsing.
- Each position is split into `X Y W H` by unquoted `set -- $position`, since POSIX sh has no arrays.
- Only one of two extents ever applies to a window, and both are left/right/top/bottom. `_NET_FRAME_EXTENTS` is the window manager's title bar and borders. wmctrl positions the frame but sizes the *client*, so these extents come off the target size; otherwise the window overhangs its cell by the title bar (measured: 128 px of overlap between the top and bottom halves). `_GTK_FRAME_EXTENTS` is the invisible shadow margin that GTK apps carry inside their own geometry (122/122/110/134 on Ghostty). It is added back, so the *visible* edge lands on the cell rather than the transparent one.
- wmctrl uses gravity 1 (north-west), not 0. Gravity 0 means "whatever the app declared", and an app declaring CenterGravity ends up measurably off its cell.

## Consequences

Everything here assumes X11 and Cinnamon. Wayland sessions get none of it (see 0005). Multi-monitor tiling: [yordan-kanchelov/dotfiles#20](https://github.com/yordan-kanchelov/dotfiles/issues/20).
