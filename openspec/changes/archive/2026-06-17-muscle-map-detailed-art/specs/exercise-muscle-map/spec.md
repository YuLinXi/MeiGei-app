## ADDED Requirements

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
