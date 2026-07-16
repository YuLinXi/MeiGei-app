## Context

Team 属于服务端权威域，当前以 REST 拉取成员/打卡，以 APNs 提醒新打卡和表情回应。iOS 的 `TeamDetailView` 已同时持有成员与当日 checkin，可以直接派生成员今日状态；后端已有全局 `IdempotencyFilter` 和 `PushService`，无需建立聊天、WebSocket 或新的同步域。

“今天没有 Team 动态”只能说明成员没有向当前 Team 分享 checkin，不能推断其没有训练。因此产品文案和服务端资格判断都围绕 Team 可见动态，不使用“偷懒”“还没练”等表述。

## Goals / Non-Goals

**Goals:**

- Team 成员可对当日尚无 Team checkin 的队友发送一次轻量“拍一拍”。
- 服务端统一执行成员关系、Team 消息偏好、当日去重和跨 Team 限频。
- 接收方通过 APNs 得知发送者和 Team，点击后进入对应 Team。
- iOS 在现有 Team cover 卡提供易点击入口，并以“拍一拍队友” sheet 展示状态和操作。

**Non-Goals:**

- 不增加自定义文案、群发、回复、聊天、历史记录、公开计数或排行榜。
- 不把 nudge 建模为 SwiftData/LWW 同步对象，不增加 WebSocket。
- 不增加定时清理或通用通知路由框架。

## Decisions

### 1. 使用服务端权威的 `team_nudge` 事件表

新增 `team_nudge(id, team_id, sender_user_id, recipient_user_id, nudge_date, created_at)`，并对 `(team_id, sender_user_id, recipient_user_id, nudge_date)` 建唯一约束；另为发送者/接收者的当日限频查询建立索引。领域模型和新 API 使用 `receiveTeamNotifications` 表达统一 Team 消息偏好，按 Team 隔离；数据库暂时复用旧 `receive_workout_nudges` 物理列并映射到新字段，保留用户选择及旧后端回滚兼容性，但不再代表独立的拍一拍偏好。

身份只引用内部 `app_user.id`，不接触 Apple provider id。nudge 是服务端权威、短生命周期的交互事件，不属于离线同步对象，因此不增加 `serverId/localId/updatedAt/version` 同步信封，也不使用软删除；Team 软解散或成员退出后因成员校验立即不可再访问或触发旧记录，账号或 Team 残留被硬删时再由外键级联清理。

替代方案是只用 Redis/内存限频，但会在重启后丢失幂等状态，也不利于多实例一致性；当前 PostgreSQL 表更直接可靠。

### 2. REST 契约保持最小，仅暴露成员是否可出现在拍一拍列表

- `GET /teams/{teamId}/nudges/today`：返回服务端日期、当前发送者今日已拍的 `recipientUserIds`、允许接收拍一拍的其他成员 ID，以及当前用户在该 Team 的 Team 消息偏好。
- `POST /teams/{teamId}/members/{recipientUserId}/nudges`：必须带 `Idempotency-Key`；成功返回被拍成员和日期，不返回对方偏好或接收方限额。
- `PATCH /teams/{teamId}/members/me/notification-preferences`：必须带 `Idempotency-Key`，更新当前用户在该 Team 的统一 Team 消息偏好；旧 `nudge-preferences` 路径继续作为同一状态的兼容别名，不产生第二份偏好。

iOS 继续用现有 members + checkins 组合成员状态，并用可接收成员 ID 过滤 sheet；不为一次功能另建聚合成员接口。列表只暴露成员当前能否作为拍一拍接收者，不返回具体偏好字段。接收方在页面展示后关闭提醒或不再具备资格时，POST 仍只返回通用“暂时无法拍一拍该成员”。

### 3. 服务端使用 Asia/Shanghai 自然日并串行化配额检查

MVP 使用 `Asia/Shanghai` 自然日计算 nudge 日期和限频窗口，与当前主要用户和部署时区一致，客户端不能自行提交日期绕过限制。发送前在同一事务中按 UUID 固定顺序锁定发送者与接收者的 `app_user` 行，再检查/写入配额，避免并发请求突破上限或死锁。

规则为：同一发送者→接收者→Team 每日一次；发送者每日最多触达 5 位不同成员；接收者每日最多收到 3 条 APNs。接收者达到推送上限后仍记录本次成功 nudge，但静默抑制 APNs，调用方无法据此推断接收方配额。

替代方案是信任客户端日期或接受并发窗口，但会让限频可绕过；为此增加两行用户锁查询是可接受的最小一致性成本。

### 4. APNs 复用现有 `PushService`，点击事件走轻量通知路由

推送标题固定为“队友拍了拍你”，正文为“{发送者名称} 在「{Team 名称}」喊你一起练练”，自定义字段为 `type=team_nudge`、`teamId`。前台收到时刷新 Team 数据；用户点击通知时，`PushManager` 发布打开事件，`MainTabView` 切到 Team tab，`TeamListView` 选择对应 Team。

