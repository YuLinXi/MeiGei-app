## ADDED Requirements

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
