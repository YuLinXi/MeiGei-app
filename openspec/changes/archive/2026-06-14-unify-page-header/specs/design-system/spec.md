## ADDED Requirements

### Requirement: 统一圆形图标按钮

设计系统 SHALL 提供唯一的圆形图标按钮组件 `CircleIconButton`，作为所有 Header / 导航栏中「返回 / 更多操作 / 次级图标动作」的单一来源；视图代码 MUST NOT 在页面内本地复制等价实现（如自绘 `navCircle`、自绘 Menu 圆形 label）。

- 默认直径 SHALL 为 36pt（导航类圆钮与主操作钮 `CircleAddButton` 直径对齐）。
- 图标字号 SHALL 由组件按统一规则从直径推导，MUST NOT 在调用点硬编码图标字号；同一直径下所有圆钮的图标视觉重量一致。
- 外观为白底（`Theme.Color.surface`）+ 1pt `Theme.Color.border` 描边 + 圆形，按压走 `PressableButtonStyle`。
- SHALL 支持 `active` 高亮态（选中/展开时用 `Theme.Color.accent` 前景 + `Theme.Color.accentSoft` 底 + `Theme.Color.accentSofter` 描边）与 `rotated` 旋转态（如 ⋯ 展开时旋转 90°）。
- SHALL 提供 Menu 版入口：以同一外观 label 包裹 SwiftUI `Menu`，确保「点击触发」与「弹出菜单」两类圆钮视觉完全一致。

#### Scenario: 子页接入返回按钮

- **WHEN** 任一 push/sheet 子页需要返回按钮
- **THEN** 使用 `CircleIconButton(systemName: "chevron.left", …)`，直径 36pt，图标字号由组件推导，外观为纸感白底圆形
- **AND** 不出现系统默认蓝色返回箭头

#### Scenario: 更多操作菜单圆钮

- **WHEN** Header 右侧需要「⋯ 更多操作」弹出菜单
- **THEN** 使用 `CircleIconButton` 的 Menu 版，其外观与点击触发版完全一致
- **AND** 菜单展开时圆钮进入 `active` + `rotated` 态

#### Scenario: 禁止本地复制实现

- **WHEN** 新增或修改任意页面的 Header 圆形按钮
- **THEN** 复用 `CircleIconButton`，MUST NOT 在该页内重新声明等价的圆形按钮外观函数

### Requirement: 统一子页 Header 容器

设计系统 SHALL 提供子页（push/sheet 二级及以上页面）的 Header 容器 `PaperNavBar`（或等价的 `.paperToolbar()` 修饰符），封装以下职责，使各子页以单一接入点获得一致的导航栏：

- 隐藏系统默认返回按钮（`navigationBarBackButtonHidden(true)`）。
- 在 iOS 26+ 对工具栏按钮施加 `sharedBackgroundVisibility(.hidden)`，消除 Liquid Glass 自动圆形背景与纸感圆钮叠成的「双环」；低于 iOS 26 走等价无背景分支。
- 提供左（返回）/ 中（标题）/ 右（操作）三槽位；左、右槽位默认承载 `CircleIconButton`。
- 标题 SHALL 使用单一字体 token（取代既有系统 inline / `body(15,heavy)` / `display(30)` 等并存写法），居中、单行截断。

所有 push/sheet 子页的标题栏 MUST 经由该容器实现；MUST NOT 直接散用裸 `.toolbar { … }` + 手搓圆钮 + 逐 `ToolbarItem` 打 `sharedBackgroundVisibility` 补丁的旧写法。Tab 根页（训练 / 计划 / 动作 / Team / 我的）的自绘大标题范式不受此要求约束——其中「我的」(`ProfileView`) 作为 Tab 根页（无返回箭头）SHALL 归入自绘大标题范式（`display(36, heavy)`），不走 `.paperToolbar()`。

#### Scenario: 子页统一接入

- **WHEN** `WorkoutDetailView` / `PlanDetailView` / `TeamDetailView` / `ExerciseDetailView` / `TeamPlansView`（push/sheet 子页）渲染顶部标题栏
- **THEN** 均经由 `.paperToolbar()` 接入，标题字体一致、返回/操作钮均为 36pt 纸感圆钮
- **AND** 不再各自处理 `navigationBarBackButtonHidden` 与 iOS 26 双环补丁

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
