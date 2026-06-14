## Why

`exercise-muscle-data` 的 `MuscleMapView` 当前用我**手绘简化**的扁平人体（约 12 区块面，「积木人」观感）。真机验收后确认：保真度明显不如开源 `react-native-body-highlighter`（MIT）的**详细解剖底图**（每面 70–92 段 path）。本 change 把高亮图的**美术底图**整体升级为该开源数据的渲染，三态染色/性别切换/缺数据隐藏等行为契约不变。

## What Changes

- `MuscleMapView` 渲染数据从「手绘简化 path」替换为**开源详细解剖 path**（已抽取生成 `MuscleBodyArt.swift`，男女各正/背 4 面、各自 viewBox）。
- 新增**完整 SVG path 解析器**：支持 `M/m L/l H/h C/c Q/q A/a Z/z`（绝对/相对、隐式重复指令、椭圆弧 A→三次贝塞尔近似）；原解析器仅 `M/L/Q/Z` 不足以渲染开源数据。
- 新增 **slug → `MuscleRegion` 映射**：按开源肌肉 slug（chest/deltoids/trapezius/quadriceps…）着三态色，未映射部位（neck/hands/head/hair/knees…）作 idle 静默底。
- **BREAKING（实现路线）**：高亮图从「自绘、零资产」改为「**直接使用开源 MIT path（衍生作品）**」——须随包附 `react-native-body-highlighter` 的 LICENSE 与版权声明。
- 手绘简化版 `BodyArt` 数据移除；`MuscleMapView` 对外 API（`primary/secondary/sex/side`）**不变**，详情页无需改动。

## Capabilities

### New Capabilities
<!-- 无 -->

### Modified Capabilities
- `exercise-muscle-map`: 高亮图底图保真度与素材许可的行为约束（解剖详细矢量底图、MIT 衍生须附许可）。渲染三态/性别/缺数据隐藏等既有行为不变。

## Impact

- **iOS**：重写 `Workout/MuscleMapView.swift`（SVG 解析器升级 + Canvas 渲染 + slug 映射）；新增生成数据 `Models/MuscleBodyArt.swift`；移除内联手绘 `BodyArt`。
- **许可**：新增 `react-native-body-highlighter` MIT LICENSE 文件随包；design/proposal 注明出处。
- **非影响**：`MuscleRegion` 枚举、动作 `primaryRegions/secondaryRegions` 数据、`UserProfile.sex`、`ExerciseDetailView` 接入、三态色 token 均不变。

## Non-goals

- **不做**对开源 path 的二次美术精修（发型/比例微调）——本期忠实渲染原图，restyle 仅限配色（纸感三态）。
- **不做**第三套体型 / 体脂分级。
- **不做** PDF imageset 路线（保持纯代码矢量渲染）。
- **不做** `MuscleMapView` 对外 API 变更。
