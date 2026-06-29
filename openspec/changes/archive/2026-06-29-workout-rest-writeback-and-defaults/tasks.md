## 1. 规格与数据模型

- [x] 1.1 补充 workout-tracking 规格，明确休息回填持久化与下一组默认休息规则。
- [x] 1.2 为 iOS `WorkoutSet` 增加 `plannedRestSeconds` / `actualRestSeconds` 可空字段。
- [x] 1.3 为后端 `workout_set` 增加对应 nullable integer 字段与 entity 映射。

## 2. 同步链路

- [x] 2.1 在 iOS `WorkoutSetDTO` 与 `SyncEngine` push/pull 映射中传递休息字段。
- [x] 2.2 确认后端 workout 聚合同步 push/pull 保留休息字段。

## 3. 训练页行为

- [x] 3.1 完成组并启动休息时写入当前组 `plannedRestSeconds`。
- [x] 3.2 休息完成事件消费时写入当前组 `actualRestSeconds` 并落盘。
- [x] 3.3 实现同一动作内默认休息策略：热身后 fallback，正式组后继承上一正式组预计时长。
- [x] 3.4 继续休息、取消完成、删除组时正确维护持久休息字段。
- [x] 3.5 训练页休息时长展示改为读取 `WorkoutSet.actualRestSeconds`。

## 4. 测试与验证

- [x] 4.1 增加 iOS 单元测试覆盖休息字段持久化与默认休息策略。
- [x] 4.2 增加后端测试覆盖 workout set 休息字段同步保留。
- [x] 4.3 运行 OpenSpec、后端测试和 iOS 编译验证。
