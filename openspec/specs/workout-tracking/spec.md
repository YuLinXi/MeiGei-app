## Purpose

定义 DontLift 训练核心三屏（训练首页 / 训练进行中 / 动作详情）与 Live Activity 的行为规约。训练记录、休息计时、动作库的基础行为以现有实现为准；本 spec 聚焦视觉强度升级后的可观察行为与边界条件（empty state、placeholder、PR 元素配色独占）。
## Requirements
### Requirement: 训练首页周聚合视图

iOS 训练首页 SHALL 在顶部展示「本周训练量」hero（按本地时区周一 00:00 为周起点），并以两宫格展示本周「总组数 / 总次数」。聚合数据 MUST 按需即时计算自本地 `Workout` 集合，不入库。App MUST NOT 展示或计算「平均时长」统计。当本周训练数为 0 时，hero MUST NOT 显示「0.0 t」字面量，而 SHALL 展示鼓励性 Empty State 文案与「开始第 1 次训练」CTA。

#### Scenario: 本周已有训练
- **WHEN** 用户进入训练首页，本周已记录 4 次训练，总训练量 28.4 吨
- **THEN** Hero 显示「28.4 t」并附副标「已完成 4 / Y 次」（Y 为当前激活计划的周训练目标次数，无激活计划时改为「本周第 4 次训练」）

#### Scenario: 本周尚未训练
- **WHEN** 本周训练数为 0
- **THEN** Hero 显示「准备好了吗？」文案与「开始第 1 次训练」CTA，不显示「0.0 t」

#### Scenario: 两宫格缺值
- **WHEN** 某一项聚合为 0
- **THEN** 显示「—」而非「0」

### Requirement: 训练进行中浮动休息圆环

训练进行中页 SHALL 在剩余休息时间 > 0 时，于屏幕右下（Tab Bar 之上 16pt 间距）渲染一个浮动圆环 FAB，包含圆环进度（按 `restEndDate` 与原始 `restDuration` 比例计算）与中心 `MM:SS` 剩余时间。FAB 倒计时 MUST 与 Live Activity 共享同一墙钟 `endDate`。点击 FAB SHALL 展开为全屏遮罩的休息计时弹窗，弹窗 MUST 提供「−10s / +10s / 完成」三键与下一组提示，关闭弹窗 SHALL 退回浮动 FAB 形态。

#### Scenario: 完成一组后 FAB 出现
- **WHEN** 用户标记当前组完成并设置 60 秒休息
- **THEN** FAB 在 60 秒内从 100% 圆环递减至 0%，剩余秒数实时更新

#### Scenario: 展开弹窗后 ±10s
- **WHEN** 用户在弹窗中点击 +10s
- **THEN** 圆环对应延长 10 秒，FAB 折叠后剩余时间一致

#### Scenario: 倒计时归零
- **WHEN** `restRemaining <= 0`
- **THEN** FAB 淡出隐藏，弹窗如展开中则自动关闭

### Requirement: 训练相关 UI 视觉基线

训练首页、训练进行中、动作详情、休息计时、PR 庆祝等训练相关界面 SHALL 使用 `design-system` 提供的纸感 Theme Token 渲染（纸白底 / 近黑文字 / 朱砂红强调 / 纸感阴影）。强调色统一为 `Theme.Color.accent`（朱砂红），PR 元素与普通 CTA 共用，MUST NOT 出现霓虹辉光或青/品红强调色。

#### Scenario: CTA 使用朱砂红
- **WHEN** 渲染训练首页 CTA「开始今日训练」
- **THEN** CTA 使用 `Theme.Color.accent` 实底白字 + `paperShadow`，无任何辉光

#### Scenario: PR 元素使用朱砂红
- **WHEN** 动作详情页或庆祝弹窗存在 PR 数据
- **THEN** PR 徽标/竖条/数值使用 `Theme.Color.accent`，不再使用品红

### Requirement: 训练历史与 PR 识别

系统 SHALL 提供训练日历（按日期查看已完成训练）与单动作历史曲线（默认展示重量趋势）。系统 SHALL 在保存训练时自动识别个人记录（PR）并给予提示。统计数据 MUST 可由原始记录重算，系统 SHOULD 避免持久化冗余统计结果。

为支持大规模历史数据，客户端 UI 的常规渲染路径 MUST NOT 直接订阅完整训练聚合树并在视图 `body` 或 computed property 中反复全量扫描 `Workout` / `WorkoutExercise` / `WorkoutSet`。客户端 SHOULD 使用窄查询、时间范围切片、fetch limit、内存派生快照或可重建本地索引来提供首页摘要、PR、动作历史曲线与计划预填。

#### Scenario: 查看动作历史曲线
- **WHEN** 用户打开某个动作的历史
- **THEN** 系统以时间为横轴展示该动作的重量趋势曲线
- **AND** 客户端仅加载该动作相关的历史序列或读取派生快照，不因打开单个动作而订阅全部训练聚合树

#### Scenario: 自动识别 PR
- **WHEN** 用户某动作本次的重量超过其历史最大值
- **THEN** 系统标记该次为新 PR 并向用户展示庆祝提示
- **AND** PR 判定结果 MUST 可由原始训练记录重建

#### Scenario: 大历史库首页可交互
- **GIVEN** 本地存在至少 1000 条已完成训练记录
- **WHEN** 用户打开训练首页
- **THEN** 首页 SHALL 展示本周摘要、最近训练和开始训练 CTA
- **AND** 首页 MUST NOT 在每次渲染时遍历全部历史训练的所有动作与组

#### Scenario: 导入历史后统计一致
- **GIVEN** 用户导入大量历史训练记录
- **WHEN** 客户端完成本地派生快照或索引重建
- **THEN** 首页摘要、动作 PR、动作历史曲线、计划自适应预填 SHALL 与从原始训练记录完整重算的结果一致
- **AND** 派生快照或索引丢失时系统 SHALL 能从原始训练记录重新构建

#### Scenario: 派生数据不参与同步冲突
- **WHEN** 客户端为提升性能维护本地派生快照或索引
- **THEN** 这些派生数据 MUST NOT 作为云同步真相源上传
- **AND** 训练记录同步冲突仍 SHALL 依据原始同步实体的 last-write-wins 规则处理

### Requirement: 动作库（ExerciseLibrary）版式

`ExerciseLibraryView` SHALL 采用**训记式左栏版式 + 解剖三级树导航**：导航栏（标题「动作」+ 右上 `+`）+ 搜索框（占位「搜索 {N} 个动作」，N=去噪后内置+自定义合计）下方，主体分**左栏部位轴**与**右侧动作区**两栏。

**左栏（解剖树，竖排）** SHALL 固定窄宽竖列：顶部「全部」「我的（自定义）」+ 全部 11 个 L1 部位，每项带数量角标；超屏自身可纵向滚动。有下级的节点 MUST 支持**逐级就地手风琴展开**：L1 展开 L2，L2 再展开 L3，点哪一级即过滤到哪一级。若某 L1 只有一个 L2 且该 L2 有 L3，UI SHALL 折叠这个唯一 L2，直接展示 L3（如「胸→上胸/中下胸」「肩→前束/中束/后束」），但内部筛选仍使用完整 L2/L3。无下级的节点 MUST NOT 展开。**MUST NOT** 以独立横滚 chip 行承载部位/肌肉/肌头任一级。

**右侧动作区** SHALL 顶部渲染**器械轴** `HorizontalChipPicker`（`EquipmentType`），与解剖树**正交叠加**；下方动作列表按**解剖树层级分段**：选「全部」按 L1 分段，选某 L1 按其 L2 分段，选某 L2 按其 L3 分段（无下级则平铺）。若该 L1 命中单一 L2 折叠规则，则选 L1 后直接按 L3 分段。**MUST NOT** 使用「复合推/拉/腿/单关节」等动作模式分组。同段内 curated 内置动作 SHALL 优先排序。

每个动作行 SHALL 显示 thumb（部位图/首字占位）+ 中文名 + 归属副标（部位·肌肉/肌区·器械；命中单一 L2 折叠规则时不显示被折叠的 L2）+ 右侧最新 PR 副标。配图 MUST 沿用别练了自绘纸感风格，MUST NOT 引入第三方写实解剖线稿。

搜索框 SHALL 做**中文模糊匹配**：query 按空格拆为关键词，名称 MUST 包含**全部**关键词（顺序无关、大小写不敏感）方为命中。MUST NOT 实现拼音、英文 code、别名、相关度排序、debounce 或预建索引。query 非空时搜索 MUST 作为**全局通道**——忽略左栏 L1/L2/L3 选择、对全库匹配、结果按 L1 分段、左栏选中态淡化；器械 chip 仍叠加。query 清空后 MUST 回到左栏当前选择的浏览态。

