## Context

内置动作（`BuiltinExercise`，随包只读）目前字段为 `code / name / primaryMuscle / equipmentType`，~150 条。动作详情页（`ExerciseDetailView`）的部位高亮图、要点、协同肌自 MVP 起均为占位。设计稿已在 Open Design `MeiGeiApp2` 的 `meigei-c-muscle-map.html` 完成：男女各正/背 4 张扁平极简人体、16 区分区、卧推染色示例（Chrome 渲染为准；OD 预览缩略图因 `<use>` 兼容问题显示残缺，与最终资产无关）。

约束：1–2 人小团队 MVP；iOS 17.4+ SwiftUI；无第三方重依赖偏好；纸感极简设计系统（朱砂红 `Theme.Color.accent`）；内置动作不入同步域。

## Goals / Non-Goals

**Goals:**
- 用「1 套矢量人体 + 每动作几个枚举值」替代「每动作一张图」，使存储与动作数量解耦、零版权风险。
- 16 区枚举 rawValue 直接当资产命名，消除映射层。
- 性别仅切底图轮廓，肌群/染色/数据两性共用，避免动作数据翻倍。
- 产出可复用的 `MuscleMapView`，为后续详情页重构与计划/Team 等场景复用。

**Non-Goals:**
- 详情页五段重构（接入高亮图、「你的数据」段、去 CTA）——后续 `exercise-detail-redesign`。
- 自定义动作 region 录入、写实解剖图、动图/视频、后端动作下发、体型分级。

## Decisions

### D1：图 = 数据（枚举数组），而非每动作一张图
动作只存 `primaryRegions` / `secondaryRegions: [MuscleRegion]`，渲染时按区染色。150 动作 = 150 行数据，图始终 4 张。
- 备选：每动作 PNG/SVG（被否：存储随动作增长、版权与采集成本高）。

### D2：`MuscleRegion` rawValue 即资产名
枚举 case rawValue（`chest` / `deltFront` …）= asset catalog 内 imageset 名 = OD 设计稿 SVG 图层名，三处逐字对齐，渲染层零映射。

### D3：渲染方案 —— 实现采用纯 SwiftUI Path（PDF 改为可选）
以 MIT `react-native-body-highlighter` 为**比例参考自绘重画**（非复制其 path）。
- **实现决定（与初稿不同）**：5.1 最终用**纯 SwiftUI `Path`**——把设计稿（220×470 viewBox）的 region path 字符串作数据，写一个极简 SVG-path 解析器（`SVGPathShape`，仅 M/L/Q/Z）+ 左半镜像渲染，三态切 `fill`。矢量、可染色、**零资产依赖**，无需第三方 SVG 库，亦无需先导 PDF 即可上线。PDF imageset 方案降级为「将来想换更精写实资产时的可选升级」。
- 初稿曾把纯 Path 列为「手调成本高」而倾向 PDF；但坐标已在 Open Design 设计稿中调好并 Chrome 验证，直接移植即可，成本远低于预期，故反转。
- 备选 A：运行时解析完整 SVG 库（被否：零重依赖偏好）。
- 备选 C：直接用开源 RN 组件 path（被否：写实多边形与纸感极简调性不符）。

### D4：性别 = profile 上的渲染开关
`sex: male | female`（默认 `male`）。`bodyAsset(sex, side, region)` 选 4 套底图之一；染色与 region 数组与性别正交。
- 备选：男女各存一套 region 数据（被否：肌肉解剖位置两性一致，纯冗余）。

### D5：`primaryMuscle` 粗类保留
粗 8 类继续做动作库筛选 chip 与 `historyKey`（`builtinCode ?? customId ?? name`）归并；细分 region 仅服务高亮图与目标肌群展示。两套并存、互不替代。

### D6：数据模型与 Day-1 铁律
- `BuiltinExercise`：随包**只读静态数据**，不入同步域，无 serverId/localId/version——新字段只是静态结构扩展，不涉及同步、幂等、软删。
- profile `sex`：**纯本地字段、不同步**。实现时核对发现 profile 当前没有同步域（同步域仅 `custom-exercises`/`workout-plans`/`workouts`），`UserProfile` 是本地缓存、后端 `AppUser` 无 profile 更新接口，`displayName`/`email` 也不跨设备同步。故 `sex` 仅落本地 `UserProfile`，不新增同步实体、不动后端、不加 Flyway 迁移。Day-1 同步铁律对该字段不适用（它不进同步域）；将来若 profile 同步落地再统一纳入。
  - 备选：本 change 一并建 profile 同步（新同步域 + 后端表 + 接口）——被否：范围远超本 change，且 MVP 阶段 profile 跨设备同步非刚需。

## Risks / Trade-offs

- [16 区不足以精确表达所有动作] → 接受粒度损失；16 区已覆盖主流训练肌群，复杂动作就近归并，详情页要点文字补充说明。
- [自绘解剖精度不及专业插画] → App 高亮图为示意非教学；以「能识别练哪块」为标准，发型/肌理留 PDF 精修阶段。
- [150 条 region/要点回填工作量大且易错] → 按肌群分批录入 + 评审；要点为原创短句，避免逐字抄第三方（版权）。
- [PDF imageset 数量（16 区 × 正背 × 男女）] → 仍是常数级（约 16×2×2 上限，且多数区正背共用一面），与动作数量无关，远优于每动作一图。
- [OD 预览渲染残缺误导验收] → 以 Chrome/真机渲染为准，OD 缩略图不作质量依据。

## Migration Plan

1. 加 `MuscleRegion` 枚举与 `BuiltinExercise` 三字段（默认空），编译通过、既有功能不受影响。
2. 分肌群批量回填 150 条 region + 要点数据。
3. OD 设计稿精修 → 导 4 套底图 PDF imageset（名=rawValue）入 asset catalog，附 MIT 许可证声明。
4. 实现 `MuscleMapView`（三态染色 + 正/背切换 + 缺数据隐藏）。
5. profile 加 `sex` 字段 + 设置项切换。
- 回滚：字段为纯加法、内置数据只读，移除组件与字段即恢复；profile `sex` 可空，旧客户端忽略该字段无副作用。

## Open Questions

- 详情页接入由后续 `exercise-detail-redesign` 处理；本 change 的 `MuscleMapView` 是否需要先在某个调试入口自检？倾向：加一个内部预览（不进正式导航）。
- `sex` 默认值与首次引导：默认 `male` 不弹问，还是注册流程顺带问一次？倾向默认 `male` + 设置可改，不打断。
