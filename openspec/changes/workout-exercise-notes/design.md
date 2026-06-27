## Context

当前 `Workout`、`WorkoutExercise`、`WorkoutSet` 均已有 `note` 字段；后端 baseline 表、DTO 与 iOS `SyncEngine` 的 workout 聚合 push/pull 也已经传递这些字段。也就是说，本 change 不需要新增数据库字段、REST 接口或同步实体，主要缺口在 iOS 训练流程的添加入口和展示方式。

现有训练详情遵守“已完成会话默认只读摘要与显式编辑”的边界。Team 分享使用 `CheckinSummary` 快照，当前只包含标题、时间、动作、组和容量，不包含备注；Team 规格也明确不做文字评论、群聊或私信。因此动作备注首版应保持个人训练日志属性，不默认扩大到 Team 可见范围。

## Goals / Non-Goals

**Goals:**

- 允许用户在训练进行中为某个动作记录本次备注。
- 在训练中和已完成训练详情中展示动作备注，且无备注时不占用 UI 空间。
- 复用现有 `WorkoutExercise.note`、SwiftData 本地保存和 workout 聚合同步链路。
- 保持 Team 分享快照不包含备注，避免改变隐私边界。

**Non-Goals:**

- 不新增 `Workout.note` 或 `WorkoutSet.note` 的 UI。
- 不设计动作库长期备注、计划项备注、标签、模板或富文本能力。
- 不新增后端接口、数据库迁移、同步水位或幂等写接口。
- 不在 Team feed、Team 历史详情、emoji reaction 或外部海报中展示备注。
- 不改变已完成训练默认只读原则；完成后直接补写备注不在首版范围内。

## Decisions

### D1：备注绑定 `WorkoutExercise.note`

动作备注语义是“本次训练中这个动作的上下文”，最贴合 `WorkoutExercise.note`。它不同于动作库说明，也不同于单组备注。

备选方案：

- `Workout.note`：只能描述整次训练，不适合记录某个动作的技术细节。
- `WorkoutSet.note`：粒度更细，但组行已经承载重量、次数、完成态和组类型，首版会明显增加输入复杂度。
- 动作库或计划项备注：会变成长期知识或处方说明，不等同于本次训练日志。

### D2：训练中通过动作级入口编辑，保存时才写入模型

动作卡右上 `...` 菜单扩展为动作设置菜单，在组间休息与删除动作之间增加“添加备注 / 编辑备注”。点击后打开底部 sheet，使用 draft 文本承载输入，最多 200 字。用户点击“完成”时 trim 文本，空字符串写为 `nil`，非空写入 `exercise.note`，然后触发已有的训练聚合 dirty/save 流程。

这样避免每输入一个字就写 SwiftData 和标脏，也符合离线优先：本地确认即保存，后续由既有 sync 重试队列上传。取消 sheet 不应写入任何数据。

### D3：展示采用轻量摘要，避免把卡片变成文档编辑器

训练中动作卡只有在 `note` 非空时展示备注摘要。展开态在标题下方展示最多 2 行的纸感 note strip；备注是信息性内容，颜色 MUST 使用中性文字、底色和描边，不使用朱砂红强调。折叠态可用轻量图标或“有备注”提示，但不展示完整文本，避免折叠摘要膨胀。

已完成训练详情在动作标题与组列表之间展示备注，只读、最多 2 行，超出部分省略；点击备注条弹出只读 sheet 展示完整内容。无备注不显示占位文案。

备注完整内容 sheet 属于只读查看型弹层，不展示顶部“完成/取消”等操作按钮；用户通过系统下滑关闭。相同规则也适用于 Team 训练详情这类不可编辑的详情 sheet，以及历史月份浏览这类无需显式确认的浏览型 sheet。此类 sheet 统一使用居中、加粗的大标题；编辑、排序等需要显式确认或取消的 sheet 保留 `PaperSheetHeader` 操作区。

### D4：Team 分享不携带备注

`CheckinSummary` 首版保持现状，不新增 `ExerciseSummary.note` 或 `SetSummary.note`。用户完成训练后如果自动分享到 Team，Team checkin 继续只包含训练摘要与每组重量/次数详情。

如果未来要让备注进入 Team，需要另起 change 明确隐私开关、旧 summary 兼容解析、撤回语义和历史详情展示方式。

### D5：不新增数据模型和迁移

本 change 复用已有同步域字段，因此不新增服务端写接口，也不新增 idempotency key。Day-1 铁律的处理方式如下：

- 身份三层：不涉及新的身份模型或跨用户读取。
- 幂等键：不新增 REST 写接口；备注跟随 workout 聚合上传，沿用既有 push 幂等键。
- 同步字段：备注属于已有 `WorkoutExercise` 聚合内容，继续跟随 `Workout` 的 `serverId/localId/updatedAt/deletedAt/version/syncStatus`。
- 软删除：不新增删除语义；删除训练或动作时，备注随既有聚合和墓碑流程消失。
- 冲突：继续使用 workout 聚合 last-write-wins，不做字段级 merge。

## Risks / Trade-offs

- [Risk] 用户可能期待完成后补写备注 → Mitigation：首版在历史详情只读展示；如要支持补写，需基于“已完成会话显式编辑”单独设计保存、PR 重算和 Team 摘要更新边界。
- [Risk] 备注过长影响训练中卡片密度 → Mitigation：训练中摘要限制行数，完整编辑只在 sheet 中进行。
- [Risk] Team 成员以为能看到备注 → Mitigation：UI 和规格明确备注是个人训练日志，Team 快照不扩字段。
- [Risk] 既有 `WorkoutSet.note` 字段造成实现误用 → Mitigation：任务中明确只接 `WorkoutExercise.note`，不暴露组级备注入口。

## Migration Plan

- 无数据库迁移；已有本地或服务端 `WorkoutExercise.note` 数据在新 UI 中自然展示。
- 客户端升级后，旧训练中如果已有动作备注则在详情中显示；没有备注则 UI 不变。
- 回滚客户端时，备注字段仍保留在模型和同步数据中，只是没有新增 UI 入口。

## Open Questions

- 无。 “上次备注带入/提醒”属于动作长期提醒或下次训练提示，后续如需要应独立设计。