#### Scenario: 左栏纵览 11 部位
- **WHEN** 进入动作库
- **THEN** 左栏竖排可见「全部 / 我的」+ 11 个 L1 部位（含手臂/颈部/功能性等），各带数量角标；无需横滑发现部位

#### Scenario: 三级逐级下钻
- **WHEN** 用户点 L1「胸」展开其下级并点「上胸」
- **THEN** UI 直接显示「胸→上胸/中下胸」，右侧过滤为内部链「胸→胸大肌→上胸」命中者；点无下级的节点（如 L2「背阔肌」）不再展开、右侧平铺该 L2

#### Scenario: 右侧按树层级分段
- **WHEN** 用户在左栏选 L1「胸」
- **THEN** 因「胸」只有一个 L2 且有 L3，右侧直接按「上胸/中下胸」分段；选「全部」按 L1 分段；多 L2 部位仍先按 L2 分段；**不**出现「单关节」等动作模式伪分组

#### Scenario: 器械轴正交叠加
- **WHEN** 左栏选「胸 → 上胸」、器械轴选「哑铃」
- **THEN** 右侧过滤为内部命中「胸→胸大肌→上胸」且 `equipmentType=="哑铃"` 者；任一轴留「全部」则该轴不约束

#### Scenario: 自定义动作入口与并段
- **WHEN** 用户点左栏「我的」
- **THEN** 右侧只显示未删除的自定义动作；改选某具体部位时，该部位下的自定义动作按 `primaryMuscle` 并入对应段

#### Scenario: 中文模糊多关键词搜索
- **WHEN** 用户输入「杠铃 卧推」（或「卧推 杠铃」）
- **THEN** 命中名称同时含「杠铃」与「卧推」者（如「平板杠铃卧推」），顺序无关；搜索期间忽略左栏选择、全库匹配并按 L1 分段、左栏选中态淡化

#### Scenario: 命中 PR 副标
- **WHEN** 某动作历史最佳 1RM > 0
- **THEN** 行右侧副标显示「PR · {重量}」mono 字体，按当前单位（kg / lb）

#### Scenario: 数据库空
- **WHEN** 内置动作 0 条且自定义 0 条
- **THEN** 右侧渲染单张占位卡「动作库尚未采集，点右上 + 添加自定义动作」+ CTA

### Requirement: 计划列表（PlanList）版式

`PlanListView` SHALL 按计划分组展示用户的训练计划。计划列表 MUST NOT 使用「最近在用」计划置顶 featured 卡；所有计划 MUST 使用同一种标准计划卡片。计划页不再通过视觉强调表达 active/featured/最近使用状态。

计划列表 SHALL 按以下结构渲染：

- 非删除的 `WorkoutPlanGroup` 按 `sortOrder` 升序展示；同值时按 `updatedAt` 倒序兜底。
- 每个分组下展示 `groupId` 指向该分组的非删除计划。
- 组内计划按 `sortOrder` 升序展示；同值时按 `updatedAt` 倒序兜底。
- `groupId == nil`、引用缺失分组或引用已删除分组的计划 SHALL 展示在「未分组」。
- 「未分组」默认排在实体分组之后。
- 当没有任何计划且没有任何分组时，显示全局空状态。

每张标准计划卡 SHALL 至少包含：

- 计划名。
- 当前模式（严格 / 自适应）。
- 动作数与总组数。
- 模式行为摘要。
- 可由本地训练记录重算的使用摘要，例如累计训练次数与上次训练时间。

计划卡 MUST NOT 因最近使用而切换为更大尺寸、左侧强调条、三列 meta featured 卡、渐变或额外强调阴影。「最近在用」判定 MAY 继续用于训练首页 CTA 的默认计划选择，但 MUST NOT 影响计划 Tab 的排序与视觉层级。

「推荐模板」段在内置动作库数据采集完成前 MUST NOT 渲染（连同其段标题 eyebrow）。

#### Scenario: 按分组展示计划
- **GIVEN** 用户有分组「胸背」「腿」与若干计划
- **WHEN** 用户进入计划页
- **THEN** 页面 SHALL 先展示「胸背」分组及其计划
- **AND** 再按分组 `sortOrder` 展示其它分组
- **AND** 未归属任何分组的计划 SHALL 展示在「未分组」

#### Scenario: 所有计划卡片标准化
- **GIVEN** 用户有多个计划，其中某计划最近 14 天内被训练过
- **WHEN** 用户进入计划页
- **THEN** 该计划 MUST NOT 以 featured 卡或置顶富卡展示
- **AND** 所有计划 SHALL 使用同一种标准计划卡片

#### Scenario: 计划页排序不受最近使用影响
- **GIVEN** 计划 A 最近训练过，计划 B 未训练但排序在 A 前
- **WHEN** 用户进入计划页
- **THEN** 计划 B 仍 SHALL 按 `sortOrder` 排在计划 A 前
- **AND** 最近使用状态不应改变计划 Tab 的排序

#### Scenario: 无计划无分组
- **WHEN** 用户没有任何计划且没有任何分组
- **THEN** 计划页 SHALL 显示全局空状态，引导新建计划或新建分组

#### Scenario: 推荐模板段在数据未就绪时隐藏
- **WHEN** 内置动作库数据尚未采集完成，用户进入计划页
- **THEN** 页面 MUST NOT 渲染「推荐模板」段标题或占位卡

### Requirement: 计划详情（PlanDetail）版式

`PlanDetailView` SHALL 顶部 navbar 显示返回按钮 + 三点菜单；下方 eyebrow（如「PLAN · 训练模板」）+ 大标题（计划名，多行 `Theme.Font` Hero/L1）+ 3 列 meta（动作数 / 组数 / 当前模式）。动作列表 SHALL 用 `ScrollView` + 自绘 row card，每行：左侧 mono 两位序号（`01`/`02`，`Theme.Color.accent` 着色）+ 中间动作名 + 下次有效处方 mono 副标 + 来源说明 + 右侧 chevron/handle。

计划详情 SHALL 展示该计划的模式标识（严格 / 自适应），并 SHALL 提供查看该模式回写规则说明的入口（自适应模式说明至少含：组数/次数/重量按实绩更新、训练中新增动作并入计划、跳过的动作保留需手动删）。计划列表与计划详情 MUST NOT 展示按公式估算的预计时长；原预计时长位置 MUST 替换为当前模式或下次依据。

#### Scenario: 展示模式标识
- **WHEN** 用户进入一个自适应计划的详情页
- **THEN** 页面显示「自适应」模式标识，且可查看其回写规则说明

#### Scenario: 预计时长位置展示模式
- **WHEN** 用户查看计划列表或计划详情
- **THEN** 页面不显示「预计」或「≈N 分钟」这类估算时长
- **AND** 原预计时长位置显示当前模式「严格」或「自适应」

#### Scenario: 添加动作占位行
- **WHEN** 计划详情列表渲染结束
- **THEN** 末尾固定一张 dashed `border2` 占位卡「＋ 添加动作」，点击 push 到动作选择器。

#### Scenario: 底部 CTA
- **WHEN** 渲染计划详情
- **THEN** 底部固定一行：左侧 ghost 按钮（白底 + `border` 描边「复制」）+ 右侧 primary 按钮「开始训练 →」(`accent` 实底白字 + `paperShadow`)。

#### Scenario: 计划 JSON 解码失败
- **WHEN** 计划 items 字段解码失败
- **THEN** 列表区显示单张红色占位卡「计划数据损坏，请重建」`Theme.Color.danger`，DEBUG 构建 OSLog 打印原始 payload 前 200 字符。

### Requirement: 训练计划模式（严格 / 自适应）

每个训练计划（`WorkoutPlan`）SHALL 带一个**模式**，由可扩展枚举承载，当前取值为 `strict`（严格）与 `adaptive`（自适应），默认 `adaptive`。新建计划与任何未识别的模式值 MUST 视为 `adaptive`，以保证旧数据与跨版本兼容。

- **严格模式**：编辑计划项时，动作、组数、次数 MUST 为必填，重量为选填。语义为「照剧本执行」——开始训练时整组复制预设（见「开始训练预填落值」），完成训练时 MUST NOT 回写计划。
- **自适应模式**：编辑计划项时，仅动作 MUST 为必填，组数 / 次数 / 重量均为选填。语义为「记录我的进化」——首次/无历史用计划预设落值，完成训练后 MUST 按「自适应模式实绩回写计划」对来源计划做 upsert 回写。

