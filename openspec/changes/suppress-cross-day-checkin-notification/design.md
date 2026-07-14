## Context

Team checkin 由 iOS 离线队列在训练同步成功后提交。`checkinDate` 来自 `workout.startedAt` 的客户端本地日期，但请求可能因离线或弱网延迟到次日；后端当前在首次插入 checkin 后无条件发送“今天完成训练”的 APNs，因而会对历史补录产生错误通知。

## Goals / Non-Goals

**Goals:**

- 保留历史训练的 checkin 创建、日期归属、摘要更新和幂等语义。
- 仅为发送时仍属于客户端本地当日的首次 checkin 通知队友。
- 让即时分享和 pending 重放跨过午夜后得到一致结果。
- 保持旧版客户端请求兼容。

**Non-Goals:**

- 不调整数据库、幂等键、APNs 文案或 `PushService`。
- 不让服务端推断客户端时区，也不把静默结果写入 pending intent。
- 不改变历史 checkin 的展示或可见性。

## Decisions

1. `POST /checkins` 请求体新增 primitive `boolean suppressNotification`。Jackson 对缺失 primitive 字段使用 `false`，旧版客户端继续触发原通知行为；相比版本化 endpoint 或服务端时区推断，该方案改动更小且语义明确。
2. iOS 在每次构造并发送 `CheckInRequest` 时比较 `checkinDate` 与 `TeamService.dateOnly(.now)`。比较不在入队时执行，因此同一 pending intent 跨过本地午夜重放时会自动转为静默。
3. 后端无论是否静默都执行原有 checkin upsert。仅首次插入且 `suppressNotification == false` 时查询 Team 成员并调用通知，既保留补录又避免无用成员查询。
4. 现有幂等键和 `(team,user,workout)` upsert 保持不变；已存在 checkin 的摘要更新继续不重复通知。

## Risks / Trade-offs

- [旧版 iOS 不发送新字段，跨日补录仍可能推送] → 后端先部署保证兼容，新版 iOS 发布后获得精准修复。
- [客户端日期或时区设置错误会影响静默判断] → 以用户设备的本地自然日作为产品语义，不在服务端引入无法可靠获知的时区推断。
- [客户端可主动要求静默] → 该字段只降低通知，不扩大数据访问或写入权限，服务端仍执行原有成员与训练归属校验。

## Migration Plan

1. 先部署兼容新字段的后端；旧版客户端行为不变。
2. 再发布发送时计算静默标记的 iOS 版本。
3. 回滚 iOS 不影响后端；回滚后端前需确保新版客户端发送的额外 JSON 字段仍由旧配置忽略。

## Open Questions

无。
