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

### Requirement: 个人计划分享到 Team 入口

iOS SHALL 在个人计划详情页提供「分享到 Team」入口。用户触发后，系统 SHALL 允许用户选择一个自己已加入的 Team，并明确说明分享到 Team 的计划不会带作者重量，Team 成员可基于快照 Fork 或直接开始训练。

#### Scenario: 从个人计划详情分享到 Team
- **WHEN** 用户进入自己的个人计划详情页
- **THEN** 页面提供「分享到 Team」入口
- **AND** 文案 MUST 使用“分享”，不得使用“发布到 Team”作为主要动作名

#### Scenario: 分享前说明无重量
- **WHEN** 用户准备将计划分享到 Team
- **THEN** 系统展示分享确认或说明
- **AND** 明确说明 Team 成员看到的版本不包含作者重量

#### Scenario: 分享成功反馈
- **WHEN** 用户确认将计划分享到 Team A 且服务端创建分享版本成功
- **THEN** 系统展示成功反馈
- **AND** Team A 的 Team 分享计划页可看到该分享计划的最新版本

### Requirement: Team 分享计划页

iOS SHALL 在 Team 详情页提供「Team 计划」入口，进入后展示该 Team 的分享计划卡片列表。列表 SHALL 分组展示当前用户自己分享的计划和其他成员分享的计划。每张卡片 SHALL 展示计划名、上次更新时间、分享者名字、动作预览、复制人数和总完成次数；卡片 MUST NOT 展示“我分享的”标签、版本号或计划模式。页面 MUST 使用既有纸感 token，MUST NOT 使用辉光、霓虹或营销式大 hero。

#### Scenario: 浏览 Team 分享计划
- **WHEN** 用户进入某 Team 的「Team 计划」页且该 Team 有分享计划
- **THEN** 页面展示分享计划卡片列表
- **AND** 列表区分「我分享的计划」和「成员分享计划」
- **AND** 每张卡展示上次更新时间、分享者名字、动作预览、复制人数和总完成次数
- **AND** 每张卡不展示版本号或计划模式

#### Scenario: 查看分享计划动作详情
- **WHEN** 用户点击某个 Team 分享计划卡片
- **THEN** 系统进入该分享计划详情页
- **AND** 详情页展示完整动作列表、每个动作的组数和次数
- **AND** 详情页不展示作者重量或计划模式

#### Scenario: 卡片展示复制和完成反馈
- **WHEN** 某分享计划已有 6 人复制且总共完成 9 次
- **THEN** 卡片展示类似「6 人复制 · 总共 9 次完成」的聚合反馈
- **AND** 不展示未分享训练的成员明细或训练详情

#### Scenario: 作者查看自己分享的计划
- **WHEN** 当前用户查看自己分享到 Team 的计划卡片
- **THEN** 该计划展示在「我分享的计划」分组
- **AND** 不展示「Fork 到我的计划」或「复制」入口
- **AND** 卡片底部仅展示一个「开始训练」主按钮
- **AND** 其他成员查看同一计划时仍可看到采用入口

#### Scenario: 作者删除自己分享的计划
- **WHEN** 当前用户进入自己分享的计划详情页
- **THEN** 页面提供删除分享入口
- **AND** 删除成功后该计划从 Team 计划列表移除
- **AND** 其他成员分享的计划不展示删除入口

#### Scenario: Team 无分享计划
- **WHEN** 进入「Team 计划」页且该 Team 暂无分享计划
- **THEN** 显示 Team 语境的空状态
- **AND** 不报错、不空白、不展示旧的“发布计划”文案

### Requirement: Team 分享计划采用操作

iOS SHALL 在 Team 分享计划卡片上提供两种采用方式：主操作「开始训练」和次操作「Fork 到我的计划」。开始训练 SHALL 基于该卡片当前展示的分享版本创建一次训练；Fork SHALL 创建当前用户的独立个人计划。两种操作完成后 SHALL 给出明确反馈。

#### Scenario: 从分享计划直接开始训练
- **WHEN** 用户点击某 Team 分享计划卡片的「开始训练」
- **THEN** 系统基于该分享版本进入训练记录页
- **AND** 不要求用户先 Fork 为个人计划

#### Scenario: Fork 到我的计划
- **WHEN** 用户点击某 Team 分享计划卡片的「Fork 到我的计划」
- **THEN** 系统为当前用户创建独立个人计划
- **AND** 成功后提示用户该计划已保存到「计划」

#### Scenario: 采用不可开始的分享版本
- **WHEN** 分享版本包含当前客户端无法识别且缺少名称快照的动作
- **THEN** 卡片展示明确错误提示
- **AND** 「开始训练」和「Fork 到我的计划」不得静默生成损坏计划或训练

### Requirement: Team 分享计划反馈隐私说明

