# team-ui Specification

## Purpose
TBD - created by archiving change redesign-remaining-neon-screens. Update Purpose after archive.
## Requirements
### Requirement: Team 详情顶部 Cover 卡

`TeamDetailView` SHALL 在导航栏下方渲染一张 cover 卡：顶部右上角 pill 显示「`{今日已练人数} / {成员数} 今日已练`」（背景 `Theme.Color.accentCyan` + 黑字），下方大字 `Theme.Font.display(28, .bold)` 显示 Team 名称。卡背景为 `LinearGradient` 从 `Theme.Color.surface2` 到 `Theme.Color.bg`，圆角 `Theme.Radius.lg`。

#### Scenario: 渲染 Team 详情
- **WHEN** 用户进入 Team 详情页且当日 5/6 成员已打卡
- **THEN** cover 卡右上 pill 显示「5 / 6 今日已练」，大字显示该 Team 名称。

### Requirement: 成员头像横向列表

Cover 卡下方 SHALL 渲染成员头像横向列表：每个头像 28×28pt 圆形 + 首字母（背景色按用户 ID hash 到 4 档预设色），最多显示 4 个，超出折叠为「+{N}」灰底头像；列表尾部 `Theme.Font.mono` muted 文字「`{N} 成员`」。

#### Scenario: 成员 ≤ 4 人
- **WHEN** Team 成员 4 人
- **THEN** 渲染 4 个头像，不显示「+N」折叠。

#### Scenario: 成员 > 4 人
- **WHEN** Team 成员 6 人
- **THEN** 渲染前 4 个头像 + 1 个「+2」灰底头像 + 尾部「6 成员」文字。

### Requirement: 动态 Feed 卡片

`FeedItemCard` SHALL 包含三部分：feed-head（头像 + 用户名 + `Theme.Font.mono` 右对齐时间「HH:mm」）、feed-body（训练动态文字，PR 部分用 `Theme.Color.accentMagenta` + `.neonGlow(.magenta, .sm)` 着色）、feed-emoji 反应行。卡片背景 `Theme.Color.surface`，圆角 `Theme.Radius.md`。

#### Scenario: 训练含 PR
- **WHEN** 用户当次训练命中 PR
- **THEN** body 文字中 PR 部分（如「卧推 102.5kg × 6 ★ PR」）渲染为 magenta + glow，其余文字 `Theme.Color.fg`。

#### Scenario: 训练无 PR
- **WHEN** 用户当次训练无 PR
- **THEN** body 全部为 `Theme.Color.fg` 常规色。

### Requirement: 4 emoji 反应行

每张 feed 卡底部 SHALL 渲染固定 4 个 emoji 反应位 + 1 个 + 按钮：emoji 顺序固定为 🔥 / 💪 / 😱 / 👏。每个 emoji chip 显示「emoji + 计数」，计数 0 时 chip 背景 `Theme.Color.surface2` + muted 文字，计数 > 0 时 chip 背景 `Theme.Color.surface` + `Theme.Color.fg`。点击 chip 切换当前用户的该 emoji 反应。

#### Scenario: 用户点击未点亮的 🔥
- **WHEN** 用户点击 🔥 chip 且自己尚未对该动态点 🔥
- **THEN** 计数 +1，chip 切到「点亮」样式，同时调用 `TeamService.react(activityId:, emoji:)`。

#### Scenario: 用户取消已点亮的 🔥
- **WHEN** 用户点击 🔥 chip 且自己已点亮
- **THEN** 计数 -1，chip 切回 muted 样式，调用同接口（服务端按 last-write 切换）。

### Requirement: 空 Team 占位

`TeamDetailView` SHALL 在 feed 为空时渲染占位卡「今日还没有动态，去训练第一个！」 + CTA 按钮「开始训练」（跳到训练 tab）。占位卡 MUST 使用 `Theme.Color.surface` 背景，不使用霓虹辉光。

#### Scenario: Team 今日 0 动态
- **WHEN** 进入 Team 详情且当日 feed 为空
- **THEN** 显示占位卡 + CTA。

