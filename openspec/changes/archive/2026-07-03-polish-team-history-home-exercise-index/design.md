## Context

本 change 覆盖三个高频浏览路径，但不改变核心数据真相源：

- Team 历史训练已经有 `TeamCheckinHistoryView`、`TeamCheckinHistoryModels` 和 `TeamService.checkinHistory(teamId:month:)`。当前月份档案由 `loadedMonths.keys.min()` 推导最早月份，因此首次进入时通常只显示当前月，即使 Team 在上月已有 checkin 也无法从「选择月份」发现。
- 训练首页已有 `WorkoutHistoryStore.home.currentWeekStats` 与 `weekWorkouts`，周统计按本地周一 00:00 起算。首页可以继续复用这些本地派生数据展示一周完成状态。
- 动作库右侧已有竖向 `equipmentQuickFilter`，但它由多个 `Button` 叠在动作列表右侧，快速滑动时容易和动作 row tap 竞争，误入详情。

约束：Team 数据仍是服务端权威；Workout 数据仍由本地 SwiftData + 自写同步负责；本 change 不新增同步实体、不新增写接口、不引入第三方 UI 依赖。

## Goals / Non-Goals

**Goals:**

- Team 历史月份选择能展示完整可选月份范围，并允许用户直接进入历史月份加载数据。
- 首页提供周一到周日的训练完成勾选，让用户一眼看到本周节奏。
- 动作库右侧快速定位具备独立触控区，支持按下拖动连续切换，并避免误触动作卡片。
- 所有 UI 保持现有纸感 Theme token、紧凑工具型体验和可访问性语义。

**Non-Goals:**

- 不新增 Team checkin 本地 SwiftData 缓存，也不把 Team 历史变成离线优先同步域。
- 不新增手动打卡、补签、连续 streak、周目标设置或 Team 挑战。
- 不改变 `Workout` / `WorkoutSet` 同步协议，不持久化首页周勾选状态。
- 不重做动作库分类、搜索、器械数据源、肌群缩略图或动作详情。
- 不新增后端写接口；若后续必须补充只读月份摘要接口，也不纳入同步冲突模型。

## Decisions

1. Team 月份档案优先由客户端生成完整月份范围。

   - 做法：`TeamCheckinHistoryModels.archiveGroups` 增加最早可选月份参数，使用 `team.createdAt` 所在月到当前月生成月份列表；已加载月份展示真实天数、次数、容量和密度条，未加载月份展示中性占位或“点按加载”，不能展示“没有训练”。
   - 理由：现有服务端已经支持按月拉取历史，用户当前问题是月份入口不可达；先修入口，不为摘要额外设计 API。
   - 备选：新增 `GET /teams/{id}/checkins/months` 返回月份摘要。该方案能让月份 sheet 首次打开就有准确密度，但需要后端只读接口、DTO、测试和兼容处理，当前问题不必先走这条路。

2. 首页周勾选从 `WorkoutHistoryStore` 的首页快照派生。

   - 做法：在 `HomeWorkoutSnapshot` 增加本周 7 天状态或等价轻量模型，按 `weekWorkouts.startedAt` 聚合到周一到周日；`WorkoutListView` 在 hero 与本周训练列表之间展示一条紧凑周勾选条。
   - 理由：本周训练列表和统计已经来自同一派生快照，新增状态不会重复扫描全量历史，也符合“统计可重算、少存冗余”的原则。
   - 备选：直接在 `WorkoutListView.body` 中遍历 `weekWorkouts` 计算。数据量小但会把日期逻辑散到 View 中，不利于测试和后续复用。

3. 周勾选只表达“当天是否有完成训练”，不表达目标进度。

   - 做法：每日只有完成/未完成/今天三个可见状态；同日多次训练可在辅助文案里表达本周次数，但每日点位仍只勾一次。
   - 理由：当前没有周目标配置，也不应从截图照搬 `0/2` 目标语义；避免凭空新增目标体系。
   - 备选：按当前激活计划推断周目标。现有计划没有可靠周频次字段，推断会误导。

4. 动作库右侧索引改为单一手势控制面，而不是一串独立按钮。

   - 做法：抽出 `LibraryQuickIndex` 或等价子视图，提供固定宽度命中区；通过 `DragGesture(minimumDistance: 0)` 根据触点 y 坐标映射到索引项，进入/变化时给轻触反馈并更新筛选或滚动目标；命中区消费手势，动作列表 row 的 `Button` 不延伸到该区域。
   - 理由：iOS 通讯录式索引的核心是按下后连续滑动定位，而不是逐个小按钮点击。独立命中区能降低误触详情的概率。
   - 备选：继续使用按钮但扩大间距。按钮点击仍无法支持丝滑拖动，且右侧 overlay 与 row tap 的竞争没有本质变化。

5. 数据模型仍遵守 Day-1 铁律。

   - Team 历史为服务端权威只读查询，不新增写接口，因此不涉及幂等键。
   - 首页周勾选是本地派生视图状态，不作为同步对象上传；原始训练同步仍使用既有 `Workout` 同步信封和 last-write-wins。
   - 动作库索引是纯 UI 交互，不改 `CustomExercise` 软删除、同步字段或动作 manifest 主键。

## Risks / Trade-offs

- [Risk] 未加载月份在月份 sheet 中没有真实训练次数，用户可能以为没有数据。
  → Mitigation：未加载月份使用中性文案和淡化密度条，accessibility 不读“没有训练”；选择后立即加载并更新该月摘要。

- [Risk] Team `createdAt` 缺失或晚于历史 checkin 会导致月份范围仍不完整。
  → Mitigation：缺失时至少显示当前月和已加载月份范围；若发现线上数据存在该异常，再补只读月份摘要接口修正数据源。

- [Risk] 首页新增周勾选占用垂直空间，挤压核心 CTA 和本周训练列表。
  → Mitigation：做成单行紧凑组件，避免营销 hero；空周和已有训练都使用同一稳定高度。

- [Risk] 动作库索引拖拽时频繁更新筛选导致列表重建过多。
  → Mitigation：只在索引项变化时更新状态并触发 haptic；复用现有分页重置和 `scrollTo("LIB_TOP")` 逻辑，避免每个 drag tick 都刷新。

- [Risk] 自定义 VoiceOver 用户无法使用拖拽索引。
  → Mitigation：每个索引项提供可访问标签和可选择状态，保留单点点击/辅助功能选择路径。
