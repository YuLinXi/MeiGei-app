## ADDED Requirements

### Requirement: 饮食日记顶部宏量进度环

`FoodDiaryView` SHALL 在标题下方渲染一个组合视图 `MacroRingView`：左侧 120×120pt 圆环显示「当日总热量 / 目标热量」（中心 `Theme.Font.numeric` 大数字 + `Theme.Font.mono` 小单位 `KCAL`），右侧 4 条横向进度条依次为 **蛋白质 / 碳水 / 脂肪 / 水**。圆环外层进度色 MUST 为 `Theme.Color.accentCyan` 并附 `.neonGlow(.cyan, .sm)`。

#### Scenario: 当日已记录食物
- **WHEN** 进入「饮食」tab 且当日有食物条目
- **THEN** 圆环按「当日总热量 / 营养目标热量」绘制 stroke trim，中心显示 `1854` 与 `/ 2600 KCAL` 两行；4 条进度条 fill 比例 = 实际 / 目标，clamp 到 [0,1.0]。

#### Scenario: 当日未记录食物
- **WHEN** 进入「饮食」tab 且当日 0 条食物
- **THEN** 圆环 trim 为 0；中心数字显示 `0`，进度条仅渲染底色 `Theme.Color.surface2`。

### Requirement: 餐次分块结构

饮食日记 SHALL 按「早餐 / 午餐 / 晚餐 / 加餐 / 训练后」分块呈现，每块顶部为 `MealBlockHeader`：粗体餐次名 + `Theme.Font.mono` 小字「`{热量} kcal · {首条时间 HH:mm}`」。每块下方为食物行，行间用 1pt `Theme.Color.border` 分隔，最后一块不画底部 border。

#### Scenario: 餐次内食物超过 4 条
- **WHEN** 某餐次条目数 > 4
- **THEN** 列表显示前 4 条，第 5 条起折叠为「`+ {N} 项` `{合计 kcal}`」单行 muted 文字。

#### Scenario: 餐次内 0 条
- **WHEN** 某餐次当日 0 条食物
- **THEN** 该餐次块 MUST NOT 渲染（不显示空块）。

### Requirement: 饮食日记右下角悬浮 + 按钮

`FoodDiaryView` SHALL 在 tabbar 上方右侧 22pt 处放置一个 56×56pt 圆形 FAB，背景 `Theme.Color.accentCyan` + `.neonGlow(.cyan, .md)`，中心为 + 图标。点击后 push 到 `FoodPickerView`，默认餐次 = 当前时段（按本地时区 06-10 早餐 / 10-14 午餐 / 14-18 加餐 / 18-22 晚餐 / 22-06 加餐）。

#### Scenario: 上午点击 FAB
- **WHEN** 本地时间 09:30，用户点击 FAB
- **THEN** `FoodPickerView` 顶部显示「添加 · 早餐」。

### Requirement: 食材选择器顶部搜索框 + 横向 chip

`FoodPickerView` SHALL 在顶部依次渲染：搜索框（`Theme.Color.surface` 背景，左 search icon + 占位「搜索 1500 项标准食材」）、横向 chip 选择器（默认选中「最近」），chip 列表为：`最近 / 收藏 / 蛋白质 / 主食 / 蔬菜 / 水果 / 自定义`。chip 选中态背景 `Theme.Color.accentCyan` + `Theme.Color.accentInk` 文字，未选中态 `Theme.Color.surface` + `Theme.Color.fg2`。

#### Scenario: 切换 chip
- **WHEN** 用户点击 chip「蛋白质」
- **THEN** 列表过滤为蛋白质类食材，eyebrow 文字从「最近常用」切到「蛋白质」。

#### Scenario: 已添加食材的视觉反馈
- **WHEN** 某食材本次会话已添加到当前餐次
- **THEN** 该行右侧圆按钮从 + 图标切到 ✓ 图标，背景从 `Theme.Color.surface` 切到 `Theme.Color.accentCyan`。

### Requirement: 食材行版式

每个食材行 SHALL 包含：42×42pt 圆角缩略图（emoji 或单色背景）、食材名（粗体）+ `Theme.Font.mono` 小字「`{kcal} kcal / {单位} · P {蛋白} · C {碳水} · F {脂肪}`」、右侧 28×28pt 添加按钮。

#### Scenario: 中文食材名超长
- **WHEN** 食材名 > 8 个汉字
- **THEN** 食材名单行截断 with `lineLimit(1)`，副标继续显示完整宏量。
