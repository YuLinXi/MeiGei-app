## 1. 后端 API 与数据访问

- [ ] 1.1 新增 Flyway 迁移，为 `team_checkin(team_id, checkin_date DESC, created_at DESC)` 增加历史按月查询索引。
- [ ] 1.2 在 `TeamCheckinMapper` 增加按 `teamId + checkinDate` 月范围查询 checkin 的方法，排序为 `checkin_date DESC, created_at DESC`。
- [ ] 1.3 在 `CheckinService` 增加 `listCheckinHistory(userId, teamId, month)`：先校验 Team 成员身份，再查询该月 checkin 与 reactions。
- [ ] 1.4 在 `CheckinController` 增加只读接口 `GET /teams/{teamId}/checkins/history?month=yyyy-MM`，返回 checkins + reactions。
- [ ] 1.5 补充后端测试：成员可查、非成员拒绝、已撤回/删除 checkin 不返回、同月多日排序稳定。

## 2. iOS API 模型与服务

- [ ] 2.1 在 `TeamService` 增加按月读取 Team checkin 历史的方法，入参使用月份日期或 `yyyy-MM` 字符串。
- [ ] 2.2 复用或扩展 `TeamCheckinFeedDTO` 作为历史接口响应模型，确保 checkins 与 reactions 解码一致。
- [ ] 2.3 增加 Team 历史月数据的轻量 view state/value model：按日期分组 checkin、生成月摘要、生成月份档案所需数据。

## 3. iOS 日历组件复用

- [ ] 3.1 从 `WorkoutCalendarView` 抽取通用日历展示壳，覆盖月份 Header、左右切月、今天入口、42 格月历、选中日期抽屉。
- [ ] 3.2 抽取或泛化月份档案 Sheet，使个人历史与 Team 历史可复用年份分组、月份行、右侧年份索引。
- [ ] 3.3 改造个人 `WorkoutCalendarView` 使用通用日历壳，并保持现有个人历史行为与视觉不变。
- [ ] 3.4 为通用日历壳保留适配点：日格标题、副标题、月摘要、抽屉行、空状态、点击行行为。

## 4. iOS Team 历史与详情 UI

- [ ] 4.1 在 `TeamDetailView` 增加「历史训练」入口，导航到 Team 历史训练月历页。
- [ ] 4.2 新增 Team 历史训练月历页：按月加载 Team checkin 历史，支持切月、选月、今天、下拉刷新。
- [ ] 4.3 在 Team 历史月历日格与抽屉中展示 Team 语境摘要：成员名、训练标题、动作/组/训练量、同日数量提示。
- [ ] 4.4 新增 `TeamCheckinDetailSheet` 或等价详情视图，基于 `TeamCheckinDTO.parsedSummary` 展示标题、时间、动作数、组数、训练量、动作列表与每组重量/次数。
- [ ] 4.5 让今日动态 `FeedItemCard` 与 Team 历史行复用同一套详情入口。
- [ ] 4.6 为 `summary` 解析失败或空动作快照提供明确空状态，不显示 0 或伪数据。

## 5. 验证与回归

- [ ] 5.1 运行 `./gradlew test` 验证后端 Team 历史接口与既有 Team 行为。
- [ ] 5.2 运行 iOS simulator build，确认个人历史日历抽壳后无编译错误。
- [ ] 5.3 手工验证个人历史日历：切月、选月、今天、打开训练详情行为不变。
- [ ] 5.4 手工验证 Team 历史：今日动态可打开详情、历史月历按月加载、选中日期抽屉展示 checkin、详情展示动作与组。
- [ ] 5.5 运行 `openspec validate --all`，确认 proposal/design/spec/tasks 均合法。