新建计划页 SHALL 在计划名称下方提供严格 / 自适应模式选择，并 SHALL 展示与编辑页一致的模式说明文案。模式 SHALL 在计划详情页以可见标识呈现，并 SHALL 向用户提供该模式回写规则的说明（自适应模式至少说明：组数/次数/重量按实绩更新、训练中新增动作并入计划、训练中跳过的动作保留需手动删）。计划详情右上角更多操作菜单 MUST NOT 展示计划模式入口；模式说明/切换入口 SHALL 由计划详情页正文中的模式说明卡承载。「严格」MUST 仅约束「初始预填来源为整组复制」，MUST NOT 锁定训练中的临场改值与打勾。

计划模式 sheet SHALL 采用「草稿选择」语义：用户点选严格 / 自适应选项时 MUST NOT 立即写入 `WorkoutPlan.mode` 或标脏；只有点击右上角「确定」且通过二次确认后，系统才 SHALL 持久化新模式。若用户选择严格模式但计划项缺少组数或次数，系统 SHALL 在点击「确定」时提示补齐，且 MUST NOT 展示二次确认或保存变更。

#### Scenario: 新建计划默认自适应
- **WHEN** 用户新建一个训练计划
- **THEN** 模式选择默认选中 `adaptive`，编辑时仅「动作」为必填项

#### Scenario: 新建计划可直接选择严格模式
- **WHEN** 用户在新建计划页选择严格模式并保存
- **THEN** 新计划模式为 `strict`，并在后续添加动作时按严格模式必填校验

#### Scenario: 切换到严格模式需补齐必填
- **WHEN** 用户把某自适应计划切换为严格模式，而其中某动作缺组数或次数
- **THEN** 系统 SHALL 提示补齐严格模式必填项（动作 + 组数 + 次数）后方可完成切换

#### Scenario: 模式切换需确定与二次确认
- **WHEN** 用户在计划模式 sheet 中点选另一个模式
- **THEN** 计划模式不会立即变化
- **AND** 用户点击「确定」后，系统展示二次确认
- **AND** 仅当用户确认后，计划模式才被保存并标脏同步

#### Scenario: 更多菜单不展示模式入口
- **WHEN** 用户进入计划详情页并打开右上角更多操作菜单
- **THEN** 菜单不包含「计划模式」或模式切换入口

#### Scenario: 未识别模式兜底
- **WHEN** 客户端读到本端未识别的计划模式值（如来自更高版本）
- **THEN** 按 `adaptive` 处理，不崩溃

### Requirement: 开始训练预填落值与未打勾组清理

从计划开始训练时，预填值 MUST **真正写入** `WorkoutSet.weightKg/reps`（落值），且新建组 `completed` MUST 为 `false`；MUST NOT 仅以占位/灰字展示。「是否计入统计」与「是否真实完成」一律由 `completed` 区分。

- **严格模式**：`buildFromPlan` MUST 按 `suggestedSets`（缺省按业务默认）建组，并把 `suggestedReps` 与 `suggestedWeightKg`（若有）整组落值到每一组。
- **自适应模式**：MUST 优先用「上次同动作 completed 实绩」落值（若存在历史，按 `historyKey` 命中）；无历史时回退用计划 `suggested*` 落值；若缺少计划组数且无历史，默认生成 4 组。

每个由计划项生成的 `WorkoutExercise` MUST 携带其来源 `PlanItem.itemId`（`planItemId`）；训练中临时新增、非来自计划的动作 `planItemId` MUST 为 `nil`。

结束训练时，未 `completed` 的预填残留组 MUST 被丢弃，使训练记录与后续回写只含真实发生的数据。

#### Scenario: 严格模式整组落值
- **WHEN** 用户从一个严格计划（卧推 4 组 × 8 次 × 60kg）开始训练
- **THEN** 生成 4 个 `WorkoutSet`，每组 `weightKg=60、reps=8、completed=false`；用户对实际完成的组打勾即可，无需重输数字

#### Scenario: 自适应模式历史优先落值
- **WHEN** 用户从自适应计划开始训练，且该动作上次 completed 实绩为逐组 62.5kg×8
- **THEN** 各组按上次同序号 completed 值落值（如 62.5kg×8），计划 `suggested*` 仅在无历史时作为回退

#### Scenario: 新增计划动作默认生成 4×10
- **WHEN** 用户在计划详情里添加一个新动作
- **THEN** 计划项默认保存 `suggestedSets=4` 与 `suggestedReps=10`
- **AND** 下次从该计划开始训练时，此动作直接生成 4 个 `reps=10、completed=false` 的组

#### Scenario: 未打勾组在结束训练时清理
- **WHEN** 某动作预填 4 组，用户只对 2 组打勾后结束训练
- **THEN** 仅保留 2 个 completed 组，另 2 个未打勾的预填组被丢弃，不进训练记录、不参与统计与回写

### Requirement: 计划详情展示下次有效处方

计划详情页 SHALL 把动作列表展示为「下次训练处方」而不只是静态计划字段。每个动作行 SHALL 展示下一次从该计划开始训练时会生成的有效处方摘要（组数 / 次数 / 重量）与来源说明；该摘要 MUST 与「开始训练预填落值」使用的 `PlanPrefill` 规则一致。

- **自适应模式**：下次有效处方 MUST 优先基于上次同动作 completed 正式组；无历史时回退计划 `suggested*`；无历史且缺少计划组数时默认 4 组。动作行 SHALL 展示来源标签（至少包括：历史、预设、默认、保留）与来源说明（如「来自上次完成 · 昨天」「计划预设」「默认起步」「上次未练 · 已保留」）。
- **严格模式**：下次有效处方 MUST 直接展示计划预设，并 SHALL 明确「严格执行 · 完成后不更新」。严格模式仍 MUST 在缺少必填组数/次数时阻止开始训练。
- **列表页**：计划列表中每个计划卡 SHALL 展示当前模式，并 SHALL 用一行短文案说明行为差异（如「下次依据：上次完成实绩」「完成后自动更新」「严格执行 · 不回写」「默认 4×10 起步」）。用户 MUST NOT 只有进入详情页后才知道计划是否会自动回写。

#### Scenario: 自适应详情显示历史来源处方
- **WHEN** 用户进入一个自适应计划详情页，且「卧推」上次 completed 正式组为 `65kg×5`
- **THEN** 「卧推」动作行显示「下次 ... 65 kg × 5」
- **AND** 来源显示为历史来源（如「历史」「来自上次完成 · 昨天」）
- **AND** 用户点「开始这次训练」后生成的 `WorkoutSet` 与该处方一致

#### Scenario: 自适应详情显示计划预设来源
- **WHEN** 用户进入一个自适应计划详情页，且某动作无 completed 历史但有 `suggestedSets=4、suggestedReps=10`
- **THEN** 该动作行显示「下次 4 组 × 10」
- **AND** 来源显示「预设」或「计划预设」

#### Scenario: 自适应详情显示默认起步
- **WHEN** 用户进入一个自适应计划详情页，且某动作无 completed 历史、无计划组数
- **THEN** 该动作行显示默认 4 组起步
- **AND** 若该动作有默认次数 10，则显示「下次 4 组 × 10」

#### Scenario: 计划列表展示模式行为摘要
- **WHEN** 用户查看计划列表，列表中同时存在严格计划与自适应计划
- **THEN** 每张计划卡都显示当前模式
- **AND** 严格计划显示不回写语义，自适应计划显示自动更新或下次依据语义

### Requirement: 自适应模式实绩回写计划

自适应模式计划在训练**完成**后，MUST 对其来源计划（`Workout.planId` 命中的 `WorkoutPlan`）执行一次 upsert 合并回写。回写 MUST 仅依据本次 `completed` 的正式组（`countsForStats` 为真，即 `setType != .warmup && completed`）。严格模式 MUST NOT 回写。

合并规则：

- **动作（只增不减）**：训练含、计划无（`planItemId == nil`）的动作 MUST 以新 `PlanItem` append 到计划末尾，并按 `historyKey`（`builtinExerciseCode ?? customExerciseId ?? exerciseName`）去重（命中已有项则视为更新而非新增）；计划含、本次训练未涉及的动作 MUST 保留不动，系统 MUST NOT 自动删除。
- **组数（只增不减）**：`suggestedSets = max(计划现值, 本次该动作 completed 正式组数)`。
- **重量 / 次数（如实写回，可升可降）**：取本次该动作 completed 正式组中**最大重量那一组**的 `(weightKg, reps)`，写入 `suggestedWeightKg / suggestedReps`；系统 MUST NOT 对重量/次数取历史最大值（不合成虚构最佳组合，允许 deload 下降）。

