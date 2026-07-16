## MODIFIED Requirements

### Requirement: 计划详情（PlanDetail）版式

`PlanDetailView` SHALL 顶部 navbar 显示返回按钮 + 三点菜单；下方 eyebrow（如「PLAN · 训练模板」）+ 大标题（计划名，多行 `Theme.Font` Hero/L1）+ 3 列 meta（动作数 / 组数 / 当前模式）。动作列表 SHALL 用原生 `List` 行承载自绘 row card，每行：左侧 mono 两位序号（`01`/`02`，`Theme.Color.accent` 着色）+ 中间动作名 + 下次有效处方 mono 副标 + 来源说明 + 右侧 chevron/handle。列表 MUST 保持纸感卡片外观，并 MUST 由系统原生手势仲裁纵向滚动、动作行侧滑与左边缘侧滑返回。

每个动作行 SHALL 支持点击编辑和向左侧滑显示删除操作。删除操作 MUST 禁止全滑直接执行，并 MUST 在用户二次确认后才删除动作。动作行 MUST NOT 挂载会与列表纵向滚动或系统边缘返回竞争的页面级自定义拖拽手势。

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

#### Scenario: 从动作卡区域连续上下滚动
- **GIVEN** 计划详情包含多张动作卡且内容超过一屏
- **WHEN** 用户从任一动作卡内部开始上下拖动
- **THEN** 列表 SHALL 连续纵向滚动，拖动过程 MUST NOT 因动作行删除手势而断触

#### Scenario: 从动作卡高度侧滑返回
- **GIVEN** 计划详情由上一页 push 进入
- **WHEN** 用户从屏幕左边缘、任一动作卡所在高度开始向右拖动
- **THEN** 页面 SHALL 连续执行系统跟手 pop 转场并返回上一页

#### Scenario: 左滑删除动作需二次确认
- **WHEN** 用户在动作卡上向左侧滑并点击删除
- **THEN** 页面 SHALL 展示删除动作二次确认
- **AND** 用户取消时动作保持不变
- **AND** 用户确认时才删除该动作并沿用现有离线同步流程

#### Scenario: 全滑不直接删除动作
- **WHEN** 用户在动作卡上执行完整的向左全滑
- **THEN** 页面 MUST NOT 绕过二次确认直接删除动作
