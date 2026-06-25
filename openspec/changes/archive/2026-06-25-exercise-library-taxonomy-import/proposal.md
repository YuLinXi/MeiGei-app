## Why

别练了当前内置动作仅 153 条，且动作库为**单轴粗筛选**——顶部 7 个粗肌群 chip（全部/胸/背/腿/肩/手臂/核心），没有器械筛选、没有子分类、没有臀/全身入口。作为「严肃健身工具」，动作覆盖面偏窄；更关键的是这套单轴分类**撑不住动作量增长**：一旦动作数到数百，一个「腿」chip 底下塞 200+ 动作将无法浏览。

业界成熟健身 App（如训记）已用**双轴 + 子分类**解决这个规模问题：细分部位（左栏，~15 类，部分带子分类）× 器械（顶部 chip，~11 类）。本 change 以训记公开的标准动作中文名表（`Foveluy/Xunji-movements`，1092 条，仅公开中文名、无内部 key、无版权敏感数据）为数据源，做两件互相绑定、缺一不可用的事：

1. **分类法升级**：把动作库从单轴粗筛选升级为「细分部位 × 器械」双轴；并把当前割裂的「粗 8 类浏览 / 细 16 区高亮」两套肌群**合并为一套两级肌群**。
2. **全量导入**：把训记里别练了尚未支持的动作（去归一化重复后 928 条）补入内置动作库，库规模 153 → 1081。

> 分类升级与数据导入**耦合**：只导数据不上双轴 = 库不可浏览；只上双轴不导数据 = 空架子。故合并为一个 change，但**分两层交付**（先名字/筛选可用，后长尾回填 region/要点）。

## What Changes

- **浏览分类轴升级为两级肌群（取代旧粗 8 类）**：新增 `ExerciseCategory` 浏览父级枚举（~15 类：胸/背/肩/斜方肌/二头/三头/前臂/腿/小腿/臀/腹(核心)/颈部/功能性/有氧/热身拉伸）。其中力量类父级与现有 `MuscleRegion`（16 区高亮叶级）建立**父→子**归属（如父级「肩」⊇ `deltFront`+`deltRear`），浏览与高亮从此是**同一套肌群的两级**；非肌群类（有氧/热身/功能性/颈部）无 region 子级、不显高亮。旧 `MuscleGroup`（粗 8 类）**移除**，其在筛选与 `historyKey` 归并中的职责由 `ExerciseCategory` 接管。
- **浏览部位轴支持子分类（三层结构：部位 → 子分类 → 动作）**：部分 `ExerciseCategory` 父级下挂可选的**子分类**层（如「胸」→ 上胸 / 中下胸，对齐训记左栏二级），落在 `BuiltinExercise` 的可选 `subcategory` 字段上。子分类**父级作用域内有效**、可为空（空=该父级下未细分/「全部」）；有氧/热身等非肌群父级一般不设子分类。动作库左栏点父级可展开其子分类做更细筛选。
- **器械类型扩展并拆细**：`EquipmentType` 从 6 类扩到 ~11 类：杠铃/哑铃/壶铃/器械/**史密斯**/**悍马机**/**T杠**/绳索/**弹力带**/**悬挂(TRX/吊环)**/自重/其他。悍马机、史密斯、T杠从原「器械/杠铃」拆出独立成类；现有 153 条按新粒度**重新打 tag**。
- **动作库 UI 升级为双轴**（`workout-tracking` 能力的「动作库版式」Requirement 修订）：左栏细分部位轴 + 顶部器械 chip 轴，二者正交筛选；保留搜索框与 PR 副标。配图沿用别练了**自绘纸感矢量**风格，**不引入训记的写实解剖线稿**。
- **全量导入 928 条动作**：每条含 `code`（语义英文 slug）+ `name`（训记中文名）+ `category`（`ExerciseCategory`）+ `equipmentType`。拉伸/放松/泡沫轴/有氧/Tabata 类**收录但 `primaryRegions` 留空**（模型既有「空 region → 高亮自动隐藏」行为，无需改渲染）。
- **code 生成方案**：`[器械前缀_]动作主体[_修饰]` 语义英文蛇形（如 `HAMMER_CHEST_PRESS`、`BAND_FACE_PULL`、`CARDIO_RUN`），与现有 153 风格一致；真碰撞才追加 `_2`；**一经发布即冻结**。产出 `中文名 → code` 映射表入仓库作唯一权威源。
- **去重与历史合并**：训记动作经归一化匹配到现有 153 条的，**复用旧 code、不新建**（保留其已回填的 region/要点）。导入动作名若**撞上用户已有手填/自定义动作名**，把旧历史按规则**自动合并**到新内置动作，避免同一动作历史曲线断成两条。

