## Context

当前 Team 计划共享直接复用 `WorkoutPlan.sharedToTeamId`：作者把自己的同步域计划挂到 Team，成员从 Team 列表 Fork。这个模型实现简单，但产品语义是“作者计划持续暴露给 Team”，不适合新的决策：Team 中流通的应是一次“分享到 Team”的无重量快照版本，成员 Fork 或直接开始后都不接受后续更新。

训练首页当前会根据 active plan 自动把 CTA 变成“从某计划开始”。这把“快速记录今天真实训练”和“明确选择计划执行”混在一起。本 change 将首页 CTA 收敛为无计划自由训练，并在完成后提供“保存为计划模板”，让计划从真实训练中沉淀。

Team 域仍是服务端权威；个人 `WorkoutPlan` 和 `Workout` 仍是离线优先同步域。新能力必须保持默认私有、幂等写入、软删除和 LWW 同步边界。

## Goals / Non-Goals

**Goals:**

- 首页“开始训练”始终创建无计划训练。
- 完成无计划训练或 Team 分享计划直接开始的训练后，可显式保存为个人计划模板。
- “分享到 Team”生成无重量、不可变的分享计划版本。
- Team 成员可从分享版本 Fork 为个人计划，或直接开始一次训练。
- Fork 和直接开始只保留软关联，不接收作者后续版本更新。
- Team 计划页展示友好的计划卡与聚合反馈：复制人数、总完成次数。
- 未分享训练详情时，只记录最小化反馈事件，不暴露训练内容。

**Non-Goals:**

- 不做分享计划版本的增量更新、订阅同步、远程覆盖或 Fork 合并。
- 不做作者向成员分配计划、强制完成、排行榜或完成率考核。
- 不把 Team 分享计划放入 SwiftData 同步域。
- 不改变个人计划自适应回写规则；只有明确来源于个人 `WorkoutPlan` 的训练才回写该计划。
- 不让 Team 计划反馈事件替代 Team checkin；二者隐私边界不同。

## Decisions

### D1：首页 CTA 永远创建无计划训练

训练首页底部 CTA 不再读取 active plan，也不再调用 `start(from:)`。它只创建空白 `Workout(planId: nil)` 并进入训练记录页。计划执行入口保留在个人计划详情页和 Team 分享计划页。

选择这个方案的原因：

- 首页是“马上记录”的入口，不负责猜测用户今天要练哪个模板。
- 避免用户误以为首页推荐计划会自动回写或影响某个计划。
- 计划详情页仍保留明确的“开始训练”，不会削弱计划能力。

备选方案是保留 active plan 但增加“空白训练”二级入口；这会继续让首页承担计划选择心智，和本 change 的目标相反。

### D2：完成后保存计划是显式行动卡，不是结束确认的一部分

结束训练仍先完成既有归档副作用：清理未完成组、PR 检测、HealthKit、自动分享 Team、休息计时停止。归档完成后，在完成页展示“保存为计划模板”行动卡。

保存规则：

- 只对 `Workout.planId == nil` 的训练默认展示；其中包括首页空白训练和 Team 分享计划直接开始训练。
- 用户点“保存为计划”后打开 sheet，填写名称、模式、分组。
- 默认名称来自训练标题；没有标题时使用日期类默认名。
- 默认模式为 `adaptive`。
- 计划项按训练动作顺序生成，只使用已完成的正式组推导处方。
- 个人计划是私有同步实体，可以保留用户自己的重量、组数、次数；后续分享到 Team 时再剥离重量。

备选方案是结束训练时弹出第二个确认弹窗；这会叠加在已有结束训练二次确认之后，干扰归档主流程。

### D3：Team 分享计划使用服务端权威的分享线索 + 不可变版本

新增服务端权威数据模型，替代把 `WorkoutPlan.shared_to_team_id` 作为 Team 计划列表的事实来源：

```text
team_plan_share
  id uuid
  team_id uuid
  owner_user_id uuid
  source_plan_id uuid nullable  -- 软指针，不设 FK 到同步域计划
  title text
  latest_version_id uuid nullable
  created_at / updated_at / deleted_at / version

team_plan_share_version
  id uuid
  share_id uuid
  version_number int
  plan_name_snapshot text
  mode text nullable     -- 兼容旧版本字段；客户端不展示、不强制继承
  items jsonb              -- 无重量快照，保留稳定 itemId、动作引用、名称快照、组数、次数
  created_at
```

服务端在用户“分享到 Team”时读取该用户自己的 `WorkoutPlan`，校验 Team 成员身份，剥离所有重量字段，创建新版本。若同一用户将同一来源计划再次分享到同一 Team，则追加新版本并更新 `latest_version_id`；Team 计划页默认展示最新版本。分享计划不把作者的计划模式作为使用规则，客户端不展示版本号或模式，采用后由使用者自行决定个人计划模式。

