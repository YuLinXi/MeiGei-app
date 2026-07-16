## Why

Team 当前只能在队友训练后通过打卡和 emoji 互动，尚缺少训练前的轻量触达。增加一次性“拍一拍”可以让熟人小圈子自然地互相提醒训练，同时避免引入聊天、公开催促或社交压力。

## What Changes

- 在 Team 详情页的“今日已练”区域增加“拍一拍队友”入口，统一展示队友今日 Team 动态状态。
- 允许成员对今天尚无 Team 动态的队友发送一次“拍一拍”，并通过 APNs 告知对方是谁、来自哪个 Team。
- 增加服务端成员关系校验、当日去重和发送/接收限频，避免骚扰和跨 Team 滥用。
- 增加每个 Team 独立的“接收拍一拍”偏好；关闭后不接收该 Team 的催练通知。
- 将“训练完成后自动分享”和“接收拍一拍”作为 Team 详情页并列设置，新成员默认均为开启。
- 被拍成员完成 Team 打卡后，继续复用现有打卡动态与提醒闭环，不新增回复、聊天或历史页。

## Capabilities

### New Capabilities

- `team-workout-nudge`: 定义 Team 成员拍一拍、服务端限频、偏好与 APNs 通知契约。

### Modified Capabilities

- `team-ui`: 增加“拍一拍队友”入口、队友状态列表、拍一拍操作与接收偏好交互。
- `team-data-governance`: 将新 Team 成员的训练自动分享偏好默认值调整为开启。
- `workout-tracking`: 训练完成后继续按 Team 偏好分享，不再要求默认开启状态经过首次授权。

## Impact

- 后端：新增 `team_nudge` 数据表、Team nudge REST API、限频校验及 APNs 载荷。
- iOS：扩展 Team API model/service，并在 `TeamDetailView` 增加“拍一拍队友” sheet 和拍一拍交互。
- 数据库：增加 Flyway 迁移；`team_member` 增加按 Team 保存的接收偏好，并将自动分享默认值调整为开启。
- 依赖与公开 API：不新增第三方依赖；现有 API 保持兼容。

## Non-goals

- 不支持自定义文案、群发、回复、聊天、拍一拍历史、公开计数、排行榜或连续催促。
- 不将“没有 Team 动态”等同于“没有训练”，不使用“偷懒”“还没练”等判断性文案。
- 不新增 WebSocket、SwiftData 同步对象或通用通知中心。
- 不在本期增加定时清理任务；数据仅用于当日幂等和限频，不提供历史查询能力。
