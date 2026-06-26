## Why

Team 当前只展示「今日动态」，成员无法回看 Team 自创建以来已经分享到该 Team 的训练记录；同时今日动态只展示一句摘要，虽然 `team_checkin.summary` 已经包含动作与组详情，但 UI 没有提供查看入口。

这个 change 将 Team 训练可见性从“今天的 feed”扩展为“可按月历回看的 Team checkin 历史”，并复用个人历史日历的交互模型，降低新设计成本。

## What Changes

- Team 详情页新增「历史训练」入口，进入 Team 月历式历史页。
- Team 历史页按月份展示该 Team 自创建以来仍可见的 checkin，支持月份切换、月份选择和选中日期抽屉。
- Team 今日动态和 Team 历史页中的 checkin 都可打开详情。
- Checkin 详情基于 `team_checkin.summary` 快照展示每个动作、每一组重量与次数；不回查原始 `Workout` 聚合。
- 后端新增按月获取 Team checkin 历史的只读接口，并返回该月 checkin 与 reaction，供客户端按日期聚合。
- 明确 Team 历史边界：展示的是“已分享到该 Team 且未撤回/未删除的 checkin”，不是成员个人训练的全量历史。
- 当前成员可查看该 Team 自创建以来的可见 checkin，不按加入时间截断。

## Non-goals

- 不提供 Team 全局搜索、年度热力图、PR 排行榜、复杂统计图或趋势图。
- 不开放队友原始 `Workout` 聚合读取权限；详情只使用 checkin 快照。
- 不恢复已撤回、已随训练删除移除、或从未分享到 Team 的训练。
- 不改变训练默认私有、自动分享偏好、按次撤回和 emoji reaction 的既有语义。
- 不把个人历史日历的数据源改为服务端接口；个人历史仍使用本地 projection。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `team-sharing`: 增加 Team checkin 历史查询、可见性边界、按月历史读取与详情快照语义。
- `team-ui`: 增加 Team 历史月历页、今日动态/历史列表共用的 checkin 详情展示，以及与个人历史日历一致的交互要求。

## Impact

- 后端 Team API：新增只读历史接口，例如 `GET /teams/{teamId}/checkins/history?month=yyyy-MM`。
- 后端数据访问：`team_checkin` 增加按 team + 月份范围倒序查询；可能需要补充 `(team_id, checkin_date DESC, created_at DESC)` 索引。
- iOS Team：新增 Team 历史页、checkin 详情 Sheet、按月加载与 reaction 聚合。
- iOS 日历 UI：抽取个人历史日历的通用壳或共享组件，让个人历史与 Team 历史复用布局、月份选择、日格和抽屉行为。
- OpenSpec：更新 `team-sharing` 与 `team-ui` 的要求，明确历史可见性与详情展示。
