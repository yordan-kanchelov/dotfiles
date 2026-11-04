# Git Graph

A commit graph of the focused terminal's repository, after VS Code's Git Graph:
colored lanes for every branch, labels for branches, remotes and tags, the
checked-out branch marked, and uncommitted changes as a dashed row on top.
Double-clicking a branch label checks it out; right-clicking a label or a commit
opens Git Graph's menus (checkout, merge, rebase, cherry pick, revert, reset,
tag, branch, push, delete, copy), each asking first in a dialog. Clicking a
commit shows its details and files, and a file its diff. It fills a side panel
(a Graph button beside Files and Changes, see docs/top-bar.md) or a pane.

![Git Graph](preview.png)

## What you see

One column on the `background` color, radius 10, 1px `border`, base type 12.5px.
Top to bottom:

- **Header**, 42px, 14px side padding, bottom border. "Graph" at 13px semibold.
  Beside it the current branch as a chip: 22px tall, radius 6, `accent` at 15%
  (`accent` + `26`) behind `accent` text, a 12px branch icon and the name at
  11.5px semibold; detached HEAD reads `detached at <8 chars>` with a commit icon.
  On the right, 24px icon buttons in `muted`: Fetch (arrow down, only when the
  repo has remotes; it says `Fetching…` while running) and Refresh. No commit
  count, as in Git Graph.
- **Toolbar**, 34px, 10px side padding, bottom border: a segmented control
  `All branches | Current` (22px segments, 11.5px, the chosen one `raised` with a
  border) and a `Remotes` checkbox (13px box, `accent` filled with a check when
  on).
- **Column headers**, 24px, 11px `dim`: Graph (as wide as the graph), Description
  (the rest), Date (62px, right-aligned), and from a width of 600px also Author
  (120px) and Commit (66px). Each column but Description has a drag handle in the
  gap at one edge (8px wide, column-resize cursor, `border` on hover, a 1px `accent`
  line while dragging): Graph's on its right, the others' on their left.
- **Rows**, 24px each, a virtual list with a scrollbar:
  - The graph cell: lanes 12px apart from a 6px inset, at most 40% of the width.
    Lines are 1.5px strokes in lane colors `ansi4, ansi2, ansi5, ansi3, ansi6, ansi1,
    ansi12, ansi10, ansi13, ansi11, ansi14, ansi9` (cycling by lane); a change of
    lane is a cubic curve with vertical tangents inside half a row. Commit dots
    are 8px, filled with the lane color; HEAD's is a ring (2px lane-color border on
    `background`).
  - Labels, 6px apart, 18px tall, radius 5, 1px border, monospace 11px with a
    10px icon: a local branch (branch icon) bordered in its lane color, with a
    same-named remote riding on it as a second part (`main | origin`, the part
    tinted with the lane color at 12%); a remote-only branch (cloud icon); a tag
    (tag icon) in `ansi3`; a detached `HEAD` filled `accent`. The checked-out
    branch is filled with its lane color, text in `background`, semibold, with a
    check icon instead of the branch icon, and comes first. Names longer than 22
    characters are cut with `…`. Labels and description clip together so the date
    columns never move.
  - The description in `foreground`; merge commits `dim`; HEAD's semibold.
  - Date as `now`, `12m`, `3h`, `6d`, `Oct 3`, `Mar 2025`, in `dim`. Author in
    `muted`; the hash's first 8 characters in monospace 11px `dim`.
  - HEAD's row tinted with its lane color at 8%; the selected row `selected`;
    `hover` under the pointer.
  - **Uncommitted changes (N)** as the first row whenever the working tree has
    changes: a gray ring, a dashed gray line (3 on, 3 off) down to HEAD's lane,
    `muted` text, `*` in the other columns.
  - With more history, a last row `Load 300 more commits` in `accent`. Scrolling
    it into view loads the next 300, as Git Graph does (`Loading more commits…`
    meanwhile); a click does the same.
