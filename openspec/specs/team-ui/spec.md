# team-ui Specification

## Purpose
TBD - created by archiving change redesign-remaining-neon-screens. Update Purpose after archive.
## Requirements
### Requirement: Team 详情顶部 Cover 卡

`TeamDetailView` SHALL 在导航栏下方渲染一张 cover 卡：顶部右上角 pill 显示「`{今日已练人数} / {成员数} 今日已练`」（背景 `Theme.Color.accent` + 白字），下方大字 `Theme.Font` 显示 Team 名称（`fg`），并展示邀请码（`mono` muted）。卡背景为 `Theme.Color.surface`（白）+ 1px `border` + `paperShadow(.sm)`，圆角 `Theme.Radius.lg`。MUST NOT 使用青色/品红渐变或辉光。

#### Scenario: 渲染 Team 详情
- **WHEN** 用户进入 Team 详情页且当日 5/6 成员已打卡
- **THEN** cover 卡右上 pill 显示「5 / 6 今日已练」（朱砂红实底白字），大字显示该 Team 名称，纸感白底卡。

### Requirement: 成员头像横向列表

Cover 卡下方 SHALL 渲染成员头像横向列表：每个头像 28×28pt 圆形 + 首字母（背景色按用户 ID hash 到 4 档预设色），最多显示 4 个，超出折叠为「+{N}」灰底头像；列表尾部 `Theme.Font.mono` muted 文字「`{N} 成员`」。

#### Scenario: 成员 ≤ 4 人
- **WHEN** Team 成员 4 人
- **THEN** 渲染 4 个头像，不显示「+N」折叠。

#### Scenario: 成员 > 4 人
- **WHEN** Team 成员 6 人
- **THEN** 渲染前 4 个头像 + 1 个「+2」灰底头像 + 尾部「6 成员」文字。

### Requirement: 动态 Feed 卡片

`FeedItemCard` SHALL 包含三部分：feed-head（头像 + 用户名 + `Theme.Font.mono` 右对齐时间「HH:mm」）、feed-body（训练动态文字，PR 部分用 `Theme.Color.accent` 着色，无辉光）、feed-emoji 反应行。卡片背景 `Theme.Color.surface`（白），圆角 `Theme.Radius.md`，1px `border` + `paperShadow(.sm)`。

#### Scenario: 训练含 PR
- **WHEN** 用户当次训练命中 PR
- **THEN** body 文字中 PR 部分（如「卧推 102.5kg × 6 ★ PR」）渲染为 `accent` 朱砂红着色（无 glow），其余文字 `Theme.Color.fg`。

#### Scenario: 训练无 PR
- **WHEN** 用户当次训练无 PR
- **THEN** body 全部为 `Theme.Color.fg` 常规色。

### Requirement: 4 emoji 反应行

每张 feed 卡底部 SHALL 渲染固定 4 个 emoji 反应位：emoji 顺序固定为 🔥 / 💪 / ❤️ / 👏，对应后端 code 为 `fire` / `muscle` / `heart` / `clap`。每个 emoji chip 始终显示 emoji；计数 > 0 时追加计数。当前用户点亮的 chip 背景为 `accentSoft`（浅朱砂底），未点亮 chip 背景为 `Theme.Color.bg`。点击 chip 切换当前用户的该 emoji 反应。

#### Scenario: 用户点击未点亮的 🔥
- **WHEN** 用户点击 🔥 chip 且自己尚未对该动态点 🔥
- **THEN** 计数 +1，chip 切到「点亮」样式（浅朱砂底），同时调用 `TeamService.react(checkinId:, emoji:)`。

#### Scenario: 用户取消已点亮的 🔥
- **WHEN** 用户点击 🔥 chip 且自己已点亮
- **THEN** 计数 -1，chip 切回 muted 样式，调用同接口（服务端按 last-write 切换）。

### Requirement: 空 Team 占位

`TeamDetailView` SHALL 在 feed 为空时渲染占位卡「今日还没有动态，去训练第一个！」 + CTA 按钮「开始训练」（跳到训练 tab）。占位卡 MUST 使用 `Theme.Color.surface` 背景，不使用霓虹辉光。

#### Scenario: Team 今日 0 动态
- **WHEN** 进入 Team 详情且当日 feed 为空
- **THEN** 显示占位卡 + CTA。

### Requirement: 删除训练后今日动态一致性

当一条已打卡的训练记录被删除并同步成功后，Team 今日动态 Feed MUST 反映该动态的移除——不得继续展示已删除训练对应的打卡。后端在 workout 墓碑同步时已级联撤销对应 checkin；`TeamDetailView` MUST 在本端「同步完成」后重新拉取 checkins 以反映该移除，并 SHALL 在场景回到前台时兜底刷新。

刷新触发 MUST 绑定「同步完成」事件而非「删除动作」瞬间：删除为离线 `pendingDelete`，须等下一次同步 push 成功、后端撤销 checkin 后再拉取，方能避免拉回尚未撤销的旧动态。

#### Scenario: 删训练后动态消失
- **WHEN** 用户停留在 Team 详情页，于训练 tab 删除一条已打卡训练，随后同步完成
- **THEN** 该 Team 的今日动态 Feed 自动重新加载并不再显示该条动态，无需用户手动下拉刷新

#### Scenario: 同步未完成前不误刷
- **WHEN** 删除已发生但尚未同步到后端（仍为 `pendingDelete`）
- **THEN** Team Feed 不因「删除动作」本身提前刷新而拉回旧动态；待同步完成后再反映移除

#### Scenario: 回前台兜底刷新
- **WHEN** 删除并同步在 App 处于后台期间完成，用户随后将 App 切回前台并停留在 Team 详情页
- **THEN** Team Feed 兜底重新加载，反映该动态的移除

### Requirement: Team 计划 Fork 列表版式

Team 详情页 SHALL 提供「Team 计划」入口，进入后渲染该 Team 的共享训练计划模板列表（纸感卡片）。每张计划卡 SHALL 显示：计划名（`fg` 大字）+ 作者信息（「by {ownerName}」`mono` muted）+ 右侧「Fork」按钮（白底 + `accent` 描边 + `accent` 文字）。点击 Fork SHALL 为当前用户创建该计划的独立副本（复用既有 Fork 流程），成功后给出反馈。MUST 使用纸感 token，MUST NOT 出现辉光。

#### Scenario: 浏览 Team 计划列表
- **WHEN** 用户进入某 Team 的「Team 计划」页且该 Team 有 2 个共享计划
- **THEN** 渲染 2 张纸感计划卡，各含名称、作者、右侧 Fork 按钮

#### Scenario: Fork 一个计划
- **WHEN** 用户点击某计划卡的「Fork」按钮
- **THEN** 系统为该用户创建独立计划副本（带稳定 itemId），并提示「已 Fork 到我的计划」

#### Scenario: Team 无共享计划
- **WHEN** 进入「Team 计划」页且该 Team 暂无共享计划
- **THEN** 显示占位卡「该 Team 还没有共享计划」，不报错不空白
