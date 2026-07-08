## Context

动作库的自定义顶部搜索框目前内嵌在 `ExerciseLibraryContentView` 的普通 `VStack` 内容流中，并被两个入口复用：

- 动作库 Tab：`NavigationStack → TabView → ExerciseLibraryView → ExerciseLibraryContentView`
- 训练 / 计划添加动作：`.sheet → ExercisePickerView → ExerciseLibraryContentView`

真机弹出系统键盘时，SwiftUI 会把 keyboard safe area 纳入布局调整。由于搜索框处在会被外层 host 重新提案高度 / safe area 的内容流中，页面整体上移，搜索框会与状态栏、Dynamic Island 或「返回上个 App」提示重叠。此前局部 modifier 和键盘 offset 补偿无法稳定覆盖 Tab 切换、sheet 生命周期和真机输入法路径。

本 change 仅调整 iOS 动作库 UI 外壳，不涉及后端、同步实体、幂等键、软删除或数据模型。

## Goals / Non-Goals

**Goals:**

- 保留当前自定义顶部搜索框视觉。
- 在动作库 Tab 内，搜索框获得焦点并弹出系统键盘时，搜索框顶部位置保持稳定，不进入状态栏区域。
- 在训练进行中 / 计划编辑的添加动作抽屉内，搜索框获得焦点并弹出系统键盘时，交互体验与动作库 Tab 一致。
- 将搜索框、搜索状态和主体列表的布局职责拆清，避免继续依赖键盘 offset 补偿。

**Non-Goals:**

- 不改为系统 `.searchable`。
- 不重做动作库分类、器械索引、动作数据、搜索匹配或分页策略。
- 不改变其它页面的系统键盘避让行为。
- 不新增后端 API、数据库迁移、同步模型或写接口。

## Decisions

### 1. 引入动作库专用 keyboard-stable host

动作库外层使用一个局部 SwiftUI/UIKit bridge 承载内容，并在 `UIHostingController` 层排除 keyboard safe area 对该 host 的影响。项目最低 iOS 17.4，允许使用现代 `UIHostingController.safeAreaRegions` 能力。

**选择原因：**

- 键盘避让发生在 host / 容器层，不应继续在子视图用 `.offset` 追补。
- 局部 host 只作用于动作库，不影响训练详情输入框、登录页、资料页等其它键盘场景。
- 比全局修改 `NavigationStack` / `TabView` 键盘策略风险更小。

**替代方案：**

- `.searchable`：最稳定，但会改变当前自定义搜索框视觉，本 change 明确不采用。
- 子视图 `.ignoresSafeArea(.keyboard)` / `.safeAreaInset` / `.offset`：已被真机路径证明不稳定，不再延续。

### 2. 抽出 `ExerciseLibraryShell`

新增一个动作库 shell 负责：

- 持有 `query`
- 渲染顶部 `searchBar`
- 将 `query` 传入主体内容
- 作为 Tab 和 picker 的共同入口

`ExerciseLibraryContentView` 收敛为主体内容，保留左栏、右侧列表、器械索引、过滤和删除逻辑。

**选择原因：**

- 搜索框是外壳 chrome，不应和列表主体混在同一内容流里。
- Tab 页和 sheet 页需要复用同一套顶部搜索和键盘策略。

### 3. 键盘出现时不移动顶部搜索框，只允许列表底部被遮挡或滚动

本 change 的稳定性目标是顶部搜索框不动。键盘遮挡底部列表内容是可接受的，因为搜索场景下用户主要关注顶部输入和上方过滤结果；后续若需要，可以只给右侧列表增加底部留白，但不能让顶部搜索框参与键盘避让。

## Risks / Trade-offs

- `UIHostingController.safeAreaRegions` 在当前 TabView / sheet 嵌套中行为若与预期不一致 → 用真机验证；若仍不稳定，下一步把整个动作库入口改为 UIKit-backed view controller，而不是继续加 SwiftUI offset。
- 搜索框从主体内容抽出后，可能影响内容顶部间距 → 保持现有 `Theme.Spacing.md` / picker `14` 的顶部间距语义，并用真机截图校验。
- keyboard-stable host 需要继续占满 Tab 内容区，右下悬浮添加按钮不得通过 `safeAreaInset` 抬高整块动作库内容。
- 键盘可能遮住列表底部若干行 → 本 change 优先保证搜索框可见；底部列表留白可作为后续增强。

## Migration Plan

- 无数据迁移。
- 撤回失败的键盘通知 offset 补偿。
- 实现局部 keyboard-stable host 与动作库 shell。
- 运行 iOS simulator build。
- 真机回归动作库 Tab、Tab 切换返回、训练中添加动作 sheet、中文输入法候选栏、返回上个 App 状态栏路径。

## Open Questions

- 真机是否仍存在特定输入法候选栏导致的额外安全区变化；若存在，优先通过 host 边界处理，不回到 offset 补偿。
