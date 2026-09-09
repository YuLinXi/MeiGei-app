## 1. iOS 端 — 共用行组件

- [x] 1.1 在 `MuscleLoadReviewView.swift` 的 `MuscleLoadRowView` 中，于组数文本之后同排追加容量文本（复用 `formatMuscleLoadVolume(entry.volumeKg)`，弱化色 `.medium` 字重），组数保持主数字；调整行内宽度预算（组数/容量合并区域），确保「12 组 · 8.6 t」在首页小卡（无变化胶囊/趋势柱）与复盘页（有胶囊+趋势柱）两种形态下都不截断。验证：`xcodebuild -project DontLift.xcodeproj -scheme DontLift -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build` 编译通过
- [x] 1.2 更新 `MuscleLoadRowView` 头部注释（现写「肌群名 + 负荷条 + 组数 + …」）补容量；行组件的 accessibilityLabel 与复盘页行按钮的 `accessibilityLabel`（`MuscleLoadReviewView.swift` 中「\(name)，\(entry.workingSets) 组」）追加容量朗读。验证：编译通过，且 VoiceOver 朗读包含容量

## 2. iOS 端 — 验证

- [x] 2.1 跑全套 `xcodebuild test`（不用 `-only-testing:DontLiftTests` 单跑，已知会挂起）确认 269+ 用例全绿、聚合层无回归。验证：测试全绿
- [x] 2.2 模拟器目检：首页肌群负荷小卡 Top3 行显示「N 组 · 容量」；点进复盘页，八肌群行同样显示；展开贡献明细仍正常；切到「上周」容量随数据切换。验证：模拟器截图确认两处行内均有容量，且为 0 的肌群行显示「0 组 · 0 kg」不崩版
## 3. iOS 端 — 复盘页对比口径调整（评审反馈）

- [x] 3.1 `MuscleLoadRowView` 移除变化胶囊（`baselineSets` 参数、`delta`、`deltaPill`），首页小卡与复盘页调用点同步去掉该参数；「其他」桶行不再出现「持平」文字。验证：编译通过，模拟器复盘页行内只剩 名称/负荷条/组数·容量/趋势柱
- [x] 3.2 复盘页头部总览改为「共 N 有效组 · 总容量」（总容量为看板全部桶 volumeKg 之和，与总组数同范围）；对比文案扩展为组数 + 容量双分量（八肌群口径，与既有 totalDelta 同范围），某分量为 0 时省略该分量文字，两个分量均为 0 时整条对比文案（含圆点）隐藏。验证：编译通过；模拟器种子数据下头部显示「共 126 有效组 · 总量 t」与「较上周同期多 43 组 · 多 xx t」
- [x] 3.3 `MuscleLoadAggregator` 新增 `volumeKg(of:in:)` 取值入口（与 `sets(of:in:)` 同构）；展开的贡献明细面板顶部新增该肌群较同期的组数变化与容量变化行（分量持平省略、均持平隐藏，「其他」桶不展示）。验证：编译通过；展开背行可见「较上周同期多 11 组 · 多 6.2 t」样式文案
- [x] 3.4 重跑全套 `xcodebuild test` 确认全绿无回归。验证：测试全绿
- [x] 3.5 模拟器截图复核四点反馈：行内无对比增量、头部带总容量、对比文案带容量、展开面板含组数与容量对比。验证：截图确认
- [x] 3.6 对比基线口径调整（二次反馈）：`MuscleLoadAggregator.snapshot` 的 `baseline` 从上周同期截断改为上周整周（与 `previousBoard` 同区间一次聚合两用）；移除 `previousBaseline` 与 `sameOffsetPreviousWeekRange` 死代码；上周视图头部与展开面板不再展示对比；对比文案前缀「较上周」。更新 `MuscleLoadAggregatorTests`（删除两个 sameOffset 区间测试，`snapshotBuildsBoardBaselineSeriesAndContributions` 基线期望 2→5）。验证：编译通过 + 全套测试全绿
- [x] 3.7 模拟器截图复核新口径：本周头部「较上周少 N 组 · 多 X t」可与上周页签数字直接对账；上周视图无任何对比文案。验证：截图确认
- [x] 3.8 首页小卡 footer 调整（三次反馈）：去掉「全部 →」文案，摘要改为「共 N 组 · 总容量」（含「其他」桶，与复盘页头部同口径）；卡片 accessibilityLabel 同步带容量。验证：编译通过 + 模拟器首页截图确认

## 4. iOS 端 — 真机回归

- [x] 4.1 真机目检：行内布局在长文本（如「12.3 t」）下不挤压趋势柱；头部与对比文案排版正常；趋势柱仍按组数口径。验证：真机目检通过（用户在真机反馈轮次中目检确认，截图覆盖 814 kg / 24.1 t 等长短容量文本与双页签排版）