不引入通用 deep-link coordinator。若目标 Team 已解散或用户已退出，列表刷新后不导航，保持安全降级。

### 5. 成员 sheet 只承载拍一拍操作，Team 偏好留在详情页

cover 卡中的今日进度 pill 和整个头像栈都作为按钮打开 sheet，点击区域至少 44pt；重叠的 26pt 单个头像只负责展示。sheet 不展示标题或 Team 名小文案，列表排除本人，并将尚无 Team 动态与已有 Team 动态的队友分组，避免把状态表达成是否训练。

sheet 保留系统 drag indicator 与下滑关闭手势，不重复增加手动关闭按钮。列表排除本人和已关闭当前 Team 消息的成员。“拍一拍”使用 `hand.tap` SF Symbol，无二次确认。点击后轻触觉反馈并乐观切为“已拍”；请求失败则回滚并显示错误。详情页相邻展示“分享动态”和“Team消息”，后者统一控制拍一拍、队友打卡和表情回应推送，继续使用乐观更新和失败回滚。

### 6. 新 Team 成员的分享与消息偏好默认开启

新建或加入 Team 时，`auto_share_workouts` 与领域字段 `receiveTeamNotifications` 均写入 `true`。数据库默认值也统一为 `true`，防止遗漏字段的写入路径产生不同结果；旧物理列中的已有关闭选择原样保留。本地 dev seed 每次重置为默认开启，专用的“小满”关闭接收场景除外。

### 7. 偏好更新响应直接使用本次已保存值

更新 Team 消息偏好时，服务端完成成员校验和数据库 `UPDATE` 后，响应中的 `receiveTeamNotifications` 直接使用请求中已经写入的 `enabled`。不在同一事务内再次读取成员实体作为响应值，避免 MyBatis 一级缓存返回更新前状态，造成 iOS 乐观状态立即回跳。当日已拍列表和可接收成员列表仍按服务端权威查询返回。

### 8. 偏好保存期间保持 Toggle 视图身份

`Team消息` 仅在初次状态尚未加载时展示 `ProgressView`。用户切换后继续渲染同一个原生 `Toggle`，保持乐观值和固定布局，并通过 `.disabled(teamNotificationPreferenceBusy)` 阻止重复提交。保存失败仍按既有逻辑回滚并提示，不在请求期间用 spinner 替换开关。

### 9. 自定义成员查询显式映射兼容物理列

领域实体使用 `receiveTeamNotifications`，数据库为兼容旧客户端和旧后端继续保留 `receive_workout_nudges` 物理列。MyBatis-Plus 的 `@TableField` 只保证框架生成的 SQL 映射正确，自定义 `@Select` 不会自动把旧列名映射到已重命名的实体属性。因此所有返回 `TeamMember` 的自定义查询均显式将旧物理列别名为 `receive_team_notifications`，保证普通成员读取、事务锁行读取和批量成员读取使用同一偏好值。

## Risks / Trade-offs

- [跨时区用户在午夜附近看到的“今天”可能与服务端日期不同] → MVP 明确采用 Asia/Shanghai；后续有海外需求时再为账户保存 IANA timezone。
- [记录成功但 APNs 因凭据、系统权限或接收限额未展示] → API 只承诺 nudge 已记录，不承诺设备已展示；进入 Team 时仍可看到现有 Team 动态闭环。
- [旧客户端不知道新 push 类型] → payload 保留 `teamId`，旧客户端最多按现有 Team 推送刷新处理，不影响使用。
- [成员退出后历史 nudge 行暂时保留] → 所有读取/发送先校验当前成员关系，且数据不提供历史 API；账号/Team 硬删由外键级联清理。
- [偏好已写入但响应返回旧值] → 更新接口使用本次已保存值构造响应，并以服务测试覆盖关闭后开启的回跳场景。
- [保存期间替换控件导致设置卡抖动] → 只在首次加载时显示 spinner，保存期间保持原 Toggle 并临时禁用。
- [旧物理列与新领域属性名称不一致导致读取为默认 `false`] → 返回 `TeamMember` 的自定义查询显式设置列别名，并通过真实数据库与 Simulator 请求链路回归。

## Migration Plan

1. 先部署兼容旧字段与旧接口的后端 API；分享与 Team 消息偏好对新成员默认开启，已有成员的保存值不被覆盖。
2. 部署 iOS 客户端，入口仅在新版本出现。
3. 回滚 iOS 时后端表可保留；回滚后端代码时新增表和列不影响旧代码，待确认无新客户端流量后再单独清理。

## Open Questions

无。本 change 按上述 MVP 边界实现；海外时区与记录清理策略留待真实需求出现后再设计。
