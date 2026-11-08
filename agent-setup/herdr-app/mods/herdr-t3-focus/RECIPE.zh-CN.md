# T3 Focus

> 中文译本。给 agent 构建用的正本是 [RECIPE.md](RECIPE.md)，两者不一致时以英文为准。

Herdr App 的一个侧栏：只把仍需要你关注的 agent 以卡片放在眼前，最新动态排最前。处理完的 agent 由你手动 Settle，沉入底部安静的折叠列表；有新工作就自动回来。参照 [T3 Code](https://github.com/pingdotgg/t3code) 的 Settle 侧栏。

![T3 Focus](preview.png)

## 你看到什么

从上到下，底色为主题的 `chrome`，正文 13px：

1. **顶栏**（32px，左内边距 8，右 10）：一个宽的 `Search` 按钮（26px 高，搜索图标 + "Search"），然后是三个 26px 方形图标按钮：space 筛选（`list-filter.svg`；选了一个 space 时显示它的头像，选了多个时两个头像叠放）、New space（`folder-plus`）、New agent（`square-pen`）。
2. **卡片**（可滚动列表，内边距 8，间距 2）：每个既没 Settle、也不在工作的 agent 一张。卡片内边距 10/8，圆角 10；是当前聚焦的 agent 时用 `selected` 背景，否则悬停时用 `hover` 背景。
   - 第 1 行（20px，12px `dim` 文字）：14px space 头像（圆角 4，白色粗体首字母，底色为 space 颜色）、space 名（远程 agent 显示为 `space · machine`），然后是右上角位。
   - 第 2 行：14px 标题，只有聚焦的卡片用 `foreground`，其余用 `muted`；最右是 16px 程序图标。
   - 第 3 行，有内容才显示（12px `dim`）：分支，以及 "N sub-agents working"。
   - 右上角位：blocked 显示 `Needs you`（琥珀色 `blocked`，14px `!` 徽章）；done 且还没看过显示 `Done`（绿色 `ansi2`，circle-check 图标）；否则显示距上次变化多久（`now`、`5m`、`3h`、`2d`、`1w`）。
   - 为空时显示 "Nothing needs you."（还没有 agent 上报状态时显示 "No agent status yet…"）。
3. **收纳区**，靠 `margin-top: auto` 推到底部：
   - **Working N** 标题（30px，12px 中粗 `dim`，数量和箭头在最右），默认折叠；展开后以卡片列出工作中的 agent，带转圈图标和计时的 `Working 9s`。
   - **Settled N** 标题，默认折叠；展开后以单行显示最近 Settle 的 10 个，下面是 `Show 25 more`。数字前的 `Clear` 按钮关闭已 Settle 的窗格（不含当前查看的 agent 及其所在 tab）：第一次点击变为 `Clear N?`，再点一次确认；指针离开按钮 400ms 后取消（指针从未停在上面时为 3 秒，按钮消失时立即取消），双击只会询问、不会确认。空了的 tab 由 Herdr 关闭。space 不关：会被清空的 space 先在其终端当前所在目录新建一个 shell tab（`panes().cwd`，不用 space 的起始目录，否则没命名的 space 会被改名）（`tab.new`；`pane.close` 不能关 space 的最后一个窗格），之后切回你原来所在的 tab。会话由 agent 自己保存（`pi -r`、`claude -r`、`codex resume`）。
   - 单行：30px，圆角 8，程序图标 50% 不透明度，标题 `muted`，右侧是 Settle 了多久。

space 头像颜色读共享状态 `space.colors`（`ansi6` `#22a99a`、`ansi3` `#e3814f`、`ansi4` `#5b8def`、`ansi5` `#8b7cf6`、`ansi2` `#3fae6a`、`ansi1` `#d9649a`，或任意 `#hex`）；没有这个状态时所有头像都是 `#22a99a`。

## 它怎么表现

- **状态。** `blocked`（以及子 agent 的 `error`）显示 Needs you，并留在上方。`working`，或者在等工作中的子 agent，进入 Working 收纳区。`done` 显示 Done；`idle` 显示时间。agent 取它整棵子 agent 树里最紧急的状态。
- **排序。** 卡片按各自最近一次"回到你手上"的时间排（本 mod 看到的状态变化；在那之前用 core 的 `status_ms`）。Working 按开始工作的时间排，Settled 按 Settle 的时间排。顺序传给 `setAgentOrder`，不含已 Settle 的 agent，所以 `agent.next` / `agent.prev` 按卡片顺序走，最后才到已 Settle 的。
- **点击**卡片或单行：对它执行 `agent.focus`（聚焦它的窗格；布局里有 agent 块时在那里显示它）。查看已 Settle 的 agent 不会让它回来。
- **Settle。** 悬停在已结束的卡片上（整棵树里没有 working 或 blocked），右上角变成 `✓ Settle` 按钮。Settle 当前聚焦的 agent 时，焦点移到下一张卡片（没有就上一张）；Settle 后台的 agent 不改变焦点。按键命令 `t3-focus.settle` 对当前查看的 agent 做同样的事（须已结束且未置顶），已 Settle 的则取回。
- **取消 Settle。** 悬停在单行上，时间变成撤销箭头；点击后 agent 回到卡片最上方。
- **拖动。** 照 T3：卡片或行移动 6px 即拿起。拿起期间 `Pinned` 和 `Active` 标签展开，副本跟着鼠标上下移动并标出松开后的动作（`Pin`、`Unpin`、`Settle`、`Un-settle`），列表在落点让出目标分区行高的间隙（原生 150ms `height` 过渡）；空的或折叠的分区显示虚线占位。拖到 Pinned 置顶（置顶卡片上半部或下半部：放在它上面或下面），拖到 Active 取消置顶并取消 Settle，拖到 Settled 即 Settle。按 Esc 或从左右两侧拖出放回原处；从上下边缘拖出则按标记落下（Herdr 不上报侧栏外的松手）；Working 卡片拿不起来。划选：按住 `✓ Settle` 或已 Settle 行的撤销箭头划过多行，一次 Settle 或取回整段。置顶卡片按置顶顺序留在顶部，不提供 Settle 按钮。置顶存在共享状态 `agents.pins`，与 Herdr T3 的 agents 列表共用。
- **新工作自动取消 Settle：**agent（或子 agent）变为 working 或 blocked，或 core 的 `turn` 计数超过 Settle 时记下的值。后者能发现没开窗口期间做过的工作。
- **筛选。** 筛选按钮打开一个弹层（宽 260px，最高 360），带搜索框，列出 `All spaces` 和每个 space。单击只看那个 space；shift 单击加入或移除它，弹层保持打开。按屏幕记住。
- **Search** 打开自带的 `picker`；**New space** 执行 `space.new`；**New agent** 打开 props `newMenu` 指定的 mod，没有则打开自带的 `new-menu`。
- 收纳区折叠状态、筛选和最近看到的状态存在本 mod 的 `localStorage`。当前聚焦的 agent 即使在折叠的收纳区里或超出分页，也始终显示。

## 由什么构成

- 一个 mod：`mods/t3-focus/`（`main.js`、`name.js`（卡片标题：Pi 会话名、命名过的标签、有意义的终端标题，最后是程序名）、`undo.svg`、`list-filter.svg`，`mod.json` 让它以 300px 停靠在 `left`）。可选 props `newMenu`：**New agent** 打开的 mod（Herdr T3 布局传 `t3-new-menu`）。
- `herdr`：`agents()`、`terminals()`（`labels`、`turn`、`status_ms`、`parent`、`state`）、`panes()`（分支）、`spaces()`、`run`（`agent.focus`、`space.new`、`mod.open`）、`hc`、`notify`、`theme`、`shared("space.colors")`、`setAgentOrder`。
- `gpui-base`：`Popover`、`InputState`、`Input`、`v_flex`、`h_flex`。
- Settle 状态是 agent 终端上的 core 标签：`hc label <address> settled=<ms>:<turn>`；写 `settled=` 删除。终端结束，标签随之消失；所有 mod 和窗口都能读到。
- 自带图标：`mods/workspace-chrome/{search,folder,folder-plus,square-pen,check,circle-check,spinner,chevron-down,chevron-right}.svg`。

## 注意

- `hc label` 写入的标签大约 0.65 秒后才出现在 `terminals()`。先把新值记为待定，让行立即移动；写入失败就撤回，并发一条错误 `notify`。
- `terminals()[].status_ms` 只是 App 启动时的值，仅在 mod 自己看到变化前兜底。
- 记录变化时间时把 `done` 和 `idle` 视为同一状态：查看一个 done 的 agent 会让它变 idle，而查看不算新动态。
- 没有窗格的子 agent 不在 `agents()` 里，要沿 `terminals()` 的 `parent` 找。
- 卡片移走时不会触发指针离开事件：Settle / 取消 Settle 时清掉悬停状态。
- 悬停样式能作用到文字，作用不到 `svg`；把悬停做成状态，图标和文字才能一起变亮。
- 不做自动 Settle 和 Snooze。Settle 从不影响进程。

## 完成标准

- `herdr-app check mods/t3-focus` 通过。
- 悬停已结束的 agent 出现 `✓ Settle`；点击后一秒内移入 Settled，`hc get <address> --json` 里有 `settled=<ms>:<turn>`。
- 给这个 agent 发新提示，它回到卡片区，标签被删掉。
- 悬停已 Settle 的行，点箭头，它回到卡片最上方。
- 已 Settle 超过 10 个时，展开的收纳区显示 10 个和 `Show N more`。
- `agent.next` 按卡片显示顺序依次切换。
