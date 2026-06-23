## MODIFIED Requirements

### Requirement: 训练历史与 PR 识别

系统 SHALL 提供训练日历（按日期查看已完成训练）与单动作历史曲线（默认展示重量趋势）。系统 SHALL 在保存训练时自动识别个人记录（PR）并给予提示。统计数据 MUST 可由原始记录重算，系统 SHOULD 避免持久化冗余统计结果。

为支持大规模历史数据，客户端 UI 的常规渲染路径 MUST NOT 直接订阅完整训练聚合树并在视图 `body` 或 computed property 中反复全量扫描 `Workout` / `WorkoutExercise` / `WorkoutSet`。客户端 SHOULD 使用窄查询、时间范围切片、fetch limit、内存派生快照或可重建本地索引来提供首页摘要、PR、动作历史曲线与计划预填。

#### Scenario: 查看动作历史曲线
- **WHEN** 用户打开某个动作的历史
- **THEN** 系统以时间为横轴展示该动作的重量趋势曲线
- **AND** 客户端仅加载该动作相关的历史序列或读取派生快照，不因打开单个动作而订阅全部训练聚合树

#### Scenario: 自动识别 PR
- **WHEN** 用户某动作本次的重量超过其历史最大值
- **THEN** 系统标记该次为新 PR 并向用户展示庆祝提示
- **AND** PR 判定结果 MUST 可由原始训练记录重建

#### Scenario: 大历史库首页可交互
- **GIVEN** 本地存在至少 1000 条已完成训练记录
- **WHEN** 用户打开训练首页
- **THEN** 首页 SHALL 展示本周摘要、最近训练和开始训练 CTA
- **AND** 首页 MUST NOT 在每次渲染时遍历全部历史训练的所有动作与组

#### Scenario: 导入历史后统计一致
- **GIVEN** 用户导入大量历史训练记录
- **WHEN** 客户端完成本地派生快照或索引重建
- **THEN** 首页摘要、动作 PR、动作历史曲线、计划自适应预填 SHALL 与从原始训练记录完整重算的结果一致
- **AND** 派生快照或索引丢失时系统 SHALL 能从原始训练记录重新构建

#### Scenario: 派生数据不参与同步冲突
- **WHEN** 客户端为提升性能维护本地派生快照或索引
- **THEN** 这些派生数据 MUST NOT 作为云同步真相源上传
- **AND** 训练记录同步冲突仍 SHALL 依据原始同步实体的 last-write-wins 规则处理
