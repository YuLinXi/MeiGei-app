## 1. 焦点状态机

- [x] 1.1 定义 `FocusedCell`（`.weight(UUID)` / `.reps(UUID)`，按 `WorkoutSet.localId`）
- [x] 1.2 在 `WorkoutLoggingView` 持有 `@State focused: FocusedCell?`，通过参数下传 `ExerciseBlock` → `SetRow`
- [x] 1.3 `isActive` 改为 focused 派生（`isEditing`）；保留「第一个未完成组」为弱视觉待办标记（`isTodo`，仅次序号/勾选环弱提示）
- [x] 1.4 `readOnly` 态：值单元不可点（`onTapGesture` guard `!readOnly`）、不设 focused

## 2. 值显示单元（替换 TextField）

- [x] 2.1 `SetRow` 的重量/次数从 `TextField` 改为可点击 `valueCell`（`Text` + `onTapGesture` 设 focused），移除 `.keyboardType`/`numberField`/`intField`
- [x] 2.2 聚焦字段视觉（accentSoft 底 + accent 1.5px 描边）与 D7 一致；次数态不显小数提示
- [x] 2.3 值显示沿用 `formatKg`（重量）/ `String(reps)`（次数），空值显示 placeholder（kg/次）

## 3. 自研键盘视图

- [x] 3.1 新建 `WorkoutKeypad`：4×3 数字区（底排 `. 0 ⌫`）+ 右侧 `上一项`/`下一项`（各跨 2 行）+ 浮动「收起」键
- [x] 3.2 次数态 `.` 键灰显且无效（`decimalEnabled` 控制 + `.disabled`）
- [x] 3.3 走 `Theme` 配色/圆角；`KeyPressStyle` 按压缩放/降透明反馈
- [x] 3.4 每键补 `accessibilityLabel`；值单元补 `accessibilityValue` + `.isButton` trait

## 4. 编辑缓冲与数值规则

- [x] 4.1 缓冲 `buffer: String` + `pendingReplace`；聚焦时 `currentText` 载入现值并置 `pendingReplace = true`
- [x] 4.2 数字键：pending 则覆盖、否则追加；`⌫` 取消 pending 并删末位
- [x] 4.3 重量：单个 `.`、空缓冲补 `0.`、小数点后 2 位上限（第 3 位忽略）；整数部分上限 4 位（防御）
- [x] 4.4 次数：仅整数（4 位上限）、`.` 无效
- [x] 4.5 每次变化 `writeBack` 写回 `weightKg`/`reps`（空串→nil）并调 `touch()`（markDirty+save）

## 5. 键盘承载与跳转

- [x] 5.1 `WorkoutLoggingView` 用 `.safeAreaInset(edge:.bottom)` 挂键盘，`focused != nil` 时显示（move 过渡）
- [x] 5.2 键盘升起时隐藏休息 FAB（`focused == nil` 条件），避免底部遮挡冲突（R2）
- [x] 5.3 `keypadPrev`/`keypadNext` 沿当前动作 `sequence` 跳；末项「下一项」→ 收起；首项「上一项」→ 保持
- [x] 5.4 `ScrollViewReader` + `.id(set.localId)`，focused 变化时 `scrollTo(anchor:.center)`
- [x] 5.5 「收起」键 `dismissKeypad()` 置 `focused = nil`

## 6. 验收

- [ ] 6.1 `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` 通过 —— **本环境无 iOS 模拟器运行时，无法执行**；已做 `swiftc -frontend -parse` 语法检查通过 + 全量语义复查，待用户机器跑全量 build
- [ ] 6.2 模拟器手测：点重量→升键盘、跳转链路、末项收起、小数 2 位上限、次数禁小数、打字即覆盖、⌫ 不覆盖
- [ ] 6.3 高亮跟随焦点（点非首个未完成组验证不再停在第一未完成组）
- [ ] 6.4 VoiceOver 抽测键位与值单元可读
- [ ] 6.5 只读态（已结束训练）不可聚焦、键盘不升起
