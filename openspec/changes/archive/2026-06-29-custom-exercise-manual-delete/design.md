## Context

`CustomExercise` 已经是同步域实体，具备 `localId/serverId/updatedAt/deletedAt/version/syncStatus` 信封。后端 `CustomExerciseSyncService` 已通过 `/sync/custom-exercises/push` 支持 `deletedAt` 墓碑上传，并用 mapper 的显式 `softDelete` SQL 绕过 MyBatis-Plus `@TableLogic` 限制。

iOS 动作库当前会过滤 `deletedAt == nil` 的自定义动作，动作选择器也只显示未删除项，但用户没有入口把自定义动作标记删除。用户明确不希望常驻删除图标或左滑删除，希望改成长按删除并二次确认。

## Goals / Non-Goals

**Goals:**

- 在动作库 browse 模式提供自定义动作删除入口。
- 删除使用现有离线优先同步字段与墓碑协议，不新增数据模型。
- 删除后动作从动作库和后续选择器隐藏，已保存训练/计划引用继续可展示。
- 重新设计新建自定义动作弹窗，使分类选择对齐动作库标签分类，并减少顶部留白。

**Non-Goals:**

- 不做编辑、重命名、恢复、批量删除。
- 不新增后端 REST 删除接口或数据库迁移。
- 不级联改写历史训练、计划项或 Team 快照。

## Decisions

1. 删除入口使用自定义动作行长按触发。
   - 理由：常态行内不展示任何删除符号，PR pill 继续保持行内最右侧；长按比常驻按钮和左滑更低干扰，适合动作库 browse 模式里的低频破坏性操作。
   - 备选：左滑删除在该屏横向信息密度高时不够直观；常驻左侧 `minus.circle.fill` 控制会增加视觉噪音；常驻右侧按钮会挤占 PR 位置。

2. 删除走 `markDeleted()` + `modelContext.save()` + `syncEngine.syncAll()`。
   - 理由：符合离线优先和同步对象软删除铁律；离线时 `pendingDelete` 留在重试队列。
   - 备选：直接物理删除本地对象会丢失待上传墓碑，其他设备无法同步删除。

3. 保留既有引用和快照。
   - 理由：训练记录和计划项保存了自定义动作 id 与名称快照，删除动作库条目不应破坏历史可追溯性或自动改变用户模板。
   - 备选：删除时清理计划引用会产生隐式模板变更，历史训练清理会影响统计和审计语义。

4. 新建自定义动作表单改为标签网格。
   - 理由：部位标签直接来自 `ExerciseCategory.allCases`，器械标签直接来自 `EquipmentType.allCases`，与动作库左栏和器械轴同源；去掉二级滚轮弹层后 sheet 可按内容自适应高度，顶部留白更少。
   - 备选：保留滚轮仅调整留白仍存在二级弹层和交互成本，不符合“对齐动作库标签分类”的要求。

## Risks / Trade-offs

- [Risk] 长按入口可发现性低于显式按钮 → 仅用于动作库 browse 模式的低频破坏操作；删除前用 `paperConfirmDialog` 二次确认，并明确影响范围。
- [Risk] 离线删除暂未同步到其他设备 → 墓碑保留为 `pendingDelete`，现有同步引擎下次 `syncAll` 自动重试。
- [Risk] 已有计划仍引用被删除动作，后续从计划开始训练仍可能使用快照名称 → 这是本变更的显式选择，避免删除动作库条目连带修改用户计划。
- [Risk] 部位/器械标签数量较多导致 sheet 变高 → 使用自适应 detent 与紧凑 chip 网格，必要时内容纵向滚动；名称仍是唯一必填字段。
