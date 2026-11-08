# Git Graph for Herdr

A commit graph for the [Herdr](https://herdr.dev) desktop app, in the spirit of
VS Code's [Git Graph](https://github.com/mhutchie/vscode-git-graph) extension:
every branch's history as colored lanes, branch and tag labels, and the git
actions you'd want from them, one double-click or right-click away. It follows
the repository of the terminal you're focused on, and in a folder of
repositories lists them all (Manygit).

![Git Graph in Herdr](preview.png)
![Multi Repo Git Graph in Herdr](multi-repo.png)

Written from scratch as a native Herdr mod (no web view, no code from the VS Code
extension).

## What it does

- **The graph.** Git Graph's table (graph, description, date, and when there's room
  author and commit), newest first, with a lane per branch and curves where
  branches fork and merge. Merge commits are muted.
- **Many repositories (Manygit).** Focus a terminal in a folder that holds
  repositories, and the panel lists them, grouped by folder, after
  [manygit](https://github.com/rabeeh-ta/manygit): each one's branch,
  uncommitted changes, and whether it's ahead (↑) or behind (↓) its upstream,
  not pushed, or has no remote. Click one for its graph, with everything below;
  its name in the header drops the list down to switch to another, and
  **‹ Manygit** goes back. Right-click one for a new agent or terminal tab in
  it, then pull, push or fetch (whichever its ↑/↓ asks for first), commit,
  stash or reset its changes, open its remote's page, or copy its path. It searches 3 folders deep
  (1 to 5: the gear's Scan depth; Show tags there adds each one's newest tag), skipping hidden folders and `node_modules`-style
  ones, but not your home folder or anything above it (another machine's
  `~` and `/` included).
- **Where you are.** The checked-out branch's label is filled with a ✓, the header
  shows the branch, and HEAD is a ring on a tinted row.
- **Labels.** Local branches carry their remote (`main | origin`), remote-only
  branches and tags have their own. Toggle remote branches, and all branches or
  just the current one, from the toolbar.
- **Uncommitted changes** sit on top as their own row, joined to HEAD by a dashed
  line.
- **Double-click a branch label** to check it out. A remote branch with no local
  one asks for the local name first.
- **Right-click** what's under the pointer:
  - a branch: checkout, rename, delete, merge into the current branch, rebase onto it, push, copy name
  - a remote branch: checkout, merge, delete it on the remote, copy name
  - a tag: delete, push, copy name
  - a commit: add tag, create branch, checkout, cherry pick, revert, merge, rebase, reset (soft, mixed, hard), copy hash or subject
  - uncommitted changes: commit (staging every change first, or only what's
    staged), stash, reset, show them in Herdr's Changes panel
- **Commit details.** Click a commit for its message, hash, parents, author, date
  and changed files; click a file for its diff.
- **Live.** It reloads when refs move (a commit, checkout or fetch from any
  terminal), refreshes the uncommitted row as you edit, and fetches with one
  button. 300 commits at first, and 300 more each time you scroll to the end.
- **Fast to switch.** Every repository you've looked at is kept, and the history
  of the ones open in your other spaces is read ahead, so switching agents shows
  its graph at once (then checks for changes in the background). Clicking a
  commit shows its header at once; the files follow, and a commit you've opened
  before is instant.

Everything that changes the repository asks first in a dialog, except checking
out a local branch and the Fetch button. Destructive choices are red, and when
git refuses, its own message stays in the dialog.

## What it runs

The mod runs `git` in the focused repository (on its machine, for spaces on
another machine) and reads files there to show an untracked file's contents. If
the focused folder isn't itself a repository, one `find` looks for repositories
in it, and each one found gets a `git status` (again every 15 seconds while the
list shows). Right-clicking one reads its remotes (`git config`) and asks Herdr
which agents are installed (Herdr asks that machine's shell, as its + menu
does). Git reaches the network only when you press Fetch, Fetch all (each
listed repository with a remote, with login prompts off, as manygit does), Pull,
Push, or delete a remote branch. The mod never runs a shell itself: every git
call is an argument list, and names you type can't start with `-`.

`git status` runs the clean filters a repository's own `.git/config` defines
(as it does in your terminal), so it runs only for what the panel shows: the
focused repository, or the repositories listed under the focused folder. The
folders open in your other spaces are read ahead for their history and branches
only (`git log`, `rev-parse`, `for-each-ref`, `git remote`), which run no
command from the repository's config.

The mod itself makes one request of its own: at most once a day it asks GitHub's
public API for this repository's latest release
(`api.github.com/repos/rabeeh-ta/herdr-git-graph/releases/latest`), with no
token and nothing about you or your repositories. See [Updating](#updating) to
turn it off.

## Install

Ask your Herdr agent: *"add the mod at github.com/rabeeh-ta/herdr-git-graph"*.
It reads [RECIPE.md](RECIPE.md) and the files, copies `mods/git-graph/` into
`~/.config/herdr-app/mods/`, and checks it.

Or by hand:

```sh
git clone https://github.com/rabeeh-ta/herdr-git-graph
cp -R herdr-git-graph/mods/git-graph ~/.config/herdr-app/mods/
```

If you already have a mod called `git-graph`, rename this one's folder, and the
`mods/git-graph/` paths and `mod: "git-graph"` names inside it, to match.

### Updating

An installed copy doesn't update itself. When a newer release is out, the
graph's header shows an **Update Graph** dot; click it for what changed. To update,
ask your Herdr agent: *"Update the git-graph mod from
github.com/rabeeh-ta/herdr-git-graph"*, or by hand:

```sh
cd herdr-git-graph && git pull
rm -rf ~/.config/herdr-app/mods/git-graph && cp -R mods/git-graph ~/.config/herdr-app/mods/
```

The top-bar copies below don't need redoing: they open `git-graph` by name.

To stop the daily check, click **Stop checking** in the update window, or set
`CHECK = false` in `mods/git-graph/update.js` (an update puts it back). Watching
the repository's releases on GitHub tells you too.

### Put it in the top bar

Herdr's tab bar has Files and Changes buttons. [docs/top-bar.md](docs/top-bar.md)
adds Git beside them (your agent can do it in a minute), by cloning Herdr's
`main` layout and `tabs` mod, and optionally ⌘G to open and close it.

### Or open it as a pane

Beside a terminal, for a wider view of one repository:

```sh
herdr-app do pane.split '{"direction":"right","mod":"git-graph","props":{"folder":"/path/to/repo"}}'
```

## Limits

- Tested on macOS with Herdr 0.1.9 to 0.1.12. Linux and Windows aren't tested yet.
- Manygit needs `find` and `env`, so it works on macOS and Linux (and spaces on
  them), not on Windows. It skips a repository whose own folder is hidden or
  named like a build folder (`build`, `dist`, `vendor`, `target`).
- Herdr stops a command after 30 seconds, so a fetch, pull or push over a slow
  network, or a slow pre-commit hook, can fail there.
- Labels clip when a row has many.
- A very large history loads slower the first time if the repository has no
  commit-graph file (a fresh clone usually doesn't): openedx-platform, 78k
  commits, takes about half a second. `git commit-graph write --reachable` (or
  `git maintenance start`) in that repository brings it to about 60 ms.
- Not in this version: Git Graph's find (Ctrl+F), a branch-picker dropdown, pull
  in the graph (a Manygit row's menu has it), interactive rebase, and per-file
  actions in commit details.

## Development

```sh
npm test
```

The tests build throwaway repositories (with a bare "remote") and check the
parsing, lanes, label positions, menus, validation, and every action against
real git. The UI was checked in an isolated Herdr window (`HERDR_APP_HOME` and
`HC_SESSION` pointed at a scratch folder).

## Contributing

Pull requests are welcome.

- Run `npm test` and say in the PR that it passes.
- **If the change shows on screen, add a screenshot**, before and after when it
  fixes something you can see. It's the fastest way to review a UI change.
- Say which Herdr version and OS you tested on, and the zoom if it isn't 1.
- Update `RECIPE.md` when behavior changes, so the recipe still builds what the
  mod does.

## License

MIT, see [LICENSE](LICENSE). Most icons are drawn after
[Lucide](https://lucide.dev) (ISC, see `mods/git-graph/icons/LICENSE-lucide.txt`).
