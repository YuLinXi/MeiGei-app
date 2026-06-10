## Purpose

定义 DontLift 训练核心三屏（训练首页 / 训练进行中 / 动作详情）与 Live Activity 的行为规约。训练记录、休息计时、动作库的基础行为以现有实现为准；本 spec 聚焦视觉强度升级后的可观察行为与边界条件（empty state、placeholder、PR 元素配色独占）。
## Requirements
### Requirement: 训练首页周聚合视图

iOS 训练首页 SHALL 在顶部展示「本周训练量」hero（按本地时区周一 00:00 为周起点），并以三宫格展示本周「总组数 / 总次数 / 平均时长」。聚合数据 MUST 按需即时计算自本地 `Workout` 集合，不入库。当本周训练数为 0 时，hero MUST NOT 显示「0.0 t」字面量，而 SHALL 展示鼓励性 Empty State 文案与「开始第 1 次训练」CTA。

#### Scenario: 本周已有训练
- **WHEN** 用户进入训练首页，本周已记录 4 次训练，总训练量 28.4 吨
- **THEN** Hero 显示「28.4 t」并附副标「已完成 4 / Y 次」（Y 为当前激活计划的周训练目标次数，无激活计划时改为「本周第 4 次训练」）

#### Scenario: 本周尚未训练
- **WHEN** 本周训练数为 0
- **THEN** Hero 显示「准备好了吗？」文案与「开始第 1 次训练」CTA，不显示「0.0 t」

#### Scenario: 三宫格缺值
- **WHEN** 某一项聚合为 0
- **THEN** 显示「—」而非「0」

### Requirement: 训练进行中浮动休息圆环

训练进行中页 SHALL 在剩余休息时间 > 0 时，于屏幕右下（Tab Bar 之上 16pt 间距）渲染一个浮动圆环 FAB，包含圆环进度（按 `restEndDate` 与原始 `restDuration` 比例计算）与中心 `MM:SS` 剩余时间。FAB 倒计时 MUST 与 Live Activity 共享同一墙钟 `endDate`。点击 FAB SHALL 展开为全屏遮罩的休息计时弹窗，弹窗 MUST 提供「−10s / +10s / 完成」三键与下一组提示，关闭弹窗 SHALL 退回浮动 FAB 形态。

#### Scenario: 完成一组后 FAB 出现
- **WHEN** 用户标记当前组完成并设置 60 秒休息
- **THEN** FAB 在 60 秒内从 100% 圆环递减至 0%，剩余秒数实时更新

#### Scenario: 展开弹窗后 ±10s
- **WHEN** 用户在弹窗中点击 +10s
- **THEN** 圆环对应延长 10 秒，FAB 折叠后剩余时间一致

#### Scenario: 倒计时归零
- **WHEN** `restRemaining <= 0`
- **THEN** FAB 淡出隐藏，弹窗如展开中则自动关闭

### Requirement: 训练相关 UI 视觉基线

训练首页、训练进行中、动作详情三屏 SHALL 使用 `add-neon-design-system` 提供的 Theme Token 渲染（颜色 / 字体 / 间距 / 圆角 / 发光阴影）。霓虹品红色（`Theme.Color.accentMagenta`） MUST NOT 用于上述三屏的常态 UI 元素，仅 PR 庆祝相关元素（PR 卡边光、PR 徽标、新增 PR 文字）可使用。

#### Scenario: 常态元素不得使用品红
- **WHEN** 渲染训练首页 CTA「开始今日训练」
- **THEN** CTA 必须使用 cyan accent，不得使用 magenta

#### Scenario: PR 元素使用品红
- **WHEN** 动作详情页存在 PR 数据
- **THEN** PR 卡的左侧 3px 竖条与外发光必须使用 magenta accent

### Requirement: 动作库（ExerciseLibrary）版式

`ExerciseLibraryView` SHALL 顶部依次渲染：导航栏（标题「动作」+ 右上 `+` 添加按钮）、搜索框（占位「搜索 {N} 个动作」，N=内置+自定义合计）、`HorizontalChipPicker`（部位筛选：全部 / 胸 / 背 / 腿 / 肩 / 手臂 / 核心）。下方为按「复合动作 · 推 / 拉 / 腿 / 单关节」分组的动作列表，每组顶部一行 `eyebrow` 分隔；每个动作行 SHALL 显示 thumb（emoji 或部位图占位）+ 双语名（中文粗体 + 英文 muted）+ 右侧最新 PR 副标。

