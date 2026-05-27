## ADDED Requirements

### Requirement: 禁用 List/Form 顶层容器

新视图（本 change 涉及的 9 屏及未来同风格视图）MUST NOT 使用 SwiftUI `List` 或 `Form` 作为顶层滚动容器。若因功能必要（如系统级 swipe-to-delete）必须使用，MUST 通过 `.scrollContentBackground(.hidden)` + `.background(Theme.Color.bg)` 隐藏 iOS 默认浅灰背景，并在视图代码注释中标注「必要的 List 用法」原因。

#### Scenario: 新增设置类视图
- **WHEN** 新增 `ProfileView` 或同类设置 / 列表视图
- **THEN** 顶层使用 `ScrollView { LazyVStack { ... } }`，分组用自绘 `eyebrow` + `cardStyle()` 容器；不出现 `List` / `Form`。

#### Scenario: 必须使用 List 的边缘场景
- **WHEN** 某视图必须使用 List（如需要原生 swipe action）
- **THEN** 视图 MUST 调 `.scrollContentBackground(.hidden).background(Theme.Color.bg)`，且文件注释解释为何无法用自绘 VStack。

### Requirement: 横向 Chip 选择器组件

设计系统 SHALL 提供 `HorizontalChipPicker<Item: Identifiable>` 组件：水平 `ScrollView` + `HStack(spacing: Theme.Spacing.sm)` + 每个 chip 高 32pt、横 padding 14pt、`Theme.Radius.pill` 圆角。选中态背景 `Theme.Color.accentCyan` + `Theme.Color.accentInk` 文字 + `.neonGlow(.cyan, .sm)`；未选中态背景 `Theme.Color.surface` + 1pt `Theme.Color.border` + `Theme.Color.fg2` 文字。

#### Scenario: 动作库部位筛选
- **WHEN** ExerciseLibraryView 渲染部位筛选 chips
- **THEN** 使用 `HorizontalChipPicker`，传入 `[全部, 胸, 背, 腿, 肩, 手臂, 核心]`，默认选中第 0 个。

#### Scenario: 食材选择器分类
- **WHEN** FoodPickerView 渲染分类 chips
- **THEN** 使用同一个 `HorizontalChipPicker`，复用相同样式 token。

### Requirement: 宏量色补充语义 `macroFat`

设计系统 SHALL 在 Assets 新增一个 colorset `macroFat`（暖橙，目标 `oklch(72% 0.18 35)`，对应 sRGB 由 `scripts/oklch_to_srgb.*` 离线生成）。该颜色 MUST 仅用于「饮食 - 脂肪进度条」语义；视图代码 MUST NOT 在非饮食模块或非脂肪语义下引用该颜色。

#### Scenario: 饮食日记脂肪进度条
- **WHEN** 渲染脂肪宏量进度条
- **THEN** 进度填充使用 `Theme.Color.macroFat`，其余进度条使用 cyan / blue。

#### Scenario: 非脂肪语义引用
- **WHEN** 视图试图把 `macroFat` 用于非脂肪 UI（如 PR 卡 / 错误提示）
- **THEN** Code review MUST 拒绝该提交，迁移到 `accentMagenta` / `danger` / `accentCyan` 等正确语义色。
