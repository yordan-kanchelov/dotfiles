# T3 Inbox

> 中文译本。给 agent 构建用的正本是 [RECIPE.md](RECIPE.md)，两者不一致时以英文为准。

Herdr App 的一个侧栏：只把仍需要你关注的 agent 以卡片放在眼前，最新动态排最前。处理完的 agent 由你手动 Settle，沉入底部安静的折叠列表；有新工作就自动回来。参照 [T3 Code](https://github.com/pingdotgg/t3code) 的 Settle 侧栏。

![T3 Inbox](preview.png)

## 你看到什么

从上到下，底色为主题的 `chrome`，正文 13px：

1. **顶栏**（32px，左内边距 8，右 10）：一个宽的 `Search` 按钮（照 T3 搜索框 32px 高，16px 搜索图标 + "Search"，14px 中粗），然后是三个 26px 方形图标按钮：space 筛选（`list-filter.svg`；选了一个 space 时显示它的标记，选了多个时两个标记叠放）、New space（`folder-plus`）、New tab（`square-pen`）。
2. **卡片**（可滚动列表，内边距 8，间距 2）：每个既没 Settle、也不在工作的 agent 一张。卡片内边距 10/6，圆角 6，同 T3；是当前聚焦的 agent 时用 `selected` 背景，否则悬停时用 `hover` 背景。
   - 第 1 行（20px，12px `dim` 文字）：16px 的 space 标记（见下）、space 名，然后是右上角位。
   - 第 2 行：14px 标题。同 T3，聚焦、blocked 或 done 时醒目（`foreground`，中粗），否则退后（`muted`，常规）；悬停时只提亮颜色。
   - 第 3 行，有内容才显示（12px `dim`）：分支，以及 "N sub-agents working"。
   - 标记：16px 程序图标，60% 不透明度；其他机器上的 agent 在它前面多一个 14px `dim` 的 server 图标，悬停显示机器名。有第 3 行时放在第 3 行末尾，否则放在第 2 行末尾，让标题独占一行。
   - 右上角位：blocked 显示 `Needs you`（琥珀色 `blocked`，14px `!` 徽章）；done 且还没看过显示 `Done`（绿色 `ansi2`，circle-check 图标）；否则显示距上次变化多久（`just now`、`5m`、`3h`、`2d`，同 T3，不计周）。
   - 为空时显示 "Nothing needs you."（还没有 agent 上报状态时显示 "No agent status yet…"）。
3. **收纳区**，靠 `margin-top: auto` 推到底部：
   - **Working N** 标题（照 T3 32px，12px 中粗 `dim`，常规字重的数量和箭头在最右），默认折叠；展开后以卡片列出工作中的 agent，带转圈图标和计时的 `Working 9s`（之后是 `4m`、`1h 5m`），未悬停或聚焦时 70% 不透明度。
   - **Settled N** 标题，默认折叠；展开后以单行显示最近 Settle 的 10 个，下面是 `Show 25 more`。数字前的 `Clear` 按钮关闭已 Settle 的窗格（不含当前查看的 agent 及其所在 tab），关闭前通过自带的 `confirm` 对话框确认（`Close N terminals?`，和关闭标签一致；命令是 `t3-inbox.clear`）。空了的 tab 由 Herdr 关闭。space 不关：会被清空的 space 先在其终端当前所在目录新建一个 shell tab（`panes().cwd`，不用 space 的起始目录，否则没命名的 space 会被改名）（`tab.new`；`pane.close` 不能关 space 的最后一个窗格），之后切回你原来所在的 tab。会话由 agent 自己保存（`pi -r`、`claude -r`、`codex resume`）。
   - 单行：照 T3 36px，圆角 6，开头是 16px 的 space 标记，未聚焦或悬停时 40% 不透明度，然后是 `muted` 标题，右侧是 Settle 了多久。

**Space 标记**，照 T3 Code 画项目的方式（`mods/t3-inbox/project.js`）：优先用项目自己的图标（圆角 25%），从 space 当前所在位置（第一个终端的目录，否则是创建时的目录）的仓库根目录查找：依次是 T3 的常见文件（`favicon.svg`、`public/favicon.ico`……`.idea/icon.svg`），然后是页面的 `<link rel="icon">` 或路由的 `{ rel: "icon", href }`。找到后复制到 App 目录的 `cache/t3-icons/`（图片只能从那里显示），并通过 `space.icons` 共享；找到的 10 分钟后重查，没找到的 1 分钟后重查。否则显示字母标记：名字的第一个字母或数字，转大写（`智能算量` → `智`），粗体等宽，大小是标记的 0.64，颜色由名字哈希到 T3 的 18 种颜色之一，底色是同色的 14% 淡色。没有可显示的字符时（`~`）显示文件夹。

## 它怎么表现

- **状态。** `blocked`，或 `error`（失败结束的一轮，它自己或子 agent 的；`agents()` 没有这个状态，从 `terminals()` 读）显示 Needs you，并留在上方。其次是它自己的 `done`：回复在 Active 里显示 Done，旁边注明在跑的子 agent；读完后回到 Working，计时接着这轮的开始时间。`working`，或者在等工作中的子 agent，进入 Working 收纳区。`idle` 显示时间。规则写在 `mods/t3-inbox/tree.js`，与 Herdr T3 共用。
- **排序。** 卡片按各自最近一次"回到你手上"的时间排（本 mod 看到的状态变化；在那之前用 core 的 `status_ms`）。Working 按本轮开始的时间排，Settled 按 Settle 的时间排；时间相同按 address，顺序不随数据到达的先后变化。查看卡片不改变顺序。停止工作的 agent 照 T3 在 Working 多留 2 秒，期间显示真实状态：这 2 秒内继续工作，或等你处理（blocked）后再继续，都保持原位；2 秒后排到卡片最上面。blocked 立即离开，置顶或已 Settle 的不留。agent 短暂从列表消失时保留位置，只有终端结束才删除记录。顺序传给 `setAgentOrder`，已 Settle 的排最后，所以 `agent.next` / `agent.prev` 按列表顺序走。
- **点击**卡片或单行：对它执行 `agent.focus`（聚焦它的窗格；布局里有 agent 块时在那里显示它）。查看已 Settle 的 agent 不会让它回来。
- **Settle。** 悬停在已结束的卡片上（整棵树里没有 working 或 blocked），右上角变成 `✓ Settle` 按钮；已置顶的也一样。和 T3 相同，Settle 立即取消置顶。写入失败时，置顶放回原来的位置，其间新加的置顶也保留。Undo 同样把置顶放回原位。Settle 当前聚焦的 agent 时，焦点移到下面一张卡片，到底则从顶部绕回，同 T3；Settle 后台的 agent 不改变焦点。按键命令 `t3-inbox.settle` 对当前查看的 agent 做同样的事（须已结束），已 Settle 的则取回到卡片最上方。Settle 按钮的悬停提示只在当前查看的卡片上写出这个键，因为键只作用于它；当前查看的已 Settle 行，撤销箭头的提示也写出它。
- **Un-settle。** 悬停在单行上，时间变成撤销箭头（提示 `Un-settle`）；点击后 agent 回到卡片最上方。只有明确的取回才排到最上方：点这个箭头、拖出 Settled、对已 Settle 的 agent 按键。Undo 把 agent 放回原位。用别的方式清掉的 `settled` 标签，比如在另一个窗口点 Undo，也保持原位。Herdr T3 的标签栏用 `shared("t3-inbox.unsettled")` 报告它的按键取回（address → 每次取回都递增的戳），Inbox 把每个新戳当作一次取回。
- **撤销提示**，同 T3：Settle 和取消置顶会在第一个收纳区标题上方显示 `Settled 2 agents, Undo`，持续 5 秒（200ms 淡入淡出）。连续的同一操作合并计数；Undo 恢复原样，不算新动态。没有快捷键：⌘Z 留给终端。
- **行详情**，同 T3 的线程卡片：悬停在卡片或单行上，在它右侧 4px 处从顶部弹出 `Popup`：标题，然后是 space、其他机器的名字、分支和程序，12px，最宽 320px。第一张等 150ms；已有一张显示中或关闭不足 400ms 时，下一张立即打开。第一张和最后一张有 150ms 淡入淡出。行内控件亮起、拖动或点击该行时隐藏。
- **键盘**，照 T3 的 focus-visible（`focus.js`）：用 `pane.go` 移到 Inbox（`"focusable": true`）后进入键盘模式，Tab 走遍它的控件，当前控件有 2px `accent` 内描边；键盘落在卡片上时，卡片悬停才出现的控件也会出现；Enter 或 Space 触发。菜单支持 Home、End，没有搜索框的菜单还支持 T3 的字母 typeahead；搜索框里 Home、End 仍移动光标。键盘离开所有控件后退出该模式；鼠标操作不变。
- **悬停标签**，同 T3 的 tooltip：每个纯图标控件和无文字标记都用 `HoverCard`（`tip.js`）说明自己，有绑定按键时一并显示。程序图标没有标签。
- **动效**，同 T3：行的顺序或分区变化时，移动的行从原位滑过去（收纳区标题、Show more 和空状态那行也一起动，行不会从它们上面滑过），新行从上方 40px 或跟随上面保留的行淡入，离开的行在原位淡出；150ms ease-out，拖动中或一次超过 40 行时不做。放下的行从松手处滑过去。悬停行时，时间与 Settle 或撤销按钮交叉淡入淡出。
- **拖动。** 照 T3：卡片或行移动 6px 即拿起。拿起期间 `Pinned` 和 `Active` 标签展开，副本跟着鼠标上下移动并标出松开后的动作（`Pin`、`Unpin`、`Settle`、`Un-settle`），列表在落点让出目标分区行高的间隙（原生 150ms `height` 过渡）；空的或折叠的分区显示虚线占位。拖到 Pinned 置顶（置顶卡片上半部或下半部：放在它上面或下面），拖到 Active 取消置顶并取消 Settle，拖到 Settled 即 Settle。按 Esc 或从左右两侧拖出放回原处；从上下边缘拖出则按标记落下（Herdr 不上报侧栏外的松手）；Working 卡片拿不起来。划选：按住 `✓ Settle` 或已 Settle 行的撤销箭头划过多行，一次 Settle 或取回整段。置顶卡片按置顶顺序留在顶部。置顶存在共享状态 `agents.pins`，与 Herdr T3 的 agents 列表共用。
- **新工作自动取消 Settle：**agent（或子 agent）变为 working 或 blocked，或 core 的 `turn` 计数超过 Settle 时记下的值。后者能发现没开窗口期间做过的工作。
- **筛选。** 筛选按钮打开一个弹层（宽 260px，最高 360），带搜索框，列出 `All spaces` 和每个 space。单击只看那个 space；shift 单击加入或移除它，弹层保持打开。按屏幕记住。
- **Search** 打开 props `picker` 指定的 mod，没有则打开自带的 `picker`；**New space** 执行 `space.new`；**New tab** 打开 props `newMenu` 指定的 mod，没有则打开自带的 `new-menu`。
- **当前查看的行**，同 T3 的路由行：即使在折叠的收纳区里或超出 Settled 分页也始终显示；查看没有自己行的子 agent 时，点亮最近的已列出祖先，Settle 也作用在这张卡片上；从别处进入查看的 agent 若被筛选隐藏，筛选放宽到全部 space 并保留（首次绘制时不放宽，查看期间手动选的筛选也不变）。
- **Snooze**，照 T3：`snoozed=<唤醒毫秒>` 写在 agent 的终端上（`hc label`，回读前暂存）。悬停时，不需要人处理的卡片（工作中、已置顶的也可以；这一轮失败算需要人）在 Settle 前显示 20px 的 `clock` 按钮；悬停的控件占住角落，状态在其下淡出。点开菜单（`Popover`，150ms 淡入，宽度随内容、至少 160px，行高 28px，从时钟左缘垂下、向右越过侧栏边缘；鼠标或按键到达前不高亮；↑/↓，Enter 或 Space，Esc；焦点句柄交给面板，打开时在面板自己的 key context 里绑定 Enter 和 Space，因为 Popover 自带的绑定只会关闭菜单）：In 1 hour、In 3 hours、This evening（18:00，过点消失）、Tomorrow（9:00）、Next week（周一 9:00，周日时显示为 Tomorrow），最早的在上，同一分钟只留一行，右侧写唤醒时间。和 T3 一样，时长从点击时算起，菜单画出后已过去的时间会被拒绝并提示。分隔线下的 `Custom…` 打开对话框（本 mod 作为 overlay，同 t3-actions 的编辑器）：Date and time（自绘日历，过去的日期不可选，加 `HH:MM`）或 Duration（带 − / + 的数字字段，单位从下拉选 Minutes、Hours、Days，同 T3）。不存在或已过去的时间、非正数的时长会提示并保持打开；结果经 `shared("t3-inbox.custom")` 和 `t3-inbox.custom-snooze` 命令交给 Inbox，和预设一样 Snooze，除非此时 agent 已需要人处理。预设不可配置。Snooze 后出现 T3 的 `Snoozed 1 agent, Undo` 提示；若在查看它，则和 Settle 一样跳到下一张。Snoozed 收纳区在 Working 和 Settled 之间，默认折叠，最早醒的在上；行的样式同已 Settle 的行，显示剩余时间（`10m`、`3h`、`2d`，`accent` 闹钟），悬停换成划掉的闹钟（Wake；按住划过多行叫醒整段）。把行拖出来即唤醒（标记 `Wake`）；不能拖进去：放下时给不出唤醒时间。到点后回到原位（其间 `track` 跳过宽限期；在 Snooze 期间结束的工作算回到你手上，所以醒来时排到顶部，和 T3 的 return 一样），标 `blocked` 色的 `Woke`，直到看过或点击（只有活动窗口里的查看才算：后台窗口不清掉到期的 Snooze，也不因新一轮清掉，Woke 留给人）；悬停时 Woke 留在控件旁边；仍在工作的显示在 `Working` 旁边。撤销 Settle 会还原未到期的 Snooze。提前结束：需要人时只在此期间显示（标签保留）；它的子树失败、查看时开始新一轮、Wake、置顶或 Settle 清除标签。已置顶的保留置顶，醒来回到原处。
- **mod pane 卡片。** 没有 agent 的标签里的 mod pane，点 agent 卡片到不了，所以在 `shared("<mod>.program")` 里声明了 `inbox: true` 的（比如 review：`{ icon, tint, name, inbox: true }`；只有图标不算声明）有自己的卡片，每个标签一张：space 标记和名字、`<mod>.titles` 里的名字，图标放在 agent 卡片放程序图标的位置。它按 `<mod>.status` 走，和 agent 按状态走一样：`working` 在 Working 收纳区，`done` 和 `blocked` 回到 Active 顶部；第一次出现时在 Active 顶部。`inbox: true` 同时表示这个 pane 可以随时关掉，状态都在别处：Settle（`Settle and close`，和 agent 同样的条件下才提供，以及 `cmd-shift-s`）就是 `pane.close`，正在查看时先跳到下一张，没有 Settled 也没有 Undo；space 的最后一个标签会先询问。单击是 `pane.focus`，可跨 space。不能置顶、不能拖动、不参与划选。受 space 筛选影响，查看被筛掉的卡片时放宽筛选。agent 旁边的 mod pane 没有卡片，它点亮那个 agent 的卡片。
- 收纳区折叠状态、筛选和最近看到的状态存在本 mod 的 `localStorage`。画出来的行以 `t3-inbox.rows`（`{ order, view }`）共享，供布局的快捷键遍历：其中是 agent 的 address，mod pane 的卡片是 `pane:<id>`，要用 `pane.focus`。

## 由什么构成

- 一个 mod：`mods/t3-inbox/`（`main.js`、`name.js`（卡片标题：Pi 在跑时的 Pi 会话名、命名过的标签、有意义的终端标题，最后是程序名）、`tree.js`（状态规则）、`project.js`（space 标记）、`tip.js`（悬停标签）、`details.js`（行详情）；视图的状态和生命周期在 `main.js`，另有 `row-model.js`（每行的字段、顺序和收纳区，由纯数据算出）、`row-view.js`（卡片和单行）、`list-view.js`（列表和收纳区）、`actions.js`（Settle、Snooze、Undo）、`drag.js`、`snooze.js`（菜单、Custom 对话框和时间）、`filter.js`（顶栏和 space 筛选）、`sidebar.js`（Inbox 放在布局的 stack 里时，查找侧栏的布局节点）；`icons/`，`mod.json` 让它以 300px 停靠在 `left`）。可选 props `newMenu`：**New tab** 打开的 mod（Herdr T3 布局传 `t3-new-menu`）。`picker`：**Search** 打开的 mod（Herdr T3 布局传 `t3-picker`）。
- `herdr`：`agents()`、`terminals()`（`labels`、`turn`、`status_ms`、`parent`、`state`）、`panes()`（分支、`cwd`）、`spaces()`、`run`（`agent.focus`、`pane.focus`、`space.new`、`mod.open`、`tab.new`、`pane.close`）、`openOverlay`（`confirm` 对话框）、`hc`、`exec`、`notify`、`theme`、`shared` / `setShared`（`agents.pins`、`space.icons`、`t3-inbox.rows`、`t3-inbox.unsettled`，以及 mod 的 `<mod>.program`、`.titles`、`.status`）、`keys`、`setAgentOrder`。
- `gpui-base`：`Popover`、`Popup`、`HoverCard`、`InputState`、`Input`、`v_flex`、`h_flex`。
- 运行的程序：`hc label`；为 space 标记，在 space 所在的机器上运行 `git rev-parse --show-toplevel`、`sh -c` 文件测试和 `base64`。
- Settle 状态是 agent 终端上的 core 标签：`hc label <address> settled=<ms>:<turn>`；写 `settled=` 删除。终端结束，标签随之消失；所有 mod 和窗口都能读到。
- 自带图标：`mods/workspace-chrome/{search,folder,folder-plus,square-pen,check,circle-check,spinner,chevron-down,chevron-right,server,git-branch,pin}.svg`。

## 注意

- `hc label` 写入的标签大约 0.65 秒后才出现在 `terminals()`。先把新值记为待定，让行立即移动；写入失败就撤回，并发一条错误 `notify`。慢速远程下，同一个标签的多次写入可能以任意顺序落地：有不止一次在途时保留最后一次意图，全部返回后若标签不符就再写一次。
- `terminals()[].status_ms` 只是 App 启动时的值，仅在 mod 自己看到变化前兜底。
- 记录变化时间时把 `done` 和 `idle` 视为同一状态：查看一个 done 的 agent 会让它变 idle，而查看不算新动态。
- 没有窗格的子 agent 不在 `agents()` 里，要沿 `terminals()` 的 `parent` 找。
- 卡片移走时不会触发指针离开事件：Settle / Un-settle 时清掉悬停状态。
- 悬停样式能作用到文字，作用不到 `svg`；把悬停做成状态，图标和文字才能一起变亮。
- Herdr 只对元素后续的变化做缓动：移动的行要换新 id，先在原位画一次，再放开。
- Herdr 不能用代码滚动普通列表，所以和 T3 不同，当前查看的行不会自动滚到视野内。
- `.tooltip()` 只接受字符串且用外壳自己的样式，所以用 `HoverCard`；它不会翻转，窗口底部的控件要自己向上打开。详情卡片是实色的：T3 的毛玻璃会模糊背后内容，mod 做不到。
- 不做自动 Settle。Settle 从不影响进程。

## 完成标准

- `herdr-app check mods/t3-inbox` 通过。
- 悬停已结束的 agent 出现 `✓ Settle`；点击后一秒内移入 Settled，`hc get <address> --json` 里有 `settled=<ms>:<turn>`。
- 这次 Settle 显示 `Settled 1 agent, Undo` 5 秒；Undo 恢复原样。
- 把工作中的 agent Snooze 1 小时后，它进入 Snoozed；出现权限请求时显示 Needs you，答复后再次隐藏。到点后标 `Woke` 醒来。
- 悬停卡片时，详情在旁边淡入；移到下一张卡片时，立即显示它的详情。
- `Clear` 在关闭任何窗格前，先通过 `confirm` 对话框询问。
- 给这个 agent 发新提示，它回到卡片区，标签被删掉。
- 悬停已 Settle 的行，点箭头，它回到卡片最上方。
- 已 Settle 超过 10 个时，展开的收纳区显示 10 个和 `Show N more`。
- `agent.next` 按卡片显示顺序依次切换。
