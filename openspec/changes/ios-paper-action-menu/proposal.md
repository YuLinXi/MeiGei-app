## Why

计划页与 Team 页仍在使用 SwiftUI `Menu` 呈现顶部 `+`、分组 `...`、计划详情 `...` 等动作入口，弹层视觉与当前「纸感极简」设计系统不一致，在 iOS 26 上尤其容易和系统 Liquid Glass 语义混杂。

这些入口已经成为训练计划分组和 Team 工作流的高频操作，应收敛为项目自有的统一动作菜单组件，确保视觉、动效、可访问性和关闭行为一致。

## What Changes

- 在 iOS DesignSystem 中新增统一纸感动作菜单组件，用于替代 SwiftUI `Menu` 类动作入口。
- 支持圆形 `+` 与圆形 `...` 触发按钮，并在菜单展开时进入 active/rotated 高亮态。
- 菜单项支持标题、SF Symbol 图标、普通/危险角色、禁用态与回调动作。
- 弹层使用项目纸感 token：`surface` 白底、`border` 描边、`Radius.lg` 圆角、`paperShadow` 阴影、`PressableButtonStyle` 按压反馈。
- 替换现有系统 `Menu` 用点：计划列表顶部 `+`、计划分组 `...`、计划详情 `...`、Team 列表顶部 `+`，并移除 `CircleIconMenu` 对 SwiftUI `Menu` 的依赖。
- 保留现有确认弹窗 `paperConfirmDialog` 与错误 `.alert` 行为；本 change 不处理错误提示弹窗改造。

## Non-goals

- 不重做 `paperConfirmDialog`、删除确认、训练冲突确认等二次确认弹窗。
- 不替换 `.alert("出错了")` 这类错误提示；错误提示可后续单独设计 `paperErrorDialog` 或 toast。
- 不改动计划分组、Team、同步、数据库或后端 API 行为。
- 不引入第三方弹窗库，不依赖系统 Liquid Glass / blur 作为主要视觉。
- 不把 Team 详情页现有自绘底部 action sheet 强行合并进本次范围，除非实现时发现可低风险复用。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `design-system`: 增加统一纸感动作菜单要求，并禁止本 change 覆盖范围内继续使用 SwiftUI `Menu` 呈现动作菜单。

## Impact

- iOS：新增或扩展 `DesignSystem/Components.swift` 中的动作菜单组件；调整 `Workout/PlanViews.swift`、`Team/TeamViews.swift` 的菜单入口。
- UI/UX：动作菜单视觉从系统弹层切换为项目纸感浮层，交互需覆盖点外关闭、边缘定位、禁用态、危险动作和 Reduce Motion。
- 测试：需要 iOS 编译验证，并手动检查计划页/计划详情/Team 页各菜单入口在普通和边缘位置下不遮挡、不溢出。
