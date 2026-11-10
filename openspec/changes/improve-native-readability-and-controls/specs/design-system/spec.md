# Spec Delta

## MODIFIED Requirements

### Requirement: Theme Token 命名空间

App 的颜色、字体、间距、圆角 SHALL 以 `Theme.Color.*` / `Theme.Font.*` / `Theme.Spacing.*` / `Theme.Radius.*` 命名空间集中暴露；视图 MUST NOT 直接构造等价的颜色或字号字面量。品牌强调与可读操作 SHALL 使用各自职责的 token。

#### Scenario: 引用颜色
- **WHEN** 新视图需要主色 CTA 背景
- **THEN** 通过 `Theme.Color.action` 获取可读深朱砂色值，装饰强调通过 `Theme.Color.accent` 获取品牌原色
- **AND** 不在视图内直接构造等价的颜色字面量

### Requirement: 横向 Chip 选择器组件

设计系统 SHALL 提供 `HorizontalChipPicker<Item: Identifiable>`，保留水平 ScrollView、相邻 8pt 间距、横向内边距 14pt 和 pill 圆角。默认视觉高度至少 32pt，实际触达 SHALL 至少 44×44pt，阅读字号放大时文字与容器共同增长。选中态 SHALL 使用可读深朱砂实底与白字，未选中态保留白底、主描边与次级正文；辅助功能 SHALL 提供名称和选择状态。

#### Scenario: 动作库部位筛选
- **WHEN** 动作库展示部位或器械筛选 chips
- **THEN** 使用公共横向选择器，默认选中全部，切换选项后仅目标项标记已选择
- **AND** 放大字号后仍可横向浏览完整名称，触达区域不与相邻选项重叠

### Requirement: 纸感色板 Token

设计系统 SHALL 保留纸白、近黑、暖表面、边框与朱砂品牌强调的色相及层级，提供可读的次级文字和状态色。普通文字及小号白字操作 SHALL 在实际背景上达到至少 4.5:1；大字至少 3:1。`muted` SHALL 使用更深的暖灰，操作文字与实底按钮 SHALL 使用同源深朱砂操作色；品牌强调和装饰浅底保留原色。浅色 colorset 保持 universal 单值，不增加外观开关。

#### Scenario: 卡片描边与背景
- **WHEN** 渲染任意纸感卡片
- **THEN** 表面为白色 `#ffffff`，页面为纸白 `#f4f2ec`，主描边保持 `#e4ddd0`，暖表面保持 `#efece5`
- **AND** 近黑正文 `#1c1a17`、次级正文 `#5e5950` 与次边框 `#d8d2c6` 保持原有职责

#### Scenario: 强调浅底着色
- **WHEN** 渲染 LIVE 横幅或选中态浅底
- **THEN** 浅底与浅边继续分别使用 8% 和 18% 的品牌朱砂 `#d9482b`
- **AND** 浅底上的小号操作文字使用深朱砂可读色

#### Scenario: 次级文字与小号按钮可读
- **WHEN** 展示提示、单位、状态、按钮文字或输入占位
- **THEN** 文字在纸白、卡片白或所在暖底上满足对应对比要求
- **AND** 不使用装饰性浅灰或原品牌朱砂充当未达标的小号文字／白字按钮底色

### Requirement: 等宽数字字体回退

App SHALL 加载 JetBrains Mono 展示训练量、PR、计时器等数字。缺少相应字体或字重时 SHALL 回退至系统等宽字体，保持数字对齐、系统字号缩放与可读性，MUST NOT 崩溃或显示错误字形。

#### Scenario: 字体资源齐全
- **WHEN** App 启动并验证所需 JetBrains Mono 字体已注册
- **THEN** 等宽字段以相应字体显示，并按其文本角色响应系统字号

#### Scenario: 字体资源缺失
- **WHEN** Bundle 中缺少所需字体文件或字重
- **THEN** 对应字段使用系统等宽字体并按相同文本角色缩放
- **AND** DEBUG 打印一次诊断，Release 静默回退