- **Details**, 320px under the list when a commit is selected, top border. A 32px
  bar with `Commit <8 chars>` (or `Uncommitted changes` and an `Open Changes`
  link) and a `×`. Below, scrolling: the subject semibold, then label/value rows
  at 11.5px (64px `dim` labels): Commit (full hash, monospace, `accent`),
  Parents, Author `name <email>`, Date (`2026-10-28 12:09 · 2d`). These come from
  the history already loaded, so they show the moment the commit is clicked, with
  `Loading files…` under them; what git adds lands below without moving them:
  Committer when different, the body's lines in `muted`, then `N files +a −d`
  and one 24px row per file:
  the status letter (A `ansi2`, D/U `ansi1`, else `blocked`), the folder `dim`,
  the name, `+a` `ansi2`, `−d` `ansi1`. Clicking a file turns the area into its
  diff: a `← Files` back link and the path, then 20px monospace rows, hunk headers
  on `raised`, added lines on `ansi2` at 9%, removed on `ansi1` at 9%, line
  numbers in a 34px `dim` column.
- **In place of the table**: centered, a 46px `raised` tile with a 22px icon, a
  14px semibold title and a 12px `muted` line: `No folder`, `Not a git repository`
  (`<folder, ~-shortened> isn't inside a git repository. Focus a terminal in a
  repository to see its history.`), `No commits yet`, `Can't read the history`
  (git's error, icon in `ansi1`), `Loading history…`.

**The menu** is a 268px popup at the pointer on `popover`, 5px padding, 30px rows
(radius 7, a 14px `muted` icon, 12.8px text), 1px `border` separators between
sections; delete items are `ansi1`. Up/down/enter/esc work.

**Dialogs** are 420px wide on `popover` with 18px padding, like Herdr's prompt: a
15px semibold title with `Esc` on the right, a `muted` sentence, labelled 36px
inputs (radius 9, `accent` border when focused), radio rows for a mode (38px,
radius 8, `accent` or, for a destructive mode, `ansi1`), checkboxes, an `ansi1`
error line, and `Cancel` / the action on the right. The action button is `solid`,
or `ansi1` when the action or the chosen mode destroys something.

## How it behaves

- Agent statuses (working, blocked, done, idle) aren't shown: this is a git view.
  Nothing animates.
- **Which repository**: the focused pane's live folder (`panes()[i].cwd`), else
  `focused().cwd`, else the space's folder, on the space's machine. Opened with
  `props.folder` (as a pane), always that folder, here. A new folder starts
  clean (selection, page size, details) and loads at once; a slower load for the
  previous folder drops its result.
- **Switching fast**: leaving a folder keeps it as it was (the last 24 folders).
  Coming back shows that in the same frame, then reads it again in the background
  and redraws only if something changed (the log, HEAD, branches, remotes or the
  uncommitted files). Like manygit, the folders open in other spaces' panes are
  read ahead, one at a time, this machine's first: 1.5 s after start, then every
  15 s for new ones. A commit's details are kept too (the last 200): clicking it
  again shows them at once.
- **Loading**: one round of git calls, all together, from the pane's folder (each
  answers from a subfolder too, and status names paths from the repository
  root): `git rev-parse --show-toplevel`, `git log` (all refs except `refs/stash`
  with All branches, or `HEAD` with Current; `--exclude=refs/remotes/*` too when
  Remotes is off; `--date-order --decorate=full -n301`: one past the page says
  whether there are more, as Git Graph asks), `rev-parse HEAD`, `symbolic-ref
  --short HEAD`, `for-each-ref refs/heads`, `git remote` and `git status
  --porcelain=v1 -z --no-renames --untracked-files=all`. Reads pass `--no-optional-locks -c core.fsmonitor=false
  -c diff.autoRefreshIndex=false`, so they write nothing under `.git`.