回写 MUST 经由对 `WorkoutPlan` 的本地编辑（`markDirty`）走既有同步域 LWW，MUST NOT 新增独立同步路径。

完成训练页 MUST 展示本次回写的逐项 diff 回执（改值 / 新增 / 已保留），并 MUST 提供「撤销此次更新」入口；撤销 MUST 将计划还原至回写前快照。

#### Scenario: 组数只增不减
- **WHEN** 计划某动作 `suggestedSets=5`，本次只完成 3 个正式组
- **THEN** 回写后 `suggestedSets` 仍为 5（取 max，不因 deload 缩减）

#### Scenario: 重量次数如实写回顶组
- **WHEN** 本次某动作完成 `60kg×8、60kg×8、65kg×5`（均正式组）
- **THEN** 回写 `suggestedWeightKg=65、suggestedReps=5`（最大重量顶组），`suggestedSets=max(现值,3)`

#### Scenario: 训练中新增动作并入计划
- **WHEN** 用户在自适应计划的训练里临时加了一个不在计划中的动作并完成
- **THEN** 该动作以新 `PlanItem` append 到计划末尾（携带本次实绩），下次开始训练即包含它

#### Scenario: 跳过的动作保留不删
- **WHEN** 计划含「过顶推举」，本次训练跳过未做
- **THEN** 计划仍保留「过顶推举」，仅能由用户在计划模板内手动删除

#### Scenario: 回写可撤销
- **WHEN** 用户在完成训练页点「撤销此次更新」
- **THEN** 来源计划还原到本次回写前的状态，并重新标脏以同步该还原

#### Scenario: 严格模式不回写
- **WHEN** 用户完成一次由严格计划发起的训练
- **THEN** 计划数据保持不变，完成页不展示回写回执

### Requirement: 计划 Fork 字段规则

Fork（复制为新计划 / Team 计划模板分发）一个计划时，新计划 MUST 复制 **动作 + 组数（`suggestedSets`） + 次数（`suggestedReps`）**，并 MUST 清空重量（`suggestedWeightKg`）；新计划模式默认 `adaptive`。系统 MUST NOT 在 Fork 时携带原计划的 `suggestedWeightKg` 或任何训练实绩。

Fork 得到的新计划 MUST 默认归入接收者的「未分组」（`groupId == nil`），并按接收者未分组列表的末尾生成 `sortOrder`。系统 MUST NOT 把发布者或源计划的分组结构复制给接收者。

#### Scenario: Fork 不带重量
- **WHEN** 用户 Fork 一个已被实绩回写到「深蹲 5 组 × 5 次 × 100kg」的自适应计划
- **THEN** 新计划得到「深蹲 5 组 × 5 次」、重量为空，模式为 `adaptive`

#### Scenario: Fork 默认未分组
- **WHEN** 用户 Fork 一个属于发布者「胸背」分组的 Team 计划
- **THEN** 接收者的新计划 `groupId` SHALL 为 nil
- **AND** 新计划 SHALL 显示在接收者的「未分组」

### Requirement: 单一活跃训练会话

系统 SHALL 保证同一时刻至多存在一个进行中训练会话（`deletedAt == nil && endedAt == nil`）。所有「开始训练」入口（空白训练、由计划发起、由动作详情「加入今日训练」）MUST 经统一守卫；当已存在进行中会话时，系统 MUST NOT 静默新建第二个会话，而 SHALL 提示用户「继续」或「丢弃」既有会话。

#### Scenario: 无进行中会话时开始训练
- **WHEN** 不存在进行中会话，用户点击「开始训练」
- **THEN** 系统创建唯一进行中会话并进入 Live 记录界面

#### Scenario: 已有进行中会话时再次开始
- **WHEN** 已存在一个进行中会话，用户尝试开始一次新训练
- **THEN** 系统弹出「继续 / 丢弃」选择，而非新建第二个进行中会话

#### Scenario: 选择继续
- **WHEN** 用户在「继续 / 丢弃」中选择「继续」
- **THEN** 系统打开既有进行中会话，不创建新会话

#### Scenario: 选择丢弃
- **WHEN** 用户在「继续 / 丢弃」中选择「丢弃」
- **THEN** 系统删除既有进行中会话（不再出现于任何列表、不计入统计），随后创建新会话

### Requirement: 进行中会话的首页呈现与继续入口

训练首页 SHALL 在存在进行中会话时，于顶部以醒目的「继续训练」横幅呈现该会话（区别于「最近训练」常规行）。进行中会话 MUST NOT 作为普通已完成记录混入「最近训练」列表。「继续训练」横幅 SHALL 采用按压交互样式提供点按反馈，点击时 SHALL 触发一次轻碰撞触感（`Theme.Haptics.impact(.light)`）；横幅 MUST 为 VoiceOver 合成单一可点元素并附语义化标签（训练名 + 进度）。

#### Scenario: 存在进行中会话
- **WHEN** 用户进入训练首页且存在一个进行中会话
- **THEN** 首页顶部显示「继续训练」横幅，点击进入该会话的 Live 记录界面并伴随一次轻触感

#### Scenario: 进行中会话不混入最近列表
- **WHEN** 存在一个进行中会话
- **THEN** 「最近训练」列表不将该进行中会话显示为普通已完成行

#### Scenario: VoiceOver 朗读横幅
- **WHEN** VoiceOver 用户聚焦「继续训练」横幅
- **THEN** 横幅作为单一元素被朗读为含训练名与「N/M 组完成」进度的语义整句，而非逐字段拆读

### Requirement: 会话计时为墙钟且无会话级暂停

进行中会话的计时 SHALL 为墙钟时长（`now − startedAt`，包含组间休息），实时刷新。系统 MUST NOT 提供「暂停整场训练」的控件。组间「歇一下」的需求由组间休息计时器承载，不影响会话总时长。

#### Scenario: 进行中实时计时
- **WHEN** 会话处于进行中
- **THEN** 计时从 `startedAt` 起按墙钟实时递增显示

#### Scenario: 无暂停控件
- **WHEN** 用户查看进行中页的控制区
- **THEN** 不存在「暂停训练」按钮（仅有结束、添加动作等操作）

### Requirement: 结束训练需二次确认

结束训练 SHALL 经过二次确认。进行中会话的结束按钮文案 MUST 为「结束训练」。点击「结束训练」MUST **始终**弹出确认（即使所有组已完成，不得跳过确认），确认弹窗 MUST 复用统一的二次确认 UI（`paperConfirmDialog`）并展示本次「动作数 · 已完成组数」摘要。

确认文案 SHALL 随**未完成组数**变化：当存在未勾选完成的组（`remainingSetCount > 0`）时，确认弹窗 MUST 以强警示文案提示尚有 N 组未完成；当全部组已完成时，使用常规归档提示文案。

仅确认后系统才将会话置为已完成（设置 `endedAt`）并执行个人归档副作用（HealthKit 写入、PR 检测、自适应计划回写）。Team 分享 MUST NOT 作为结束训练的无条件自动副作用；结束后系统 SHALL 读取用户已在 Team 内首次确认开启的自动分享偏好，只为这些 Team 创建或更新 checkin。若未开启任何 Team 自动分享，系统 SHALL 保持「仅自己可见」，不展示强制分享确认，不创建 Team checkin。结束训练 MUST 同时停止当前进行中的组间休息计时全套——撤销待发本地通知、收起浮动 FAB 与休息弹窗、立即结束休息 Live Activity。取消 SHALL 使会话保持进行中，不产生任何副作用，且 MUST NOT 影响正在进行的休息计时。

「丢弃进行中会话」路径 MUST 同样停止当前休息计时全套，且 MUST NOT 创建 Team checkin。

#### Scenario: 按钮文案为结束训练
- **WHEN** 用户进入进行中会话
- **THEN** 结束入口按钮文案显示「结束训练」（而非「停止训练」）

#### Scenario: 全部完成时确认结束
- **WHEN** 所有动作组均已勾选完成，用户点击「结束训练」
- **THEN** 弹出常规确认（「结束训练?/将归档本次训练并计算 PR」+「动作数·已完成组数」摘要）；确认后会话置为已完成并执行 HealthKit 写入、PR 检测与个人归档副作用
- **AND** 若用户未开启任何 Team 自动分享，系统保持仅自己可见，不创建 Team checkin

