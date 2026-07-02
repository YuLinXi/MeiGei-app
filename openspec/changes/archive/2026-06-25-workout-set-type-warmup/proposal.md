## Why

当前每一组（`WorkoutSet`）一视同仁，没有「正式组 / 热身组」之分。后果是**热身组污染了所有统计口径**：周训练量 `Σ weightKg×reps`、总组数/总次数、PR 最大重量、历史强度曲线全都把热身的轻重量算了进去，让「严肃健身工具」的核心数字失真。业界（Strong / Hevy / RP）的标准答案是把「组类型」做成**单组级别的标签**：热身组记录照留、但不计入正式组统计，且视觉上与正式组区分（热身显「热」、正式组从 1 重新编号）。

本 change 引入组类型，**当前只落 `working`（正式组）/ `warmup`（热身组）两种**，但用**可扩展枚举**承载，给后续正式类组类型留好口子，加新类型时无需改数据结构与统计判据。历史数据无迁移成本：新字段默认 `working`，旧记录天然全是正式组。

## What Changes

- **数据模型新增组类型**：`WorkoutSet` 增 `setTypeRaw: String`（默认 `"working"`），由可扩展枚举 `WorkoutSetType { working, warmup }` 承载（raw-string 存储，复刻现有 `SyncStatus`/`syncStatusRaw` 风格）。后端 `workout_set` 加 `set_type text NOT NULL DEFAULT 'working'`（`V2` 迁移）+ 实体字段；同步 set DTO 两端带上该字段。
- **统一统计判据 `正式组 = setType != .warmup`**：PR（`PRStats.maxWeightByKey` / `latestPR`）、周聚合（训练量 / 总组数 / 总次数）、历史强度曲线一律排除热身组。判据写成「`!= warmup`」而非「`== working`」，使将来新增的正式类组类型自动归入「正式」、无需再改统计代码。
- **录入交互（徽章 + ⋯ 菜单双入口）**：组序号徽章可点击在 `正式组 ⇄ 热身组` 间切换（当前两态，toggle），组级 ⋯ 菜单亦提供「标为热身组/改回正式组」项提升可发现性；热身组徽章显「热」（朱砂红浅底 pill）、正式组按 1/2/3… 重新编号（仅正式组参与编号）。
- **热身组自动吸顶**：同一动作下，热身组强制排在正式组之前；正式组之间保持用户手动顺序。
- **BREAKING（统计口径，非数据破坏）**：已有记录里若被用户回标为热身组，则该组不再计入上述统计——这是口径变化，旧训练数据本身不动、默认仍全为正式组。

## Capabilities

### New Capabilities
<!-- 无新增 capability -->

### Modified Capabilities
- `workout-tracking`: 新增「组类型（正式组/热身组）枚举与录入」「热身组排除于统计与 PR」两条 requirement；修改「训练首页周聚合视图」requirement，明确总组数/总次数仅计正式组。

## Impact

- **数据模型（iOS）**：`Models/Workout.swift` 的 `WorkoutSet` 加 `setTypeRaw` 属性（默认值）；新增 `WorkoutSetType` 枚举 + `WorkoutSet.setType` 计算属性。
- **数据模型（后端）**：新增 `db/migration/V4__workout_set_type.sql`（V2/V3 已占用，顺延 V4；`ALTER TABLE workout_set ADD COLUMN set_type text NOT NULL DEFAULT 'working'`）；`entity/WorkoutSet.java` 加 `setType` 字段。
- **统计（iOS）**：`Workout/PRStats.swift`（两个方法）、`Workout/WorkoutWeeklyStats.swift`（volume/setCount/repCount）、历史强度曲线遍历处统一加 `setType != .warmup` 谓词。
- **同步契约**：`Networking/APIModels.swift` 的 `WorkoutSetDTO` 加 `setType`；后端 `WorkoutTree` 直接内嵌 `WorkoutSet` 实体，加列+字段即随 Jackson 上线；set 走聚合全量替换，无 LWW 逐字段冲突。
- **UI（iOS）**：`Workout/WorkoutDetailView.swift`（或组行渲染处）徽章点击切类型、正式组重编号、热身吸顶排序；`Workout/WorkoutKeypad.swift` 的「加一组」默认追加正式组。
- **非影响**：不改休息计时 / Live Activity / Team / 计划模块；不引入其它组类型的具体行为（仅留枚举扩展位）。

## Non-goals

- **不做**其它组类型的录入与展示——仅保证枚举可扩展。
- **不做**热身组的自动推荐/自动生成（如按正式组重量反推热身阶梯）。
- **不做**为组类型新增独立同步信封——`WorkoutSet` 仍是聚合孙节点，随 workout 整树全量替换。
- **不做**历史数据的批量重标——旧记录默认全为正式组，是否回标由用户在编辑态逐组操作。
