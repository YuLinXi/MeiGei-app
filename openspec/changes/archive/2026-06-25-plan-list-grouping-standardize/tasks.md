## 1. OpenSpec

- [x] 1.1 新增计划分组与列表标准化 proposal/design/tasks/spec。
- [x] 1.2 校验 OpenSpec 变更。

## 2. 后端数据模型

- [x] 2.1 新增 `workout_plan_group` 表 migration。
- [x] 2.2 给 `workout_plan` 增加 `group_id` 与 `sort_order` migration。
- [x] 2.3 新增后端 `WorkoutPlanGroup` entity/mapper/service。
- [x] 2.4 扩展 `WorkoutPlan` entity 同步字段 `groupId/sortOrder`。
- [x] 2.5 新增计划分组同步 controller 路由，并接入 `AbstractSyncService`。
- [x] 2.6 更新账号删除清理范围，覆盖 `workout_plan_group`。
- [x] 2.7 更新 Team Fork 规则，Fork 副本默认 `groupId=nil`、`sortOrder` 追加到接收者未分组末尾。

## 3. iOS 数据模型与同步

- [x] 3.1 新增 SwiftData `WorkoutPlanGroup` 模型，遵循 `Syncable`。
- [x] 3.2 扩展 `WorkoutPlan`：`groupId`、`sortOrder`。
- [x] 3.3 新增 `WorkoutPlanGroupDTO` 与 sync domain。
- [x] 3.4 扩展 `WorkoutPlanDTO` push/pull 映射 `groupId/sortOrder`。
- [x] 3.5 调整 `SyncEngine` 同步顺序：分组先于计划。
- [x] 3.6 对旧本地计划兼容：缺失分组进入「未分组」，`sortOrder` 同值时按 `updatedAt` 兜底。

## 4. iOS 计划列表 UI

- [x] 4.1 移除 `PlanListView` 中的 `activePlan/otherPlans/featuredCard` 列表分流。
- [x] 4.2 增加分组 projection：实体分组 + 未分组 section。
- [x] 4.3 所有计划统一使用标准 `planCard` 样式。
- [x] 4.4 顶部新增「新建计划 / 新建分组」入口。
- [x] 4.5 支持空分组轻量展示。

## 5. iOS 分组管理

- [x] 5.1 新建分组 sheet。
- [x] 5.2 重命名分组 sheet。
- [x] 5.3 删除分组二次确认，并把组内计划移动到未分组。
- [x] 5.4 分组排序交互，提交后重写分组 `sortOrder`。
- [x] 5.5 组内计划排序交互，提交后重写计划 `sortOrder`。
- [x] 5.6 新建计划支持选择分组。
- [x] 5.7 计划详情支持移动到分组。

## 6. 验证

- [x] 6.1 后端测试：分组同步 push/pull、软删、账号删除。
- [x] 6.2 iOS 编译验证。
- [ ] 6.3 iOS 手动验证：旧计划未分组、创建分组、移动计划、删除分组、排序、跨设备同步容错。
- [x] 6.4 重新校验 OpenSpec。
