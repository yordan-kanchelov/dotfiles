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

- **Header**, 42px, 14px side padding, bottom border. The tool's name at 13px
  semibold: "Git" for a repository, "Manygit" for a folder of them (see
  **Manygit** below). A repository opened from the Manygit list shows a back
  chevron and "Manygit" (back to the list), then the repository's name as a
  chip (folder icon, `raised`, `selected` while open) that drops the list's
  rows down under the header, over the graph: `raised`, at most 260px with
  scrolling, the open repository `selected` with its name in `accent`, every
  row read again on opening. Picking one opens it; `Esc` closes the dropdown.
  Beside it, the current branch appears as a chip: 22px tall, radius
  6, `accent` at 15% (`accent` + `26`) behind `accent` text, a 12px branch icon
  and the name at 11.5px semibold; detached HEAD reads `detached at <8 chars>`
  with a commit icon. On the right, 24px icon buttons in `muted`: Fetch (arrow
  down, only when the repo has remotes; it says `Fetching…` while running) and
  Refresh, and Settings (a gear) on the Manygit list and when a folder holds
  none. No commit count, as in
  Git Graph.
- **Manygit**, when the folder isn't a repository but holds some, after
  [manygit](https://github.com/rabeeh-ta/manygit)'s repository pane, in place of
  the toolbar and table. The header reads `Manygit`, `N repos` in `dim`. Rows
  grouped by the folder they're in (a 26px `dim` 11px heading, `group/`, `./`
  for the top; no headings when every repo is at the top), each 34px, indented
  28px under a heading (14px otherwise) to read as inside it: the name at 11.5px
  (`accent` for the open one), right after it the uncommitted count as a 6px dot
  and number in `blocked` and how it stands against its upstream, and on the right, as PR #2's
  picker, the branch in `muted`
  with a 12px branch icon (`detached`; git's error in `ansi1` when status
  fails), at most 200px. Against its upstream, at
  11.5px as Herdr's Spaces list draws it: `↑N` in `ansi2`, `↓N` in `ansi1`
  (both when it has diverged), nothing when it's in sync; then manygit's
  states Herdr has no mark for: `not pushed` in `ansi1` (a remote, but the
  branch has no upstream; nothing on a detached HEAD), `no remote` `dim`, `…` while loading. A click opens the repository's graph with everything above;
  "‹ Manygit" or `Esc` (with nothing else open) returns to the list.
  **Right-click a row**: its remotes (`git config --get-regexp
  '^remote\..*\.url$'`) and the machine's agents (`knownAgents`, kept per
  machine and asked again after) are read, then a 268px menu opens at the
  pointer. First Herdr's own: `New <agent> tab` for up to 3 installed agents,
  most picked first as Herdr's + menu (their icon, in color unless tinted), and
  `New terminal tab`, each `tab.new` with the repository as its folder. Then
  what the row's token asks for first: behind, Pull, Fetch, Push; ahead, Push,
  Fetch, Pull; no upstream, `Push and set upstream…`, Fetch; otherwise Fetch,
  Pull, Push (all need a remote; Pull an upstream). Pull asks first and runs
  `git pull --ff-only --quiet`; Push is the graph's dialog (remote, set
  upstream); Fetch runs at once. With uncommitted changes: Commit, Stash, Reset
  uncommitted changes, the graph's dialogs. Last: `Open on <host>` (origin's
  web page: https without credentials, or an scp/ssh URL on its host), Copy
  path, Copy branch name. Actions check the row's HEAD and branch as the
  graph's do, and the list reads again after one. A row still loading, or that
  git can't read, has no menu.
  Fetch all (the fetch arrow and `Fetch all`, `Fetching 3/12…` while it runs)
  fetches every repository with a remote (or not read yet), 8 at a time, as
  manygit does: `env GCM_INTERACTIVE=0 GIT_TERMINAL_PROMPT=0 GIT_ASKPASS= git
  fetch --quiet`, so saved credentials and SSH's configuration work but nothing
  stops to ask for a login. Each row reads its status again as its fetch ends;
  a failure shows git's last line in `ansi1` where the branch goes and `fetch
  failed` as its token, until a later fetch of it works. It goes on if a
  repository is opened, and ends with a toast (`Fetched 12 repositories`, or
  `Fetched 10 of 12 repositories`, a warning).
  Settings opens a 240px popup with two 30px rows and no other text: `Scan
  depth` and a 56px input holding the depth (1 to 5, 3 by default, manygit's;
  `shared("git-graph.depth")`), and `Show tags` with a checkbox, off by
  default (`shared("git-graph.tags")`), as manygit's `t`. A valid depth applies
  as it's typed and searches again; anything else turns the box `ansi1`.
  With tags on, each row reads its newest tag too (`for-each-ref --count=1
  --sort=-creatordate refs/tags`, beside the status call) and shows it just
  before the branch: a tag icon and the name in `dim`, at most 120px. Enter or Esc
  closes it.
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
  (`<folder, ~-shortened> isn't inside a git repository, and holds none within N
  levels. Focus a terminal in one, or search deeper in settings.`; for a folder
  that isn't searched, `… isn't a repository, and is too big to search for
  them. Focus a terminal in a repository, or in a folder that holds some.`),
  `No commits yet`, `Can't read the history`
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
  `props.folder` (as a pane), always that folder, here. If it's a repository,
  use it; otherwise it's a Manygit folder when it holds repositories. A home
  folder and any folder above it aren't searched (too big, and on macOS walking
  home asks for Desktop, Documents and Downloads): this machine's `home()`, and
  for another machine, whose home isn't known, `/`, `/root`, `/home/<name>` and
  `/Users/<name>`. They say so.
  A new folder starts clean (selection, page size, details) and loads at once; a
  slower load for the previous folder drops its result.
