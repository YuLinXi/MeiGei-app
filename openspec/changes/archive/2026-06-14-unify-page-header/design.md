## Context

iOS 端 Header 现状（已逐文件核实）：

- **范式 A — Tab 根页**（训练 / 计划 / 动作 / Team）：隐藏系统导航栏，自绘大标题 `display(36, heavy)` + tracking `-1.08`，右上挂 `CircleAddButton`/`CircleAddLabel`（36pt）。自洽，本次保留。「我的」(Profile) 例外，落在范式 B。
- **范式 B — 子页**，三种实现并存：
  - B1：系统 inline + 自绘圆钮 `CircleIconButton(size: 32)` + 逐 `ToolbarItem` 打 `sharedBackgroundVisibility(.hidden)`（`WorkoutDetailView`、`PlanDetailView`）。
  - B2：纯自绘 `navBar` HStack + 本地 `navCircle(32×32, icon 15)`（`TeamDetailView`）——重复造轮子，且带 `CircleIconButton` 没有的 active/rotated 态。
  - B3：纯系统导航 + 系统蓝色返回箭头（`ProfileView`、`ExerciseDetailView`、`TeamPlansView`）。

不一致根因：`DesignSystem.CircleIconButton` 默认值（直径 38、图标 `size×0.4`）从无人采用，事实标准是 32 + 自定义图标重量；DS 未提供 active/rotated/Menu 变体，于是 `TeamDetailView.navCircle`、`PlanDetailView.menuButton` 各自复制。

约束：纯视图层改动，不涉及后端 / 数据模型 / 网络契约（Day-1 数据铁律在此不适用）；最低 iOS 17.4，需兼容 iOS 26 的 Liquid Glass 工具栏背景；以 `xcodebuild` 编译 + 真机目测验证。

## Goals / Non-Goals

**Goals:**
- 圆形图标钮收敛为 `CircleIconButton` 单一组件，含 active/rotated/Menu 变体，删除 `navCircle`、`menuButton` 两处复制。
- 圆钮直径统一 36pt；图标字号由组件按统一规则推导，不在调用点硬编码。
- 子页 Header 经单一容器 `.paperToolbar()` 接入：一处封装隐藏系统返回、iOS 26 双环处理、左/中/右三槽位、统一标题字体。
- B3 三页改纸感圆形返回钮，消灭系统蓝色箭头。

**Non-Goals:**
- 不改 Tab 根页大标题范式与 Tab Bar 外观。
- 不抽通用「页面脚手架」（内容滚动 / 底栏 / safeArea 不在本次封装）。
- 不改 Header 触发的任何业务逻辑（菜单项、删除确认弹窗等照旧）。

## Decisions

### 决策 1：圆钮统一 36pt，图标字号按比例推导

`CircleIconButton` 默认 `size` 由 38 改为 36；图标字号从 `size × 0.4`（36→14.4）改为 `size × 0.42`（36→≈15），与既有 `navCircle` 实测的 15pt/semibold 视觉重量对齐，避免放大直径后图标显小。所有调用点删除显式 `size: 32` 覆写，走默认 36。

- 备选：保留 32 仅统一实现。否决——32 离 HIG 44pt 最小触达更远，且用户已拍板 36。
- 备选：图标用固定常量 15。否决——组件支持任意直径时按比例更稳健；36 这一标准直径下二者结果一致（≈15）。

### 决策 2：`CircleIconButton` 扩展 active / rotated + Menu 变体

在现有组件上追加可选参数，吸收 `navCircle`/`menuButton` 的能力：

```
struct CircleIconButton {
    let systemName: String
    var size: CGFloat = 36
    var active: Bool = false        // 高亮：accent 前景 + accentSoft 底 + accentSofter 描边
    var rotated: Bool = false       // ⋯ 展开旋转 90°
    let action: () -> Void
}
// 共享外观抽成 private 的 CircleIconLabel(systemName:size:active:rotated:)，
// 供 Button 版与 Menu 版复用，确保两类入口像素一致。
struct CircleIconMenu<Content: View> {   // Menu 版
    let systemName: String
    var size/active/rotated ...
    @ViewBuilder var menu: () -> Content
}
```

- active 态配色复用 `Theme.Color.accent/accentSoft/accentSofter`（与 `navCircle` 一致），非 active 走 surface + border。
- 备选：保留 `navCircle`/`menuButton` 不动只改尺寸。否决——重复实现正是本次要消灭的根因。

### 决策 3：子页 Header 用 `.paperToolbar()` 修饰符，而非全自绘 navBar

选「修饰符封装系统 `.toolbar`」而非「TeamDetail 式全自绘 HStack」：

```
extension View {
    func paperToolbar<Trailing: View>(
        title: String,
        onBack: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) -> some View
}
```

内部职责：`navigationBarTitleDisplayMode(.inline)` + `navigationBarBackButtonHidden(true)`；`ToolbarItem(.topBarLeading)` 放返回 `CircleIconButton`；`ToolbarItem(.principal)` 放统一字体标题；`ToolbarItem(.topBarTrailing)` 放 `trailing`（页面传 `CircleIconButton` 或其 Menu 版）；iOS 26 分支统一施加 `sharedBackgroundVisibility(.hidden)`，把当前散落在各页的 `if #available` 补丁收口到这一处。

- 选系统 toolbar 而非全自绘：保留系统对 safeArea / 状态栏 / 大标题协作的处理，少踩布局坑；`TeamDetailView` 由全自绘 navBar 改接此修饰符。
- 备选：全自绘 navBar 统一。否决——丢失系统 inset 处理，且每页仍要自管布局。

### 决策 4：子页标题统一字体 token = `Theme.Font.l2`（16pt / semibold）

取代现状的「系统 inline / `body(15,heavy)` / `display(30)`」三套。选 `l2`（语义即「卡片标题/按钮文字 16 semibold」）以复用既有 token、避免新增；视觉接近平台 inline 习惯又带纸感字重。

- 备选：新增 `navTitle = display(17, semibold)` 贴近系统 17pt。备选保留为 Open Question，若 16 在真机偏小再升 17。

## Risks / Trade-offs

- **iOS 26 `sharedBackgroundVisibility` 收口** → 集中到 `.paperToolbar` 一处的 `if #available` 分支，低版本走等价无背景路径；改动后逐页在 iOS 26 模拟器/真机确认无双环。
- **直径 32→36 撑高 Header / 影响紧凑布局**（如 `TeamDetailView` `frame(height: 46)` 的 navBar）→ 改接 `.paperToolbar` 后由系统 toolbar 决定高度，目测各页钮与标题垂直居中、无截断。
- **`TeamDetailView` 失去自绘 navBar 的细节**（如 active 态 `accentSoft` 背景、paperShadow）→ active/rotated 已并入 `CircleIconButton`；`paperShadow` 若必要可作为组件可选项，否则按「纸感圆钮默认无阴影」简化（与 Workout/Plan 详情现状一致）。
- **范式 A 不动导致根页与子页两套 Header 并存** → 这是有意分层（一级大标题 vs 二级 inline），spec 已显式豁免 Tab 根页，不视为不一致。

## Open Questions

1. 子页标题字体取 `l2`(16) 还是新增 `navTitle`(17)？默认 `l2`，真机偏小再升。
2. 纸感圆钮是否统一带 `paperShadow(.sm)`？现 Workout/Plan 详情无阴影、TeamDetail 有。倾向「默认无阴影」求一致，最终以真机目测定。
