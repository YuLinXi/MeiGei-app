## Context

当前 Team 详情页只调用 `GET /teams/{teamId}/checkins/feed?date=yyyy-MM-dd` 展示今日动态。后端 `team_checkin` 已经保存 `summary jsonb` 快照，iOS 的 `CheckinSummary` 也已包含 `exercises[].sets[]`，但 `FeedItemCard` 只渲染一句摘要，没有打开详情的入口。

个人训练历史已经有月历体验：月份标题、42 格月历、选中日期抽屉、月份档案 sheet。该 UI 适合 Team 历史，但现有 `WorkoutCalendarView` 绑定 `WorkoutHistoryStore`、`WorkoutRowSummary` 和本地 `WorkoutDetailView`，不能直接给 Team 使用。

Team 域是服务端权威，`team_checkin.workout_id` 是软指针无 FK，`summary` 是成交时刻快照。Team 历史必须遵守默认私有：只展示用户明确分享到该 Team 的 checkin。

## Goals / Non-Goals

**Goals:**

- 提供 Team 自创建以来的 checkin 历史月历。
- 今日动态与历史页的 checkin 都能打开动作/组详情。
- 个人历史与 Team 历史复用同一套日历布局和月份选择交互。
- 保持 Team 历史服务端权威，按月拉取，不进入 SwiftData。
- 详情仅依赖 `team_checkin.summary` 快照，不要求访问原始 `Workout`。

**Non-Goals:**

- 不做 Team 搜索、年度热力图、PR 榜单、趋势图或统计图。
- 不把 Team 历史同步进本地离线同步域。
- 不改变 checkin 写入、撤回、删除训练级联撤销、自动分享偏好的现有语义。
- 不让队友读取原始 `Workout` 聚合树。
- 不重做个人历史数据 projection。

## Decisions

### D1：Team 历史按月查询，而不是无限滚动分页

新增只读接口：

```text
GET /teams/{teamId}/checkins/history?month=yyyy-MM
```

返回该 Team 指定月份内的 checkin 与 reactions：

```json
{
  "checkins": [],
  "reactions": []
}
```

月份按 `team_checkin.checkin_date` 的自然月过滤，使用 `[monthStart, nextMonthStart)`。这是 LocalDate 字段，不做时区换算。客户端切换月份时按月拉取并缓存本页状态；下拉刷新重拉当前月。

选择按月接口的原因：

- 月历 UI 天然以月份为单位，避免客户端逐日循环请求。
- 数据规模可控：Team ≤10 人，一个月 checkin 数量有限。
- 实现比 cursor pagination 简单，适合 MVP。

备选方案是 `limit + before` 无限滚动，但它需要额外把流式结果映射回月历，月份选择也需要独立摘要接口，首版复杂度更高。

### D2：历史可见性以 checkin 为准

Team 历史展示所有当前仍存在的 `team_checkin`：

- 当前用户必须仍是该 Team 成员。
- 不按当前用户加入时间截断；当前成员可查看该 Team 自创建以来仍可见的 checkin。
- 已撤回 checkin、训练删除后被后端级联移除的 checkin、账号删除清理掉的 checkin 不返回。
- 从未分享到 Team 的个人训练不出现在 Team 历史。

这与 Team “训练默认私有、授权后可见”的数据治理一致。服务端只查询 `team_checkin`，不从成员个人 `workout` 表反推历史。

### D3：详情基于 summary 快照，不回查原始 Workout

Team checkin 详情使用 `TeamCheckinDTO.parsedSummary` 渲染：

- 标题、开始/结束时间、动作数、总组数、训练量。
- 每个动作名称。
- 每组重量与次数。

不通过 `workout_id` 读取 `workout/workout_exercise/workout_set`。原因：

- `workout_id` 是软指针，原始训练可能已删除或属于队友。
- `summary` 是分享时授权给 Team 的快照，隐私边界更清晰。
- 避免为队友训练详情新增跨用户 Workout 读取权限。

如果后续需要展示组类型、备注、PR 标记，应扩展 `CheckinSummary`，并保证旧 summary 解析降级。

### D4：抽取日历展示壳，Team/个人分别适配数据

从 `WorkoutCalendarView` 抽出通用 SwiftUI 组件，例如：

```text
CalendarHistoryScaffold<Row, Detail>
  ├─ 月份 Header / 月份选择 / 左右切月 / 今天
  ├─ 42 格 calendar grid
  ├─ selected day drawer
  └─ MonthArchiveSheet
```

通用值模型只表达 UI 需要的摘要：

```text
CalendarHistoryDaySummary<Row>
  - date
  - rows
  - countText
  - volumeText / secondaryText
  - badges

CalendarHistoryMonthSnapshot<Row>
  - monthStart
  - days[42]
  - monthSummaryText
```

个人历史适配器继续从 `WorkoutHistoryStore` 读取 projection，并点击进入 `WorkoutDetailView`。Team 历史适配器从 `TeamService` 按月读取 checkin，按 `checkinDate` 分组，并点击打开 `TeamCheckinDetailSheet`。

不直接让 `WorkoutCalendarView` 增加 Team 分支，避免把本地 SwiftData fetch、Team API、两套详情导航混在一个 view 里。

### D5：后端只读接口不需要幂等键，不新增同步信封

本 change 新增的是读接口，不需要 idempotency key。Team checkin 仍是服务端权威域，不进入客户端同步域，不新增 `serverId/localId/updatedAt/deletedAt/version`。删除训练、撤回 checkin、账号删除等既有写路径继续维护 `team_checkin` 可见集合。

需要补充的数据库能力是查询索引，而不是新表：

```sql
CREATE INDEX idx_checkin_team_month
ON team_checkin (team_id, checkin_date DESC, created_at DESC);
```

实际迁移名按当前 Flyway 序号追加。

## Risks / Trade-offs

- [Risk] 按月接口在极端高频 Team 中单月返回较多记录 → Team 规模上限为 10 人，MVP 可接受；必要时再加 `limit`。
- [Risk] 旧 `summary` 缺字段或解析失败导致详情空白 → iOS 使用现有 `parsedSummary` 兜底，并在详情中显示“训练快照不可用”的空状态。
- [Risk] 抽取日历壳过度泛型化导致复杂 → 只抽 UI 布局和值模型，不抽数据加载；Team/个人各自持有状态。
- [Risk] 当前成员可看加入前历史可能超出部分用户预期 → 这是“Team 自创建以来历史”的明确产品边界，进入 Team 即可查看 Team 既有公开 checkin；不展示未分享到 Team 的个人训练。
- [Risk] 个人历史和 Team 历史的月摘要口径不同 → UI 文案由适配器提供，不把“正式组/PR”等个人特有语义强塞给 Team。

## Migration Plan

1. 新增 Flyway 索引迁移，不改既有表结构。
2. 后端新增 `TeamCheckinFeed` 复用型响应或新 DTO，提供按月历史接口。
3. iOS 先抽通用日历壳并用个人历史回归验证视觉不变。
4. iOS 新增 Team 历史页，接入按月接口与详情 Sheet。
5. Team 详情页新增「历史训练」入口；今日动态卡片增加打开详情。

回滚时可隐藏 iOS 入口并保留只读接口；索引迁移无需回滚。

## Open Questions

- `CheckinSummary` 是否需要在本 change 内补充 `setType`、组备注或 PR 标记？当前需求只要求动作详情数据的重量/次数，首版不扩展。
- Team 历史页空月份是否展示“本月没有 Team 训练”还是保留当前个人历史的轻量空文案？建议实现时按 Team 语境单独写文案。
