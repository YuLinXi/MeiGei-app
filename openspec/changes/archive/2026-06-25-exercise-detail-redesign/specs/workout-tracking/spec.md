## ADDED Requirements

### Requirement: 动作详情页（ExerciseDetail）版式与行为

内置动作详情页 SHALL 为**纯浏览/查资料**页，自上而下五段：① 肌群高亮图、② 标题与 meta、③ 你的数据、④ 动作要点、⑤ 目标肌群。该页 MUST NOT 提供任何写入训练数据的入口（移除「加入今日训练」CTA），MUST NOT 在进入或停留时创建或修改训练会话。加动作入口仍由训练会话的动作选择器与计划编辑承担。

#### Scenario: 进入详情页不触发写入
- **WHEN** 用户从动作库点进某内置动作详情
- **THEN** 页面仅展示资料，不新建/不修改任何 `Workout`，无底部「加入今日训练」按钮

#### Scenario: 五段结构
- **WHEN** 内置动作有完整细分数据
- **THEN** 依次显示「肌群高亮图 / 标题+部位·器械 chip / 你的数据 / 动作要点 / 目标肌群」，页面滚到底即止、无置底 CTA

### Requirement: 详情页肌群高亮图

详情页顶部 SHALL 以 `MuscleMapView` 渲染该动作的肌群高亮图，主动肌/协同肌取自动作的 `primaryRegions`/`secondaryRegions`，底图按用户 `UserProfile.sex` 选择，默认面取「亮区更多」一侧并可正/背切换。当动作无细分区数据（如自定义动作或未回填）时，高亮图段 MUST 隐藏，不显示占位条纹。

#### Scenario: 内置动作显示高亮图
- **WHEN** 查看「杠铃卧推」（primaryRegions=[chest]）
- **THEN** 顶部显示高亮图，胸为主动色、三角肌前束/肱三头为协同色

#### Scenario: 性别切底图
- **WHEN** 用户 `sex` 为 `female`
- **THEN** 高亮图用女版底图轮廓，点亮区与染色不变

#### Scenario: 缺数据隐藏
- **WHEN** 动作 `primaryRegions` 为空
- **THEN** 高亮图段不渲染，页面从标题段开始

### Requirement: 详情页「你的数据」段

详情页 SHALL 展示该动作的个人历史摘要：上次训练日期、最近一组（重量×次数）、PR；并展示一个按时间的迷你强度图。所有数值 MUST 自本地 `workouts`（已结束、未软删，按 `historyKey` 匹配）即时重算，MUST NOT 持久化冗余。当该动作无任何历史记录时，该段 SHALL 降级为「还没练过」提示，MUST NOT 显示 0 或假数据。

#### Scenario: 有历史
- **WHEN** 用户此前练过该动作
- **THEN** 显示上次日期、最近一组、PR 与迷你图；点迷你图进全屏历史（无独立全屏页时降级为不可点）

#### Scenario: 无历史
- **WHEN** 用户从未记录过该动作
- **THEN** 「你的数据」段显示「还没练过」，不显示 0kg / 空图

### Requirement: 详情页要点与目标肌群

详情页 SHALL 展示动作 `formCues`（编号短句列表）与目标肌群。目标肌群 MUST 用 `MuscleRegion.displayName` 中文名，并以与高亮图一致的三态色点区分主动肌/协同肌。当 `formCues` 为空时要点段隐藏；当无 region 时目标肌群段隐藏。内部 `code` MUST NOT 作为主要信息展示给用户（可隐藏或降为次要脚注）。

#### Scenario: 要点与肌群展示
- **WHEN** 动作有 3 条 `formCues`、primary=[chest]、secondary=[deltFront, triceps]
- **THEN** 要点段列 3 条编号短句；目标肌群段显示「主动肌 胸大肌」「协同肌 三角肌前束 · 肱三头肌」，色点与高亮图同源

#### Scenario: 不暴露内部 code
- **WHEN** 查看任意内置动作
- **THEN** 页面不把 `BB_BENCH_PRESS` 这类 code 作为标题/主要字段展示
