## 1. 数据模型（iOS 端）

- [x] 1.1 新增 `MuscleRegion` 枚举（16 区，`String` rawValue=资产名，附 `displayName` 中文）；放 `Models/MuscleRegion.swift`
- [x] 1.2 `BuiltinExercise` 增加 `primaryRegions: [MuscleRegion]` / `secondaryRegions: [MuscleRegion]` / `formCues: [String]`，默认空，确保编译通过且既有 `primaryMuscle`/`historyKey`/筛选不受影响
- [x] 1.3 写单测：`MuscleRegion.allCases.count == 16`、rawValue 无重复且仅 ASCII 字母、每个 case 有 displayName、新字段默认空（`MuscleRegionTests.swift`）

## 2. 内置动作数据回填（iOS 端，体力活）

- [x] 2.1 回填全部 153 条动作的 `primaryRegions`/`secondaryRegions`（`BuiltinExercise+Regions.swift`，`starter` 自 `regionData` enrich）
- [x] 2.2 每条动作 3 条原创 `formCues`（≤22 字短句，自写规避版权）
- [x] 2.3 校验：单测 `everyBuiltinEnrichedWithRegionsAndCues`（全员主动肌非空 + ≥3 要点）、`benchPressEnrichedCorrectly` 均通过

## 3. 用户性别字段（iOS 端，纯本地）

> 实现时核实：profile 无同步域（同步仅 custom-exercises/workout-plans/workouts），`UserProfile` 为本地缓存、后端无 profile 写接口。故 `sex` 定为**纯本地字段**，原后端任务 3.3 取消（见 design.md D6）。

- [x] 3.1 iOS：`BodySex` 枚举 + `UserProfile.sex` 本地字段（默认 `male`，SwiftData 默认值轻量迁移安全）
- [x] 3.2 iOS：ProfileView 加「偏好 · 性别」男/女切换 pill，切换即写本地 `profile.sex` + `save`
- [x] ~~3.3 后端 Flyway~~ —— **取消**：profile 不同步，无需后端列/接口
- [x] 3.4 验证：性别字段落地、高亮图按 sex 选底图（模拟器核对）

## 4. 高亮图资产（基础设施 / 设计）—— 改为可选

> 实现时 5.1 选了**纯 SwiftUI Path** 渲染（坐标取自设计稿，矢量/可染色/零资产依赖），PDF imageset 方案因此**变为可选升级**，非 MVP 必需（见 design.md D3 更新）。下列任务仅在将来想换更精的写实资产时再做。

- [ ] 4.1（可选）在 OD 精修人体后导每区 PDF imageset（名=rawValue）
- [ ] 4.2（可选）资产入 asset catalog + `MuscleMapView` 渲染层切到 Image
- [x] 4.3 MIT 出处：以 `react-native-body-highlighter` 为比例参考自绘重画（非复制 path），出处已记于 design/proposal；正式发版前补 LICENSE 文件

## 5. 高亮图组件（iOS 端）

- [x] 5.1 `MuscleMapView(primary:secondary:sex:side:)`：纯 SwiftUI Path（SVGPathShape 解析 + 左半镜像），三态 `accent`/`accentSofter`/idle
- [x] 5.2 正/背切换（`side` 参数）+ 默认面取「亮区更多」一侧（`resolvedSide`）；各面只渲染本面区数据
- [x] 5.3 缺数据降级：`primary` 为空 → `EmptyView`，不渲染占位
- [x] 5.4 `#Preview`（DEBUG，卧推男正 / 引体女背）作自检入口

## 6. 验收

- [x] 6.1 `xcodebuild build` + 测试 target 编译通过；既有筛选/historyKey/PR 不回归（动作库逻辑未动）
- [x] 6.2 单测覆盖 spec 数据类场景（16 区契约、回填覆盖、卧推染色映射）；`MuscleRegionTests` 7 例全过
- [x] 6.3 模拟器目检通过（详情页高亮图正常渲染）
