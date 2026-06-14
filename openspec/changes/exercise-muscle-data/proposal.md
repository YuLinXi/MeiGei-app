## Why

内置动作当前只有粗粒度 `primaryMuscle`（胸/背/肩/手臂/腿/臀/核心/全身 8 类），动作详情页的部位高亮图自 MVP 起一直是「斜纹·采集中」占位，要点与协同肌也是空占位。「严肃健身工具」的动作百科缺了最该有的两块：**练到哪些肌肉**（可视化）与**怎么做对**（要点）。本 change 补齐细分肌群数据，并以一套**自绘矢量人体高亮图**（男女各正背）落地可视化——存储与动作数量无关，无版权风险。

## What Changes

- 新增 `MuscleRegion` 16 区枚举（`traps` / `deltFront` / `deltRear` / `chest` / `biceps` / `triceps` / `forearms` / `abs` / `obliques` / `lats` / `lowerBack` / `glutes` / `quads` / `hams` / `calves`），rawValue 即高亮图 SVG/PDF 图层名，男女共用。
- `BuiltinExercise` 增加三个字段：`primaryRegions: [MuscleRegion]`、`secondaryRegions: [MuscleRegion]`、`formCues: [String]`（动作要点 3–5 条）。150 个内置动作按肌群批量回填——均为客观事实，无营养/版权敏感数据。
- 用户 profile 新增 `sex` 字段（`male` / `female`，默认 `male`/可在设置切换）。**性别只切换高亮图底图轮廓**（♀肩窄/腰收/髋宽/长发）；染色逻辑、动作 region 数组、16 区划分两性完全共用。
- 新增**肌群高亮图组件**：男女各正/背共 4 张矢量底图（扁平极简纸感，以 MIT `react-native-body-highlighter` 为比例参考自绘重画），按 `primaryRegions`/`secondaryRegions` 三态染色（`Theme.Color.accent` / `accentSofter` / idle），支持正/背切换、默认面取亮区更多的一侧。
- `primaryMuscle`（粗 8 类）**保留**，继续做动作库筛选 chip 与 `historyKey` 归并。新字段为纯加法。

## Capabilities

### New Capabilities
- `exercise-muscle-map`: 细分肌群数据模型（`MuscleRegion` 16 区、动作的 primary/secondary regions、动作要点）、用户性别字段、男女正背肌群高亮图的渲染与三态染色行为。

### Modified Capabilities
<!-- 无：动作详情页五段重构留给后续 exercise-detail-redesign change；本 change 只产出数据与可复用高亮图组件，不改 workout-tracking 既有行为规约。 -->

## Impact

- **iOS 模型层**：`Models/BuiltinExercise.swift`（加枚举与字段 + 150 条数据回填）；新增 `MuscleRegion` 类型；profile 模型加 `sex` 字段（本地 + 同步信封，遵守 Day-1 字段铁律）。
- **iOS 视图层**：新增 `MuscleMapView` 可复用组件（asset catalog 内 PDF imageset，名=rawValue，ZStack 叠放染色）；不在本 change 接入详情页。
- **资产**：男女正背 4 套人体 + 16 区，从 Open Design `MeiGeiApp2` 的 `meigei-c-muscle-map.html` 精修后导「Preserve Vector Data」PDF；附 `react-native-body-highlighter` 的 MIT 许可证声明。
- **同步契约**：`BuiltinExercise` 为随包只读数据，不入同步域；profile `sex` 走既有 profile 同步路径，纯字段加法，不动 LWW 与幂等键约定。
- **非影响**：不改 `WorkoutPlan` / `Workout` 同步聚合，不动 `primaryMuscle` 既有筛选与 historyKey 逻辑。

## Non-goals

- **不做**动作详情页五段重构（高亮图接入、「你的数据」段、去掉底部 CTA、要点/目标肌群联动）——留给后续 `exercise-detail-redesign` change。
- **不做**自定义动作（`CustomExercise`）的 region 录入——自定义动作无细分数据时隐藏高亮图。
- **不做**写实解剖插画、动图/视频演示、第三方解剖图直接引用。
- **不做**多套体型（仅 male/female 二元底图；不含体脂/肌肉量分级形态）。
- **不做**后端动作库下发——内置动作继续随包发布。
