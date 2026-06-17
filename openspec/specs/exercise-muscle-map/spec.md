## Purpose

定义 DontLift 细分肌群数据模型与肌群高亮图可视化的行为规约：`MuscleRegion` 16 区枚举、内置动作的主动肌/协同肌/动作要点、用户本地性别字段，以及男女正背人体高亮图的渲染与三态染色规则。本能力只产出数据与可复用高亮图组件，不改动动作详情页既有交互与同步契约。

## Requirements

### Requirement: 细分肌群区域模型

系统 SHALL 定义 `MuscleRegion` 枚举，恰好包含 16 个区：`traps`、`deltFront`、`deltRear`、`chest`、`biceps`、`triceps`、`forearms`、`abs`、`obliques`、`lats`、`lowerBack`、`glutes`、`quads`、`hams`、`calves`。每个 case 的 rawValue MUST 与高亮图资产的图层/imageset 命名逐字一致，并附带中文显示名。该枚举 MUST 男女共用，与用户性别无关。

#### Scenario: 枚举与资产命名一致
- **WHEN** 渲染层按某个 `MuscleRegion` 取对应高亮图层
- **THEN** 直接以其 rawValue（如 `chest`、`deltFront`）作为 imageset 名取图，无需额外映射表

#### Scenario: 区域提供中文名
- **WHEN** 目标肌群文案需要展示某区域
- **THEN** 由 `MuscleRegion` 提供中文显示名（如 `deltFront` → 「三角肌前束」）

### Requirement: 内置动作细分肌群与要点

`BuiltinExercise` SHALL 新增三个字段：`primaryRegions: [MuscleRegion]`（主动肌）、`secondaryRegions: [MuscleRegion]`（协同肌）、`formCues: [String]`（动作要点，3–5 条原创短句）。150 个内置动作 MUST 全部回填这三个字段。已有的 `primaryMuscle`（粗 8 类）、`equipmentType`、`code` MUST 保留不变，继续服务动作库筛选与 `historyKey` 归并。新字段为纯加法，MUST NOT 改变既有同步契约或 historyKey 计算。

#### Scenario: 卧推的肌群数据
- **WHEN** 读取 `BB_BENCH_PRESS`
- **THEN** `primaryRegions` 含 `chest`，`secondaryRegions` 含 `deltFront` 与 `triceps`，`formCues` 含至少 3 条要点

#### Scenario: primaryMuscle 仍可筛选
- **WHEN** 动作库按「胸」chip 筛选
- **THEN** 仍按 `primaryMuscle == "胸"` 过滤，行为与本 change 前一致

#### Scenario: 协同肌可为空
- **WHEN** 某动作为孤立单关节动作、无明确协同肌
- **THEN** `secondaryRegions` 为空数组，渲染时仅主动肌染色

### Requirement: 用户性别字段

用户本地 profile SHALL 新增 `sex` 字段，取值 `male` 或 `female`，默认 `male`，可在设置中切换。该字段 MUST 仅用于选择高亮图底图轮廓，MUST NOT 影响任何肌群数据、染色逻辑或统计。`sex` 为**纯本地字段、不参与云同步**——与现状一致（`UserProfile` 是本地缓存，`displayName`/`email` 等同样不跨设备同步，profile 当前无同步域与服务端写接口）。跨设备同步留待将来 profile 同步能力落地时再扩展，本 change MUST NOT 为此新增同步实体或后端接口。

#### Scenario: 默认性别
- **WHEN** 用户从未设置性别
- **THEN** 高亮图按 `male` 底图渲染，不阻塞任何流程

#### Scenario: 切换性别只换底图
- **WHEN** 用户把 `sex` 从 `male` 切到 `female`
- **THEN** 同一动作的高亮图换为女版底图轮廓，被点亮的肌肉区与染色完全不变

### Requirement: 肌群高亮图渲染与三态染色

系统 SHALL 提供可复用的肌群高亮图组件，依据传入的 `primaryRegions` / `secondaryRegions` 与当前用户 `sex`、当前展示面（正/背）渲染。每个肌肉区 MUST 呈现三态之一：主动肌染 `Theme.Color.accent`、协同肌染 `accentSofter`、其余为 idle 静默色。底图为矢量（PDF Preserve Vector Data 或等价 Path），MUST 随 App 随包发布、与动作数量无关，MUST NOT 因新增动作而增加图片资产数量。

#### Scenario: 卧推正面染色
- **WHEN** 以 `male` + 正面渲染卧推（primary=[chest], secondary=[deltFront, triceps]）
- **THEN** 胸区为 accent 实色，三角肌前束为 accentSofter 浅色，其余区为 idle

#### Scenario: 正背切换
- **WHEN** 当前动作的点亮区分布在正反两面，用户切到背面
- **THEN** 背面可见区（如 `triceps`/`lats`/`glutes`）按同一三态规则染色，正面专属区不显示

#### Scenario: 默认展示面
- **WHEN** 首次展示某动作高亮图
- **THEN** 默认面取「被点亮区域更多」的一侧（卧推默认正面）

#### Scenario: 缺细分数据降级
- **WHEN** 目标为自定义动作或 `primaryRegions` 为空
- **THEN** 组件 MUST 隐藏（不渲染占位条纹/空人体），由调用方决定替代展示

### Requirement: 高亮图解剖底图保真与许可

肌群高亮图的人体底图 SHALL 为**解剖详细的矢量人体**（每面数十段路径，肌肉分块可辨），MUST NOT 退回粗糙的占位/积木块观感。底图来源于 `react-native-body-highlighter`（MIT）的 path 数据，作为衍生作品使用，App 随包 MUST 附带其 MIT 许可证与版权声明。三态染色（主动肌 `accent` / 协同肌 `accentSofter` / idle）、性别切底图、正背切换、缺数据隐藏等行为 MUST 与既有契约保持一致。

#### Scenario: 详细底图渲染
- **WHEN** 展示任一动作高亮图
- **THEN** 人体为解剖详细矢量图（含三角肌/胸/腹/股四头等可辨分块），非粗糙块面

#### Scenario: 三态染色不变
- **WHEN** 渲染卧推（primary=[chest], secondary=[deltFront, triceps]）
- **THEN** 胸为 accent、三角肌前束/肱三头为 accentSofter、其余肌肉为 idle 底色，与升级前同口径

#### Scenario: 许可随包
- **WHEN** 构建发布包
- **THEN** 包含 `react-native-body-highlighter` 的 MIT 许可证文本与版权声明

### Requirement: SVG 路径渲染能力

高亮图渲染 SHALL 内置一个 SVG path 解析器，至少支持指令 `M/m`、`L/l`、`H/h`、`C/c`、`Q/q`、`A/a`、`Z/z`，正确处理绝对/相对坐标、单指令后的隐式重复坐标组，以及椭圆弧（`A`）到三次贝塞尔的近似。每个肌肉 slug 的所有 path 段 MUST 按其映射的 `MuscleRegion` 统一着色；未映射到任何 region 的部位（如颈/手/头发）MUST 以 idle 底色渲染。

#### Scenario: 弧线指令正确渲染
- **WHEN** path 含相对椭圆弧 `a`（女版数据）
- **THEN** 解析器以贝塞尔近似还原弧段，人体轮廓平滑无破面

#### Scenario: slug 着色映射
- **WHEN** 某 slug 为 `deltoids` 且当前面为正面、动作协同肌含 `deltFront`
- **THEN** 该 slug 全部 path 段着 `accentSofter`；`neck`/`hands` 等无映射 slug 着 idle
