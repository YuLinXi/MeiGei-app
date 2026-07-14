## Why

离线训练可能在次日才补同步并自动分享到 Team，当前后端会把历史日期的补录误当作“今天完成训练”向队友发送 APNs。需要保留历史 checkin 的正确归属，同时避免跨日补录产生误导性通知。

## What Changes

- `POST /checkins` 增加可选的 `suppressNotification` 布尔字段，缺失时保持现有通知行为。
- iOS 在每次实际发送 checkin 请求时，将 `checkinDate` 与客户端当前本地日期比较；历史日期请求静默，当日请求正常通知。
- 后端始终创建或更新 checkin，仅在首次创建且未要求静默时通知同 Team 的其他成员。
- 即时分享和 pending 队列重放使用同一发送时判断，跨过午夜的重试自动转为静默。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `team-sharing`: 明确跨日补录仍写入原 checkin 日期，但不得向 Team 成员发送“今天完成训练”的通知。

## Impact

- API：`POST /checkins` 请求体新增向后兼容的可选字段。
- 后端：`CheckinController`、`CheckinService` 及其单元测试。
- iOS：`CheckInRequest`、`TeamService` 及日期判断单元测试。
- 无数据库迁移、无新依赖，不修改幂等键、pending intent 结构、APNs 文案或 `PushService`。

## Non-goals

- 不改变 checkin 的日期归属、历史展示或 upsert 语义。
- 不由服务端推断客户端时区或当前本地日期。
- 不补偿或撤回已经发送的通知。
