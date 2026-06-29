## Why

当前用户可以创建自定义动作，但动作库没有手动删除入口，误建或过期动作会长期留在动作库与动作选择器中。自定义动作已经是离线优先同步实体并支持软删墓碑，本变更补齐用户可见的删除能力。

## What Changes

- 动作库 browse 模式的自定义动作行通过长按提供手动删除入口。
- 删除前展示二次确认，明确删除后仅从动作库和后续选择器移除。
- 确认删除后走现有 `CustomExercise` 同步信封：本地写入 `deletedAt`、置为 `pendingDelete`，再由同步引擎上传墓碑。
- 历史训练、已有计划项和 Team/计划快照保留既有引用与名称快照，不被删除动作连带改写。
- 新建自定义动作弹窗改为紧凑标签网格，分类数据源对齐动作库的 `ExerciseCategory` 与 `EquipmentType`。

## Non-goals

- 不新增自定义动作编辑、重命名、恢复或批量删除能力。
- 不新增后端 REST 删除接口、数据库表或同步字段。
- 不清理或改写历史训练、已有计划项、统计记录或 Team 快照。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `workout-tracking`: 动作库中自定义动作支持手动删除，并通过现有离线同步墓碑传播。

## Impact

- iOS：`ExerciseLibraryView` / `ExerciseLibraryContentView` 自定义动作行长按删除、删除确认、本地软删同步触发，以及 `CustomExerciseEditorView` 表单布局。
- 后端：复用现有 `/sync/custom-exercises/push` 墓碑协议；补充测试锁定 `CustomExerciseSyncService` 的显式软删 SQL 路径。
- OpenSpec：更新 `workout-tracking` 动作库要求。
