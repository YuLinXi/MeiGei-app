## 1. DesignSystem 组件收敛（iOS 端）

- [x] 1.1 改 `DesignSystem/Components.swift`：`CircleIconButton` 默认 `size` 38→36，图标字号由 `size×0.4` 改为 `size×0.42`（36→≈15, semibold）
- [x] 1.2 抽 private `CircleIconLabel(systemName:size:active:rotated:)` 承载圆钮外观；`CircleIconButton` 改为复用它
- [x] 1.3 给 `CircleIconButton` 增 `active`/`rotated` 可选参数：active 走 `accent`/`accentSoft`/`accentSofter`，非 active 走 `surface`+`border`；rotated 旋转 90°
- [x] 1.4 新增 Menu 版 `CircleIconMenu<Content>`（同一 `CircleIconLabel` + SwiftUI `Menu`），确保与 Button 版像素一致
- [x] 1.5 新增 `extension View { func paperToolbar(title:onBack:trailing:) }`：封装 inline 标题 + `navigationBarBackButtonHidden(true)` + 三槽位 + iOS 26 `sharedBackgroundVisibility(.hidden)` 统一分支；标题用 `Theme.Font.l2`

## 2. 子页接入统一容器（iOS 端）

- [x] 2.1 `Workout/WorkoutDetailView.swift`：删自绘 `.toolbar` + 逐项 `sharedBackgroundVisibility`，改用 `.paperToolbar`（返回 + ⋯ 删除）
- [x] 2.2 `Workout/PlanViews.swift`（PlanDetailView + PlanEditorView）：改用 `.paperToolbar`，PlanDetail 右侧 ⋯ 用 `CircleIconMenu` 取代本地 `menuButton` 并删除；PlanEditor 保存键作为 trailing 传入
- [x] 2.3 `Team/TeamViews.swift`（TeamDetailView）：删自绘 `navBar` 与本地 `navCircle`，改用 `.paperToolbar`（返回 + ⋯ active/rotated 切换 actionSheet）
- [x] 2.4 `Profile/ProfileView.swift`：**修正**——Profile 是 Tab 根页（无返回箭头），归入范式 A 自绘大标题「我的」`display(36, heavy)` + 隐藏系统导航栏（非 paperToolbar）
- [x] 2.5 `Workout/ExerciseViews.swift`（ExerciseDetailView）：系统返回改 `.paperToolbar` 纸感圆形返回钮（标题留空，动作名在内容区）
- [x] 2.6 `Team/TeamViews.swift`（TeamPlansView）：系统返回改 `.paperToolbar` 纸感圆形返回钮，补 `@Environment(\.dismiss)`
- [x] 2.7 全局检索剩余 `CircleIconButton(... size: 32)` 调用点，删除显式 size 覆写归默认 36（已确认无残留）

## 3. 验证（iOS 端）

- [x] 3.1 `xcodebuild`（iPhone 17 Pro 模拟器, CODE_SIGNING_ALLOWED=NO）编译通过——**BUILD SUCCEEDED**，SourceKit 报错确认为索引竞态噪声
- [x] 3.2 各子页（Workout/Plan/Team Detail、ExerciseDetail、TeamPlans）目测：返回/⋯ 圆钮 36pt、标题字体一致、无系统蓝箭头 —— 真机/模拟器目测通过
- [x] 3.3 iOS 26 模拟器逐页确认 Header 圆钮无 Liquid Glass「双环」 —— 真机/模拟器目测通过
- [x] 3.4 Tab 根页大标题范式（含「我的」归入范式 A）回归无变化；Team ⋯ 菜单展开 active/rotated 态正常 —— 真机/模拟器目测通过

## 4. 收尾

- [x] 4.1 更新 `DesignSystem/README.md` 记录 `CircleIconButton`(36 + active/rotated/Menu)、`CircleIconMenu` 与 `paperToolbar` 用法
- [x] 4.2 自检：确认仓库内不再存在 `navCircle` / `menuButton` 等重复圆钮实现（grep 确认仅剩注释引用）
