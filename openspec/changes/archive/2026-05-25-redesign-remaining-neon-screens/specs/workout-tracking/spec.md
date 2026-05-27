## ADDED Requirements

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

### Requirement: 历史（History）版式

`HistoryView` SHALL 顶部一行 `HorizontalChipPicker` 时间窗筛选（7 天 / 30 天 / 90 天 / 全部，默认 30 天）。下方按顺序渲染：一张 chart-card（标题「月度总训练量」+ 大数字单位「吨」+ MoM delta 文字 + 19 根 cyan 柱状图，最末一根 `Theme.Color.accentMagenta` + glow 表示当前周）、`eyebrow`「本月 PR」+ PR 卡片列表（首张为 `Theme.Color.accentMagenta` 边光卡「★ NEW PR」+ 数值 + 右侧 `+{delta}` magenta pill，其余为常规 card + 右侧 `+{delta}` `Theme.Color.ok` pill）。

#### Scenario: 当月无 PR
- **WHEN** 本月窗口内 0 个 PR
- **THEN** 「本月 PR」段折叠（不渲染 eyebrow 与列表）。

#### Scenario: 切换时间窗
- **WHEN** 用户从「30 天」切到「7 天」
- **THEN** 训练量条形图重算，柱数 = 7（按日聚合）；MoM delta 改为 WoW delta；PR 段筛选窗口同步收紧。
