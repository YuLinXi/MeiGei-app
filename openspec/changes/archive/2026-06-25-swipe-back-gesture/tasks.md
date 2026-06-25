## 1. iOS 端 — 手势辅助类型

- [x] 1.1 在 `DesignSystem/Components.swift` 新增自定义 `UIGestureRecognizerDelegate`（如 `SwipeBackGestureDelegate`）：`gestureRecognizerShouldBegin` 返回 `viewControllers.count > 1`（根页保护）；按需实现 `shouldRecognizeSimultaneouslyWith`。delegate 被强引用持有（避免 `weak` 释放）。
- [x] 1.2 新增零尺寸隐形 `SwipeBackEnabler: UIViewControllerRepresentable`：承载 VC 在 `viewDidAppear`/`didMove(toParent:)` 沿 `navigationController` 探到 `UINavigationController`，把 `interactivePopGestureRecognizer.delegate` 接管为 1.1 的 delegate；首帧 nil 用 `DispatchQueue.main.async` 兜底，接管幂等。

## 2. iOS 端 — paperToolbar 收口接入

- [x] 2.1 在 `paperToolbar` 扩展（`Components.swift:101`）内以隐形 `.background(SwipeBackEnabler())`（或等价）挂载手势恢复，与 `PaperToolbarContent` 并列；保持 `navigationBarBackButtonHidden(true)` 与 iOS 26 双环处理不变。
- [x] 2.2 确认 7 个受益 push 子页（`PlanDetailView`/`PlanEditorView`/`WorkoutLoggingView`/`WorkoutDetailView`/`TeamDetailView`/`TeamPlansView`/`ExerciseDetailView`）无需逐页改动即获得侧滑返回。

## 3. iOS 端 — 验证与回归

- [x] 3.1 `xcodebuild` 编译验证通过（iPhone 17 Pro 模拟器，`CODE_SIGNING_ALLOWED=NO`）。
- [ ] 3.2 逐页手动回归侧滑返回：7 个 push 子页均能左边缘侧滑 pop、带原生跟手转场、与圆钮返回等价。
- [ ] 3.3 验证栈根页保护：5 个 Tab 根页左边缘侧滑不触发 pop、无异常空白页/崩栈。
- [ ] 3.4 验证与内部横滑控件共存：含 Swift Charts 历史曲线页、PlanEditor 拖拽排序等，侧滑手势不与内容横滑争用（如有冲突按 design.md 风险项调整）。
- [ ] 3.5 确认 `fullScreenCover`/`sheet` 模态页（删除二次确认、开发工具页、PR 庆祝）退出交互未受影响。
