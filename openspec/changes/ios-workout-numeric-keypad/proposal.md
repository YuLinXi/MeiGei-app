## Why

训练进行中（`WorkoutLoggingView` → `SetRow`）记录每组重量/次数，现状用系统 `TextField` + `.decimalPad`/`.numberPad`，存在两类问题：

1. **收起没有显式入口**：`.decimalPad`/`.numberPad` 系统键盘无 Return/Done 键，只能靠点击空白让 `TextField` 失焦才收起，训练时单手操作很别扭。
2. **三个概念错位**：当前 `isActive` = `activeSetIndex`（「第一个未完成的组」`WorkoutViews.swift:1032`），它既不是键盘焦点、也不是用户正在编辑的格子，却被借用来做红色高亮。于是**待办指示、视觉高亮、真实键盘焦点**三者各自独立、互不同步——用户点第 3 组重量框去改，高亮可能还停在第 1 组，体验含糊。

健身录入的输入语义是「整值替换」（一组重量/次数基本整体改写，而非在数字中间插字符），系统文本输入法的光标/选区红利用不上。改为**纯 SwiftUI 自研数字键盘 + 显式焦点状态机**，既给出专业训练 App 的录入手感，又顺手根治焦点语义混乱。

## What Changes

- **新增自研数字键盘**（纯 SwiftUI，挂 `safeAreaInset(edge: .bottom)`）：键位 `0-9` · `.` · `⌫`(删除) · `上一项` · `下一项` · `收起`（浮动在键盘右上角）。无「完成」键——打卡仍由每行右侧现有勾选按钮（`checkButton`）承担。
- **BREAKING（输入控件）**：`SetRow` 的 `weightKg`/`reps` 不再用系统 `TextField`，改为**可点击的值显示单元**，由自研键盘驱动编辑。移除 `numberField`/`intField` 中的 `.keyboardType` 与系统键盘依赖。
- **新增显式焦点状态机** `focused: FocusedCell?`（`.weight(setID)` / `.reps(setID)` / `nil`）：`nil` ⟺ 键盘收起、无高亮；非 `nil` ⟺ 键盘升起、所在组高亮。**高亮改为 focused 派生**，「第一个未完成组」的待办指示降级为弱视觉，不再借用高亮。
- **输入规则**：重量为小数、小数点后**最多 2 位**（第 3 位忽略），空缓冲按 `.` → `0.`；次数为整数、`.` 键灰显无效；「打字即覆盖」（pending-replace）：聚焦已有值时首个数字键清空重填，`⌫` 不清空直接删末位。
- **跳转**：`上一项`/`下一项` 沿 `组0.重量 → 组0.次数 → 组1.重量 → …` 在当前动作内前进/后退；到最后一项再「下一项」→ 收起键盘。配 `ScrollViewReader` 把 focused 行滚进可视区。

## Capabilities

### New Capabilities
<!-- 无新增 capability -->

### Modified Capabilities
- `workout-tracking`: 新增「训练录入数字键盘与焦点」requirement —— 自研键盘键位与编辑规则、显式焦点状态机与高亮派生、与打卡/休息计时解耦的关系契约。

## Impact

- **iOS 视图层**：改写 `Workout/WorkoutViews.swift` 的 `SetRow`（`numberField`/`intField` 从 `TextField` 改为值显示单元）；新增数字键盘视图（暂定 `WorkoutKeypad`）与 `FocusedCell` 焦点状态；`WorkoutLoggingView`/`ExerciseBlock` 提升 `focused` 状态、挂 `safeAreaInset` + `ScrollViewReader`。
- **数据模型**：不变。`WorkoutSet.weightKg: Double?` / `reps: Int?`（`Models/Workout.swift:102`）契约不动，键盘只改输入路径。
- **解耦**：打卡（`checkButton` → `set.completed` + `onComplete()` 起休息计时）与键盘**完全独立**——去掉键盘上的完成键后，二者互不调用。
- **非影响**：不改计划编辑页（`PlanItemEditorView` 仍用系统键盘 + toolbar Done）；不改同步/LWW；不改 PR/historyKey；不改后端。

## Non-goals

- **不做**领域键：kg/lbs 单位切换、热身组/递减组/记录左右、RPE、片总重、一键改↑↓——全部留作后续迭代（见 design.md 迭代清单）。
- **不做**单位换算与存储：重量仍以 kg 存储、按现有 `formatKg` 显示。
- **不做**系统文本输入法的光标/选区/撤销/硬件键盘/iPad 浮动键盘支持（本场景整值替换，主动放弃）。
- **不做**计划编辑页与其它表单页的键盘改造——本 change 仅限训练进行中的组记录。
