## Context

本工程 iOS 端导航是「全局唯一 `NavigationStack` 包 `TabView`」（`MainTabView.swift:78`）：5 个 Tab 根页位于栈底，所有二级/三级页经 `navigationDestination` push 出去、盖住 Tab Bar 全屏呈现。这些 push 子页统一用 `.paperToolbar()`（`Components.swift:101`）接入标题栏，内部设了 `navigationBarBackButtonHidden(true)` 以便把系统蓝色返回箭头换成纸感圆形返回钮。

`NavigationStack` 底层仍由 `UINavigationController` 驱动。UIKit 把 `interactivePopGestureRecognizer`（左边缘侧滑返回）的「是否可开始」默认委托给系统返回按钮的存在性——一旦 `navigationBarBackButtonHidden(true)` 隐藏了系统返回钮，该手势被连带禁用。结果：当前所有 push 子页只能点圆钮返回，侧滑无效。

涉及子页：`PlanDetailView` / `PlanEditorView` / `WorkoutLoggingView` / `WorkoutDetailView` / `TeamDetailView` / `TeamPlansView` / `ExerciseDetailView`，全部经同一个 `paperToolbar` 扩展，改一处即全覆盖。

## Goals / Non-Goals

**Goals:**

- 在 `paperToolbar` 单一收口处恢复左边缘侧滑返回，覆盖全部 push 子页，子页零改动。
- 侧滑返回与圆形返回钮语义等价：标准 pop + 原生跟手转场动画。
- 对栈根页（Tab 根页）做保护，侧滑不误触发 pop。

**Non-Goals:**

- 不改 `fullScreenCover` / `sheet` 模态页的退出交互（保持下滑 dismiss）。
- 不引入自绘 `DragGesture` 方案，不改回系统蓝色返回箭头，不动现有返回钮视觉与 iOS 26 双环处理。

## Decisions

### 决策 1：方案 A —— 接管 `interactivePopGestureRecognizer.delegate`

在 `paperToolbar` 内挂一个零尺寸、不可见的 `UIViewControllerRepresentable`（如 `SwipeBackEnabler`）。其承载的 `UIViewController` 在 `viewDidAppear` / `didMove(toParent:)` 时机沿 `self.navigationController` 探到所在的 `UINavigationController`，把 `interactivePopGestureRecognizer?.delegate` 接管为一个自定义 `UIGestureRecognizerDelegate`：

- `gestureRecognizerShouldBegin(_:)` 返回 `navigationController.viewControllers.count > 1`（根页保护）。
- `gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:)` 视回归结果决定是否返回 `true`，以处理与内部横滑控件并存。

自定义 delegate 由一个 `Coordinator`（或持有在 representable 内的 class）强引用，避免 `interactivePopGestureRecognizer.delegate` 为 `weak` 导致被释放。

**为何选 A 而非备选：**

- **方案 B（不隐藏系统返回键、改 `toolbarRole` 后自定义）**：会让 iOS 26 Liquid Glass「双环」问题回归，纸感样式难收口，且与现有「统一子页 Header 容器」契约冲突。
- **方案 C（全屏自绘 `DragGesture` 调 `dismiss()`）**：没有原生跟手转场动画，且与页面内部 `ScrollView` / `List` / Swift Charts 的横向手势严重打架，体验最差。
- 方案 A 是社区最成熟做法，体验最接近原生，且天然契合本工程「单一 NavigationStack + 统一 paperToolbar」的一处收口结构。

### 决策 2：手势接管的幂等与时机

`SwipeBackEnabler` 每次出现都重设 delegate 是幂等的（指向同一逻辑）。探 `navigationController` 用 `DispatchQueue.main.async` 兜底首帧 `navigationController` 尚为 nil 的竞态。delegate 实例可做成单例或随 representable 生命周期持有，二者皆可——关键是被强引用、且 `shouldBegin` 逻辑只依赖运行时 `viewControllers.count`，不缓存栈状态。

### 决策 3：收口位置

辅助类型（`SwipeBackEnabler` + delegate）与挂载点都放在 `DesignSystem/Components.swift` 的 `paperToolbar` 扩展内，作为 `.background(SwipeBackEnabler())` 或等价隐形挂载，与现有 `PaperToolbarContent` 并列。受益子页不感知、不改动。

## Risks / Trade-offs

- **[与内部横滑控件冲突]** → push 子页含 Swift Charts 历史曲线、可能的横滑 List / 拖拽排序。系统边缘手势仅占屏幕最左 ~20pt，通常不与内容区横滑冲突；如个别页（如 PlanEditor 拖拽排序）出现争用，用 `shouldRecognizeSimultaneouslyWith` 或在该控件侧限定手势区域处理。需真机/模拟器逐页回归。
- **[触碰 UIKit 私有依赖姿态]** → 仅用公开 API（`navigationController`、`interactivePopGestureRecognizer`、`UIGestureRecognizerDelegate`），非私有 selector，iOS 17.4+ 稳定有效；后续大版本若 `NavigationStack` 底层实现变动需回归。
- **[delegate 被释放]** → `interactivePopGestureRecognizer.delegate` 为 `weak`，自定义 delegate 必须有强引用持有，否则手势行为回退。实现时显式持有。
- **[根页误 pop 崩栈]** → 已由 `viewControllers.count > 1` 守卫；务必覆盖此守卫，否则 Tab 根页侧滑可能触发异常。
