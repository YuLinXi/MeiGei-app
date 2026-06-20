## Why

本工程是「全局唯一 `NavigationStack` 包 `TabView`」架构，所有二级/三级页都经 push 呈现并统一用 `.paperToolbar()` 接入标题栏。为了把系统蓝色返回箭头换成纸感圆形返回钮，`paperToolbar` 内部设了 `navigationBarBackButtonHidden(true)`——而 iOS 会因此**连带禁用左边缘侧滑返回手势**（`interactivePopGestureRecognizer`），导致这些 push 页只能点左上角圆钮返回、侧滑无效，明显偏离 iOS 用户的肌肉记忆。

## What Changes

- 在 `paperToolbar` 的单一收口处恢复左边缘侧滑返回手势：挂一个空 `UIViewControllerRepresentable`，探到所在 `UINavigationController`，把 `interactivePopGestureRecognizer.delegate` 接管为自定义 delegate，**仅当 `viewControllers.count > 1` 时允许手势开始**（根页保护，避免在 Tab 根页误触发 pop）。
- 覆盖范围 = 所有经 `.paperToolbar()` 接入的 push 子页：`PlanDetailView` / `PlanEditorView` / `WorkoutLoggingView` / `WorkoutDetailView` / `TeamDetailView` / `TeamPlansView` / `ExerciseDetailView`。改一处即全覆盖。
- 侧滑返回与圆形返回钮在语义上等价：两者都执行标准 pop（等价于 `dismiss()`），保持原生跟手转场动画。

## Non-goals

- **不**改 `fullScreenCover` / `sheet` 模态页（删除二次确认、开发工具页、PR 庆祝弹窗等）——它们的「返回」语义是下滑 dismiss，不是侧滑返回上一页，不在本次范围。
- **不**改 Tab 根页（训练/计划/动作/Team/我的）的导航行为。
- **不**引入自绘 `DragGesture` 方案（无原生跟手转场、与内部横滑控件冲突），也**不**改回显示系统蓝色返回箭头。
- **不**改变现有返回钮的视觉、布局或 iOS 26 双环处理。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `design-system`: 「统一子页 Header 容器」（`paperToolbar` / `PaperNavBar`）在隐藏系统返回按钮的同时，MUST 恢复左边缘侧滑返回手势，并对栈根页做保护。

## Impact

- **代码**：`ios/DontLift/DontLift/DesignSystem/Components.swift`（`paperToolbar` 扩展 + 新增 `UIViewControllerRepresentable` 与手势 delegate 辅助类型）。受益的 push 页无需逐页改动。
- **依赖**：触碰 UIKit（`UINavigationController` / `UIGestureRecognizerDelegate`），无新增第三方依赖。
- **风险点**：需验证侧滑手势与页面内部横滑控件（Swift Charts 历史曲线、可能的横滑 List / 拖拽排序）共存；最低 iOS 17.4 上 `NavigationStack` 底层仍是 `UINavigationController`，delegate 接管方式有效。
- **测试**：以 `xcodebuild` 编译验证为准；交互需真机/模拟器手动回归各 push 页侧滑返回。