新版 iOS 在分享请求中会携带当前本地计划名与 items 快照，服务端仍校验 `sourcePlanId` 归属；若服务端已有该计划则验证归属，随后以客户端快照生成无重量版本，避免弱网下先依赖 `syncAll()` 上传个人计划再分享而固化旧版本。旧客户端仍可只传 `sourcePlanId`，由服务端读取已同步的计划生成快照。

Day-1 铁律落实：

- 身份仍通过 `owner_user_id/user_id` 指向 `app_user.id`，不使用 Apple ID。
- “分享到 Team”“Fork 分享版本”“记录采用/完成反馈”都是写接口，必须要求幂等键。
- `team_plan_share` 是 Team 服务端权威域，带软删除和乐观锁版本；不带同步信封。
- 个人 Fork 出来的 `WorkoutPlan` 仍是同步实体，带 `serverId/localId/updatedAt/deletedAt/version/syncStatus`。
- `source_plan_id` 和 `latest_version_id` 都按软指针处理，作者删除原计划不破坏 Team 历史分享版本。

备选方案是继续复用 `workout_plan.shared_to_team_id` 并在每次编辑时重新计算 Team 展示；这会重新引入持续联动，不符合“快照版本”语义。

### D4：Fork 与直接开始都从版本快照生成，且只保留软关联

Fork 分享版本时，服务端创建新的个人 `WorkoutPlan`：

- `items` 来自版本快照，继续无重量。
- `mode` 默认使用当前用户侧的默认模式（首版为 `adaptive`），不继承作者模式；用户可在个人计划里自行调整。
- `forkedFrom` 可继续保存原计划软指针；新增或复用字段保存 `forkedFromShareVersionId` 更准确。
- 新计划默认私有，`sharedToTeamId == nil`，不复制发布者分组。

直接开始训练时，iOS 从版本快照生成一次 `Workout`：

- `Workout.planId == nil`，避免触发个人计划自适应回写。
- 训练本地保留 `sourceShareVersionId` / `sourceShareId` / `sourcePlanNameSnapshot` 等软关联，用于完成后的反馈事件和 UI 说明。
- 预填规则使用分享版本中的动作、组数、次数；不继承作者模式，按使用者侧自适应预填能力生成本次训练。重量为空或沿用使用者自己的个人历史预填能力。

备选方案是直接开始时先隐式 Fork 再从 Fork 计划开始；这会制造用户不想管理的个人计划，也会让“直接开始”失去意义。

### D5：反馈统计使用最小化事件，不复用 checkin

新增最小化反馈事件：

```text
team_plan_share_event
  id uuid
  team_id uuid
  share_id uuid
  version_id uuid
  user_id uuid
  event_type text  -- fork / direct_start / complete
  workout_id uuid nullable  -- 软指针，仅用于幂等去重，不对外展示
  event_date date nullable
  created_at timestamptz
```

Team 计划页聚合展示：

- “N 人复制”：按用户去重统计 `fork` 事件；直接开始训练不算复制。
- “总共 M 次完成”：统计全部 `complete` 事件数量，不按周过滤。
- 完成事件不包含训练 summary、重量、次数、动作组详情。
- 完成事件不创建 Team checkin；只有既有自动分享/按次分享才创建 Team checkin。
- `direct_start.workout_id` 与 `complete.workout_id` 是软指针和幂等辅助；训练尚未同步到后端时也可先记录完成反馈，若后端已存在该 workout 则校验归属。
- iOS 记录反馈事件时先写入本地 pending 队列，再发请求；请求成功后移除，弱网、取消或训练尚未同步时保留待下次同步后重试，避免完成反馈长期丢失。

备选方案是从 Team checkin 反推计划完成次数；这会漏掉未分享训练详情的用户，也会把反馈统计和隐私可见性耦合在一起。

### D6：接口按“分享版本”建模，保留旧接口兼容窗口

建议新增或替换为以下语义接口：

```text
POST /teams/{teamId}/plan-shares
  body: { sourcePlanId, planNameSnapshot?, items? }
  Idempotency-Key: required

GET /teams/{teamId}/plan-shares
  returns latest version cards + copy/total completion stats

POST /teams/plan-share-versions/{versionId}/fork
  Idempotency-Key: required

POST /teams/plan-share-versions/{versionId}/events
  body: { eventType, workoutId?, eventDate? }
  Idempotency-Key: required
```

旧的 `GET /teams/{teamId}/plans`、`POST /teams/{teamId}/plans/{planId}`、`POST /teams/plans/{planId}/fork` 可以在过渡期保留，内部转调新模型或返回最新分享版本，避免旧 TestFlight 客户端立刻失效。

