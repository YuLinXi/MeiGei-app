## Context

现状（见 proposal.md - Why）：

- `Workout.note` 列在 `V1__baseline.sql` 已存在，workout 同步信封已透传，但 iOS 无任何 UI 读写入口。
- `WorkoutExercise.note` 与超级组 `note` 已有完整的训练中编辑、历史只读展示与同步链路（spec：训练动作备注）。
- `WorkoutPlan` 后端实体为显式列（`name/items/mode/...`），`items` 为 jsonb 字符串；`PlanItem` 在 v1.1-b2 刚以同模式新增可选 `restAfterSetSeconds`。
- `workout_plan` 表当前没有 `note` 列；后端最新迁移为 `V20__team_member_preferences_default_enabled.sql`。

约束：同步域沿用客户端权威 + LWW 信封；Team 分享为服务端快照 + 客户端无重量重建；所有新字段必须向后兼容旧计划 JSON 与旧客户端。

## Goals / Non-Goals

**Goals:**

- 计划整体备注、计划动作备注在编辑/详情/开始训练/历史/转换/Team 分享全链路贯通（带入训练，不回写）。
- 后端改动最小：仅一个可空列 + 透传。
- 旧客户端、旧计划、旧分享版本零迁移成本。

**Non-Goals:**

- 不改变休息字段、回写回执、checkin 快照与海报的既有行为（备注不进这些面）。
- 不做备注的跨设备冲突合并增强（沿用 LWW）。

## Decisions

### D1: 计划整体备注存 `workout_plan` 新列，而非塞入 items jsonb

`workout_plan` 顶层字段（`name`、`mode`）均为显式列，整体备注与 `name` 同级，新增 `note text NULL` 列 + 同步 DTO/信封透传最自然。塞入 items jsonb 会破坏「items 为纯计划项数组」的既有契约，且 Team 快照重建、模板转换都要额外拆包。

- 备选：items jsonb 内嵌 `{planNote: ...}` 元对象 → 拒绝，破坏契约且各转换路径都要特判。

### D2: 计划动作备注存 PlanItem JSON 可选 `note` 键

与 v1.1-b2 的 `restAfterSetSeconds` 同模式：普通动作/递减组项直接挂 `note`；超级组项在其嵌套结构上挂 `note`。缺失即无备注，旧计划 JSON 无需迁移。同步继续由 `items` jsonb 透明承载，后端零改动。

### D3: 带入为一次性预填，绝不回写

`buildFromPlan`（含 Team 分享快照的直接开始与 Fork 后开始）在生成 `Workout`/`WorkoutExercise`/超级组时拷贝备注。之后训练中的备注编辑只落在训练聚合；`PlanWriteback` 显式排除 `note`（不回写、不进回执、不参与变化判定），严格/自适应行为一致——与休息字段不同，备注是「本次上下文」而非「处方」，回写会让模板被单次训练的感受污染。

### D4: 训练整体备注复用现有 `Workout.note` 列，只补 UI

后端列与同步早已就绪，本 change 只新增训练会话页的整体备注查看/编辑入口与已完成详情只读展示，交互对齐现有动作备注（trim、空存 nil、≤200 字）。

### D5: Team 分享复用休息字段的快照重建路径

客户端无重量快照重建逻辑在剥离重量时保留 `note` 键（与 v1.1-b2 保留休息键同一处）；服务端快照继续透明存 items jsonb + 计划整体备注随快照记录。checkin 快照与反馈事件逻辑不动。

### D6: 后端可独立先发

新列可空、信封字段可选：旧客户端不发 `note` 不受影响；新客户端连旧后端时整体备注仅本地留存（信封被忽略），不 crash。因此后端部署与 iOS 发版无先后顺序要求。

## Risks / Trade-offs

- [旧客户端（≤v1.1-b2）编辑并保存含备注的计划，重传信封会丢整体备注与动作备注] → 与休息字段一致的已知 LWW 风险，记录在发版文档；多设备用户建议同时升级，后续再评估字段保留策略。
- [备注随 Team 分享传播可能泄露作者本不想公开的文字] → 分享动作是作者显式发起，备注在计划详情对作者可见；在发版回归中要求作者分享前可见确认。
- [Workout.note 首次有 UI 后，历史存量数据该列全为 NULL] → 按无备注处理，无需回填。

## Migration Plan

1. 后端新增 `V21__workout_plan_note.sql`：`ALTER TABLE workout_plan ADD COLUMN note text;`（可空，无默认值，零数据迁移）。
2. 实体/DTO/同步信封加 `note` 透传；补充透传与旧信封（无 note）兼容测试。
3. 后端可随时先行部署；iOS 随 v1.1-b3 发版。
4. 回滚：后端回滚只需停止读取该列；列可保留不删（可空列无成本），如需严格回滚再 `DROP COLUMN`。

## Open Questions

- 计划详情中整体备注的展示位置（置顶横幅 vs 折叠区块）留到 UI 实现时按现有详情版式微调，不影响数据与行为契约。