### Requirement: 字号语义层

界面 SHALL 保留默认字号下的 Hero 32pt、L1 23pt、L2 16pt、L3 15pt、L4 13pt、L5 11pt 与计时数字 58pt 的既有层级，中文及正文使用系统字体，数据使用等宽字体。字号 SHALL 按标题、正文、标签与数据对应的系统文本角色缩放一次，MUST NOT 固定界面字号或重复放大已缩放值。固定导出画布仅在画布内保留排版字号。

#### Scenario: 渲染屏幕大标题
- **WHEN** 视图显示屏幕级大标题
- **THEN** 使用统一标题角色，默认对应 L1 或 Hero 基准，并跟随系统阅读字号放大

#### Scenario: 渲染计时器数字
- **WHEN** 休息弹层展示中心剩余时间
- **THEN** 默认使用 58pt 等宽 tabular 数字，系统字号放大后仍可完整读取时间

#### Scenario: 已有预缩放路径
- **WHEN** 计划详情展示处方、单位与元数据
- **THEN** 各自只按相应系统文本角色缩放一次，中文与数字保持一致的放大逻辑

#### Scenario: 固定导出画布
- **WHEN** 生成或预览固定尺寸的训练海报
- **THEN** 画布内部保持约定排版且提供可理解的内容摘要
- **AND** 页面上的保存、分享、取消和其他操作继续响应用户字号

### Requirement: 动效降级与 Dynamic Type 防截断基线

持续或重复动效 SHALL 在减弱动态效果开启时退化为静态或淡入淡出。界面文本 SHALL 响应系统阅读字号，通过换行、内容高度增长、滚动或合适的纵向布局保持可读，MUST NOT 以把全部文本缩回小字替代适配。必要的导航标题截断 SHALL 保留可读的完整辅助功能名称。

#### Scenario: 减弱动态效果关闭重复动画
- **WHEN** 用户开启减弱动态效果并进入含 LIVE 脉冲的界面
- **THEN** 脉冲停止重复，呈现静态样式

#### Scenario: 超大动态字号
- **WHEN** 用户把系统字号调大并浏览首页或编辑核心训练内容
- **THEN** 标题、说明与关键数值仍可读，不重叠，不被固定高度切掉
- **AND** 必要时换行、纵向排列或滚动，关键操作仍可到达

### Requirement: 统一圆形图标按钮

设计系统 SHALL 提供统一圆形图标按钮作为 Header、导航栏的返回、更多及次级操作入口，视图 MUST NOT 复制等价外观。默认视觉直径保持 36pt，与圆形添加按钮一致；实际触达区域 SHALL 至少 44×44pt。图标尺寸由组件推导，保持白底、主描边、纸感按压样式以及选中浅朱砂和旋转态。动作菜单 SHALL 使用同源自绘纸感入口，MUST NOT 改为系统 Menu。

#### Scenario: 子页接入返回按钮
- **WHEN** push 或 sheet 子页提供返回入口
- **THEN** 使用统一纸感圆钮，默认视觉直径 36pt、触达区域至少 44pt
- **AND** 不出现系统默认蓝色返回箭头

#### Scenario: 更多操作菜单圆钮
- **WHEN** Header 提供更多操作菜单
- **THEN** 点击版与菜单版使用同一圆钮外观和触达尺寸
- **AND** 展开时进入选中与旋转态，仍弹出自绘纸感动作菜单

#### Scenario: 禁止本地复制实现
- **WHEN** 新增或修改 Header 圆形按钮
- **THEN** 复用统一组件或同源菜单入口，不重新声明等价外观

### Requirement: 统一子页 Header 容器

