## 1. 数据模型（iOS）

- [x] 1.1 新增 `WorkoutSetType: String, Codable, CaseIterable { case working, warmup }`
- [x] 1.2 `WorkoutSet` 加 `var setTypeRaw: String`，默认 `"working"`；init 增形参（默认 `.working`）
- [x] 1.3 `WorkoutSet` 加计算属性 `setType`（get 兜底 `.working` / set 写 raw）与 `var countsForStats: Bool { setType != .warmup }`
- [x] 1.4 确认 SwiftData 轻量迁移：新属性带默认值，旧本地记录读出为 `working`（无需手写 migration plan）

## 2. 统计判据（iOS，统一 `!= .warmup`）

- [x] 2.1 `PRStats.maxWeightByKey`：set 循环加 `where s.countsForStats`
- [x] 2.2 `PRStats.latestPR`：同上谓词，热身组不进 best / previousBest
- [x] 2.3 `WorkoutWeeklyStats`：volume / setCount / repCount 三项均只累加 `countsForStats` 的组
- [x] 2.4 历史强度曲线遍历处（动作详情/历史页）：只取正式组点
- [x] 2.5 全仓 grep `s.weightKg`/`ex.sets` 的统计型遍历，核对无遗漏口径（PR 徽标/识别、各 volume、曲线均已加谓词；进度型计数保留全组）

## 3. 录入交互（iOS）

- [x] 3.1 组行序号徽章改为可点：单击 toggle `working ⇄ warmup`（只读态不可点）；并在组级 ⋯ 菜单加「标为热身组/改回正式组」项提升可发现性（双入口共用 `WorkoutExercise.toggleSetType`）
- [x] 3.2 徽章显示：热身组显「热」（朱砂红浅底 pill）；正式组按「仅正式组相对序」重新编号 1..n
- [x] 3.3 排序：同动作内热身组吸顶（warmup 段在前、working 段在后，段内保持原序）；切换类型后重排+重算编号
- [x] 3.4 `WorkoutKeypad`「加一组」默认追加正式组，预填上一**正式**组重量（非热身）

## 4. 同步契约

- [x] 4.1 iOS `WorkoutSetDTO` 加 `var setType: String?`；编码写 `setTypeRaw`，解码缺失兜底 `working`
- [x] 4.2 SyncEngine set ↔ DTO 映射两向带上 setType
- [x] 4.3 后端 `entity/WorkoutSet.java` 加 `private String setType;`（`WorkoutTree` 内嵌实体，随 Jackson 自动序列化）
- [x] 4.4 旧客户端不带 setType push / 新客户端 pull 旧记录：两向兜底 `working` 验证（DTO `setType?` 解码兜底 + MyBatis-Plus `NOT_NULL` 策略省略 null → DB DEFAULT 兜底）

## 5. 后端迁移与持久化

- [x] 5.1 新增 `db/migration/V4__workout_set_type.sql`（V2/V3 已占用，顺延 V4）：`ALTER TABLE workout_set ADD COLUMN set_type text NOT NULL DEFAULT 'working';`
- [ ] 5.2 启动后端验证 Flyway 自动跑 V4、旧行回填 `working`、push/pull 往返带回 setType（需本机起 PG/后端，留待联调）

## 6. 验收

- [~] 6.1 后端 `./gradlew build -x test` 通过 ✓；iOS `xcodebuild` 受阻——本机未安装 iOS 26.4 平台/模拟器 runtime（环境限制，非代码问题），待装好组件后重跑
- [x] 6.2 代码层核对 spec 场景：默认/历史=正式组（init/解码/DB 默认 working）；徽章切换+重编号+热身吸顶（`displaySortedSets`+`badgeText`+`toggleType`）；加一组默认正式组（`lastWorkingWeight` 预填）；未识别值兜底（`setType` get 兜底 `.working`）
- [x] 6.3 统计场景：热身组不计 volume/组数/次数/PR/曲线（各遍历加 `countsForStats`），LogSetRow/SetRow 仍渲染热身组记录
- [x] 6.4 周聚合 MODIFIED：`WorkoutWeeklyStats` volume/setCount/repCount 三项均 `where s.countsForStats`，hero 即三宫格仅按正式组
- [x] 6.5 同步往返：push 写 `setTypeRaw`、pull 解码兜底 working、后端实体+列默认 working，旧↔新双向兼容
- [~] 6.6 模拟器目检：受阻于同 6.1 的环境限制，待 iOS 平台组件安装后人工目检