#### Scenario: 有未完成组时强确认
- **WHEN** 仍有 N(>0) 组未勾选完成，用户点击「结束训练」
- **THEN** 确认弹窗以强警示文案提示「还有 N 组未完成」并征询是否仍要结束；确认后才归档

#### Scenario: 取消结束
- **WHEN** 用户点击「结束训练」但在确认弹窗中取消
- **THEN** 会话保持进行中，不设置 `endedAt`，不触发任何归档副作用，进行中的休息计时不受影响

#### Scenario: 结束训练即停休息计时
- **WHEN** 休息计时进行中，用户确认结束训练（或丢弃该进行中会话）
- **THEN** 浮动 FAB 与休息弹窗立即收起、待发休息提醒通知被撤销、休息 Live Activity 立即结束，不再残留倒计时

#### Scenario: 自动分享到已授权 Team
- **WHEN** 训练已归档，且用户已在 Team A 中开启自动分享
- **THEN** 系统为 Team A 创建或更新该训练 checkin
- **AND** 未开启自动分享的 Team 不出现该训练

#### Scenario: 丢弃会话不打卡
- **WHEN** 用户丢弃进行中会话
- **THEN** 系统删除该会话并停止休息计时
- **AND** 不展示强制 Team 分享 sheet，不创建 Team checkin

### Requirement: 休息结束提醒（前台声音 + 震动）

组间休息计时归零时系统 SHALL 给出明确的多通道提醒。后台/锁屏 MUST 经本地通知（含声音）提醒（既有行为）；App 在前台时，系统 MUST 在到点瞬间播放一声短促提醒音效并维持触觉反馈（按 `hapticsEnabled` 开关）。

提醒音效 SHALL 来自随包的短音效资源文件，经 `AVAudioSession` `.playback` 类别播放，因而 MUST 无视静音键（健身场景刚需）；播放 MUST 采用 `.duckOthers + .mixWithOthers`，仅瞬时压低用户后台音乐而非掐断，并在播完恢复。系统 SHALL 提供 `soundEnabled` 开关（默认开）控制该音效。前台到点的音效与本地通知声 MUST NOT 重复响两声。

#### Scenario: 前台到点出声
- **WHEN** App 在前台，休息计时归零，`soundEnabled` 为开
- **THEN** 即使手机处于静音/震动档，也播放一声短促提醒音 + 触觉反馈

#### Scenario: 不打断用户音乐
- **WHEN** 用户边训练边播放背景音乐，休息到点出声
- **THEN** 背景音乐被瞬时压低（duck）后于音效播完恢复，不被掐断

#### Scenario: 关闭声音开关
- **WHEN** `soundEnabled` 为关，休息计时归零
- **THEN** 前台不播放音效（触觉与本地通知行为不受该开关影响）

### Requirement: 休息 Live Activity 倒计时结束自动消失

休息计时的 Live Activity（灵动岛）MUST 在倒计时到达 `endDate` 后自动消失，MUST NOT 在归零后长期停留。系统 SHALL 在启动该 Live Activity 时即预约其在 `endDate`（含短暂宽限）后自动 dismiss（`dismissalPolicy: .after(...)`），从而无需 App 在后台被唤醒即可消失。当休息被提前结束、自然结束（前台）或随结束训练而终止时，系统 SHALL 以 `.immediate` 立即结束该 Live Activity，覆盖预约。

#### Scenario: 后台自然归零后自动消失
- **WHEN** App 在后台/锁屏，休息计时自然倒计时至 `endDate`
- **THEN** 灵动岛在 `endDate`（含宽限）后自动消失，无需用户回到 App 或手动操作

#### Scenario: 提前结束立即消失
- **WHEN** 用户在灵动岛点「结束」或在 App 内提前结束休息
- **THEN** 灵动岛立即消失（`.immediate`）

#### Scenario: 结束训练时一并消失
- **WHEN** 休息计时进行中，用户结束训练
- **THEN** 休息 Live Activity 立即结束消失

### Requirement: 已完成会话计时冻结

已完成会话的计时显示 SHALL 冻结为 `endedAt − startedAt`，MUST NOT 在结束后继续增长。

#### Scenario: 结束后计时不再增长
- **WHEN** 会话已结束
- **THEN** 计时显示恒为 `endedAt − startedAt`，不随当前时间变化

### Requirement: 已完成会话只读摘要与显式编辑

已完成会话 SHALL 默认以只读摘要呈现：MUST NOT 直接允许新增动作、勾选完成或修改重量/次数。系统 SHALL 提供显式「编辑」入口进入可编辑态；编辑保存后系统 MUST 重新执行 PR 检测，并更新该会话对应的 Team 打卡摘要（若已打卡）。系统 SHALL NOT 提供「将已完成会话恢复为进行中」的功能。

#### Scenario: 已完成默认只读
- **WHEN** 用户打开一个已完成会话且未进入编辑态
- **THEN** 动作的完成勾选、重量/次数输入、「添加动作」入口均不可操作

#### Scenario: 显式编辑并保存
- **WHEN** 用户在已完成会话点击「编辑」，修改某组重量后保存
- **THEN** 改动落盘，系统重算该会话的 PR，并更新对应 Team 打卡摘要

#### Scenario: 不提供恢复到进行中
- **WHEN** 用户查看已完成会话的操作项
- **THEN** 不存在「恢复 / 重新开始计时」的入口

#### Scenario: 编辑态可修正时长
- **WHEN** 用户在编辑态调整会话的开始或结束时刻
- **THEN** 会话时长与相关统计按新的 `startedAt` / `endedAt` 重算

### Requirement: 删除训练记录

系统 SHALL 允许删除已完成训练记录（列表左滑），删除 MUST 二次确认。被删除的训练 MUST 通过软删墓碑机制同步至后端，且删除后不再出现于任何列表，亦不计入任何统计（本周次数、训练量、历史曲线、PR）。左滑显露删除按钮时 SHALL 触发一次选择类触感（`Theme.Haptics.selection()`），显露与收回的回弹动画 MUST 对称。由于左滑手势对 VoiceOver 不可达，每条训练行 MUST 额外提供 VoiceOver 删除动作（`accessibilityAction(named: "删除")`），其同样走二次确认。

#### Scenario: 左滑删除已完成训练
- **WHEN** 用户在训练列表左滑某条已完成训练并确认删除
- **THEN** 该训练从列表移除、不再计入统计，并以墓碑形式同步至后端

#### Scenario: 删除需确认
- **WHEN** 用户左滑触发删除
- **THEN** 系统弹出删除确认，取消则保留该训练

#### Scenario: 左滑显露触感
- **WHEN** 用户左滑使删除按钮越过显露阈值
- **THEN** 触发一次选择类触感，松手后按对称回弹动画停靠在显露或收回位

#### Scenario: VoiceOver 删除
- **WHEN** VoiceOver 用户聚焦某条训练行并执行其「删除」自定义动作
- **THEN** 系统弹出同样的删除二次确认，确认后软删并同步

### Requirement: 热身组排除于统计与 PR

所有训练统计 SHALL 以「计入统计的组 = 正式组且已完成」为判据，即 `countsForStats` MUST 定义为 `setType != .warmup && completed`。热身组与**未完成（`completed == false`，含自适应/严格落值后未打勾的预填残组）**的组 MUST NOT 计入。受此约束的口径包括：PR 最大重量（动作库行与动作详情）、周训练量（volume）、周总组数、周总次数、历史强度曲线。被排除的组其记录本身 MUST 完整保留（重量/次数照常录入与展示，未打勾组在结束训练时按「未打勾组清理」处理），仅在统计聚合时被排除。

判据中「排除 `warmup`」部分 SHALL 表达为「非 warmup」而非「仅取 working」，使将来新增的正式类组类型自动计入，无需改动统计逻辑。

#### Scenario: 未完成的预填组不计统计
- **WHEN** 某动作落值了 4 组、用户只完成 2 组（另 2 组未打勾）
- **THEN** 周训练量、周总组数、PR 仅累计已完成的 2 个正式组，未打勾的 2 组不计入

#### Scenario: 热身组不计训练量与组数
- **WHEN** 某动作有 2 个热身组（各 40kg×10、60kg×5）与 3 个已完成正式组（各 80kg×8）
- **THEN** 周训练量只累加 3 个正式组、周总组数只计 3、热身组的 reps 不计入总次数