#### Scenario: 数据库空
- **WHEN** 内置动作 0 条且自定义 0 条
- **THEN** 列表渲染单张占位卡「动作库尚未采集，点右上 + 添加自定义动作」+ CTA。

#### Scenario: 切换部位
- **WHEN** 用户点击 chip「胸」
- **THEN** 列表过滤为包含 `chest` 主部位的动作，分组按是否复合动作 splitting。

#### Scenario: 命中 PR 副标
- **WHEN** 某动作历史最佳 1RM > 0
- **THEN** 行右侧副标显示「PR · {重量}」mono 字体，重量按当前单位（kg / lb）。

### Requirement: 计划列表（PlanList）版式

`PlanListView` SHALL 按「进行中 / 我的计划 / 推荐模板」三段渲染。进行中段 MUST 显示至多 1 张 featured plan-card（背景由 `Theme.Color.accentCyan` 到 `surface` 的 LinearGradient + `.neonGlow(.cyan, .md)`），含顶部 pill「`WEEK {n} / {total}`」+ 大标题 + 简介 + 3 列 meta（已完成 / 剩余 / 次/周）。

#### Scenario: 用户有激活计划
- **WHEN** 用户当前激活计划存在
- **THEN** 「进行中」段显示该 featured 卡，「我的计划」段显示其他草稿/未启用计划。

#### Scenario: 用户无激活计划
- **WHEN** 用户无激活计划
- **THEN** 「进行中」段折叠（不渲染 eyebrow 与卡），用户进入页面直接看到「我的计划」与「推荐模板」段。

### Requirement: 计划详情（PlanDetail）版式

`PlanDetailView` SHALL 顶部 navbar 显示返回按钮 + 三点菜单；下方 eyebrow（如「PPL · 增肌期 · 第 3 周」）+ 大标题（计划名，多行 `Theme.Font.display(30, .bold)`）+ 3 列 meta（动作数 / 组数 / 预计时长）。动作列表 SHALL 用 `ScrollView` + 自绘 row card，每行：左侧 24pt mono 序号（`Theme.Color.accentCyan` 着色）+ 中间动作名+组×次方案 mono 副标 + 右侧拖拽 handle 图标。

#### Scenario: 添加动作占位行
- **WHEN** 计划详情列表渲染结束
- **THEN** 末尾固定一张 dashed border 占位卡「＋ 添加动作」，点击 push 到动作选择器。

#### Scenario: 底部 CTA
- **WHEN** 渲染计划详情
- **THEN** 底部 tabbar 上方固定一行：左侧 50×50pt ghost 按钮（复制为新计划）+ 右侧 primary 按钮「开始这次训练 →」(cyan + glow)。

#### Scenario: 计划 JSON 解码失败
- **WHEN** `WorkoutPlan.itemsJSON` 解码抛错
- **THEN** 列表区显示单张红色占位卡「计划数据损坏，请重建」`Theme.Color.danger`，DEBUG 构建 OSLog 打印原始 payload 前 200 字符。

### Requirement: 单一活跃训练会话

系统 SHALL 保证同一时刻至多存在一个进行中训练会话（`deletedAt == nil && endedAt == nil`）。所有「开始训练」入口（空白训练、由计划发起、由动作详情「加入今日训练」）MUST 经统一守卫；当已存在进行中会话时，系统 MUST NOT 静默新建第二个会话，而 SHALL 提示用户「继续」或「丢弃」既有会话。

#### Scenario: 无进行中会话时开始训练
- **WHEN** 不存在进行中会话，用户点击「开始训练」
- **THEN** 系统创建唯一进行中会话并进入 Live 记录界面

#### Scenario: 已有进行中会话时再次开始
- **WHEN** 已存在一个进行中会话，用户尝试开始一次新训练
- **THEN** 系统弹出「继续 / 丢弃」选择，而非新建第二个进行中会话

#### Scenario: 选择继续
- **WHEN** 用户在「继续 / 丢弃」中选择「继续」
- **THEN** 系统打开既有进行中会话，不创建新会话