- **Staying live**: `watchFolder` on the repository root (and on the main
  checkout's `.git` for a linked worktree). A change to `HEAD`, `packed-refs` or
  anything under `refs/` inside the git folder reloads the history; any other
  change refreshes only the uncommitted row, at most every 1.5 s. Remote spaces
  can't be watched: they reload every 15 s. After any action, `setShared(
  "git-graph.changed", now)` makes every copy reload.
- **Drag** a column handle to resize it; Description takes what's left. A dragged
  Graph stops following its lanes (24px up to 70% of the width); Date 36–240px,
  Author 50–400px, Commit 40–200px. A double-click on a handle restores the column.
  Releasing saves the widths to `setShared("git-graph.columns", …)`: every copy
  takes them, and they last across restarts.
- **Click** a commit: details open (again: they close). `Esc` closes a diff, then
  the details.
- **Double-click** a label: a local branch other than the current one is checked
  out (`git checkout <name>`); a remote branch whose local branch exists checks
  that out; one without opens the Checkout remote branch dialog (local name
  prefilled, `git checkout -b <name> --track <remote/branch>`). Tags, HEAD and
  the rest of the row do nothing on a double-click.
- **Right-click**: on a local branch, its menu (Checkout, Rename, Delete, Merge
  into <current>, Rebase <current> on it, Push, Copy name; the first, third and
  merge/rebase are left out for the current branch); on a remote part or remote
  label, the remote menu (Checkout, Merge, Delete remote branch, Copy name); on
  a tag, Delete, Push, Copy name; anywhere else, the commit menu (Add tag,
  Create branch, Checkout, Cherry pick, Revert, Merge, Rebase, Reset, Copy hash,
  Copy subject; Checkout, Cherry pick, Merge and Rebase left out on HEAD); on the
  uncommitted row: Stash, Reset uncommitted changes, Show in Changes panel.
  Push needs a remote.
- **Actions** run as argv, stopping at the first failure. With no dialog
  (checkout of a local branch, copy, show Changes) the menu runs it, then closes.
  Otherwise a dialog asks: create branch (name, check out), add tag (name,
  optional message making it annotated), rename, delete (force), delete remote
  (`push <remote> --delete <branch>`), delete tag, merge (`--no-edit`, optional
  `--no-ff`), rebase, cherry pick and revert (`-m 1` for merges; revert
  `--no-edit`), reset (soft / mixed / hard, mixed chosen), push (remote, set
  upstream), push tag (`refs/tags/<name>`), stash (message, include untracked),
  reset uncommitted (mixed / hard), checkout commit (`--detach`). Names must be
  non-empty, without spaces, and not start with `-`. Success posts a toast
  (`Checked out fix`); a failure keeps the dialog open with git's last lines
  (hints dropped), or toasts from the menu.
- **Fetch** runs `git fetch --all` and reloads.
- **Copy** writes the clipboard and toasts `Copied`.

## Built from

- `mods/git-graph/`, `mod.json` `{ "place": "none" }`: nothing docks by itself.
- `main.js`: one `View` with four roles by `props().role`: none, the graph;
  `"menu"`, the popup (`openOverlay({ mod: "git-graph", kind: "popup", at:
  "pointer", width: 268, height, props: { role: "menu", target, ctx } })`);
  `"dialog"` (`kind: "dialog", width: 420, height` computed from its fields).
  `ctx` carries root, machine, current branch, HEAD, local branches, remotes.
  `"update"` (`kind: "dialog", width: 460, height: 400`): the update window.
- `update.js`: `VERSION` (this copy's release) and the update check. At most
  once a day (`checked` in `shared("git-graph.update")`, set before asking so
  other copies skip), one `fetch` of GitHub's `releases/latest`; a newer
  `tag_name` shows an accent dot and **Update Graph** in the header. The window shows
  the release notes and the agent prompt: Copy prompt, Release page (`open_url`,
  only a URL under the repository), Later (hides that release), Stop checking
  (`off`). `CHECK = false` turns it off in code.
- `graph.js` the table; `menu.js` and `dialog.js` the overlays; `act.js` runs an
  action and opens dialogs; `git.js` everything git and no herdr import (log and
  status parsing, labels and their widths, the hit test, menus, dialogs,
  validation, argv per action); `lanes.js` the lane layout.
- Lanes: each column waits for one commit hash and keeps its column until that
  commit comes; a commit takes the column waiting for it (or the first free one),
  other columns waiting for it end there, its first parent continues its column,
  further parents take the column already waiting for them or a free one. Rows
  get segments `[fromLane, fromY, toLane, toY, colorLane, dashed]` with y in
  {0, 0.5, 1}. Drawn per row with `window.paint_path(PathBuilder.stroke(1.5)…
  .build(), color)`, one path per color.
- Rows of a virtual list can't hold handlers, so the list takes
  `on_item_click(key)` and `on_item_secondary_click(key, event)`, and an element
  around it records each left press (`click_count`, `local_position.x`). Labels
  are drawn at computed widths (padding 5, icon 13, 6.6px per monospace character
  at 11px, 1px borders), so `x` names the label part exactly; presses past the
  description column's right edge hit nothing. Positions are divided by the
  pointer's scale (a row's reported height over 24), else the zoom.
- Herdr's `mods/changes/changes.svg` for the Show in Changes item; its own icons
  in `icons/` (Lucide-style, ISC notice there).
- Commands: `layout.select` / `layout.show` (`panel-body` → `changes`, `panel`)
  for Show in Changes. Programs: `git` only, through `exec(…, { cwd, on })`.

## Watch out

- `.when(cond, …)` needs a real boolean: `undefined` (a field a commit lacks) is
  taken for the function and throws "not a function".
- Don't give a method and a state field the same name (`details`): resetting the
  field replaces the method.
- `on_click` inside a virtual list's renderer throws; use the list's item handlers.
- Two copies (panel and pane) need different list and scrollbar names: a
  scrollbar finds its list by name.
- Labels must keep the widths the hit test computes: change one, change both.
  The dragged column widths feed its right limit too.
- A drag lives on the panel's root (`on_mouse_move`, `on_mouse_up`); a handle only
  starts it. A release outside the panel never arrives, so leaving it (`on_hover`
  false) ends the drag. Scale the pointer delta as for presses. Save on release,
  not per move, or every copy redraws during the drag.
- A popup's tasks end when it closes, so the menu finishes its git command before
  closing; dialogs run theirs and close on success.
- `git log HEAD` fails in a repository with no commits: that's the empty state,
  not an error. The uncommitted row needs HEAD's hash from `rev-parse`, since HEAD
  may be past the first 300 commits.
- Paths from `watchFolder` use backslashes on Windows: normalize before matching.
- `--date-order` walks the whole history unless the repository has a commit-graph
  file (git writes one in `git gc` and `git maintenance`; a fresh clone has
  none). On openedx-platform (78k commits, 6k refs) that's about 420 ms without
  one and 60 ms with; the kept folders hide it after the first read. The order
  can't be dropped: the lanes need children before parents.
- State created during render throws (`VirtualListScrollHandle.new()` and the
  like): make it in `init()`.
- Herdr 0.1.9 on macOS: `herdr-app check` crashes for every mod (0.1.10 fixes
  it); a copy reloaded in place may keep drawing its old frame until the layout
  is switched away and back. A hidden or fully covered window draws nothing, so
  `herdr-app shot` then returns the last frame.
- The Show in Changes item assumes the main layout's `panel` / `panel-body` ids.
- `paint_path` takes screen pixels and ignores the zoom; elements are scaled by it.
  The lines multiply their coordinates, width and dash by the zoom (`unit()`) to
  match the dots, and a row is a whole number of screen pixels (`rowPx()`; 24 ×
  0.9 = 21.6 left a hairline gap at every row edge). The list's row height must
  be that same `rowPx()`, or the rows and the list's cells disagree.
- Seen at zoom 0.9 and 0.8 only. Untested: Linux, Windows, zoom above 1, the
  diff list at a zoom other than 1, a remote machine's repository.

## Done when

- `npm test` passes: labels, the hit test and its edge limit,
  the uncommitted row and its dashed line, lane continuity across real merges,
  menus per target, validation, every action on real repos with a bare remote
  (push, delete remote, upstream, tracking checkout, soft/mixed/hard reset,
  merge with and without `--no-ff`, conflicts reported), file lists and diffs,
  the empty repository, and reads leaving `.git/index` untouched.
- In a repository with merged and open branches, a tag and a remote: lanes curve
  at each fork and merge, `main | origin` shares one label, the current branch is
  filled with a check and named in the header, HEAD is a ring.
- An edited file adds `Uncommitted changes (1)` within two seconds; a commit made
  in a terminal appears without clicking.
- Double-clicking a local branch label checks it out with a toast; a remote one
  without a local branch opens the dialog; a tag does nothing.
- Right-click opens the branch, remote, tag, commit or uncommitted menu by what's
  under the pointer; the current branch's has no Checkout or Delete.
- A dialog with an invalid name stays open with the reason; deleting an unmerged
  branch without force shows git's refusal and keeps the branch.
- Focusing a terminal outside a repository shows `Not a git repository` with the
  folder and nothing left over from the last repository.
- With three labels on a row in a 368px panel, the date stays in its column.
- Dragging the Date handle left widens Date in every row; another copy takes the
  width on release; a double-click restores 62px; double-clicking a branch label
  still checks out the label under the pointer.
