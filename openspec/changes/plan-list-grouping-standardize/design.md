# Design — 计划列表分组与标准化

## 目标形态

计划 Tab 变成「训练模板管理」界面：分组是主组织方式，计划卡片全部使用统一标准，不再因为最近使用而视觉放大。

```text
计划                                           +

胸背                                      ⋯
  ┌──────────────────────────────────────┐
  │ 胸背容量日                  自适应   │
  │ 5 动作 · 21 组                       │
  │ 下次依据：上次完成实绩               │
  │ 累计 12 次 · 上次 3 天前             │
  └──────────────────────────────────────┘

腿                                        ⋯
  ┌──────────────────────────────────────┐
  │ 深蹲重点日                  严格     │
  │ 4 动作 · 18 组                       │
  │ 严格执行 · 不回写                    │
  │ 累计 8 次 · 上次 1 周前              │
  └──────────────────────────────────────┘

未分组
  ┌──────────────────────────────────────┐
  │ 临时全身                    自适应   │
  └──────────────────────────────────────┘
```

「最近在用」仍用于训练首页 CTA 的智能默认计划，不进入计划 Tab 的排序规则，也不渲染特殊样式。

## 数据模型

新增同步实体：

```text
WorkoutPlanGroup
- localId: UUID
- serverId: UUID?
- name: String
- sortOrder: Int
- updatedAt / deletedAt / version / syncStatus
```

扩展现有计划：

```text
WorkoutPlan
- groupId: UUID?
- sortOrder: Int
```

排序规则：

- 分组：`WorkoutPlanGroup.sortOrder` 升序；同值时 `updatedAt` 倒序兜底。
- 组内计划：`WorkoutPlan.sortOrder` 升序；同值时 `updatedAt` 倒序兜底。
- 「未分组」不是实体，由 `groupId == nil` 或引用缺失/已删除分组的计划组成，默认排在实体分组之后。

为什么不使用 `groupName` 字符串：

| 能力 | `groupName` | `WorkoutPlanGroup` |
| --- | --- | --- |
| 按分组展示 | 可以 | 可以 |
| 组内排序 | 可以，需计划字段 | 可以 |
| 分组自身手动排序 | 勉强，需要额外约定 | 直接支持 |
| 空分组保留 | 不可靠 | 直接支持 |
| 重命名不批量改计划 | 不支持 | 支持 |
| 删除分组但保留计划 | 需要字符串清理 | 通过 `groupId=nil` |
| 未来颜色/图标/折叠/归档 | 不适合 | 可扩展 |

## 后端 schema

新增 migration 建议：

```sql
CREATE TABLE workout_plan_group (
    id         uuid PRIMARY KEY,
    user_id    uuid NOT NULL REFERENCES app_user(id),
    name       text NOT NULL,
    sort_order int NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    version    int NOT NULL DEFAULT 0
);

ALTER TABLE workout_plan ADD COLUMN group_id uuid;
ALTER TABLE workout_plan ADD COLUMN sort_order int NOT NULL DEFAULT 0;

CREATE INDEX idx_plan_group_user_order
    ON workout_plan_group (user_id, sort_order, updated_at)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_plan_user_group_order
    ON workout_plan (user_id, group_id, sort_order, updated_at)
    WHERE deleted_at IS NULL;
```

`workout_plan.group_id` 不强制外键到 `workout_plan_group`，保持离线同步容错：当计划先于分组同步、分组被软删、或跨设备 LWW 出现短暂乱序时，客户端把缺失分组视为「未分组」，不阻断同步。

## 同步设计

新增同步域 `workout_plan_group`，与 `custom_exercise`、`workout_plan` 一样使用同步信封：

- push 仍按幂等键去重。
- pull 按 `since` 增量。
- 冲突沿用 LWW。
- 删除分组使用软删墓碑。

同步顺序建议：

```text
custom_exercise
workout_plan_group
workout_plan
workout
```

原因是计划可能引用分组。即使同步乱序，UI 也必须容错为「未分组」，不能崩溃或隐藏计划。

## 交互设计

### 列表页

- 顶部仍为根页大标题「计划」。
- 右上 `+` 改为添加菜单或等价入口，至少提供「新建计划」「新建分组」。
- 列表按分组 section 渲染；分组标题右侧提供更多菜单（重命名、调整排序、删除分组）。
- 所有计划使用同一个标准卡片，不出现 featured / active / 置顶富卡。
- 空分组可显示轻量空态，便于用户知道分组存在。
- 全局无计划且无分组时显示原空态，引导新建计划。

### 分组管理

V1 支持基础能力：

- 新建分组：输入名称，默认追加到最后。
- 重命名分组：仅更新 group.name，不修改计划。
- 排序分组：拖拽或管理页调整 `sortOrder`。
- 删除分组：二次确认；不删除计划，客户端把该组计划移动到 `groupId=nil` 并标脏。

### 计划归属

- 新建计划时可选择分组，默认沿用当前入口所在分组；从顶部新建则默认「未分组」。
- 计划详情更多操作提供「移动到分组」。
- Team Fork 出来的计划默认私有且未分组，避免把发布者的个人分组结构带入接收者空间。

## 视觉标准

计划卡片统一包含：

- 计划名。
- 模式标识（严格 / 自适应）。
- 动作数与总组数。
- 行为摘要。
- 可选使用摘要：累计次数、上次训练时间。

计划卡片不得因为最近使用而使用不同尺寸、左侧强调条、三列 meta 大卡、渐变或额外阴影。分组 header 承担结构层级，计划卡只表达计划本身。

## 风险与取舍

- 新实体增加端到端同步工作量，但避免后续从 `groupName` 迁移到实体的二次数据迁移。
- `group_id` 不加外键牺牲数据库强一致，换取离线同步乱序容错。客户端和后端账号删除仍按 user 范围清理。
- 手动排序使用整数 `sortOrder`，拖拽提交后可重写同组所有顺序值，简单可靠；暂不引入 fractional rank。
