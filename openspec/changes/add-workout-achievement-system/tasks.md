## 1. 领域模型与勋章规则定义（iOS 端）

- [x] 1.1 创建 `BadgeDefinition.swift`：定义 24 枚硬核独立成就勋章静态枚举、板块分类（三大项俱乐部、累计吨位、纪律历程、单次极限）、达成硬核门槛与图腾标识，验证代码无编译错误。
- [x] 1.2 创建 `BadgeGrant.swift` SwiftData 实体并在 `AppModelContainer.make()` 中完成 Schema 注册，编写单元测试验证实体可正常读写与持久化。

## 2. 判定与回溯引擎（iOS 端）

- [x] 2.1 实现 `BadgeEngine.swift`：实现纯函数式三大项绑定识别（`BB_SQUAT`、`BB_BENCH_PRESS`、`DEADLIFT / SUMO_DEADLIFT` 取高）、体重倍数计算及累计吨位判定，验证规则精准命中。
- [x] 2.2 实现老用户存量异步回溯流水线（Backfill）：在后台 Task 异步按时间正序扫描历史已完成训练生成存根表，并由 UserDefaults 记录完成态，验证回溯幂等性。
- [x] 2.3 编写 `BadgeEngineTests.swift` 自动化单元测试：覆盖 24 枚徽章判定边界条件（未录入体重防护、非标准深蹲动作排除、三大项俱乐部跨越、单场 3 PR 等），验证测试全部通过。

## 3. 弹窗庆祝与生涯回顾交互（iOS 端）

- [x] 3.1 实现「生涯成就回顾」汇总弹窗组件（`CareerBadgeReviewSheet.swift`），并在 `MainTabView` 中接入首启门控逻辑（无活跃训练时弹出一次并支持收入徽章馆），验证老用户升级首启弹窗体验。
- [x] 3.2 实现「训练结算庆祝」高光弹窗（`WorkoutBadgeCelebrationSheet.swift`），并在 `WorkoutLoggingView.finishWorkout()` 流程中挂接增量命中触发与震动触感反馈，验证单场突破即时庆祝。

## 4. 个人中心与徽章馆展示（iOS 端）

- [x] 4.1 在 `ProfileView.swift` 的总训练卡下方新增「成就徽章」概览入口卡片，动态展示已解锁数（如 `8 / 24`）与最近解锁的微缩勋章图腾，验证卡片视觉与排版。
- [x] 4.2 实现二级全屏「成就徽章馆」（`BadgeWallView.swift`）：采用 3 列网格布局，已解锁态支持点击弹窗反查当日训练，未解锁态展示暗钛质感与达成实时进度条，验证导航与反查跳转顺畅。

## 5. 视觉资产与整体验收（iOS 端）

- [x] 5.1 接入 24 枚勋章矢量/位图图腾资产与金属反光、朱砂红高光材质规范，验证已解锁与未解锁状态渲染对比鲜明。
- [x] 5.2 运行完整工程构建验证（`xcodebuild build`）并执行自动化测试套件，确认无构建警告与回归缺陷。