- **Switching fast**: leaving a folder keeps it as it was (the last 24 folders).
  Coming back shows that in the same frame, then reads it again in the background
  and redraws only if something changed (the log, HEAD, branches, remotes or the
  uncommitted files). Like manygit, the folders open in other spaces' panes are
  read ahead, one at a time, this machine's first: 1.5 s after start, then every
  15 s for new ones. Read-ahead leaves out `git status` (it runs the clean
  filters a repository's own config defines): the uncommitted row comes with
  the read when the folder is shown. A commit's details are kept too (the last
  200): clicking it again shows them at once.
- **Manygit loading**: one `find -H <folder> -mindepth 1 -maxdepth <depth+1>`
  walk (on the space's machine too; `-H` follows the folder itself when it's a
  symlink, since macOS's find lists nothing under one, and no symlink below it)
  prints each `.git`
  and prunes there, and prunes hidden folders, `node_modules`, `vendor`,
  `venv`, `__pycache__`, `dist`, `build`, `target`, `site-packages` and
  `Library` (a repository whose own folder has one of those names isn't found);
  its output counts even when it exits 1 (an unreadable folder), at most 500
  repositories. Each row's status is one `git status --porcelain=v2
  --branch -z --no-renames --untracked-files=normal` (branch, upstream,
  ahead/behind and the changed count; manygit needs six to eight calls), plus
  `git remote` only when there's no upstream, at most 8 at a time, each row
  drawing as it comes, each read on the machine the list was read on and
  skipped once the panel has left it (a load id, new for each load, so opening
  a repository and coming back can't revive an older one). Locally, each
  repository's `.git` is watched by one loop for as long as it's listed
  (opening one and coming back keeps them; a loop whose repository isn't listed
  any more ends at its next change), and a ref or index change re-reads that
  row; the list re-reads every 15 s for working tree edits, keeping the old
  values on screen until new ones differ. A folder that held none isn't
  searched again by the 15 s re-read, only by Refresh, a new depth or coming
  back to it. An upstream that's configured but gone from the remote (git
  prints `branch.upstream` and no `branch.ab`) reads `upstream gone` in
  `ansi1`, and has no Pull.
- **Loading**: resolve the root with `git rev-parse --show-toplevel`; for the
  repository, together run `git log` (`--branches --tags --ignore-missing HEAD`, plus
  `--remotes` when Remotes is on, with All branches, or `HEAD` with Current; not
  `--all`, which also walks other tools' refs such as `refs/t3/checkpoints/*`;
  `--date-order --decorate=full -n301`: one past the page says whether there
  are more, as Git Graph asks), `rev-parse HEAD`, `symbolic-ref --short HEAD`,
  `for-each-ref refs/heads`, `git remote` and `git status --porcelain=v1 -z
  --no-renames --untracked-files=all`. Reads pass
  `--no-optional-locks -c core.fsmonitor=false -c diff.autoRefreshIndex=false`,
  so they write nothing under `.git`.
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
  uncommitted row: Commit, Stash, Reset uncommitted changes, Show in Changes panel.
  Push needs a remote.
- **Actions** run as argv, stopping at the first failure. With no dialog
  (checkout of a local branch, copy, show Changes) the menu runs it, then closes.
  Otherwise a dialog asks: create branch (name, check out), add tag (name,
  optional message making it annotated), rename, delete (force), delete remote
  (`push <remote> --delete <branch>`), delete tag, merge (`--no-edit`, optional
  `--no-ff`), rebase, cherry pick and revert (`-m 1` for merges; revert
  `--no-edit`), reset (soft / mixed / hard, mixed chosen), push (remote, set
  upstream), push tag (`refs/tags/<name>`), commit (message; "Stage every
  change first (untracked too)" runs `add --all` before `commit -m`, ticked
  unless something is already staged, and refused while `ls-files --unmerged`
  lists conflicts, since it would commit their markers), stash (message,
  include untracked), reset uncommitted (mixed / hard), checkout commit
  (`--detach`). Checkout of a local branch is `checkout <name> --`, so a branch
  deleted since the graph was drawn fails instead of naming a path. Names must
  be non-empty, without spaces, and not start with `-`; a commit message is
  free text, given as `-m`'s own argument. Success posts a toast (`Checked out
  fix`); a failure keeps the dialog open with git's last lines (hints dropped),
  or toasts from the menu.
- **Fetch** runs `git fetch --all` and reloads.
- **Copy** writes the clipboard and toasts `Copied`.

## Built from

- `mods/git-graph/`, `mod.json` `{ "place": "none" }`: nothing docks by itself.
- `main.js`: one `View` with five roles by `props().role`: none, the graph;
  `"menu"`, the popup (`openOverlay({ mod: "git-graph", kind: "popup", at:
  "pointer", width: 268, height, props: { role: "menu", target, ctx } })`);
  `"dialog"` (`kind: "dialog", width: 420, height` computed from its fields).
  `ctx` carries root, machine, current branch, HEAD, local branches, remotes.
  `"update"` (`kind: "dialog", width: 460, height: 400`): the update window.
  `"settings"` (`kind: "popup", at: "pointer", width: 240, height: 92`): the
  Manygit scan depth and Show tags (`settings.js`).
- `repos.js`: Manygit's `find` arguments, its output as grouped repositories,
  the one-call status and its parse, and the sync token; pure, so the tests
  run them on real folders.
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
- The zoom, in a list: a row is a whole number of screen pixels (`rowPx()`; 24 ×
  0.9 = 21.6 left a hairline gap at every row edge), `rowH()` the same in the
  units elements take. Herdr 0.1.12 zooms lists itself ("Lists in mods follow
  the zoom"), and the two versions differ (`updates().app.version`, asked once):
  - 0.1.12 and later: the list's row height is `rowH()` and the lines are drawn
    in units, like the dots. Scaling them as before put every line 1.2× further
    out than its dot at zoom 1.2, and every row 1.2× too tall.
  - Before: `paint_path` in a list took screen pixels and ignored the zoom, so
    the lines multiply their coordinates, width and dash by it (`unit()`), and
    the list's row height is `rowPx()`.
- Seen at zoom 0.9 and 0.8 before 0.1.12. Untested: Linux, Windows, the diff
  list at a zoom other than 1 before 0.1.12. Manygit needs `find` and `env`, so
  not Windows.
- Herdr's `exec` stops a command after 30 s: a fetch, pull or push over a slow
  network, or a slow pre-commit hook, fails there.

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