## Capabilities

### New Capabilities
- `exercise-library`: 动作库的分类法与内置动作数据契约——`ExerciseCategory` 两级肌群浏览轴 + 可选子分类层（三层结构）、扩展后的 `EquipmentType`、内置动作导入数据集、code 生成与冻结规则、去重与同名历史合并规则、非力量动作的收录与高亮降级。

### Modified Capabilities
- `workout-tracking`: 「动作库（ExerciseLibrary）版式」Requirement 由单轴部位 chip 改为「细分部位 × 器械」双轴筛选。
- `exercise-muscle-map`: 「内置动作细分肌群与要点」Requirement 中关于 `primaryMuscle`（粗 8 类）保留做筛选/归并的表述被修订——粗 8 类由 `ExerciseCategory` 取代（**依赖 `exercise-muscle-data` 先归档**，见 design「依赖与排序」）。

## Impact

- **iOS 模型层**：`Models/BuiltinExercise.swift`（`primaryMuscle: String` 语义改为 `category`，新增可选 `subcategory: String?`，重新打 equipment tag，追加 928 条数据）；新增 `Models/ExerciseCategory.swift`（含 `ExerciseCategory` 父级 + 各父级允许的子分类定义）；`MuscleGroup` 移除、引用处迁移到 `ExerciseCategory`；新增 `中文名→code` 映射与导入数据文件（按肌群/品类分文件，避免单文件过大）。
- **iOS 视图层**：`Workout/ExerciseViews.swift` 动作库改双轴筛选（左栏部位**+可展开子分类** + 顶部器械 chip）；自定义动作录入的肌群/器械 Picker 选项更新到新枚举。
- **historyKey**：`builtinCode ?? customId ?? name` 计算式不变；但「同名合并」需一次性迁移逻辑（把匹配到的旧自定义/手填记录改挂新内置 code）。
- **同步契约**：`BuiltinExercise` 仍为随包**只读静态数据**，不入同步域；本 change **不改** `WorkoutPlan`/`Workout`/`CustomExercise` 的同步聚合与 LWW/幂等约定。同名历史合并是**本地一次性数据迁移**，不新增同步实体。
- **依赖**：依赖 `exercise-muscle-data` 与 `muscle-map-detailed-art` 先完成并归档（三者同改 `BuiltinExercise.swift`，避免交错冲突）。
- **非影响**：不改后端（内置动作随包发布、无后端动作库下发）；不动训练记录/休息计时/Team。

## Non-goals

- **不做**训记写实解剖线稿配图、动图/视频演示、第三方解剖图直接引用——配图沿用别练了自绘纸感矢量（与 `exercise-muscle-data` 一致）。
- **不做**「饮食」tab 或任何饮食相关分类（饮食模块已于 2026-06-01 整体移除，勿复刻训记图中的训练/饮食切换）。
- **不做**全部 928 条新动作的 region/要点回填即时完成——本 change 先交付「名字/筛选/可被计划引用」，region/要点作为长尾数据债分肌群逐批回填（详见 design「迁移分层」）。
- **不做**「置顶」个性化常用——留二期。
- **不做**后端动作库下发、动作的云同步——内置动作继续随包只读发布。
- **不做**自定义动作（`CustomExercise`）的 category/region 录入升级——沿用现有自定义动作行为。
