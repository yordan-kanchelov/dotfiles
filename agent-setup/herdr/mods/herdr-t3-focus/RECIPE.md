# T3 Focus

A sidebar for Herdr App that keeps only the agents still asking for your attention in sight, as cards, newest news first. Agents you are done with are settled by hand and sink into a quiet, folded list at the bottom; any new work brings them back. Modeled on the Settle sidebar of [T3 Code](https://github.com/pingdotgg/t3code).

![T3 Focus](preview.png)

## What you see

Top to bottom, on the `chrome` theme background, 13px text:

1. **Top row** (32px, left padding 8, right 10): a wide `Search` button (26px high, search icon + "Search"), then three 26px square icon buttons: space filter (`list-filter.svg`, or the chosen space's avatar, two overlapping avatars when several), New space (`folder-plus`), New agent (`square-pen`).
2. **Cards** (scrolling list, padding 8, gap 2): one per agent that isn't settled and isn't working. Card: padding 10/8, radius 10, `selected` background when it is the focused agent, `hover` background otherwise on hover.
   - Line 1 (20px, 12px `dim` text): 14px space avatar (rounded 4, white bold initial on the space color), space name (`space · machine` for remote agents), then the corner.
   - Line 2: title at 14px, `foreground` only for the focused card, `muted` otherwise; the program icon (16px) at the right.
   - Line 3, only when there is something to say (12px `dim`): branch, and "N sub-agents working".
   - Corner: `Needs you` (amber `blocked`, a 14px `!` badge) for blocked, `Done` (green `ansi2`, circle-check) for done and not yet seen, else how long ago it last changed (`now`, `5m`, `3h`, `2d`, `1w`).
   - Empty: "Nothing needs you." (or "No agent status yet…" when no agent has reported).
3. **Shelves**, pushed to the bottom by `margin-top: auto`:
   - **Working N** header (30px, 12px medium `dim`, count and chevron at the right), folded by default; open, it lists working agents as cards with a spinner pill `Working 9s` counting up.
   - **Settled N** header, folded by default; open, it shows the 10 most recently settled as slim rows, then `Show 25 more`. A `Clear` button before the count closes the settled panes (not the one in view or its tab): the first click turns it into `Clear N?`, a second confirms; the ask ends 400ms after the pointer leaves (3s if the pointer was never on it, at once if the button goes), and a double-click only asks. Herdr closes emptied tabs. Spaces stay: one left empty first gets a shell tab where its terminals were (`panes().cwd`, not the space's starting folder, which would rename an unnamed space) (`tab.new`; `pane.close` refuses a space's last pane), then the view returns to the tab you were on. Sessions stay with the agent (`pi -r`, `claude -r`, `codex resume`).
   - Slim row: 30px, radius 8, program icon at 50% opacity, `muted` title, settled-ago time at the right.

Space avatar colors come from the shared `space.colors` state (`ansi6` `#22a99a`, `ansi3` `#e3814f`, `ansi4` `#5b8def`, `ansi5` `#8b7cf6`, `ansi2` `#3fae6a`, `ansi1` `#d9649a`, or any `#hex`); without it every avatar is `#22a99a`.

## How it behaves

- **Statuses.** `blocked` (or a sub-agent's `error`) shows Needs you and stays up top. `working`, or an agent waiting on a working sub-agent, goes to the Working shelf. `done` shows Done; `idle` shows its age. An agent takes the most urgent state of its sub-agent tree.
- **Order.** Cards by when each last came back to you (a state change this mod saw; before that, the core's `status_ms`). Working by when it was set going. Settled by when it was settled. The order is passed to `setAgentOrder`, without settled agents, so `agent.next` / `agent.prev` follow the cards and reach settled agents last.
- **Click** a card or slim row: `agent.focus` on it (focuses its pane; in a layout with an agent block, shows it there). Viewing a settled agent leaves it settled.
- **Settle.** Hovering a card that is finished (nothing in its tree working or blocked) turns its corner into a `✓ Settle` button. Settling the focused agent moves focus to the next card (or the previous one); settling one in the background moves nothing. The key command `t3-focus.settle` does the same for the agent in view (finished and unpinned), or brings it back if it is settled.
- **Unsettle.** Hovering a slim row turns its time into an undo arrow; clicking puts the agent back at the top of the cards.
- **Drag.** As in T3: move a card or row 6px to lift it. While lifted, the `Pinned` and `Active` labels open, the lifted copy follows the pointer up and down and says what letting go does (`Pin`, `Unpin`, `Settle`, `Un-settle`), and the list opens a gap the size of the destination's row where it will land (a native 150ms `height` transition); empty or folded sections show a dashed placeholder. Onto Pinned pins (upper or lower half of a pin: above or below it), onto Active unpins and unsettles, onto Settled settles. Esc or leaving the sidebar sideways puts it back; leaving off the top or bottom lands it where the badge says (Herdr reports no release outside the sidebar); Working cards don't lift. Sweep: press `✓ Settle` or a settled row's undo and move across rows to settle or bring back the whole run. Pinned cards stay up top in pin order and offer no Settle button. Pins live in shared state `agents.pins`, the same list Herdr T3's agents list uses.
- **New work unsettles by itself:** the agent (or a sub-agent) becomes working or blocked, or the core's `turn` counter has passed the one stored at settle time, which also catches work done while no window was open.
- **Filter.** The filter button opens a popover (260px wide, at most 360 tall) with a search field and `All spaces` plus every space. Click shows that space alone; shift-click adds or removes it and keeps the menu open. Remembered on this screen.
- **Search** opens the shipped `picker`; **New space** runs `space.new`; **New agent** opens the mod named by the `newMenu` prop, else the shipped `new-menu`.
- Shelf folding, the filter and the last seen states are kept in the mod's `localStorage`. The focused agent stays visible even on a folded shelf or past the page.

## Built from

- One mod, `mods/t3-focus/` (`main.js`, `name.js` (a card's title: the Pi session, a named tab, a telling terminal title, else the program), `undo.svg`, `list-filter.svg`, `mod.json` docking it `left` at 300px). One optional prop, `newMenu`: the mod **New agent** opens (the Herdr T3 layout passes `t3-new-menu`).
- `herdr`: `agents()`, `terminals()` (`labels`, `turn`, `status_ms`, `parent`, `state`), `panes()` (branch), `spaces()`, `run` (`agent.focus`, `space.new`, `mod.open`), `hc`, `notify`, `theme`, `shared("space.colors")`, `setAgentOrder`.
- `gpui-base`: `Popover`, `InputState`, `Input`, `v_flex`, `h_flex`.
- Settled state is a core terminal label on the agent itself: `hc label <address> settled=<ms>:<turn>`; `settled=` removes it. It ends with the terminal and every mod and window can read it.
- Shipped icons: `mods/workspace-chrome/{search,folder,folder-plus,square-pen,check,circle-check,spinner,chevron-down,chevron-right}.svg`.

## Watch out

- A label written with `hc label` takes about 0.65s to come back in `terminals()`. Keep the new value as pending so the row moves at once; drop it on failure and show an error `notify`.
- `terminals()[].status_ms` is only as of the app's start; it is a fallback until the mod sees a change itself.
- Treat `done` and `idle` as one when tracking change times: looking at a done agent turns it idle, and looking is not news.
- Sub-agents without a pane aren't in `agents()`; walk `terminals()` by `parent` for them.
- A card moves away without a pointer-leave event: clear the hover state on Settle / Unsettle.
- A hover style reaches text but not an `svg`; keep hover as state so icon and label brighten together.
- No auto-settle or snooze. Settling never touches the process.

## Done when

- `herdr-app check mods/t3-focus` passes.
- A finished agent shows `✓ Settle` on hover; clicking moves it to Settled within a second and `hc get <address> --json` shows `settled=<ms>:<turn>`.
- Sending that agent a new prompt brings it back to the cards and removes the label.
- Hovering a settled row and clicking the arrow puts it on top of the cards.
- With 11+ settled agents, the open shelf shows 10 and `Show N more`.
- `agent.next` walks the cards in their shown order.
