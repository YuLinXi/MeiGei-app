## Context

`SetRow`（`WorkoutViews.swift:1137`）目前用两个系统 `TextField` 录入重量/次数：

- `numberField` → `.keyboardType(.decimalPad)`，`intField` → `.keyboardType(.numberPad)`，**均无显式收起入口**。
- 行高亮由 `isActive` 控制，而 `isActive = (activeSetIndex == set.setIndex)`，`activeSetIndex` 取「第一个未完成组」（`WorkoutViews.swift:1032`）——它是**待办指示**，不是焦点。
- 没有任何 `@FocusState`，真实键盘焦点完全交给系统，与高亮不同步。

本 change 用纯 SwiftUI 自研键盘 + 一个显式焦点状态机统一这三件事。

## Goals / Non-Goals

**Goals**
- 给训练录入一个专用数字键盘，含明确的收起入口与上一项/下一项跳转。
- 用一个 `focused` 真相源，统一「键盘升降 / 行高亮 / 当前编辑格」。
- 重量小数 ≤2 位的稳健输入；次数纯整数。

**Non-Goals**
- 领域键（单位/组类型/RPE/片总重/一键改）——留作迭代。
- 改数据模型、同步、PR 口径、后端、计划编辑页键盘。

## Decisions

### D1：纯 SwiftUI 自研，不走系统键盘 / inputView

`SetRow` 的重量/次数从 `TextField` 改为**可点击值显示单元**（`Button`/`onTapGesture` 包裹 `Text`），点击设置 `focused`。键盘本体是普通 SwiftUI 视图，挂 `WorkoutLoggingView` 的 `.safeAreaInset(edge: .bottom)`，`focused != nil` 时出现。

- **为何不用 `UITextField.inputView`（UIKit 自定义键盘）**：本场景整值替换、不需要光标/选区，UIViewRepresentable 反而引入桥接复杂度与焦点双源问题。
- **代价**：放弃系统输入法的光标/选区/撤销/硬件键盘——本场景用不上；无障碍需手动补（见 D6）。

### D2：焦点状态机 `FocusedCell`

```swift
enum FocusedCell: Equatable {
    case weight(UUID)   // WorkoutSet.localId
    case reps(UUID)
}
```

- `focused: FocusedCell?` 提升到能覆盖整个动作列表的层级（`ExerciseBlock` 或 `WorkoutLoggingView`，取决于键盘是否跨动作跳转——本版**仅在当前动作内跳转**，故置于 `ExerciseBlock` 即可，但键盘 UI 需在 `WorkoutLoggingView` 层挂 `safeAreaInset`；用绑定下传或上提至 `WorkoutLoggingView` 持有、`ExerciseBlock`/`SetRow` 通过 `@Binding` 读写）。
- **派生**：`isActive(set) = (focused 所在的 set == set)`；原 `activeSetIndex` 的「第一个未完成组」保留为**弱视觉待办标记**（如序号着色或淡描边），与高亮区分。
- `focused == nil` ⟺ 键盘收起；任何「收起」动作（收起键、跳过末项、显式 dismiss）都置 `nil`。

### D3：编辑缓冲区与 pending-replace

每个聚焦单元维护一个字符串缓冲 `buffer: String` + 标志 `pendingReplace: Bool`。

```
聚焦某格：buffer = 该格现值格式化串；pendingReplace = true
按数字 d：
  若 pendingReplace → buffer = d；pendingReplace = false
  否则             → buffer += d（受 D4 约束）
按 "."（仅重量）：
  pendingReplace → buffer = "0."；false
  buffer 已含 "." → 忽略
  buffer 为空     → buffer = "0."
  否则            → buffer += "."
按 ⌫：pendingReplace = false；buffer 删末位（空则保持空）
```

每次缓冲变化即 `parse(buffer)` 写回 `set.weightKg`/`set.reps` 并调 `onChange()`（沿用现有即时落盘 + markDirty 路径）。

### D4：数值约束

- **重量**（`Double?`）：仅允许一个 `.`；小数点后已有 2 位时，后续数字键忽略（不追加、不进位）。整数部分上限建议 4 位（≤9999kg，防御性，可选）。空串 → `weightKg = nil`。
- **次数**（`Int?`）：`.` 键灰显且无效；仅 `0-9`。位数上限建议 4 位（可选）。空串 → `reps = nil`。
- 复用现有 `formatKg` 做显示格式化（与表头/统计一致）。

### D5：跳转顺序

序列 = 当前动作内 `sortedSets` 展开为 `[组0.weight, 组0.reps, 组1.weight, 组1.reps, …]`。

- `下一项`：沿序列前进一格并聚焦；**已在末项** → 收起键盘（`focused = nil`）。
- `上一项`：后退一格；**已在首项** → 留在首项（或灰显禁用），不收起。
- 切换聚焦时 `ScrollViewReader.scrollTo(focused 行 id)`，把该行滚到键盘上方可视区。
- **不跨动作跳转**（本版）：到本动作末项即收起，换动作靠用户点击。

### D6：无障碍

自绘键盘每个键 MUST 加 `accessibilityLabel`（如「数字 7」「删除」「上一项」「收起键盘」）；值单元 `accessibilityValue` 反映当前值 + 聚焦态。`.` 在次数态标记为不可用。

### D7：键位排布（已定）

```
                         ⌄ 收起        ← 浮动在键盘右上角
┌────────────────────────────────────┐
│   1     2     3   │                 │
│   4     5     6   │    上一项        │
│   7     8     9   │    下一项        │
│   .     0     ⌫   │                 │
└────────────────────────────────────┘
```

- 数字区 4×3，底排 `. 0 ⌫`（对齐系统 decimalPad 肌肉记忆）。
- 右侧列两个大键 `上一项 / 下一项`。
- 收起键浮在键盘右上角（参考《训记》chevron），不占数字区。
- 配色/圆角走 `Theme`；次数态 `.` 键降透明度表「灰显无效」。

## Risks / Trade-offs

- **R1 焦点状态提升的改动面**：`focused` 需在 `WorkoutLoggingView`/`ExerciseBlock`/`SetRow` 间穿透。→ 用单一 `@State` + `@Binding` 下传，避免多源。
- **R2 safeAreaInset 与既有底部 UI 冲突**：训练页底部可能已有「新增一组/动作库」等按钮。→ 键盘出现时这些底部操作应被键盘遮挡或下移，需在实现时核对 `WorkoutLoggingView` 底部布局。
- **R3 无障碍回归**：丢掉系统键盘的免费无障碍。→ D6 强制补 label，验收纳入 VoiceOver 抽测。
- **R4 readOnly/已完成训练**：现有 `readOnly` 态禁输入。→ 值单元在 `readOnly` 时不可点、不设 `focused`。

## Migration Plan

- 纯前端、无数据迁移；`weightKg/reps` 字段与同步契约不变。
- 一次性替换 `SetRow` 的输入控件；旧 `numberField`/`intField` 的 `TextField` 实现删除。
- 计划编辑页（`PlanItemEditorView`）暂不动，保留系统键盘 + toolbar Done。

## 后续迭代清单（本 change 不做）

- kg/lbs 单位切换（需定「仅显示换算」vs「存储单位」，建议存 kg）。
- 组类型标签键：热身组 / 递减组 / 记录左右（需数据模型扩展 set 类型字段）。
- RPE 录入键（需 set 增 RPE 字段）。
- 片总重（每侧配重计算器）。
- 一键改↑↓（批量微调本动作所有组的重量/次数）。
- 键盘跨动作连续跳转（末项→下一动作首组）。
