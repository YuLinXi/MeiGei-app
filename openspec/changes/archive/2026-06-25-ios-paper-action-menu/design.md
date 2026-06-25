## Context

当前 iOS 设计系统已经有 `CircleIconButton`、`CircleAddButton`、`.paperToolbar()`、`paperConfirmDialog` 和 `PressableButtonStyle` 等纸感组件，但动作菜单仍有两条路径：

- `CircleIconMenu` 与页面局部 `Menu` 继续使用 SwiftUI 系统弹层。
- `TeamDetailView` 有一套页面内自绘底部 action sheet，但只服务 Team 退出/解散场景。

这导致计划页顶部 `+`、分组 `...`、计划详情 `...`、Team 顶部 `+` 在视觉和动效上脱离项目现有 token，截图中的系统浮层也不符合当前纸感 UI。该变更只影响 iOS 端展示与交互，不新增服务端 API、不修改 SwiftData 模型、不涉及同步对象；Day-1 数据铁律在本设计中不适用，但实现不得引入新的写接口、身份字段或同步状态。

## Goals / Non-Goals

**Goals:**

- 提供一个可复用的纸感动作菜单组件，作为 SwiftUI `Menu` 的项目内替代。
- 统一圆形 `+` 与 `...` 触发入口的展开态、关闭行为、菜单行样式、危险动作语义和可访问性。
- 替换本 change 覆盖范围内的系统 `Menu` 用点，使计划页和 Team 页菜单视觉一致。
- 保持现有 `paperConfirmDialog` 删除确认链路不变：动作菜单只负责选择动作，不负责二次确认。

**Non-Goals:**

- 不重做错误 `.alert`、`paperConfirmDialog` 或训练冲突弹窗。
- 不改计划分组、Team、训练同步、后端或数据库行为。
- 不引入第三方弹层库。
- 不把所有底部 sheet 都抽象为同一个组件；Team 详情现有底部 action sheet 可后续单独收敛。

## Decisions

### 1. 使用自绘 `PaperActionMenu`，不再包装 SwiftUI `Menu`

`PaperActionMenu` 通过触发按钮记录 anchor frame，并在当前页面上覆盖透明 scrim + 菜单卡片。菜单项使用普通 SwiftUI `Button` 渲染，因此视觉、动画和行内布局完全受项目 DesignSystem 控制。

替代方案：

- 继续使用 SwiftUI `Menu`：实现成本低，但无法可靠控制系统浮层样式，正是本次要解决的问题。
- 使用 `.confirmationDialog`：适合底部动作表，不适合顶部小菜单，也仍是系统样式。
- 所有菜单改底部 sheet：手指可达性好，但顶部 `+` / `...` 的轻量动作会变重，和截图问题不匹配。

### 2. 以数据模型描述菜单项，而不是每页手写 VStack

组件提供类似以下语义模型：

```swift
struct PaperMenuItem: Identifiable {
    enum Role { case normal, destructive }
    let id: String
    let title: String
    let systemImage: String
    var role: Role = .normal
    var isEnabled: Bool = true
    let action: () -> Void
}
```

页面只声明菜单项和触发 label，具体行高、图标尺寸、颜色、分隔线、关闭动画由组件统一处理。这样计划页分组菜单、计划详情菜单、Team 顶部菜单都不会散写一套相似 UI。

### 3. 菜单定位采用锚定浮层，自动避让屏幕边缘

菜单默认与触发按钮右边缘对齐，出现在按钮下方，卡片顶部与触发圆钮底部保持 8pt 垂直间距；当下方空间不足时可向上弹出；当靠近左右边缘时 clamp 到安全区域内。根页顶部 `+` 与子页导航栏 `...` 都属于右上角高频场景，右对齐更稳定。

基本结构：

```text
ZStack
├─ 页面内容
└─ if isPresented
   ├─ scrim: Color.clear/fg.opacity(0.001)，点击关闭
   └─ PaperMenuCard(anchor: triggerFrame, gap: 8pt)
      ├─ item row
      ├─ divider
      └─ item row
```

scrim 不需要变暗；这是轻量动作菜单，不是阻断式确认弹窗。必要时可使用极低透明度保证可点击命中，但视觉上保持页面不被遮罩压暗。

### 4. 视觉 token 走现有纸感体系

菜单卡片使用：

- 背景：`Theme.Color.surface`
- 描边：`Theme.Color.border`
- 圆角：`Theme.Radius.lg`
- 阴影：`paperShadow(.md)` 或等价柔和阴影
- 行高：约 52pt，水平 padding 14-16pt
- 图标：18pt，普通使用 `Theme.Color.accent` 或 `fg2`，危险动作使用 `Theme.Color.danger` 或现有危险色 token
- 文字：`Theme.Font.l2`，单行，必要时 `minimumScaleFactor`

菜单展开时，触发按钮应进入 active 态；`...` 按钮可沿用 rotated 90° 的反馈。动画使用淡入 + 轻微位移/缩放；开启 Reduce Motion 时只淡入淡出。

### 5. 替换边界明确

本次替换范围：

- `PlanListView` 顶部 `+` 菜单。
- `PlanListView` 分组 header `...` 菜单。
- `PlanDetailView` 工具栏 `...` 菜单。
- `TeamListView` 顶部 `+` 菜单。
- `CircleIconMenu` 不再直接包装 SwiftUI `Menu`；可废弃或重定向到新组件。

保留范围：

- `.alert("出错了")` 错误提示。
- `paperConfirmDialog` 二次确认。
- Team 详情现有底部退出/解散 action sheet。

### 6. 可访问性和关闭语义必须集中处理

组件负责：

- 点菜单外区域关闭。
- 执行动作后先关闭菜单，再运行 action，避免 action 触发 sheet/navigation 时残留浮层。
- 禁用项不可点击且视觉降级。
- 菜单项保留清晰的 VoiceOver label；危险动作通过 role 或文案体现。
- Reduce Motion 开启时关闭缩放/位移动效。

## Risks / Trade-offs

- [Risk] 自绘菜单失去系统 `Menu` 的免费定位与可访问性细节 → 组件集中处理 safe-area clamp、点外关闭、禁用态和 VoiceOver label，并做手动验证。
- [Risk] 菜单叠在 `NavigationStack` / toolbar 上时层级不够 → 菜单 overlay 应挂在页面主体 ZStack 或通过修饰符包裹页面内容，必要时使用 `zIndex`。
- [Risk] 点击菜单项后同时触发关闭动画和 navigation/sheet，出现状态竞争 → 统一封装 `select(item:)`，先设置 `isPresented=false`，下一轮主队列或动画完成后执行 action。
- [Risk] 设计系统主规格仍有历史 Neon 文案 → 本 change 只新增/修改动作菜单相关要求，不扩大到全量规格清理。
