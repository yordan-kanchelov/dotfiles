# T3 Focus for Herdr App

English · [中文](README.zh-CN.md)

A Herdr App sidebar mod with [T3 Code](https://github.com/pingdotgg/t3code)-style Settle: agents that need you stay up top as cards; finished ones are settled by hand into a quiet list at the bottom and come back on new work.

![T3 Focus](preview.png)

It is the focus sidebar of the [Herdr T3 layout](https://github.com/JinJieBeWater/herdr-t3), on its own. The layout also hides a settled agent's done dot in the tabs and switches between this list and Spaces/Agents.

## Install

Ask your Herdr agent to add `herdr.dev/mods/JinJieBeWater/herdr-t3-focus`, or copy `mods/t3-focus/` into `~/.config/herdr-app/mods/`. It docks on the left the first time Herdr sees it. For a Settle key, add `"cmd-shift-s": "t3-focus.settle"` to the `global` section of `~/.config/herdr-app/keys.json`: it settles the agent in view, or brings it back. How it should look and behave: [RECIPE.md](RECIPE.md).

## Update

Herdr doesn't update mods from others, and adding this again would install a renamed second copy (`t3-focus-2`), since an install never overwrites. Update by overwriting instead:

- Tell your Herdr agent: "Update T3 Focus from github.com/JinJieBeWater/herdr-t3-focus: overwrite my installed `mods/t3-focus/` with the repo's latest, then run `herdr-app check` on it." If the first install renamed it because of a clash, overwrite under that name.
- By hand: copy the folder's files over the old ones. The mod reloads by itself on save; where it is docked stays as it is.
- Kept: the Settled shelf, settled agents, the space filter. They live in `data/` and terminal labels, not in the mod folder. Lost: your own edits to the overwritten files.

## What it runs

- `hc label <agent> settled=<ms>:<turn>` when you settle or unsettle an agent, or when new work unsettles it. Nothing else; no network, no files outside its folder.

## License

Apache-2.0, as Herdr App.

## More

- [herdr-t3](https://github.com/JinJieBeWater/herdr-t3): the full Herdr T3 layout this sidebar comes from.
- [herdling](https://github.com/JinJieBeWater/herdling): a macOS menu bar companion for Herdr.
- [pi-stuff](https://github.com/JinJieBeWater/pi-stuff): my Pi extensions and skills.
