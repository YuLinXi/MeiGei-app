# Proposal — 计划列表分组与标准化

## Why

计划 Tab 当前把「最近在用」计划以 featured 卡置顶，其余计划使用普通卡片。这个强调式结构会让计划列表同时承担「推荐继续」和「模板管理」两种语义，视觉层级不统一，也不利于用户管理越来越多的训练计划。

用户希望计划列表增加分组能力，并去掉强调展示方式。进一步确认后，分组应作为长期能力建设：未来需要分组排序、空分组保留、分组重命名、删除分组不删除计划等能力，因此不采用单纯 `WorkoutPlan.groupName` 字符串方案，而新增独立 `WorkoutPlanGroup` 实体。

## What

- 新增 `WorkoutPlanGroup` 同步实体，用于管理计划分组。
- 给 `WorkoutPlan` 增加 `groupId` 与 `sortOrder`，用于归属分组与组内排序。
- 给 `WorkoutPlanGroup` 增加 `sortOrder`，用于分组排序。
- 计划列表改为按分组渲染，所有计划使用同一种标准卡片，不再渲染 `featuredCard` 或「最近在用」置顶卡。
- 「最近在用计划」逻辑保留给训练首页开始 CTA，不再影响计划 Tab 的排序或视觉层级。
- 支持基础分组管理：新建、重命名、排序、删除；删除分组时不删除计划，组内计划移动到「未分组」。
- 新建 / 编辑计划时可选择分组；计划详情提供移动分组入口。

## Impact

- iOS：新增 SwiftData `WorkoutPlanGroup`、同步 DTO 与列表分组 UI；调整 `WorkoutPlan` 模型与 PlanList/PlanEditor/PlanDetail 交互。
- 后端：新增 `workout_plan_group` 表；`workout_plan` 增加 `group_id`、`sort_order`；新增同步域与 mapper/service/controller 路由。
- OpenSpec：替换 PlanList featured 卡要求，新增计划分组模型、排序与删除行为要求。
- 数据迁移：旧计划 `groupId=nil`，进入「未分组」；旧计划 `sortOrder=0`，同值时按 `updatedAt` 倒序兜底。
