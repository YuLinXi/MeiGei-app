## 1. 后端 / 数据库与同步契约

- [x] 1.1 新增 Flyway 迁移，为 `workout_set` 增加 `segments jsonb NOT NULL DEFAULT '[]'::jsonb` 与数组类型约束
- [x] 1.2 更新后端 `WorkoutSet` 实体，支持 `segments` 字段并保持旧数据空数组兼容
- [x] 1.3 确认 Workout 聚合 push/pull 原样收发 `setType=drop` 与 `segments`，不新增独立同步实体
- [x] 1.4 更新 Team 计划分享脱敏逻辑，递归清理 `setPrescriptions` 与 segments 内所有重量字段
- [x] 1.5 增加后端测试覆盖递减组 segments 持久化与 Team 计划脱敏

## 2. iOS 端 / 模型、DTO 与统计基础

- [x] 2.1 扩展 `WorkoutSetType` 支持递减组 raw value，并更新未知值兜底策略
- [x] 2.2 新增 `WorkoutSetSegment` 模型与 `WorkoutSet.segments` 存储，提供空数组兼容与父级摘要同步 helper
- [x] 2.3 更新 `WorkoutSetDTO` 与 `SyncEngine`，编码/解码递减组 segments 并兼容缺失字段
- [x] 2.4 新增统一统计 helper，普通组取父级重量次数、递减组展开有效 segments、热身/未完成组排除
- [x] 2.5 将 PR、周统计、历史快照、训练详情聚合、海报、Team checkin 摘要改为使用统一统计 helper

## 3. iOS 端 / 训练录入 UI

- [x] 3.1 将动作卡底部改为「递减组」与「加一组」并列入口，普通加组行为保持不变
- [x] 3.2 实现快速新增递减组：默认两段，首段从上一正式组预填，新增后聚焦到合适输入格
- [x] 3.3 更新组级更多操作菜单，支持普通组改递减组、递减组改回普通组，并处理丢弃分段确认
- [x] 3.4 实现递减组展开行 UI，展示与编辑 segment 重量/次数，支持添加/删除 segment
- [x] 3.5 扩展数字键盘焦点序列，支持递减组 segment 重量/次数输入、上一项/下一项跳转和滚动定位
- [x] 3.6 更新结束训练清理逻辑，未完成递减组和空白 segment 不进入完成记录或统计

## 4. iOS 端 / 计划处方闭环

- [x] 4.1 扩展 `PlanItem`，新增可选 `setPrescriptions` 与递减组处方/segment Codable 结构
- [x] 4.2 更新 `PlanPrefill`，严格模式按处方生成递减组，自适应模式优先历史递减组再回退处方或旧 `suggested*`
- [x] 4.3 更新 `PlanPrescriptionPreview` 与计划详情/列表摘要，展示递减组处方与来源说明
- [x] 4.4 更新保存训练为计划逻辑，写入递减组 `setPrescriptions` 并保留旧 `suggested*` 摘要
- [x] 4.5 更新自适应回写，递减组按逻辑组数回写，顶段更新 `suggested*`，完整结构写入 `setPrescriptions`
- [x] 4.6 更新 Team 计划分享/Fork 客户端逻辑，保留递减组结构并清空所有处方重量

## 5. iOS 端 / 展示与 Team 摘要

- [x] 5.1 更新训练详情只读流水，递减组显示分段明细和紧凑摘要
- [x] 5.2 更新训练分享海报，递减组用最大重量段作为顶组并表达额外分段
- [x] 5.3 更新 `CheckinSummary` 结构与渲染，Team 打卡保留和展示递减组分段
- [x] 5.4 更新 VoiceOver 文案，递减组和 segment 输入/详情可被完整朗读

## 6. 测试与回归文档

- [x] 6.1 增加 iOS 单元测试覆盖递减组统计、PR、历史快照、计划预填、计划回写、保存为计划和 Team 摘要
- [x] 6.2 增加后端测试覆盖 Flyway schema、Workout segments 同步和 Team 计划脱敏
- [x] 6.3 编写手动回归用例文档，覆盖录入、切换、统计、同步、计划、Team、兼容和隐私脱敏场景
- [x] 6.4 运行后端测试/构建、iOS 测试/构建和 OpenSpec validate，记录无法验证项

## 7. 基础设施 / 交付

- [x] 7.1 将所有 OpenSpec artifacts、代码、测试与回归文档纳入同一 change 审查范围
- [x] 7.2 完成实现后更新本 tasks.md 勾选状态
- [x] 7.3 创建 git commit 并推送当前远程分支
