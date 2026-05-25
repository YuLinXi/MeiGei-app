## ADDED Requirements

### Requirement: 训练首页周聚合视图

iOS 训练首页 SHALL 在顶部展示「本周训练量」hero（按本地时区周一 00:00 为周起点），并以三宫格展示本周「总组数 / 总次数 / 平均时长」。聚合数据 MUST 按需即时计算自本地 `Workout` 集合，不入库。当本周训练数为 0 时，hero MUST NOT 显示「0.0 t」字面量，而 SHALL 展示鼓励性 Empty State 文案与「开始第 1 次训练」CTA。

#### Scenario: 本周已有训练
- **WHEN** 用户进入训练首页，本周已记录 4 次训练，总训练量 28.4 吨
- **THEN** Hero 显示「28.4 t」并附副标「已完成 4 / Y 次」（Y 为当前激活计划的周训练目标次数，无激活计划时改为「本周第 4 次训练」）

#### Scenario: 本周尚未训练
- **WHEN** 本周训练数为 0
- **THEN** Hero 显示「准备好了吗？」文案与「开始第 1 次训练」CTA，不显示「0.0 t」

#### Scenario: 三宫格缺值
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

### Requirement: 动作详情 PR 卡与 1RM 曲线

动作详情页 SHALL 展示该动作的 Personal Record 卡片（数据源复用现有 PR 计算）与 90 天 1RM 估算曲线（采用 Epley 公式 `1RM = w × (1 + r/30)`）。无 PR 数据时整张 PR 卡 MUST 隐藏；1RM 曲线数据点 < 3 时 MUST 显示「数据不足 · 至少需要 3 次记录」占位而非空白图表。

#### Scenario: 有 PR 记录
- **WHEN** 动作存在历史 PR
- **THEN** PR 卡显示重量 × 次数大字、PR 日期、与历史第二高 PR 的差值（如「较上次 PR +2.5kg」）

#### Scenario: 无 PR 记录
- **WHEN** 动作从未被记录
- **THEN** PR 卡整体不渲染，不在页面留空位

#### Scenario: 数据点不足
- **WHEN** 90 天内 1RM 数据点少于 3 个
- **THEN** 曲线区域显示「数据不足 · 至少需要 3 次记录」占位文案

### Requirement: 训练相关 UI 视觉基线

训练首页、训练进行中、动作详情三屏 SHALL 使用 `add-neon-design-system` 提供的 Theme Token 渲染（颜色 / 字体 / 间距 / 圆角 / 发光阴影）。霓虹品红色（`Theme.Color.accentMagenta`） MUST NOT 用于上述三屏的常态 UI 元素，仅 PR 庆祝相关元素（PR 卡边光、PR 徽标、新增 PR 文字）可使用。

#### Scenario: 常态元素不得使用品红
- **WHEN** 渲染训练首页 CTA「开始今日训练」
- **THEN** CTA 必须使用 cyan accent，不得使用 magenta

#### Scenario: PR 元素使用品红
- **WHEN** 动作详情页存在 PR 数据
- **THEN** PR 卡的左侧 3px 竖条与外发光必须使用 magenta accent