#### Scenario: 热身组不破 PR
- **WHEN** 某动作的最大重量出现在一个被标为热身组的组里
- **THEN** PR 与历史曲线忽略该热身组，仅按已完成正式组计算

### Requirement: 移除首页工具栏右上角入口

训练首页工具栏右上角的占位「搜索」图标与「加号」菜单（含「空白训练」与「从某计划开始」两类项）MUST 全部移除，右上角不再呈现任何控件。首页 MUST NOT 提供任何训练记录搜索能力。左上角原「日历 / 训练历史」入口 MUST 一并移除（历史模块已删除），工具栏左上角不再呈现任何控件。移除后「开始训练」MUST 仅由底部悬浮 CTA 承载；首页 MUST NOT 提供多计划快速选择入口（多计划选择交由「计划」页）。

#### Scenario: 右上角无控件
- **WHEN** 用户进入训练首页
- **THEN** 工具栏右上角为空，不显示搜索图标，也不显示加号菜单

#### Scenario: 无首页搜索
- **WHEN** 用户希望检索历史训练
- **THEN** 首页不提供搜索框，亦无任何过滤入口

#### Scenario: 左上角无历史入口
- **WHEN** 用户查看工具栏左上角
- **THEN** 不再呈现「日历 / 训练历史」入口，左上角为空，无任何进入历史的入口

### Requirement: 首页开始入口收敛为智能单键 CTA

训练首页的「开始训练」入口 MUST 唯一收敛到底部悬浮 CTA（单点击，无长按、无备选菜单）。在**不存在**进行中会话时：若**存在**「进行中」计划，CTA 文案 SHALL 上下文化为「从『计划名』开始」并以该计划预填新会话（复用既有 `start(from:)` 流程）；若无任何计划，CTA SHALL 维持「开始今日训练 / 开始第 1 次训练」并创建空白训练。「进行中」计划的判定 MUST 复用与「计划」页一致的同一份判定逻辑（近 14 天内有关联该计划的已完成训练，否则取最近更新的计划），不得另写一套。CTA SHALL 采用按压交互样式并在点击时触发一次触感。

#### Scenario: 存在进行中计划
- **WHEN** 用户近 14 天有关联计划「严肃推拉腿」的训练，且当前无进行中会话
- **THEN** 底部 CTA 文案为「从『严肃推拉腿』开始」，单击以该计划动作项预填并进入新会话

#### Scenario: 无任何计划
- **WHEN** 用户没有任何计划且无进行中会话
- **THEN** CTA 文案为「开始今日训练 / 开始第 1 次训练」，单击创建空白训练

#### Scenario: 判定与计划页一致
- **WHEN** 「计划」页将某计划标记为「进行中」
- **THEN** 首页 CTA 上浮的计划与之为同一计划，不出现两页不一致

### Requirement: 训练录入数字键盘

训练进行中（`WorkoutLoggingView`）记录每组重量/次数时，App SHALL 使用**自研数字键盘**，MUST NOT 唤起系统 `.decimalPad`/`.numberPad`。键盘 SHALL 含键位：`0-9`、小数点 `.`、删除 `⌫`、`上一项`、`下一项`、`加一组`、`收起`；MUST NOT 含「完成」键——组打卡仍由每行右侧勾选按钮承担，与键盘解耦。键盘 SHALL 从屏幕底部出现（`safeAreaInset`），仅当存在聚焦单元时显示。

#### Scenario: 点击重量格唤起自研键盘
- **WHEN** 用户点击某组的重量单元
- **THEN** 屏幕底部升起自研数字键盘，系统键盘不出现，该单元进入聚焦态

#### Scenario: 显式收起入口
- **WHEN** 用户点击键盘右上角「收起」键
- **THEN** 键盘下收消失，焦点清空，无任何组处于高亮编辑态

#### Scenario: 键盘不含完成键
- **WHEN** 自研键盘升起
- **THEN** 键盘只提供数字/小数点/删除/上一项/下一项/加一组/收起，没有完成或打卡键；打卡仍点该组右侧勾选按钮

#### Scenario: 加一组
- **WHEN** 焦点在某动作的任一单元并按「加一组」
- **THEN** 在当前动作末尾追加一组（预填上一组重量），焦点移到新组的重量单元，键盘保持升起、该行滚入可视区

### Requirement: 录入焦点状态与高亮派生

App SHALL 维护单一焦点真相源 `focused`（取值为「某组重量」「某组次数」或「无」）。当且仅当 `focused` 非空时键盘升起；正在编辑的组的高亮 SHALL 由 `focused` 派生，MUST NOT 复用「第一个未完成组」的待办指示作为编辑高亮。「第一个未完成组」SHALL 降级为弱视觉待办标记，与编辑高亮区分。

#### Scenario: 高亮跟随焦点
- **WHEN** 用户点击第 3 组的重量单元，而第 1 组尚未完成
- **THEN** 编辑高亮落在第 3 组（焦点所在组），不停留在第 1 组

#### Scenario: 收起后无编辑高亮
- **WHEN** `focused` 被清空（收起/跳过末项）
- **THEN** 无组显示编辑高亮，「第一个未完成组」仅以弱视觉标记待办

#### Scenario: 只读态不可聚焦
- **WHEN** 训练为只读态（已结束/`readOnly`）
- **THEN** 重量/次数单元不可点、不进入焦点，键盘不升起

### Requirement: 数字录入规则与小数约束

重量录入 SHALL 为小数、小数点后**最多 2 位**：已有 2 位小数时后续数字键 MUST 被忽略；小数点 `.` 在一个值内最多一个，空缓冲按 `.` SHALL 补为 `0.`。次数录入 SHALL 为整数，小数点 `.` 键 MUST 灰显且无效。聚焦已有值的单元 SHALL 采用「打字即覆盖」：首个数字键 MUST 清空原值重填，`⌫` MUST NOT 触发清空、直接删末位。清空为空串 SHALL 写回为「无值」（nil）。重量显示 SHALL 复用既有 `formatKg` 格式化口径。

#### Scenario: 重量小数最多 2 位
- **WHEN** 重量单元已输入「62.50」后再按「7」
- **THEN** 该按键被忽略，值仍为「62.50」

#### Scenario: 空缓冲按小数点
- **WHEN** 重量单元为空时按下 `.`
- **THEN** 缓冲变为「0.」

#### Scenario: 次数禁用小数点
- **WHEN** 次数单元聚焦
- **THEN** `.` 键灰显，按下无效，只能输入整数

#### Scenario: 打字即覆盖
- **WHEN** 聚焦显示「30」的次数单元并按下「8」
- **THEN** 值变为「8」（整体覆盖），而非「308」

#### Scenario: 删除不触发覆盖
- **WHEN** 聚焦显示「30」的次数单元并按下 `⌫`
- **THEN** 值变为「3」（删末位），后续按键转为追加而非覆盖

### Requirement: 上一项/下一项跳转

`下一项`/`上一项` SHALL 在**当前动作内**沿序列「组0.重量 → 组0.次数 → 组1.重量 → 组1.次数 → …」前进/后退聚焦。处于末项时按 `下一项` SHALL 收起键盘；处于首项时按 `上一项` SHALL 保持在首项（不收起）。焦点切换时 App SHALL 将聚焦所在行滚动到键盘上方可视区。本版 MUST NOT 跨动作跳转（末项即收起，换动作靠点击）。

#### Scenario: 重量跳次数
- **WHEN** 焦点在某组重量单元并按「下一项」
- **THEN** 焦点移到同组次数单元

#### Scenario: 次数跳下一组重量
- **WHEN** 焦点在某组次数单元（非末组）并按「下一项」
- **THEN** 焦点移到下一组的重量单元，该行滚入可视区

#### Scenario: 末项收起
- **WHEN** 焦点在当前动作最后一组的次数单元并按「下一项」
- **THEN** 键盘收起，焦点清空

#### Scenario: 首项不回退
- **WHEN** 焦点在当前动作第一组的重量单元并按「上一项」
- **THEN** 焦点保持不变，键盘不收起

### Requirement: PR 庆祝弹窗版式

训练结束时若命中至少 1 项 Personal Record，系统 SHALL 弹出 PR 庆祝 Sheet（presentation detent，纸感样式）。Sheet SHALL 含：顶部圆形 PR 徽章（`accent` 实底 + 白色杠铃/奖杯图标 + `paperShadow(.md)`）、标题「Personal Record」+ 副标「{N} 项新纪录!」、记录列表（每行：动作名 + 旧纪录/「首次」→ 新重量 + 单位，提升用向上箭头 + `accent` 着色）、底部「太棒了」CTA（`accent` 实底白字）。Sheet 背景 `surface`，圆角 `Theme.Radius.lg`，scrim 半透明。MUST NOT 使用品红或辉光。