#### Scenario: 选择丢弃
- **WHEN** 用户在「继续 / 丢弃」中选择「丢弃」
- **THEN** 系统删除既有进行中会话（不再出现于任何列表、不计入统计），随后创建新会话

### Requirement: 进行中会话的首页呈现与继续入口

训练首页 SHALL 在存在进行中会话时，于顶部以醒目的「继续训练」横幅呈现该会话（区别于「最近训练」常规行）。进行中会话 MUST NOT 作为普通已完成记录混入「最近训练」列表。「继续训练」横幅 SHALL 采用按压交互样式提供点按反馈，点击时 SHALL 触发一次轻碰撞触感（`Theme.Haptics.impact(.light)`）；横幅 MUST 为 VoiceOver 合成单一可点元素并附语义化标签（训练名 + 进度）。

#### Scenario: 存在进行中会话
- **WHEN** 用户进入训练首页且存在一个进行中会话
- **THEN** 首页顶部显示「继续训练」横幅，点击进入该会话的 Live 记录界面并伴随一次轻触感

#### Scenario: 进行中会话不混入最近列表
- **WHEN** 存在一个进行中会话
- **THEN** 「最近训练」列表不将该进行中会话显示为普通已完成行

#### Scenario: VoiceOver 朗读横幅
- **WHEN** VoiceOver 用户聚焦「继续训练」横幅
- **THEN** 横幅作为单一元素被朗读为含训练名与「N/M 组完成」进度的语义整句，而非逐字段拆读

### Requirement: 会话计时为墙钟且无会话级暂停

进行中会话的计时 SHALL 为墙钟时长（`now − startedAt`，包含组间休息），实时刷新。系统 MUST NOT 提供「暂停整场训练」的控件。组间「歇一下」的需求由组间休息计时器承载，不影响会话总时长。

#### Scenario: 进行中实时计时
- **WHEN** 会话处于进行中
- **THEN** 计时从 `startedAt` 起按墙钟实时递增显示

#### Scenario: 无暂停控件
- **WHEN** 用户查看进行中页的控制区
- **THEN** 不存在「暂停训练」按钮（仅有结束、添加动作等操作）

### Requirement: 结束训练需二次确认

结束训练 SHALL 经过二次确认。点击「结束」MUST 弹出确认，展示本次「动作数 · 已完成组数」摘要；仅确认后系统才将会话置为已完成（设置 `endedAt`）并执行归档副作用（HealthKit 写入、PR 检测、Team 打卡）。取消 SHALL 使会话保持进行中，不产生任何副作用。

#### Scenario: 确认结束
- **WHEN** 用户点击「结束」并在确认弹窗中确认
- **THEN** 会话置为已完成，执行 HealthKit 写入、PR 检测与 Team 打卡

#### Scenario: 取消结束
- **WHEN** 用户点击「结束」但在确认弹窗中取消
- **THEN** 会话保持进行中，不设置 `endedAt`，不触发任何归档副作用

### Requirement: 已完成会话计时冻结

已完成会话的计时显示 SHALL 冻结为 `endedAt − startedAt`，MUST NOT 在结束后继续增长。

#### Scenario: 结束后计时不再增长
- **WHEN** 会话已结束
- **THEN** 计时显示恒为 `endedAt − startedAt`，不随当前时间变化

### Requirement: 已完成会话只读摘要与显式编辑

已完成会话 SHALL 默认以只读摘要呈现：MUST NOT 直接允许新增动作、勾选完成或修改重量/次数。系统 SHALL 提供显式「编辑」入口进入可编辑态；编辑保存后系统 MUST 重新执行 PR 检测，并更新该会话对应的 Team 打卡摘要（若已打卡）。系统 SHALL NOT 提供「将已完成会话恢复为进行中」的功能。

#### Scenario: 已完成默认只读
- **WHEN** 用户打开一个已完成会话且未进入编辑态
- **THEN** 动作的完成勾选、重量/次数输入、「添加动作」入口均不可操作

#### Scenario: 显式编辑并保存
- **WHEN** 用户在已完成会话点击「编辑」，修改某组重量后保存
- **THEN** 改动落盘，系统重算该会话的 PR，并更新对应 Team 打卡摘要

#### Scenario: 不提供恢复到进行中
- **WHEN** 用户查看已完成会话的操作项
- **THEN** 不存在「恢复 / 重新开始计时」的入口

