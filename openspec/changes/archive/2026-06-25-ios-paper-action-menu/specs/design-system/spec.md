## ADDED Requirements

### Requirement: 统一纸感动作菜单

设计系统 SHALL 提供统一纸感动作菜单组件，用于呈现轻量动作入口（例如顶部 `+`、Header `...`、分组 `...`）。本组件 MUST 使用项目自绘浮层，不得依赖 SwiftUI `Menu`、`.confirmationDialog` 或系统 action sheet 作为主要呈现方式。

菜单组件 MUST 支持：

- 由圆形 `+` 或圆形 `...` 触发。
- 菜单项标题、SF Symbol 图标、普通/危险角色、禁用态与动作回调。
- 展开时触发按钮进入 active 态；`...` 触发按钮可进入 rotated 态。
- 点菜单外区域关闭；选择菜单项后关闭菜单并执行对应动作。
- 根据触发按钮位置锚定弹出：默认右边缘对齐、显示在触发按钮下方，卡片顶部与触发圆钮底部保持 8pt 垂直间距，并在靠近屏幕边缘时保持菜单完整可见。
- 使用 `Theme.Color.surface`、`Theme.Color.border`、`Theme.Radius.lg`、`Theme.Font.*`、`paperShadow` 与 `PressableButtonStyle` 等现有纸感 token。
- 在系统开启 Reduce Motion 时禁用缩放/位移动效，退化为淡入淡出。

本 change 覆盖范围内的动作菜单入口 MUST 使用该组件，包括计划列表顶部 `+`、计划列表分组 `...`、计划详情 `...`、Team 列表顶部 `+`。二次确认弹窗和错误提示不属于本组件职责。

#### Scenario: 顶部添加菜单使用纸感组件

- **WHEN** 用户点击计划页或 Team 页右上角 `+`
- **THEN** 系统 SHALL 显示纸感动作菜单
- **AND** 菜单使用项目自绘白底卡片、描边、圆角和阴影
- **AND** 不显示 SwiftUI `Menu` 的系统弹层样式

#### Scenario: 分组更多菜单使用纸感组件

- **WHEN** 用户点击计划分组 header 右侧 `...`
- **THEN** 系统 SHALL 显示纸感动作菜单
- **AND** 菜单 SHALL 提供该分组可用操作，例如新建计划、调整计划顺序、重命名分组、删除分组
- **AND** 危险操作 SHALL 使用危险角色视觉或明确的危险文案

#### Scenario: 选择菜单项后关闭菜单

- **WHEN** 用户在纸感动作菜单中选择任一可用菜单项
- **THEN** 菜单 SHALL 先关闭
- **AND** 系统 SHALL 执行该菜单项对应动作
- **AND** 不得在后续 sheet、导航或确认弹窗出现时残留菜单浮层

#### Scenario: 点外关闭

- **WHEN** 纸感动作菜单已展开，用户点击菜单外的页面区域
- **THEN** 菜单 SHALL 关闭
- **AND** 不执行任何菜单项动作

#### Scenario: 边缘定位不溢出

- **WHEN** 触发按钮位于屏幕右上角或靠近安全区域边缘
- **THEN** 菜单 SHALL 默认与触发按钮右边缘对齐
- **AND** 菜单顶部与触发圆钮底部 SHALL 保持 8pt 垂直间距
- **AND** 菜单 SHALL 自动避让屏幕边缘
- **AND** 菜单内容 SHALL 完整可见，不被屏幕裁切

#### Scenario: 减弱动态效果

- **WHEN** 系统「减弱动态效果」开启，用户展开或关闭纸感动作菜单
- **THEN** 菜单 SHALL 使用淡入淡出过渡
- **AND** 不执行缩放或位移动效

## MODIFIED Requirements

### Requirement: 统一圆形图标按钮

设计系统 SHALL 提供唯一的圆形图标按钮组件 `CircleIconButton`，作为所有 Header / 导航栏中「返回 / 更多操作 / 次级图标动作」的单一来源；视图代码 MUST NOT 在页面内本地复制等价实现（如自绘 `navCircle`、自绘 Menu 圆形 label）。

- 默认直径 SHALL 为 36pt（导航类圆钮与主操作钮 `CircleAddButton` 直径对齐）。
- 图标字号 SHALL 由组件按统一规则从直径推导，MUST NOT 在调用点硬编码图标字号；同一直径下所有圆钮的图标视觉重量一致。
- 外观为白底（`Theme.Color.surface`）+ 1pt `Theme.Color.border` 描边 + 圆形，按压走 `PressableButtonStyle`。
- SHALL 支持 `active` 高亮态（选中/展开时用 `Theme.Color.accent` 前景 + `Theme.Color.accentSoft` 底 + `Theme.Color.accentSofter` 描边）与 `rotated` 旋转态（如 `...` 展开时旋转 90°）。
- SHALL 提供动作菜单入口：以同一外观 label 触发 `PaperActionMenu`，确保「点击触发」与「弹出菜单」两类圆钮视觉完全一致；该动作菜单入口 MUST NOT 继续包装 SwiftUI `Menu`。

#### Scenario: 子页接入返回按钮

- **WHEN** 任一 push/sheet 子页需要返回按钮
- **THEN** 使用 `CircleIconButton(systemName: "chevron.left", ...)`，直径 36pt，图标字号由组件推导，外观为纸感白底圆形
- **AND** 不出现系统默认蓝色返回箭头

#### Scenario: 更多操作菜单圆钮

- **WHEN** Header 右侧需要 `...` 更多操作弹出菜单
- **THEN** 使用圆形图标按钮的动作菜单入口，其外观与点击触发版完全一致
- **AND** 菜单展开时圆钮进入 `active` + `rotated` 态
- **AND** 弹出的菜单为项目自绘 `PaperActionMenu`，不是 SwiftUI `Menu`

#### Scenario: 禁止本地复制实现

- **WHEN** 新增或修改任意页面的 Header 圆形按钮
- **THEN** 复用 `CircleIconButton` 或设计系统提供的同源动作菜单入口
- **AND** MUST NOT 在该页内重新声明等价的圆形按钮外观函数
