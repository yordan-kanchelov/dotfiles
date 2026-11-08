# T3 Inbox for Herdr App

[English](README.md) · 中文

Herdr App 的侧栏 mod，带 [T3 Code](https://github.com/pingdotgg/t3code) 式 Settle：需要你处理的 agent 以卡片形式留在上方；处理完的手动 Settle，收进底部安静的列表；有新工作时自动回来。

![T3 Inbox](preview.png)

它就是 [Herdr T3 布局](https://github.com/JinJieBeWater/herdr-t3) 里的 Inbox 侧栏，单独拿出来。整套布局还会在标签栏隐藏已 Settle agent 的完成圆点，并能在这个列表和 Lists（Spaces 和 Agents）之间切换。

## 安装

让你的 Herdr agent 添加 `herdr.dev/mods/JinJieBeWater/herdr-t3-inbox`，或者把 `mods/t3-inbox/` 复制进 `~/.config/herdr-app/mods/`。Herdr 第一次看到它时会停靠在左侧。仓库的 `keys.json` 带一个 Settle 快捷键：`global` 里的 `"cmd-shift-s": "t3-inbox.settle"`，安装时会合并进你的 keys.json（手动安装就把这一行加进 `~/.config/herdr-app/keys.json`）：Settle 当前查看的 agent，已 Settle 的则取回。外观和行为见 [RECIPE.zh-CN.md](RECIPE.zh-CN.md)。

## 更新

Herdr 不会更新别人做的 mod。再添加一次也不行：安装从不覆盖已有文件，只会装出一份改了名的副本（如 `t3-inbox-2`）。更新要靠覆盖：

- 对你的 Herdr agent 说：「从 github.com/JinJieBeWater/herdr-t3-inbox 更新 T3 Inbox：用仓库最新的文件覆盖我已安装的 `mods/t3-inbox/`，然后对它跑 `herdr-app check`。」如果首次安装时因为重名改过名字，就覆盖改名后的那份。
- 手动更新：把目录里的文件复制过去覆盖旧的。mod 保存后自动重载，停靠位置保持不变。
- 会保留：Settled 收纳区、已 Settle 的 agent、space 筛选。这些存在 `data/` 和终端标签里，不在 mod 目录中。会丢掉：你自己对被覆盖文件的修改。
- 从 `t3-focus`（Focus 改名为 Inbox 之前）升级：把 `data/t3-focus` 改名为 `data/t3-inbox`（卡片顺序和收纳区状态），把 `keys.json` 里的 `t3-focus.settle` 改成 `t3-inbox.settle`，再删掉 `mods/t3-focus`。

## 它会运行什么

- Settle、取消 Settle，或新工作让 agent 自动回来时，运行 `hc label <agent> settled=<ms>:<turn>`。
- Snooze 或唤醒 agent 时，运行 `hc label <agent> snoozed=<ms>`。
- 为卡片的项目标记，在 space 所在的机器上运行 `git rev-parse --show-toplevel`、`sh -c` 文件测试和 `base64`，读取仓库的 favicon 和声明它的页面。找到的图标会复制到 App 目录的 `cache/t3-icons/`。除此之外不运行别的程序，不发网络请求。

## 许可证

Apache-2.0，与 Herdr App 相同。

## 更多

- [herdr-t3](https://github.com/JinJieBeWater/herdr-t3)：这个侧栏所在的完整 Herdr T3 布局。
- [herdling](https://github.com/JinJieBeWater/herdling)：Herdr 的 macOS 菜单栏伴侣。
- [pi-stuff](https://github.com/JinJieBeWater/pi-stuff)：我写的 Pi 扩展和 Skills。