### D7：自动同步提示使用全局非阻塞顶部胶囊

`SyncEngine.syncAll()` 已经串行化自动同步并暴露 `isSyncing`。iOS 根视图在该状态为 true 时展示一个顶部小胶囊；若同步很快完成，UI 仍保留约 1.2 秒，避免一闪而过。

展示边界：

- 只表达“同步中”，首版不展示百分比；当前同步过程没有稳定的跨域进度分母，强行显示百分比会误导用户。
- 胶囊挂在 App 根层，覆盖所有 Tab 和子页。
- 胶囊关闭命中测试，不拦截滚动、点击、表单输入或训练记录操作。
- 与既有全局消息共存时，全局消息向下错位，避免重叠。
- 连续同步触发时取消隐藏延迟并保持显示，避免顶部提示闪烁。

备选方案是在每个页面各自展示加载状态；这会遗漏后台自动同步，也会让同步反馈分散在页面实现里。

### D8：进行中训练使用全局浮层，不改变当前路由

进行中的训练不是普通详情页，而是贯穿 App 的全局状态。App 有进行中训练时，所有主页面和 push 子页面上都应显示训练中悬浮窗；点击悬浮窗展开训练记录浮层，收起后回到用户原本所在页面和导航层级。

实现边界：

- 根层持有 `WorkoutPresentationCenter`，作为训练浮层展开/收起的单一状态源。
- 训练首页、个人计划详情、Team 计划页等入口创建或继续 workout 后，只请求全局 presenter 展开，不再各自 push `WorkoutLoggingView`。
- 展开训练浮层不切换 Tab、不清空 `NavigationStack`，保留用户当前浏览上下文。
- 训练浮层左上角使用专用最小化按钮，视觉表达“收起到悬浮窗”，不复用普通返回箭头。
- 已完成训练历史详情仍使用普通 navigation 页面，不改成全局浮层。

备选方案是开始训练时强制切回训练首页；这能简化导航，但会打断用户从计划详情或 Team 计划页开始训练后的上下文，不符合“训练中也能继续操作 App”的目标。

## Risks / Trade-offs

- [Risk] 新增分享/版本/事件三张表提高实现量 → 这是换取“快照版本、无联动、可统计”的必要复杂度；Team 规模小，查询和聚合都可保持简单。
- [Risk] “不分享训练也计入完成次数”可能被误解为公开训练 → UI 必须明确说明只计入聚合，不展示训练内容。
- [Risk] 同一 Team 人数很少时聚合数字可能被猜出是谁 → 不展示单人明细、不推送未分享完成事件，首版仅在计划卡上展示聚合数。
- [Risk] 首页移除 active plan 可能影响习惯从首页开始计划的用户 → 计划详情页保留明确开始入口，Team 计划页也提供直接开始入口。
- [Risk] 旧 `sharedToTeamId` 数据与新模型并存 → 通过迁移生成 v1 分享版本，并保留旧接口兼容窗口。
- [Risk] 直接开始训练离线完成时反馈事件可能发送失败 → 客户端应像 pending share 一样保留待发送反馈事件；失败不影响训练归档。

## Migration Plan

1. 后端新增 `team_plan_share`、`team_plan_share_version`、`team_plan_share_event` 表与索引。
2. 数据迁移扫描非删除且 `shared_to_team_id IS NOT NULL` 的 `workout_plan`，为每个旧共享计划创建一条分享线索和 v1 无重量版本。
3. 后端新增分享版本与反馈统计接口，同时让旧 Team 计划接口在兼容期读取新模型。
4. iOS 先改首页 CTA 和完成页保存计划模板，确保基础训练闭环可独立工作。
5. iOS 改个人计划“分享到 Team”入口和 Team 计划页，接入新分享版本接口。
6. iOS 接入 Team 分享版本直接开始训练与反馈事件队列。
7. 验证新版客户端稳定后，再考虑移除或降级旧 `sharedToTeamId` UI 语义；数据库字段可继续保留兼容同步 DTO。

回滚策略：后端保留旧接口和旧字段时，可隐藏新版 iOS 入口并让旧 Team 计划列表继续工作；新增表无需立即回滚。

## Open Questions

- `forkedFromShareVersionId` / `sourceShareVersionId` 是否要进入 `WorkoutPlan`、`Workout` 同步 DTO，还是先只存在本地与反馈队列中？为了跨设备一致和完成反馈可靠，建议进入 DTO。
- 直接开始训练时是否使用个人历史预填重量？产品要求 Team 分享计划不展示重量，但成员自己的历史预填不泄露作者隐私。建议允许沿用个人历史预填。
- 完成次数口径已定为累计总量，不再接收客户端周起始参与聚合。
