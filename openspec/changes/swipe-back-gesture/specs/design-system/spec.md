## MODIFIED Requirements

### Requirement: 统一子页 Header 容器

设计系统 SHALL 提供子页（push/sheet 二级及以上页面）的 Header 容器 `PaperNavBar`（或等价的 `.paperToolbar()` 修饰符），封装以下职责，使各子页以单一接入点获得一致的导航栏：

- 隐藏系统默认返回按钮（`navigationBarBackButtonHidden(true)`）。
- 在隐藏系统返回按钮的同时，SHALL 恢复 iOS 左边缘侧滑返回手势（`interactivePopGestureRecognizer`），使所有 push 子页可通过侧滑返回上一页，行为与点击纸感圆形返回钮等价（标准 pop + 原生跟手转场）；该恢复 MUST 收口在容器内部，受益子页 MUST NOT 逐页自行处理。
- 侧滑返回的接管 MUST 做栈根页保护：仅当导航栈 `viewControllers.count > 1` 时允许手势开始，避免在 Tab 根页误触发 pop。
- 在 iOS 26+ 对工具栏按钮施加 `sharedBackgroundVisibility(.hidden)`，消除 Liquid Glass 自动圆形背景与纸感圆钮叠成的「双环」；低于 iOS 26 走等价无背景分支。
- 提供左（返回）/ 中（标题）/ 右（操作）三槽位；左、右槽位默认承载 `CircleIconButton`。
- 标题 SHALL 使用单一字体 token（取代既有系统 inline / `body(15,heavy)` / `display(30)` 等并存写法），居中、单行截断。

所有 push/sheet 子页的标题栏 MUST 经由该容器实现；MUST NOT 直接散用裸 `.toolbar { … }` + 手搓圆钮 + 逐 `ToolbarItem` 打 `sharedBackgroundVisibility` 补丁的旧写法。Tab 根页（训练 / 计划 / 动作 / Team / 我的）的自绘大标题范式不受此要求约束——其中「我的」(`ProfileView`) 作为 Tab 根页（无返回箭头）SHALL 归入自绘大标题范式（`display(36, heavy)`），不走 `.paperToolbar()`。侧滑返回手势仅作用于 push 出的子页，`fullScreenCover` / `sheet` 模态页不在此手势范围（其退出语义为下滑 dismiss）。

#### Scenario: 子页统一接入

- **WHEN** `WorkoutDetailView` / `PlanDetailView` / `TeamDetailView` / `ExerciseDetailView` / `TeamPlansView`（push/sheet 子页）渲染顶部标题栏
- **THEN** 均经由 `.paperToolbar()` 接入，标题字体一致、返回/操作钮均为 36pt 纸感圆钮
- **AND** 不再各自处理 `navigationBarBackButtonHidden` 与 iOS 26 双环补丁

#### Scenario: push 子页支持侧滑返回

- **WHEN** 用户在任一经 `.paperToolbar()` 接入的 push 子页（`PlanDetailView` / `PlanEditorView` / `WorkoutLoggingView` / `WorkoutDetailView` / `TeamDetailView` / `TeamPlansView` / `ExerciseDetailView`）从屏幕左边缘向右侧滑
- **THEN** 触发标准 pop 返回上一页，带原生跟手转场动画，效果与点击纸感圆形返回钮一致
- **AND** 该行为由 `.paperToolbar()` 容器统一提供，无需子页各自实现

#### Scenario: Tab 根页不被误触发返回

- **WHEN** 用户在导航栈根层（Tab 根页，`viewControllers.count == 1`）从左边缘侧滑
- **THEN** 不触发 pop，页面保持当前状态，不出现异常空白页或栈崩溃

#### Scenario: 我的页归入大标题范式

- **WHEN** Tab 根页「我的」(`ProfileView`) 渲染顶部
- **THEN** 用自绘大标题「我的」`display(36, heavy)` + `tracking(-1.08)`、隐藏系统导航栏，与其它 4 个 Tab 根页一致
- **AND** 不出现系统 inline 居中标题

#### Scenario: iOS 26 不出现双环

- **WHEN** 在 iOS 26+ 设备上进入任一接入了 `PaperNavBar` 的子页
- **THEN** Header 圆钮仅显示纸感白底圆形一层背景，不出现系统 Liquid Glass 叠加的第二层圆环

#### Scenario: 子页标题字体统一

- **WHEN** 任意子页显示标题文字
- **THEN** 使用容器约定的单一标题字体 token，跨子页字号、字重一致
