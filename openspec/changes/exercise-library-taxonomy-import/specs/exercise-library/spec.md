## ADDED Requirements

### Requirement: 动作浏览分类轴（两级肌群）

系统 SHALL 定义 `ExerciseCategory` 浏览父级枚举，作为动作库浏览/筛选的部位轴，取代原 `MuscleGroup`（粗 8 类）。`ExerciseCategory` MUST 同时覆盖力量类（如 胸/背/肩/斜方肌/二头/三头/前臂/腿/小腿/臀/腹(核心)）与非肌群类（颈部/功能性/有氧/热身拉伸）。力量类父级 MUST 与 `MuscleRegion`（16 区高亮叶级）建立父→子归属映射；非肌群类 MUST 映射为空 region 集合。每个 case 的 rawValue 为中文、附显示名。`historyKey`（`builtinCode ?? customId ?? name`）计算式 MUST NOT 改变。

#### Scenario: 父级覆盖全部高亮区
- **WHEN** 汇总所有力量类 `ExerciseCategory` 的子 `MuscleRegion`
- **THEN** 恰好覆盖全部 16 个 `MuscleRegion`，且每个 region 归属唯一父级

#### Scenario: 非肌群类无高亮子级
- **WHEN** 取「有氧」「热身拉伸」「功能性」「颈部」等非肌群父级的 region 子集
- **THEN** 为空集合，这些品类下的动作不渲染肌群高亮图

#### Scenario: 粗 8 类筛选职责平移
- **WHEN** 用户按部位轴筛选（如「胸」）
- **THEN** 行为对齐原粗类筛选（命中该父级的动作），不依赖已移除的 `MuscleGroup`

### Requirement: 部位子分类（三层浏览结构）

系统 SHALL 支持「部位（`ExerciseCategory` 父级）→ 子分类 → 动作」三层浏览结构。`ExerciseCategory` MUST 为每个父级声明其允许的子分类列表（可为空——表示该父级不细分）。`BuiltinExercise` SHALL 提供可选字段 `subcategory: String?`：非空时其值 MUST 属于该动作 `category` 的允许子分类列表；为空表示该父级下未细分（归「全部」）。子分类 MUST 仅在其父级作用域内有效（如「上胸」仅属「胸」），MUST NOT 作为全局枚举跨父级复用。子分类服务浏览收窄，与 `MuscleRegion`（高亮叶级）正交，MUST NOT 替代高亮数据。

#### Scenario: 胸分上胸与中下胸
- **WHEN** 读取「胸」父级的子分类列表
- **THEN** 至少含「上胸」「中下胸」；上斜卧推类动作 `subcategory` 为「上胸」，平/下斜卧推类为「中下胸」

#### Scenario: 子分类归属合法
- **WHEN** 任一内置动作的 `subcategory` 非空
- **THEN** 该值必属于其 `category` 的允许子分类列表，否则校验失败

#### Scenario: 父级无子分类或动作未细分
- **WHEN** 某父级（如「有氧」「二头」）未声明子分类，或某动作 `subcategory` 为空
- **THEN** 该父级下不出现二级筛选，动作直接归该父级「全部」，浏览/筛选不受影响

### Requirement: 器械类型扩展与拆细

系统 SHALL 把 `EquipmentType` 从 6 类扩展到约 11 类，新增 `史密斯`、`悍马机`、`T杠`、`弹力带`、`悬挂`（TRX/吊环）、`其他`。悍马机、史密斯、T杠 MUST 作为独立类型，从原「器械/杠铃」拆出。所有 rawValue MUST 为中文且无重复。现有内置动作 MUST 按新粒度重新标注 `equipmentType`，且重标注 MUST NOT 改变其 `code`。

#### Scenario: 史密斯动作重标注但 code 不变
- **WHEN** 现有 `SMITH_BENCH_PRESS` 的 `equipmentType` 由「器械」改为「史密斯」
- **THEN** 其 `code` 保持 `SMITH_BENCH_PRESS` 不变，依赖 code 的历史归并不受影响

