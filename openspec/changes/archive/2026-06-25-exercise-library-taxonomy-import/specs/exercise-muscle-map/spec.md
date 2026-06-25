> 依赖：本增量 MODIFIES `exercise-muscle-map` 能力，须在 `exercise-muscle-data` 归档（该能力进入 `openspec/specs/`）后方可应用。

## MODIFIED Requirements

### Requirement: 内置动作细分肌群与要点

`BuiltinExercise` SHALL 提供 `primaryRegions: [MuscleRegion]`（主动肌）、`secondaryRegions: [MuscleRegion]`（协同肌）、`formCues: [String]`（动作要点）三字段。内置动作的浏览/筛选与 `historyKey` 归并由 `ExerciseCategory`（两级肌群浏览父级）承担——原 `primaryMuscle`（粗 8 类 `MuscleGroup`）已被 `ExerciseCategory` 取代并移除。`equipmentType`、`code` MUST 保留不变。region/要点为高亮与目标肌群展示服务，与浏览父级是同一套肌群的叶级；新动作回填前 region 可为空，高亮图按「空 region → 隐藏」降级。

#### Scenario: 卧推的肌群数据
- **WHEN** 读取 `BB_BENCH_PRESS`
- **THEN** `primaryRegions` 含 `chest`，`secondaryRegions` 含 `deltFront` 与 `triceps`，`formCues` 含至少 3 条要点

#### Scenario: 按部位父级筛选
- **WHEN** 动作库按「胸」部位轴筛选
- **THEN** 按 `category` 命中「胸」过滤（取代原 `primaryMuscle == "胸"`），其子 region 含 `chest`

#### Scenario: 协同肌可为空
- **WHEN** 某动作为孤立单关节动作、无明确协同肌
- **THEN** `secondaryRegions` 为空数组，渲染时仅主动肌染色

#### Scenario: 未回填力量动作降级
- **WHEN** 新导入力量动作尚未回填 region
- **THEN** `primaryRegions` 为空，高亮图隐藏，但动作可正常浏览/筛选/记录