#### Scenario: 编辑态可修正时长
- **WHEN** 用户在编辑态调整会话的开始或结束时刻
- **THEN** 会话时长与相关统计按新的 `startedAt` / `endedAt` 重算

### Requirement: 删除训练记录

系统 SHALL 允许删除已完成训练记录（列表左滑），删除 MUST 二次确认。被删除的训练 MUST 通过软删墓碑机制同步至后端，且删除后不再出现于任何列表，亦不计入任何统计（本周次数、训练量、历史曲线、PR）。左滑显露删除按钮时 SHALL 触发一次选择类触感（`Theme.Haptics.selection()`），显露与收回的回弹动画 MUST 对称。由于左滑手势对 VoiceOver 不可达，每条训练行 MUST 额外提供 VoiceOver 删除动作（`accessibilityAction(named: "删除")`），其同样走二次确认。

#### Scenario: 左滑删除已完成训练
- **WHEN** 用户在训练列表左滑某条已完成训练并确认删除
- **THEN** 该训练从列表移除、不再计入统计，并以墓碑形式同步至后端

#### Scenario: 删除需确认
- **WHEN** 用户左滑触发删除
- **THEN** 系统弹出删除确认，取消则保留该训练

#### Scenario: 左滑显露触感
- **WHEN** 用户左滑使删除按钮越过显露阈值
- **THEN** 触发一次选择类触感，松手后按对称回弹动画停靠在显露或收回位

#### Scenario: VoiceOver 删除
- **WHEN** VoiceOver 用户聚焦某条训练行并执行其「删除」自定义动作
- **THEN** 系统弹出同样的删除二次确认，确认后软删并同步

### Requirement: 移除首页工具栏右上角入口

训练首页工具栏右上角的占位「搜索」图标与「加号」菜单（含「空白训练」与「从某计划开始」两类项）MUST 全部移除，右上角不再呈现任何控件。首页 MUST NOT 提供任何训练记录搜索能力。左上角原「日历 / 训练历史」入口 MUST 一并移除（历史模块已删除），工具栏左上角不再呈现任何控件。移除后「开始训练」MUST 仅由底部悬浮 CTA 承载；首页 MUST NOT 提供多计划快速选择入口（多计划选择交由「计划」页）。

#### Scenario: 右上角无控件
- **WHEN** 用户进入训练首页
- **THEN** 工具栏右上角为空，不显示搜索图标，也不显示加号菜单

#### Scenario: 无首页搜索
- **WHEN** 用户希望检索历史训练
- **THEN** 首页不提供搜索框，亦无任何过滤入口

#### Scenario: 左上角无历史入口
- **WHEN** 用户查看工具栏左上角
- **THEN** 不再呈现「日历 / 训练历史」入口，左上角为空，无任何进入历史的入口

### Requirement: 首页开始入口收敛为智能单键 CTA

训练首页的「开始训练」入口 MUST 唯一收敛到底部悬浮 CTA（单点击，无长按、无备选菜单）。在**不存在**进行中会话时：若**存在**「进行中」计划，CTA 文案 SHALL 上下文化为「从『计划名』开始」并以该计划预填新会话（复用既有 `start(from:)` 流程）；若无任何计划，CTA SHALL 维持「开始今日训练 / 开始第 1 次训练」并创建空白训练。「进行中」计划的判定 MUST 复用与「计划」页一致的同一份判定逻辑（近 14 天内有关联该计划的已完成训练，否则取最近更新的计划），不得另写一套。CTA SHALL 采用按压交互样式并在点击时触发一次触感。

#### Scenario: 存在进行中计划
- **WHEN** 用户近 14 天有关联计划「严肃推拉腿」的训练，且当前无进行中会话
- **THEN** 底部 CTA 文案为「从『严肃推拉腿』开始」，单击以该计划动作项预填并进入新会话

#### Scenario: 无任何计划
- **WHEN** 用户没有任何计划且无进行中会话
- **THEN** CTA 文案为「开始今日训练 / 开始第 1 次训练」，单击创建空白训练

#### Scenario: 判定与计划页一致
- **WHEN** 「计划」页将某计划标记为「进行中」
- **THEN** 首页 CTA 上浮的计划与之为同一计划，不出现两页不一致