#### Scenario: 单项 PR
- **WHEN** 用户结束训练且仅 1 项动作刷新纪录
- **THEN** 弹出 PR Sheet，副标显示「1 项新纪录!」，列表 1 行展示旧→新重量提升

#### Scenario: 首次记录某动作
- **WHEN** 某动作此前无历史记录、本次为首次
- **THEN** 该行左值显示「首次」而非旧重量，右值为本次重量

#### Scenario: 无 PR 不弹窗
- **WHEN** 训练结束且无任何动作刷新纪录
- **THEN** 不弹出 PR 庆祝 Sheet

### Requirement: 动作详情页（ExerciseDetail）版式与行为

内置动作详情页 SHALL 为**纯浏览/查资料**页，自上而下五段：① 肌群高亮图、② 标题与 meta、③ 你的数据、④ 动作要点、⑤ 目标肌群。该页 MUST NOT 提供任何写入训练数据的入口（移除「加入今日训练」CTA），MUST NOT 在进入或停留时创建或修改训练会话。加动作入口仍由训练会话的动作选择器与计划编辑承担。

#### Scenario: 进入详情页不触发写入
- **WHEN** 用户从动作库点进某内置动作详情
- **THEN** 页面仅展示资料，不新建/不修改任何 `Workout`，无底部「加入今日训练」按钮

#### Scenario: 五段结构
- **WHEN** 内置动作有完整细分数据
- **THEN** 依次显示「肌群高亮图 / 标题+部位·器械 chip / 你的数据 / 动作要点 / 目标肌群」，页面滚到底即止、无置底 CTA

### Requirement: 详情页肌群高亮图

详情页顶部 SHALL 以 `MuscleMapView` 渲染该动作的肌群高亮图，主动肌/协同肌取自动作的 `primaryRegions`/`secondaryRegions`，底图按用户 `UserProfile.sex` 选择，默认面取「亮区更多」一侧并可正/背切换。当动作无细分区数据（如自定义动作或未回填）时，高亮图段 MUST 隐藏，不显示占位条纹。

#### Scenario: 内置动作显示高亮图
- **WHEN** 查看「杠铃卧推」（primaryRegions=[chest]）
- **THEN** 顶部显示高亮图，胸为主动色、三角肌前束/肱三头为协同色

#### Scenario: 性别切底图
- **WHEN** 用户 `sex` 为 `female`
- **THEN** 高亮图用女版底图轮廓，点亮区与染色不变

#### Scenario: 缺数据隐藏
- **WHEN** 动作 `primaryRegions` 为空
- **THEN** 高亮图段不渲染，页面从标题段开始

### Requirement: 详情页「你的数据」段

详情页 SHALL 展示该动作的个人历史摘要：上次训练日期、最近一组（重量×次数）、PR；并展示一个按时间的迷你强度图。所有数值 MUST 自本地 `workouts`（已结束、未软删，按 `historyKey` 匹配）即时重算，MUST NOT 持久化冗余。当该动作无任何历史记录时，该段 SHALL 降级为「还没练过」提示，MUST NOT 显示 0 或假数据。

#### Scenario: 有历史
- **WHEN** 用户此前练过该动作
- **THEN** 显示上次日期、最近一组、PR 与迷你图；点迷你图进全屏历史（无独立全屏页时降级为不可点）

#### Scenario: 无历史
- **WHEN** 用户从未记录过该动作
- **THEN** 「你的数据」段显示「还没练过」，不显示 0kg / 空图

### Requirement: 详情页要点与目标肌群

详情页 SHALL 展示动作 `formCues`（编号短句列表）与目标肌群。目标肌群 MUST 用 `MuscleRegion.displayName` 中文名，并以与高亮图一致的三态色点区分主动肌/协同肌。当 `formCues` 为空时要点段隐藏；当无 region 时目标肌群段隐藏。内部 `code` MUST NOT 作为主要信息展示给用户（可隐藏或降为次要脚注）。

#### Scenario: 要点与肌群展示
- **WHEN** 动作有 3 条 `formCues`、primary=[chest]、secondary=[deltFront, triceps]
- **THEN** 要点段列 3 条编号短句；目标肌群段显示「主动肌 胸大肌」「协同肌 三角肌前束 · 肱三头肌」，色点与高亮图同源

#### Scenario: 不暴露内部 code
- **WHEN** 查看任意内置动作
- **THEN** 页面不把 `BB_BENCH_PRESS` 这类 code 作为标题/主要字段展示

### Requirement: 历史训练日历

iOS SHALL 提供历史训练日历入口，用于按日期查看已完成训练。入口 SHALL 位于训练首页标题区，点击后进入独立历史日历页。历史日历页 SHALL 以月视图展示训练日，并允许用户点选日期查看当天训练列表。

#### Scenario: 从训练首页进入历史日历
- **WHEN** 用户进入训练首页
- **THEN** 页面标题区 SHALL 提供「历史日历」图标入口
- **AND** 点击后进入历史日历页

#### Scenario: 月历展示训练日
- **GIVEN** 某月存在已完成训练
- **WHEN** 用户打开该月历史日历
- **THEN** 有训练的日期 SHALL 显示训练量短文本
- **AND** 有训练的日期 SHALL 显示当天第一条训练标题摘要
- **AND** 同日多次训练 SHALL 显示额外训练数量提示
- **AND** 本月紧凑摘要 SHALL 仅展示训练次数、训练量与正式组数
- **AND** 不展示「最长连续」指标
- **AND** 历史日历主界面 SHOULD 一屏展示月历与选中日期详情，不应由底部详情面板遮盖月历

#### Scenario: 查看某日训练
- **WHEN** 用户点选某个日期
- **THEN** 页面 SHALL 显示该日期的训练列表
- **AND** 点击某条训练 SHALL 进入该训练的只读详情页

#### Scenario: 直接选择年月
- **WHEN** 用户点击历史日历页月份旁的独立选择图标
- **THEN** 页面 SHALL 弹出月份档案 sheet
- **AND** sheet SHALL 按年份分组展示月份
- **AND** sheet SHALL 按月份展示训练天数与日期密度条
- **AND** sheet SHALL 提供年份索引用于快速跳转，并提供回到顶部入口
- **AND** 用户选择某个年月后 SHALL 直接跳转到该月
- **AND** 用户不需要逐月点击左右箭头才能查看久远历史

#### Scenario: 回到今天
- **WHEN** 用户点击「今天」
- **THEN** 页面 SHALL 跳转到今天所在月份并选中今天
- **AND** 「今天」入口 SHALL 位于月份控制区，不位于导航栏右上角
- **AND** 当页面已经显示今天所在月份且选中今天时 SHOULD 隐藏「今天」入口

#### Scenario: 空日期
- **WHEN** 用户点选没有已完成训练的日期
- **THEN** 页面 SHALL 显示轻量空状态，不应跳转或报错

### Requirement: 历史日历性能

历史日历 UI MUST NOT 在 SwiftUI `body` 渲染路径中直接订阅或遍历完整训练聚合树。客户端 SHALL 复用可重建的本地派生快照或等价窄查询生成日历摘要。服务端不需要为 V1 历史日历新增接口。

#### Scenario: 月份切换不全量扫描
- **GIVEN** 本地存在至少 5000 次已完成训练
- **WHEN** 用户切换历史日历月份
- **THEN** UI SHOULD 只读取该月日期摘要
- **AND** MUST NOT 因月份切换重新遍历全部 `WorkoutExercise` 与 `WorkoutSet`

#### Scenario: 单次详情按需展开
- **WHEN** 用户从某日训练列表打开一条训练详情
- **THEN** 客户端 SHALL 仅加载该训练详情所需的聚合树
- **AND** 历史日历页自身仍 SHALL 使用轻量摘要

### Requirement: 训练计划分组模型

系统 SHALL 提供独立的 `WorkoutPlanGroup` 同步实体，用于管理训练计划分组。分组 MUST 属于单个用户，并携带与其它同步实体一致的同步信封：`localId/serverId/updatedAt/deletedAt/version/syncStatus`。分组 MUST 至少包含 `name` 与 `sortOrder` 字段。

`WorkoutPlan` SHALL 增加 `groupId` 与 `sortOrder` 字段。`groupId == nil` 表示未分组；当 `groupId` 引用的分组不存在或已删除时，客户端 MUST 将该计划按「未分组」展示，而不是隐藏或崩溃。

