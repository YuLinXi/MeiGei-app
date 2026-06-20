## 1. iOS 端 — 复用排序面板

- [x] 1.1 新增 `ExerciseOrderItem` 与 `ExerciseOrderEditorSheet`：面板维护草稿顺序，`取消`丢弃，`完成`提交排序后的 `[UUID]`。
- [x] 1.2 排序面板使用 `List + ForEach.onMove`，进入即 `EditMode.active`，展示原生 reorder control。
- [x] 1.3 排序面板使用统一纸感 sheet 顶栏与背景，顶部按钮使用自定义 44pt 胶囊样式，并禁用下滑关闭避免与上下拖动排序冲突。

## 2. iOS 端 — 计划详情动作排序

- [x] 2.1 在 `PlanDetailView` 的 `训练动作` header 右侧增加 `排序` 入口，仅动作数大于 1 时显示。
- [x] 2.2 正常计划动作行移除常驻排序 handle，保留点行编辑、编辑图标、左滑删除；严格模式不显示逐项来源文案和“严格”胶囊。
- [x] 2.3 排序完成后按返回 ID 顺序重写 `PlanItem.orderIndex`，`plan.markDirty()` 并保存；取消不保存。

## 3. iOS 端 — 训练进行中动作排序

- [x] 3.1 在三联数下方、动作列表上方增加 `训练动作 · 排序` 紧凑 header，仅 `canEdit && exercises.count > 1` 时显示。
- [x] 3.2 打开训练排序前收起自研数字键盘、动作菜单、组菜单；正常动作卡头移除常驻排序 handle。
- [x] 3.3 排序完成后按返回 ID 顺序重写当前 `WorkoutExercise.orderIndex` 并 `touch()`；不改来源计划。

## 4. iOS 端 — 手势与状态回归

- [ ] 4.1 验证计划详情排序不破坏左滑删除、点按编辑、添加动作与开始训练。
- [ ] 4.2 验证训练进行中排序不破坏卡头展开/收起、动作更多菜单、组更多菜单、自研数字键盘、休息 FAB 拖动。
- [ ] 4.3 验证训练中排序不会自动改写来源计划顺序；计划详情排序会影响未来从计划开始的动作顺序。

## 5. 后端 / 基础设施

- [x] 5.1 确认无需后端 API、数据库迁移或基础设施改动；排序复用既有 `orderIndex` 与同步契约。

## 6. 验证

- [x] 6.1 `openspec validate workout-exercise-reorder --strict` 通过。
- [x] 6.2 `git diff --check` 通过。
- [x] 6.3 iOS `xcodebuild -project DontLift.xcodeproj -scheme DontLift -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build` 通过。

> 当前待手工回归 4.x。
