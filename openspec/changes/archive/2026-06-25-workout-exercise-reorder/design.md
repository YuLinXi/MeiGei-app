## Context

iOS 端已有两套动作顺序数据：

- `WorkoutPlan.items[].orderIndex`：计划模板里的动作顺序，随 `WorkoutPlan` 同步域以 jsonb 整体同步。
- `WorkoutExercise.orderIndex`：单次训练记录里的动作顺序，随 workout 聚合树同步。

页面也已按这两个字段排序展示：计划详情用 `orderedItems`，训练进行中用 `workout.exercises.sorted { $0.orderIndex < $1.orderIndex }`。因此本 change 不需要新增字段或后端契约，只需要把“显式排序模式”补到 UI，并在完成排序后重写连续 orderIndex。

交互环境较复杂：计划详情动作行已有左滑删除与点按编辑；训练进行中动作卡已有垂直滚动、手风琴展开、动作级菜单、组级菜单、自研数字键盘、休息 FAB 拖动；另有 `swipe-back-gesture` 恢复了 push 页左边缘侧滑返回。因此排序不再常驻在动作行/卡头内，而是进入专门排序面板。

## Goals / Non-Goals

**Goals:**

- 计划详情支持调整计划动作顺序，并影响未来从计划开始训练的动作顺序。
- 训练进行中支持调整本次训练动作顺序，并只影响当前训练记录。
- 两处重排都通过明确「排序」入口启动，避免抢占整卡点击、滚动、左滑删除、菜单等手势。
- 重排后即时落盘、标脏对应聚合根，复用现有离线优先与 LWW 同步。
- 复用 iOS 原生列表移动能力，提供 VoiceOver 可操作的排序流程。

**Non-Goals:**

- 不新增数据库字段、后端接口或同步冲突策略。
- 不做训练中重排自动回写计划顺序。
- 不支持完成训练只读详情页重排。
- 不做组（set）跨动作拖拽。

## Decisions

### 决策 1：复用 `orderIndex`，拖完后连续重排

拖动结束后重新按当前展示顺序写回 `0...n-1`：

```
计划详情：PlanItem.orderIndex
训练进行中：WorkoutExercise.orderIndex
```

这样避免稀疏序号或浮点序号带来的同步/排序边界，且与现有删除动作时重排 `orderIndex` 的代码一致。排序变更通过 `markDirty()` 进入既有同步域：

- `WorkoutPlan.markDirty()`：同步计划 jsonb，未来开始训练按新顺序。
- `Workout.markDirty()`：同步本次训练聚合树，不动计划模板。

### 决策 2：训练中重排不自动回写计划顺序

训练中改顺序通常是临场行为（器械占用、临时插队、状态变化）。自动改计划模板会制造隐式副作用，尤其和刚完成的自适应计划回写形成叠加心智。因此：

```
PlanDetail reorder  ──▶ WorkoutPlan.items orderIndex
Workout reorder     ──▶ Workout.exercises orderIndex
                         ✗ 不写 WorkoutPlan.items
```

如未来需要“把本次顺序保存回计划”，应作为显式命令另做。

### 决策 3：排序进入专门面板，不在正常行内常驻 handle

计划详情和训练进行中均提供「排序」入口，进入复用的 `ExerciseOrderEditorSheet`：

- 面板使用统一纸感 sheet 顶栏 + `List + ForEach.onMove`。
- 打开后进入 `EditMode.active`，展示 iOS 原生 reorder control。
- 面板维护草稿顺序；取消丢弃，完成后一次性提交 `[UUID]`。
- 面板根背景、列表滚动背景与呈现背景使用项目设计 token 统一；顶部「取消 / 完成」使用自定义 44pt 胶囊按钮，不走系统 toolbar 文本按钮。
- 面板禁用下滑关闭，避免拖动 reorder control 时与系统 dismiss 手势竞争；退出只能通过「取消」或「完成」。
- 正常计划动作行继续负责点按编辑、编辑图标、左滑删除。
- 正常训练动作卡继续负责展开/收起、动作菜单、组菜单、组输入。

### 决策 4：排序入口位置

- 计划详情：`训练动作` section header 右侧显示 `排序`，仅当动作数大于 1 时可见。
- 训练进行中：三联数下方、动作卡列表上方显示 `训练动作 · 排序` 紧凑 header，仅当 `canEdit && workout.exercises.count > 1` 时可见。
- 已完成训练只读页不显示排序入口。

### 决策 5：排序提交函数按 ID 顺序重写

排序面板只返回排序后的 ID 数组，业务层负责映射：

- 计划详情：按返回的 `itemId` 顺序重排 `PlanItem`，再 `plan.markDirty()` 并保存。
- 训练进行中：按返回的 `localId` 顺序重排 `WorkoutExercise.orderIndex`，再调用 `touch()`。
- 若返回 ID 与当前数据不匹配（例如面板打开期间数据变化），保留未匹配项在末尾并连续重排，避免丢动作。

## Risks / Trade-offs

- **[手势冲突]** → 排序不在正常行内处理，左滑删除、卡头点击、输入框、菜单、FAB 拖动不再和排序手势竞争。
- **[训练中焦点悬空]** → 打开排序面板前收起数字键盘与打开的组/动作菜单。
- **[面板期间数据变化]** → 提交时按当前数据与返回 ID 做安全合并，不匹配项保留在末尾。
- **[同步冲突]** → 复用 LWW；多设备同时重排同一计划时最后写入胜出，不做逐项 merge。

## Migration Plan

无数据迁移。旧数据已有 `orderIndex`；如发现历史数据存在重复/不连续序号，页面重排或删除后会归一化为连续 `0...n-1`。

## Open Questions

- 是否未来增加“训练结束时询问是否更新来源计划顺序”？当前不做，保持训练中排序仅本次有效。
