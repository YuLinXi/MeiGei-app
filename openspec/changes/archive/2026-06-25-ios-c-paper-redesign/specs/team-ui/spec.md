## MODIFIED Requirements

### Requirement: Team 详情顶部 Cover 卡

`TeamDetailView` SHALL 在导航栏下方渲染一张 cover 卡：顶部右上角 pill 显示「`{今日已练人数} / {成员数} 今日已练`」（背景 `Theme.Color.accent` + 白字），下方大字 `Theme.Font` 显示 Team 名称（`fg`），并展示邀请码（`mono` muted）。卡背景为 `Theme.Color.surface`（白）+ 1px `border` + `paperShadow(.sm)`，圆角 `Theme.Radius.lg`。MUST NOT 使用青色/品红渐变或辉光。

#### Scenario: 渲染 Team 详情
- **WHEN** 用户进入 Team 详情页且当日 5/6 成员已打卡
- **THEN** cover 卡右上 pill 显示「5 / 6 今日已练」（朱砂红实底白字），大字显示该 Team 名称，纸感白底卡。

### Requirement: 动态 Feed 卡片

`FeedItemCard` SHALL 包含三部分：feed-head（头像 + 用户名 + `Theme.Font.mono` 右对齐时间「HH:mm」）、feed-body（训练动态文字，PR 部分用 `Theme.Color.accent` 着色，无辉光）、feed-emoji 反应行。卡片背景 `Theme.Color.surface`（白），圆角 `Theme.Radius.md`，1px `border` + `paperShadow(.sm)`。

#### Scenario: 训练含 PR
- **WHEN** 用户当次训练命中 PR
- **THEN** body 文字中 PR 部分（如「卧推 102.5kg × 6 ★ PR」）渲染为 `accent` 朱砂红着色（无 glow），其余文字 `Theme.Color.fg`。

#### Scenario: 训练无 PR
- **WHEN** 用户当次训练无 PR
- **THEN** body 全部为 `Theme.Color.fg` 常规色。

### Requirement: 4 emoji 反应行

每张 feed 卡底部 SHALL 渲染固定 4 个 emoji 反应位 + 1 个 + 按钮：emoji 顺序固定为 🔥 / 💪 / 😱 / 👏。每个 emoji chip 显示「emoji + 计数」，计数 0 时 chip 背景 `Theme.Color.surface2` + muted 文字，计数 > 0 时 chip 背景 `accentSoft`（浅朱砂底）+ `Theme.Color.fg`。点击 chip 切换当前用户的该 emoji 反应。

#### Scenario: 用户点击未点亮的 🔥
- **WHEN** 用户点击 🔥 chip 且自己尚未对该动态点 🔥
- **THEN** 计数 +1，chip 切到「点亮」样式（浅朱砂底），同时调用 `TeamService.react(activityId:, emoji:)`。

#### Scenario: 用户取消已点亮的 🔥
- **WHEN** 用户点击 🔥 chip 且自己已点亮
- **THEN** 计数 -1，chip 切回 muted 样式，调用同接口（服务端按 last-write 切换）。

## ADDED Requirements

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