#### Scenario: 器械轴可独立筛选
- **WHEN** 用户在器械轴选择「弹力带」
- **THEN** 列表过滤为 `equipmentType == "弹力带"` 的动作，与部位轴正交叠加

### Requirement: 内置动作 code 生成与冻结

每个内置动作 SHALL 拥有唯一、稳定、随包发布的 `code`，作为 `historyKey` 第一主键。新导入动作的 `code` MUST 按「`[器械前缀_]动作主体[_修饰]` 语义英文蛇形」规则由中文名生成，与训记内部序号无关；真碰撞时 MUST 以确定性规则追加 `_2`/`_3`。系统 MUST 维护一份 `中文名 → code` 映射作为唯一权威源。已发布的 `code` MUST NOT 被重算或变更。

#### Scenario: code 全库唯一
- **WHEN** 校验内置动作集（现有 153 + 新导入 928）
- **THEN** 所有 `code` 唯一，无重复

#### Scenario: code 与训记序号无关
- **WHEN** 训记动作表的序号发生变化或某动作下架
- **THEN** 别练了已发布动作的 `code` 不受影响、保持不变

### Requirement: 训记动作全量导入与去重

系统 SHALL 把训记标准动作表中别练了尚未支持的动作导入内置动作库，每条含 `code`、`name`（训记中文名）、`category`（`ExerciseCategory`）、`equipmentType`。拉伸/放松/泡沫轴/有氧/Tabata 等非力量动作 MUST 被收录，但其 `primaryRegions` MUST 为空（触发高亮自动隐藏）。导入前 MUST 对训记动作做归一化匹配；命中现有内置动作的，MUST 复用现有条目与其 `code`，MUST NOT 新建重复条目。

#### Scenario: 非力量动作收录且不显高亮
- **WHEN** 导入「泡沫轴小腿放松」「跑步」「开合跳-Tabata」等
- **THEN** 它们作为内置动作可被搜索/筛选/计划引用，但 `primaryRegions` 为空，详情页不渲染肌群高亮图

#### Scenario: 概念重叠复用旧 code
- **WHEN** 训记「史密斯机卧推」经归一化匹配到现有 `SMITH_BENCH_PRESS`
- **THEN** 不新建条目，沿用现有 `SMITH_BENCH_PRESS`（含其已回填 region/要点与现名）

#### Scenario: 力量类新动作可后续回填
- **WHEN** 新导入的力量动作尚未回填 region/要点
- **THEN** 该动作可正常浏览/筛选/记录/被计划引用，高亮图按「空 region → 隐藏」降级，不阻塞任何流程

### Requirement: 同名动作历史自动合并

导入内置动作时，若某内置动作的 `name` 撞上用户已有的手填/自定义动作名（其历史此前按 `name` 归并），系统 SHALL 执行一次性本地迁移，把这些旧记录改挂到该内置动作的 `code`，使同一动作的历史曲线连续。该迁移 MUST 仅在本地进行，MUST NOT 新增同步实体或改动 LWW/幂等约定，且 MUST 幂等（可安全重跑）。

#### Scenario: 旧手填记录并入新内置动作
- **WHEN** 用户过去以手填名「战绳」记录过训练，现导入内置「战绳」(code `CARDIO_BATTLE_ROPE`)
- **THEN** 旧记录的 `historyKey` 迁移为指向 `CARDIO_BATTLE_ROPE`，历史曲线连续不断裂

#### Scenario: 无同名不动数据
- **WHEN** 用户无与任何新内置动作同名的历史/自定义动作
- **THEN** 迁移不改动任何记录

#### Scenario: 迁移幂等
- **WHEN** 同名合并迁移被重复执行
- **THEN** 结果与执行一次相同，无重复迁移或数据损坏
