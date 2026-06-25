## MODIFIED Requirements

### Requirement: 训练相关 UI 视觉基线

训练首页、训练进行中、动作详情、休息计时、PR 庆祝等训练相关界面 SHALL 使用 `design-system` 提供的纸感 Theme Token 渲染（纸白底 / 近黑文字 / 朱砂红强调 / 纸感阴影）。强调色统一为 `Theme.Color.accent`（朱砂红），PR 元素与普通 CTA 共用，MUST NOT 出现霓虹辉光或青/品红强调色。

#### Scenario: CTA 使用朱砂红
- **WHEN** 渲染训练首页 CTA「开始今日训练」
- **THEN** CTA 使用 `Theme.Color.accent` 实底白字 + `paperShadow`，无任何辉光

#### Scenario: PR 元素使用朱砂红
- **WHEN** 动作详情页或庆祝弹窗存在 PR 数据
- **THEN** PR 徽标/竖条/数值使用 `Theme.Color.accent`，不再使用品红

### Requirement: 计划详情（PlanDetail）版式

`PlanDetailView` SHALL 顶部 navbar 显示返回按钮 + 三点菜单；下方 eyebrow（如「PLAN · 训练模板」）+ 大标题（计划名，多行 `Theme.Font` Hero/L1）+ 3 列 meta（动作数 / 组数 / 预计时长）。动作列表 SHALL 用 `ScrollView` + 自绘 row card，每行：左侧 mono 两位序号（`01`/`02`，`Theme.Color.accent` 着色）+ 中间动作名 + 组×次×重量 mono 副标 + 右侧 chevron/handle。

#### Scenario: 添加动作占位行
- **WHEN** 计划详情列表渲染结束
- **THEN** 末尾固定一张 dashed `border2` 占位卡「＋ 添加动作」，点击 push 到动作选择器。

#### Scenario: 底部 CTA
- **WHEN** 渲染计划详情
- **THEN** 底部固定一行：左侧 ghost 按钮（白底 + `border` 描边「复制」）+ 右侧 primary 按钮「开始训练 →」(`accent` 实底白字 + `paperShadow`)。

#### Scenario: 计划 JSON 解码失败
- **WHEN** `WorkoutPlan.itemsJSON` 解码抛错
- **THEN** 列表区显示单张红色占位卡「计划数据损坏，请重建」`Theme.Color.danger`，DEBUG 构建 OSLog 打印原始 payload 前 200 字符。

## ADDED Requirements

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

### Requirement: 动作详情页版式

`ExerciseDetailView` SHALL 顶部 navbar（返回 + 标题）；下方依次：图片占位区（`Canvas` 绘斜条纹背景 + 中心「采集中」标签 + 上传提示图标，因部位高亮图素材尚未采集）、动作中文名（大字）+ 英文/肌群副标、「Form · 动作要点」表单卡（无内容时占位「暂无」）、肌群卡（2 列：主动肌 / 协同肌）。若该动作有 PR，SHALL 在显著位置展示 PR 卡（`accent` 着色）。整页 MUST 使用纸感 token，MUST NOT 出现辉光。

#### Scenario: 动作图未采集
- **WHEN** 进入任一内置动作详情且其部位高亮图未采集
- **THEN** 图片区渲染条纹占位 + 「采集中」标签，不显示空白或破图

#### Scenario: 动作有 PR
- **WHEN** 该动作历史最佳 1RM > 0
- **THEN** 详情页展示 PR 卡，重量用 mono 字体 + `accent` 着色

#### Scenario: 自定义动作详情
- **WHEN** 进入用户自定义动作详情
- **THEN** 副标标注「个人」标签，要点/肌群按用户填写内容展示，未填写处显示占位
