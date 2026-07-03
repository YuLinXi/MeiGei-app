## 1. iOS 端 - Team 历史月份范围

- [x] 1.1 调整 `TeamCheckinHistoryModels.archiveGroups` 或等价模型，支持从 Team 创建月到当前月生成完整月份范围。
- [x] 1.2 为月份档案项增加未加载语义或等价展示状态，避免未加载月份被读作“没有训练”。
- [x] 1.3 更新 `TeamCheckinHistoryView`，向月份档案传入 Team 创建月，并在选择未加载月份后切月、选中合理日期并触发按月加载。
- [x] 1.4 保持已加载空月份的 Team 空状态不变，并确保已加载有训练月份刷新真实训练天数、次数、组数和容量。
- [x] 1.5 增加或更新 Team 历史月份模型测试，覆盖当前月已加载但历史月未加载时仍展示历史月份、选择后加载、已加载空月份三类场景。

## 2. iOS 端 - 首页一周训练勾选

- [x] 2.1 在 `HomeWorkoutSnapshot` 或相邻轻量模型中增加本周 7 天完成状态，按本地周一 00:00 到下周一 00:00 从已完成训练派生。
- [x] 2.2 更新 `WorkoutHistoryStore` 快照构建逻辑，确保同日多次训练只点亮一次，但本周训练次数仍按 session 计数。
- [x] 2.3 在 `WorkoutListView` 中新增紧凑一周训练勾选组件，使用现有 Theme token，展示周一到周日、今天状态和已完成状态。
- [x] 2.4 调整首页布局，确保周勾选不挤压底部开始训练 CTA、不产生大 hero 或营销卡片观感。
- [x] 2.5 增加或更新周勾选模型测试，覆盖空周、同日多练、跨周边界和本地周一计算。

## 3. iOS 端 - 动作库右侧快速定位索引

- [x] 3.1 抽取 `LibraryQuickIndex` 或等价子视图，把动作库右侧快速定位/筛选锚点改为独立触控区。
- [x] 3.2 用 `DragGesture(minimumDistance: 0)` 根据触点 y 坐标映射索引项，支持按下后上下拖动连续切换。
- [x] 3.3 仅在索引项变化时更新筛选/定位状态、触发 haptic 和列表滚动，避免 drag tick 造成重复刷新。
- [x] 3.4 调整动作列表右侧 padding、content shape 和索引 overlay 命中区域，确保索引触控不触发动作 row tap、详情打开或 pick 选择。
- [x] 3.5 补充 accessibility label、选中状态和单项选择能力，保证 VoiceOver 可操作。
- [x] 3.6 增加或更新动作库交互测试/可测模型，覆盖拖动切换、单点点击和索引区不触发 row action。

## 4. 后端 / 基础设施确认

- [x] 4.1 确认本 change 不需要后端 schema 迁移、写接口、幂等键、APNs 或同步协议改动。
- [x] 4.2 如实施中发现 `team.createdAt` 无法覆盖真实历史月份，记录为后续只读月份摘要接口需求，不在本 change 中新增后端写能力。

## 5. 验证

- [x] 5.1 运行 OpenSpec 校验，确认 proposal/design/spec/tasks 可解析。
- [x] 5.2 运行 iOS Debug simulator build：`xcodebuild -project DontLift.xcodeproj -scheme DontLift -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build`。
- [x] 5.3 在 Simulator 或本地可执行路径手动验证 Team 历史月份 sheet 能选择历史月份并加载真实记录。
- [x] 5.4 手动验证首页周勾选在空周、有训练、同日多练和跨周后展示正确。
- [x] 5.5 手动验证动作库右侧索引拖动连续切换且不会误触进入动作详情。
