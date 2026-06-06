## 1. 设计系统基建（iOS 端）

- [x] 1.1 新建 `ios/MeiGei/MeiGei/DesignSystem/Haptics.swift`：`extension Theme { enum Haptics }`，暴露 `impact(_:)` / `selection()` / `notification(_:)`，内部封装对应 `UI*FeedbackGenerator`
- [x] 1.2 在 `DesignSystem/Modifiers.swift` 新增 `struct PressableButtonStyle: ButtonStyle`：按下 `scaleEffect(0.97)` + 降透明度 + `.easeOut(0.12)`，读 `accessibilityReduceMotion` 时退化为仅透明度
- [x] 1.3 将 `Workout/RestTimerSheet.swift:29,53` 两处裸 `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator` 迁移到 `Theme.Haptics`

## 2. 交互打磨：首页（iOS 端）

- [x] 2.1 `WorkoutViews.swift` 接入触感：`startBlank()`/`start(from:)` → `impact(.medium)`；继续横幅点击 → `impact(.light)`；删除确认「删除」→ `notification(.warning)`；`finish()` → `notification(.success)`
- [x] 2.2 `startCTA`、`continueBanner`、`SwipeToDeleteCard` 内容点击由 `.buttonStyle(.plain)` 改为 `PressableButtonStyle()`
- [x] 2.3 `SwipeToDeleteCard` 打磨：越过 `revealed` 阈值首次触发 `Theme.Haptics.selection()`（`@State didReveal` 去抖）；显露/收回回弹统一 `.spring(response:0.3, dampingFraction:0.8)`
- [x] 2.4 `SwipeToDeleteCard` 补 `.accessibilityAction(named: "删除") { onDelete() }`，复用现有二次确认

## 3. 信息架构 / 入口收敛（iOS 端）

- [x] 3.1 移除工具栏 `topBarTrailing` 整组：删除占位搜索 `Image` 与加号 `Menu`（含空白训练 / 从计划开始项），右上角清空；保留左上角日历入口
- [x] 3.2 抽取 `activePlan` 判定为 `WorkoutPlan.active(in:workouts:)` 静态方法，计划页改为调用该入口（行为等价）
- [x] 3.3 底部 CTA 智能单键：无进行中会话且存在 activePlan 时，`startCTA` 文案 →「从『\(name)』开始」、动作走 `start(from:)`；无任何计划时维持「开始今日 / 第 1 次训练」走 `startBlank()`；保留 `beginSession` 活跃会话守卫，不加长按/备选菜单
- [x] 3.4 确认 `startBlank()` / `start(from:)` 两个动作函数保留（仅调用入口从菜单改为 CTA），移除菜单后无悬空引用、编译通过

## 4. 视觉细节 / 无障碍（iOS 端）

- [x] 4.1 图标-only 按钮补 `accessibilityLabel`：工具栏日历（加号已移除）、`LiveHeaderView` 停止键、`restFAB`、`SetRow` 完成勾选
- [x] 4.2 `continueBanner` / `recentRow` 用 `.accessibilityElement(children: .combine)` 合成语义整句；三宫格 `statCell` 加 `accessibilityValue`
- [x] 4.3 reduceMotion 退化：`LiveHeaderView` LIVE 脉冲、restFAB 入场与休息弹窗 `.spring()` 过渡在开关开启时退化为静态/短淡变（restFAB 静态辉光非重复动效，不绑 reduceMotion）
- [x] 4.4 Dynamic Type 防截断：hero 大数字与副标、`recentRow` 标题/副标/PR、三宫格 value/label 加 `minimumScaleFactor` + `lineLimit`

## 5. 验证

- [x] 5.1 `xcodebuild`（`ios/MeiGei/`，iPhone 17 Pro 模拟器，`CODE_SIGNING_ALLOWED=NO`）编译通过 —— **BUILD SUCCEEDED**
- [ ] 5.2 真机：CTA/继续/删除/结束触感正确；左滑越阈有 selection 触感；按压微缩无布局跳动
- [ ] 5.3 工具栏：右上角无搜索、无加号菜单;左上角日历可进历史;首页无任何搜索入口
- [ ] 5.4 入口：有近 14 天计划训练时 CTA 走「从『X』」预填;无计划时走空白;与计划页「进行中」一致;无进行中会话守卫正常
- [ ] 5.5 无障碍：VoiceOver 逐控件有 label、卡片念整句、可用删除动作；开「减弱动态效果」动画退化；最大动态字号首页不破版
