> 依赖：本 change 须在 `exercise-muscle-data` 与 `muscle-map-detailed-art` 归档后再实施（三者同改 `BuiltinExercise.swift`）。详见 design「依赖与排序」。

## 1. 分类枚举（iOS 端）

- [x] 1.1 新增 `Models/ExerciseCategory.swift`：`ExerciseCategory` 浏览父级枚举（~15 类，`String` rawValue=中文，附英文/显示名），含力量类与非肌群类（颈部/功能性/有氧/热身拉伸）
- [x] 1.2 定义 `ExerciseCategory` → `[MuscleRegion]` 父子映射（力量类有子级、非肌群类空），放同文件或扩展
- [x] 1.3 定义各父级的**子分类清单**（`ExerciseCategory` → `[String]`，无子分类的父级返回空），按 design D7 审查定稿表：
  - 胸→[上胸,中下胸]；背→[背阔,中背,下背]；肩→[前束,中束,后束]；腿→[股四头,腘绳肌]；臀→[臀大肌,臀中肌]；核心→[上腹,下腹,腹斜肌,核心稳定]；有氧→[稳态有氧,间歇·Tabata]；热身拉伸→[动态热身,静态拉伸,泡沫轴放松]
  - 无子分类（返回空）：二头/三头/前臂/小腿/斜方肌/颈部/功能性
  - 导入消歧（D7）：「腿弯举/腘绳/罗马尼亚/直腿硬拉」优先归 腿→腘绳肌（高于「弯举」归二头）；耸肩→斜方肌；提踵/小腿→小腿；兜底子类放匹配末位
- [x] 1.4 `EquipmentType` 扩展到 ~11 类：新增 `史密斯`/`悍马机`/`T杠`/`弹力带`/`悬挂`/`其他`（保持 `String` rawValue 中文）
- [x] 1.5 移除 `MuscleGroup`，全量迁移引用到 `ExerciseCategory`（编译器兜底找全引用点）
- [x] 1.6 单测：`ExerciseCategory` rawValue 无重复、父子映射覆盖全部 16 个 `MuscleRegion` 且非肌群类映射为空、`EquipmentType` rawValue 无重复；每个子分类的归属父级合法、子分类名在父级内无重复

## 2. 内置动作模型与现有 153 条迁移（iOS 端）

- [x] 2.1 `BuiltinExercise`：`primaryMuscle: String` 字段语义改为 `category`（值取自 `ExerciseCategory.rawValue`）；新增可选 `subcategory: String?`；`historyKey`/`code`/`primaryRegions`/`secondaryRegions`/`formCues` 不变
- [x] 2.2 现有 153 条迁移到新 `category`（粗类→对应父级）+ 标 `subcategory`（如卧推系列标上胸/中下胸，无细分的留 nil）+ 按 D2 新粒度重新打 `equipmentType` tag（如史密斯/悍马机/T杠 从「器械/杠铃」拆出）
- [x] 2.3 单测：现有 153 条 `code` 全部不变（防历史断裂）；每条 `category`/`equipmentType` 命中合法枚举值；`subcategory` 若非空必须属于其 `category` 的允许子分类清单

## 3. code 生成与导入数据集（iOS 端，体力活）

- [x] 3.1 按 D3 规则生成 `中文名 → code` 映射（语义英文 slug + 碰撞 `_2`），提交进仓库作唯一权威源
- [x] 3.2 去重（D4）：训记动作归一化匹配现有 153，重叠者复用旧 code、不新建；产出可疑重叠清单人工抽查
- [x] 3.3 导入 928 条到内置数据文件（按品类/肌群分文件避免单文件过大），每条含 `code`/`name`(训记中文名)/`category`/`subcategory`(可空)/`equipmentType`；拉伸/放松/泡沫轴/有氧/Tabata 类 `primaryRegions` 留空、子分类多留空
- [x] 3.4 单测：全库 `code` 唯一；映射表与导入数据一致；非力量类 `primaryRegions` 为空（验证高亮自动隐藏路径）；非空 `subcategory` 均属合法父级清单

## 4. 动作库 UI 双轴升级（iOS 端）

- [x] 4.1 `Workout/ExerciseViews.swift`：动作库改「细分部位（左栏/可滚动）× 器械（顶部 chip）」双轴正交筛选，沿用纸感样式，不引入写实配图
- [x] 4.1b 部位左栏支持**子分类展开**：选中有子分类的父级（如「胸」）时展开其子分类（上胸/中下胸）供二级收窄；选子分类则在父级基础上再过滤 `subcategory`；无子分类的父级不展开
- [x] 4.2 搜索框占位「搜索 {N} 个动作」N 同步到新合计；PR 副标保留
- [x] 4.3 自定义动作录入的肌群/器械 Picker 选项更新到 `ExerciseCategory`/扩展后 `EquipmentType`
- [x] 4.4 空态/降级：库空占位卡保留；非力量动作详情页高亮图按「空 region → 隐藏」降级

## 5. 同名历史合并（iOS 端，本地一次性迁移）

- [x] 5.1 实现迁移：扫描用户记录，凡 `historyKey` 当前等于某新内置动作 `name`（即旧手填/自定义，按 name 归并）者，改挂该内置动作 `code`
- [x] 5.2 迁移幂等可重跑 + 迁移前快照/日志（便于核对回滚）
- [x] 5.3 单测：构造「旧手填记录名==新内置名」场景，迁移后 historyKey 指向 code、历史曲线连续；无匹配时不动数据；重复执行无副作用

## 6. 验收

- [ ] 6.1 `xcodebuild build` + 测试 target 编译通过；训练记录/休息计时/PR/计划引用不回归
- [ ] 6.2 动作库双轴筛选可用：部位（含子分类展开，如胸→上胸/中下胸）× 器械 任意组合命中正确子集；搜索叠加筛选生效
- [ ] 6.3 现有 153 条 historyKey 不变、历史曲线不断裂；同名合并场景手工核对 1–2 例
- [x] 6.4 全库规模与分类分布抽查（与导入清单核对，无重复 code、无非法枚举值）

## 7. 长尾回填（第二层，分批，不阻塞上线）

- [ ] 7.1 力量类新动作分批回填 `primaryRegions`/`secondaryRegions`（沿用 `exercise-muscle-data` 回填规范）
- [ ] 7.2 力量类新动作分批补 `formCues`（≤22 字原创短句，自写规避版权）
- [ ] 7.3 每批回填后单测：该批动作主动肌非空 + ≥3 要点；高亮图渲染抽查