设计系统 SHALL 以 `PaperNavBar` 或等价 `.paperToolbar()` 统一所有 push/sheet 子页的 Header、返回手势与系统背景兼容。容器 SHALL 提供左返回、中标题、右操作三槽位，左右默认使用 `CircleIconButton`；标题使用单一字体 token、居中且单行截断。页面 MUST NOT 散用裸 toolbar、自绘圆钮或逐项背景补丁。五个 Tab 根页继续使用自绘大标题，不接入子页容器；边缘返回仅作用于 push 子页。

#### Scenario: 子页统一接入

- **WHEN** `WorkoutDetailView` / `PlanDetailView` / `TeamDetailView` / `ExerciseDetailView` / `TeamPlansView`（push/sheet 子页）渲染顶部标题栏
- **THEN** 均经由 `.paperToolbar()` 接入，标题字体一致、返回/操作钮均为 36pt 纸感圆钮
- **AND** 不再各自处理 `navigationBarBackButtonHidden` 与 iOS 26 双环补丁
- **AND** 容器以纸感 leading 控件替换系统返回项，保留原生返回语义，不通过隐藏返回标志禁用手势；标题不再混用系统 inline、`body(15,heavy)` 与 `display(30)`

#### Scenario: push 子页支持侧滑返回

- **WHEN** 用户在任一经 `.paperToolbar()` 接入的 push 子页（`PlanDetailView` / `PlanEditorView` / `WorkoutLoggingView` / `WorkoutDetailView` / `TeamDetailView` / `TeamPlansView` / `ExerciseDetailView`）从屏幕左边缘向右侧滑
- **THEN** 触发标准 pop 返回上一页，带原生跟手转场动画，效果与点击纸感圆形返回钮一致
- **AND** 该行为由 `.paperToolbar()` 容器统一提供，无需子页各自实现
- **AND** 容器恢复 `interactivePopGestureRecognizer`；`fullScreenCover` / `sheet` 模态页不接管此手势，继续使用下滑 dismiss 语义
- **AND** 仅当导航栈 `viewControllers.count > 1` 时允许边缘返回手势开始

#### Scenario: Tab 根页不被误触发返回

- **WHEN** 用户在导航栈根层（Tab 根页，`viewControllers.count == 1`）从左边缘侧滑
- **THEN** 不触发 pop，页面保持当前状态，不出现异常空白页或栈崩溃

#### Scenario: 我的页归入大标题范式

- **WHEN** Tab 根页「我的」(`ProfileView`) 渲染顶部
- **THEN** 用自绘大标题「我的」`display(36, heavy)` + `tracking(-1.08)`、隐藏系统导航栏，与其它 4 个 Tab 根页一致
- **AND** 不出现系统 inline 居中标题

#### Scenario: iOS 26 不出现双环

- **WHEN** 在 iOS 26+ 设备上进入任一接入了 `PaperNavBar` 的子页
- **THEN** Header 圆钮仅显示纸感白底圆形一层背景，不出现系统 Liquid Glass 叠加的第二层圆环
- **AND** 容器对工具栏按钮使用 `sharedBackgroundVisibility(.hidden)`；低于iOS 26走等价无背景分支

#### Scenario: 子页标题字体统一

- **WHEN** 任意子页显示标题文字
- **THEN** 使用容器约定的单一标题字体 token，跨子页字号、字重一致

#### Scenario: 可见窗口中的边缘返回

- **WHEN** 用户从可见模拟器窗口或设备屏幕左边缘向右拖动
- **THEN** push 子页执行原生跟手返回，不依赖 XCTest 注入路径才能开始
- **AND** 导航栏仍只有一个纸感返回按钮，展开收起内容或关闭编辑弹层后仍可返回

## ADDED Requirements

### Requirement: 计划表单的原生输入命中

个人计划新建、基础信息及独立备注编辑的名称和备注 SHALL 保留原生文本输入与选择。纯装饰背景或描边 MUST NOT 拦截可见输入区域的点击；默认和辅助功能最大字号、最低与当前系统均 SHALL 能取得焦点并实际输入。修复 MUST NOT 通过覆盖自定义点击手势或直接改写测试数据代替原生输入，也不改变保存失败草稿、取消和重试语义。