iOS SHALL 在 Team 分享计划页或采用流程中向用户说明：基于 Team 分享计划完成训练可能计入该计划的聚合完成次数，但不会公开训练详情；训练是否出现在 Team 动态仍由自动分享或按次分享决定。

#### Scenario: 直接开始前可理解反馈边界
- **WHEN** 用户首次从 Team 分享计划直接开始训练
- **THEN** 页面或确认说明告知完成后可能计入聚合次数
- **AND** 告知不会因此公开训练内容

#### Scenario: 未分享训练不出现在 Feed
- **WHEN** 用户从 Team 分享计划开始并完成训练，但没有自动分享或按次分享
- **THEN** Team 计划卡的完成次数可以更新
- **AND** Team 今日动态与历史训练页不展示该训练

#### Scenario: 分享训练仍走既有 Team 动态
- **WHEN** 用户从 Team 分享计划开始并完成训练，且按既有规则分享到 Team
- **THEN** Team 今日动态显示该 checkin
- **AND** Team 计划卡也可以更新完成次数

### Requirement: Team 历史训练月历页

iOS SHALL 在 `TeamDetailView` 提供「历史训练」入口，进入 Team 历史训练月历页。该页面 SHALL 复用个人历史日历的核心交互模型：月份标题、月份选择、左右切月、今天入口、42 格月历、选中日期抽屉。数据源 SHALL 来自 Team checkin 历史接口，而不是本地 `WorkoutHistoryStore`。

#### Scenario: 从 Team 详情进入历史月历
- **WHEN** 用户进入 Team 详情页
- **THEN** 页面提供「历史训练」入口
- **AND** 点击后进入该 Team 的历史训练月历页

#### Scenario: 月历展示 Team 训练日
- **WHEN** Team A 在某月存在仍可见 checkin
- **THEN** Team 历史月历中有 checkin 的日期显示训练摘要
- **AND** 同日多条 checkin 显示额外数量提示
- **AND** 选中日期抽屉展示该日期的 Team checkin 列表

#### Scenario: 月份切换加载对应 Team 历史
- **WHEN** 用户在 Team 历史月历中切换到另一个月份
- **THEN** 客户端加载该 Team 该月份的 checkin 历史
- **AND** 不通过逐日请求拼装整月数据

#### Scenario: 选择月份
- **WHEN** 用户点击 Team 历史月历月份旁的选择图标
- **THEN** 页面弹出与个人历史一致的月份档案 sheet
- **AND** 用户选择某月后直接跳转到该月并加载该月 Team 历史

#### Scenario: 空月份和空日期
- **WHEN** Team 在当前月份或选中日期没有可见 checkin
- **THEN** 页面展示 Team 语境下的轻量空状态
- **AND** 不跳转、不报错、不显示个人训练历史文案

### Requirement: Team checkin 详情展示

iOS SHALL 允许用户从 Team 今日动态卡片和 Team 历史月历的 checkin 行打开同一套 checkin 详情视图。详情 SHALL 使用 `TeamCheckinDTO.parsedSummary` 渲染，不依赖本地 SwiftData 中是否存在原始 `Workout`。

#### Scenario: 从今日动态打开详情
- **WHEN** 用户点击 Team 今日动态中的一条 checkin
- **THEN** 页面打开 Team checkin 详情
- **AND** 详情展示该训练的标题、时间、动作数、组数、训练量摘要
- **AND** 详情展示每个动作与每组重量/次数

#### Scenario: 从历史月历打开详情
- **WHEN** 用户在 Team 历史月历的选中日期抽屉中点击一条 checkin
- **THEN** 页面打开与今日动态相同的 Team checkin 详情视图
- **AND** 详情内容来自该 checkin 的分享快照

#### Scenario: 旧快照解析失败
- **WHEN** 客户端无法解析某条 checkin 的 `summary`
- **THEN** 详情展示「训练快照不可用」类空状态
- **AND** 不展示 0 或空列表作为真实数据

### Requirement: 日历组件复用

iOS SHALL 抽取个人历史与 Team 历史共用的日历展示壳或等价组件，使两者共享月份 Header、月历网格、月份选择 Sheet 与选中日期抽屉的布局行为。个人历史与 Team 历史 SHALL 保持独立数据源和详情目标。

#### Scenario: 个人历史行为保持不变
- **WHEN** 用户进入个人历史日历
- **THEN** 页面仍使用本地 `WorkoutHistoryStore` 派生快照展示个人训练
- **AND** 点击训练仍进入 `WorkoutDetailView`

#### Scenario: Team 历史使用服务端数据
- **WHEN** 用户进入 Team 历史日历
- **THEN** 页面使用 Team checkin 历史接口数据
- **AND** 点击 checkin 进入 Team checkin 详情
- **AND** 个人历史和 Team 历史不共用同一个数据 store