#### Scenario: 旧计划进入未分组
- **GIVEN** 用户已有旧版本创建的计划
- **WHEN** App 升级到支持计划分组的版本
- **THEN** 旧计划 SHALL 保留
- **AND** 旧计划 SHALL 以「未分组」展示

#### Scenario: 分组可独立排序
- **WHEN** 用户调整分组顺序
- **THEN** 系统 SHALL 更新各 `WorkoutPlanGroup.sortOrder`
- **AND** 计划自身的 `sortOrder` 与 `groupId` 不应因分组排序被修改

#### Scenario: 计划可在组内排序
- **WHEN** 用户调整同一分组内的计划顺序
- **THEN** 系统 SHALL 更新该组内计划的 `WorkoutPlan.sortOrder`
- **AND** 不应修改其它分组内计划的顺序

#### Scenario: 引用缺失分组时容错
- **GIVEN** 某计划的 `groupId` 指向一个本地尚未同步到或已经软删的分组
- **WHEN** 用户打开计划列表
- **THEN** 该计划 SHALL 显示在「未分组」
- **AND** 计划数据不得丢失

### Requirement: 计划分组管理

用户 SHALL 能在计划模块中新建、重命名、排序和删除计划分组。删除分组 MUST 经过二次确认。删除分组 MUST NOT 删除组内计划；系统 SHALL 将组内计划移动到「未分组」，并把这些计划标脏以进入同步队列。

#### Scenario: 新建分组
- **WHEN** 用户在计划页新建分组并输入名称
- **THEN** 系统 SHALL 创建 `WorkoutPlanGroup`
- **AND** 新分组 SHALL 追加到分组列表末尾

#### Scenario: 重命名分组
- **WHEN** 用户重命名某个分组
- **THEN** 系统 SHALL 仅更新该分组的 `name`
- **AND** 组内计划的 `groupId` SHALL 保持不变

#### Scenario: 删除分组但保留计划
- **GIVEN** 分组「胸背」下存在计划 A 与计划 B
- **WHEN** 用户确认删除「胸背」分组
- **THEN** 「胸背」分组 SHALL 被软删
- **AND** 计划 A 与计划 B SHALL 保留
- **AND** 计划 A 与计划 B 的 `groupId` SHALL 变为 nil
- **AND** 计划 A 与计划 B SHALL 出现在「未分组」

#### Scenario: 空分组保留
- **WHEN** 用户创建一个暂时没有计划的分组
- **THEN** 该分组 SHALL 作为实体保留
- **AND** 计划列表或分组管理入口 SHALL 能让用户看到该空分组

### Requirement: 训练动作显式排序

App SHALL 允许用户在训练计划详情页和训练进行中页，通过明确的「排序」入口进入专门排序模式调整动作顺序。完成排序后 SHALL 将对应 `orderIndex` 重写为连续 `0...n-1` 顺序，并立即持久化所属聚合根。

- 在计划详情页，重排 SHALL 更新 `WorkoutPlan.items[].orderIndex`、将 `WorkoutPlan` 标脏，并影响未来从该计划开始的训练。
- 在训练进行中页，重排 SHALL 更新 `WorkoutExercise.orderIndex`、将当前 `Workout` 标脏，并且只影响当前训练记录。
- 训练进行中的重排 MUST NOT 自动更新来源计划的 `PlanItem.orderIndex`。
- 重排 SHALL 只能从可见排序入口进入，MUST NOT 通过拖动正常动作行或正常动作卡片触发。
- 正常动作行/动作卡头 MUST NOT 常驻排序 handle。
- 排序模式 SHALL 支持取消与完成：取消不保存，完成后一次性提交排序。
- 排序模式 SHALL 使用与项目 sheet 视觉一致的自定义顶部按钮与背景，MUST NOT 依赖系统 toolbar 文本按钮。
- 排序模式 MUST 禁用系统下滑关闭，避免与上下拖动排序产生手势冲突。
- 已完成训练只读页 MUST NOT 暴露动作排序入口。
- 排序模式 SHALL 使用 VoiceOver 可操作的列表移动能力。

#### Scenario: 计划详情完成排序后保存计划顺序
- **WHEN** 用户在计划详情页打开排序面板并将第 3 个动作移到第 1 个位置后点击完成
- **THEN** 该计划的 `PlanItem.orderIndex` 被重写为连续顺序
- **AND** `WorkoutPlan` 被标脏并保存
- **AND** 下次从该计划开始训练时按新的动作顺序生成训练

#### Scenario: 计划详情取消排序不保存
- **WHEN** 用户在计划详情页打开排序面板并调整顺序后点击取消
- **THEN** 计划详情动作顺序不发生变化
- **AND** `WorkoutPlan` 不因该次取消操作被标脏

#### Scenario: 训练进行中完成排序只影响本次训练
- **WHEN** 用户在训练进行中页打开排序面板并调整动作顺序后点击完成
- **THEN** 当前 `WorkoutExercise.orderIndex` 被重写为连续顺序
- **AND** 当前 `Workout` 被标脏并保存
- **AND** 来源计划的 `PlanItem.orderIndex` 不发生变化

#### Scenario: 正常页面不被排序手势抢占
- **WHEN** 用户点击计划动作行、左滑动作行，或点击训练动作卡头
- **THEN** 原有编辑、左滑删除、展开/收起、菜单、滚动与输入交互保持可用
- **AND** 正常行/卡片内不展示常驻排序 handle

#### Scenario: 已完成训练不允许排序
- **WHEN** 用户打开已完成训练的只读详情
- **THEN** 页面不展示动作排序入口
- **AND** 用户无法调整动作顺序

#### Scenario: VoiceOver 用户可在排序模式调整顺序
- **WHEN** VoiceOver 用户打开排序面板
- **THEN** 系统提供可操作的列表移动能力
- **AND** 点击完成后执行与普通排序相同的保存逻辑

#### Scenario: 排序面板拖动时不触发下滑关闭
- **WHEN** 用户在排序面板内上下拖动 reorder control
- **THEN** 面板保持打开
- **AND** 系统下滑关闭手势不响应
- **AND** 用户只能通过取消或完成退出排序模式

### Requirement: Live Activity Watch Smart Stack 条件呈现与降级

休息 Live Activity SHALL 在 iPhone 锁屏与支持 Dynamic Island 的设备上按既有规则呈现。配对 Apple Watch Smart Stack 呈现 SHALL 被视为平台条件能力：仅当系统版本、设备能力、连接状态与 ActivityKit/WidgetKit 预算支持时呈现。系统 MUST NOT 将 Apple Watch Smart Stack 不出现视为训练或休息提醒失败。Watch 不支持或未及时同步时，系统 SHALL 继续依靠 iPhone 锁屏 Live Activity、本地通知、前台声音与触觉反馈完成提醒。

#### Scenario: 支持平台显示 Watch Smart Stack
- **WHEN** 用户使用支持 iPhone Live Activity 自动转呈的 iOS/watchOS 组合，并且 Apple Watch 与 iPhone 连接正常
- **THEN** 休息 Live Activity 可在 Apple Watch Smart Stack 中呈现

#### Scenario: 不支持 Watch 时降级
- **WHEN** 用户没有 Apple Watch、watchOS 版本不支持、或连接状态导致 Smart Stack 未呈现
- **THEN** iPhone 锁屏 Live Activity 与本地通知仍按休息倒计时规则工作
- **AND** 验收不得因 Watch Smart Stack 缺席而判定休息计时失败

#### Scenario: Watch 更新延迟不影响倒计时真相
- **WHEN** Apple Watch 因连接或系统预算未及时显示最新 Live Activity 状态
- **THEN** App 内休息计时与 iPhone 端 Live Activity 仍以同一墙钟 `endDate` 为准

### Requirement: 训练计划模式属于当前 1.0 范围

当前 1.0 训练计划能力 SHALL 包含严格 / 自适应模式、开始训练历史优先预填、未完成预填组清理、训练完成后自适应回写与回写撤销。任何旧 proposal 中“不做自适应/自动重量预填”的表述 MUST 被视为已由后续 workout-tracking 规格覆盖，不得作为验收依据。

#### Scenario: 验收以主规格为准
- **WHEN** 验收人员检查训练计划行为
- **THEN** 以当前 `workout-tracking` 主规格中的严格 / 自适应、预填与回写要求为准
- **AND** 不因 `meigei-mvp` 初稿 Non-goal 中的旧表述判定这些能力越界