#### Scenario: 最大字号直接点击计划名称
- **WHEN** 用户在最低或当前系统的小屏上以辅助功能最大字号打开新建或编辑计划，并点击可见名称输入框中心
- **THEN** 原生输入框获得焦点，能够实际输入、选择或修改文字
- **AND** 装饰描边不成为阻断输入的命中层

#### Scenario: 计划备注输入和失败恢复
- **WHEN** 用户点击可见备注区域并编辑后提交，而本地保存失败
- **THEN** 原生备注仍可编辑，输入保留，用户可取消或重试
- **AND** 不因装饰层透传改变已保存处方及其他未保存内容

#### Scenario: 独立备注的大字与键盘
- **WHEN** 用户以辅助功能字号打开独立备注并显示原生键盘
- **THEN** 页头标题、取消与提交操作保持完整，正文、计数和清空可以滚动到达
- **AND** 用户可通过原生键盘工具条收起键盘，随后点击备注区域继续编辑，不提交或丢失草稿

### Requirement: 公共控件可执行语义

所有可交互开关、选择器、展开行与导航入口 SHALL 向辅助功能提供清晰名称、当前值及可执行默认动作。开关 MUST NOT 仅提供空标签；选择与展开状态 MUST NOT 只依赖颜色表达。语义完善 SHALL 保留原操作、训练结构和数据行为。

#### Scenario: 资料或训练设置开关
- **WHEN** 读屏或辅助功能定位一个设置开关
- **THEN** 可读取设置名称及开／关状态，并执行切换

#### Scenario: 选择与展开操作
- **WHEN** 用户定位计划模式、动作筛选、分组或详情展开入口
- **THEN** 能读出用途和当前选中／展开状态，并执行对应操作

### Requirement: 公共文本容器适配

Sheet 标题和操作、动作菜单、Chip 与核心编辑区 SHALL 在默认、大号及辅助功能超大字号下保留可读内容与可用操作。触达区域 SHALL 至少 44×44pt，适配后的菜单定位 SHALL 依据实际内容尺寸避让边缘。文字放大 MUST NOT 破坏编辑、返回、排序和取消手势。

#### Scenario: 大字 Sheet 与菜单
- **WHEN** 用户在超大字号下打开带长标题的 Sheet 或多项菜单
- **THEN** 内容可读取、操作可触达，菜单按实际尺寸保持在可用范围

#### Scenario: 训练编辑连续性
- **WHEN** 用户在放大字号下记录重量次数、完成组、使用休息或返回页面
- **THEN** 关键数值与状态仍可读，操作不被键盘、安全区或其他控件遮挡
- **AND** 原输入、处方、保存与手势行为保持有效

#### Scenario: 编辑中缩窄窗口
- **WHEN** 用户保持重量或次数聚焦，并将iPad训练窗口从全屏缩窄
- **THEN** 聚焦字段在新视口中保持位于数字键盘上方，可继续编辑
- **AND** 原重量、次数与训练状态保持有效，不以清空焦点或收起键盘代替避让
- **AND** 正常动画与减弱动态效果两种模式均满足该行为

#### Scenario: 小屏超级组数字输入
- **WHEN** 用户在最低或当前系统的小屏上使用辅助功能最大字号，编辑超级组成员次数并切换到统一组数
- **THEN** 完整聚焦字段处于页头与数字键盘之间，不被任一边缘遮挡
- **AND** 成员次数与统一轮数可继续修改，保存后详情显示新的处方

#### Scenario: 徽章与回顾可读
- **WHEN** 用户放大字号查看徽章墙、徽章详情、训练庆祝或生涯回顾
- **THEN** 名称、进度、达成快照与操作文字遵循公共字号和可读色，不被固定行数或高度截断
- **AND** 内容可滚动、关闭操作可到达，勋章图形保留既有绘图尺寸与风格，并由可读名称和状态补充
