# UI、UE、用户体验与性能审查（2026-11-07）

> 本文保留初始审查和各时间点的历史检查结果，不代表当前完成状态；最新结论统一见[专项收口记录](ui-ux-release-readiness-plan-2026-11-07.md)。

Method: native source audit and design review（原生 iOS；网页 detector 不适用）

## 结论与证据边界

**当前候选尚未达到本专项的准发布标准。** 纸感视觉、训练语义和历史数据架构可以继续沿用；首要工作是补齐失败恢复、保存与同步反馈、无障碍基础，再核验高频训练操作的性能。

- 候选：`feature/v1.1-b6`，HEAD `b272f6c`；当前工程版本仍为 `1.1 (5)`。已发布基线为 `v1.1-b5`，依据 [build 5 发布记录](release-1.1-b5-checklist.md)。后续上传需分配未使用的 build，不能复用 5。
- 产品目标：[PRODUCT.md](../PRODUCT.md) 已确认主要服务有训练经验、能自主安排训练的人，优先提高记录与复盘效率。
- 采用 Impeccable 4.8.0 的 native audit、iOS 指南和启发式审查，并结合 `swiftui-performance-audit`。本次为审查与优化方案，不把建议视为已实现。
- 清点了主 App 112 个 Swift 文件、widget 6 个 Swift 文件、37 个单元测试文件和 3 个 UI 测试文件。清点及模式搜索覆盖全目录；深入阅读聚焦各模块入口、关键交互、持久化与同步、历史快照和公共组件，不声称逐行完整审读了全部源文件。
- 原生实际观察：登录、训练首页、计划列表与详情、动作库、Team 列表、我的、历史日历及历史详情。页面切换和日历选日后核对了目标内容；没有以截图代替训练录入、分享、删除等行为断言。
- 环境：复用 iPhone 17 Pro / iOS 26.4，UDID `6D5D86AA-919C-427D-B5B8-B94F54F51E1F`。字体从 `large` 临时改为 `accessibility-extra-extra-extra-large`，观察后恢复 `large`。没有清理数据或创建新模拟器。
- 当前源码 Debug 构建并运行成功；定向 Swift Testing 24 项、5 个 suite 通过，0 失败、0 跳过。尚未执行本候选全量 UI 回归、帧级性能测量、iPad 验收或真机验收。
- 后端只审查与客户端体验相关的同步聚合、批量读取及错误契约，未做生产部署或后端全量测试；后端起停仍由既有指定终端管理。

最终改动、验证结论与待验门禁见[专项收口记录](ui-ux-release-readiness-plan-2026-11-07.md)。阶段 JSON 和原始临时产物已按用户要求清理。

## 审查覆盖

| 产品表面 | 已检查依据 | 本轮证据 | 后续必须补齐 |
| --- | --- | --- | --- |
| 登录、画像与首登补全 | RootView、SessionStore、LoginView、ProfileCompletionView | 源码；真实开发者登录；画像定向测试 | 无本地称呼且离线、请求失败重试、真实 Apple 登录 |
| 训练首页与继续训练入口 | WorkoutViews、MainTabView、LiveSessionCapsule | 首页实际观察、历史快照实现 | 活跃会话冲突、浮层拖拽与 VoiceOver 默认动作 |
| 普通组、递减组、超级组录入 | WorkoutViews、WorkoutEditingState、WorkoutKeypad、训练规格与相关 change | 源码、既有 UI 测试检查 | 输入、焦点、完成与撤销、热身、辅助重量的实际完整矩阵 |
| 休息、键盘与前后台 | RestTimer、RestTimerSheet、WorkoutRestFloatingControl、RestAudioExecutor | 源码及既有性能证据 | 小屏/横屏避让、计时恢复、声音和系统权限真机验证 |
| 结束训练、回写、PR 与成就 | finish、MainTabView 根弹层队列、BadgeWallStore | 源码 | 实际连续提示次数、最后休息段结算、保存失败恢复 |
| 历史日历、账本与肌群复盘 | WorkoutCalendarView、CalendarHistoryScaffold、WorkoutDetailView、MuscleLoadReviewView | 日历选日与详情实际观察；历史规模/并发测试 | 大数据日历流畅度、图表无障碍、日期边界 |
| 个人计划、分组、处方与备选 | PlanViews、PlanCreation、PlanItemDisplay、相关规格 | 列表/详情实际观察；另存与创建定向测试 | 排序、左滑删除取消/确认、边缘返回、大字号完整链路 |
| 历史另存个人计划 | WorkoutPlanTemplateFactory、PlanCreation 与 active change | 定向模型/保存测试 | UI 全链路及同步后的独立性；保留既有超级组规则 |
| 动作库、选择器、自定义与动作详情 | ExerciseViews、ExerciseSearch、ExerciseArtworkLibrary | 动作库实际观察；分页/缓存实现检查 | 搜索输入、选择返回、删除保护、小屏及图片冷缓存测量 |
| Team 列表、动态、计划、历史、共享偏好 | TeamViews、TeamService、TeamCheckinHistoryView/Models、team 规格 | 列表实际观察；源码 | 首次加载/失败/无数据区分、真实双账号共享与撤回 |
| 我的、同步、偏好、账号与法律入口 | ProfileView、SyncRow、GlobalSyncProgress、APIClient | 实际观察；源码 | 开关朗读、保存失败、删号/退出及法律入口专项验收 |
| 海报、成就馆与详情 | WorkoutSharePoster、BadgeWallView、BadgeIconView | 源码、现有资源和测试检查 | 海报预览/导出峰值、长内容、成就馆反复进入的实测 |
| widget、Live Activity、通知与 HealthKit | widget 6 文件、对应 App 控制器、PushManager、HealthKitManager | 源码与测试边界检查 | 真机、锁屏、权限拒绝与撤销、跨日、深链和可选 Watch 展示 |
| 公共设计系统与设备适配 | Theme、Components、Modifiers、HorizontalChipPicker、构建配置 | 实际大字号观察；色板计算；iPhone/iPad target 核对 | 完整 VoiceOver、Increase Contrast、小屏横屏、iPad 窗口尺寸 |
| 影响体验的后端契约 | WorkoutSyncService、GlobalExceptionHandler、客户端 APIClient | 源码；同步替身测试 | 真实服务故障、约束失败、重试幂等及聚合一致性 |

“源码/既有证据”表示已识别设计和实现路径；不代表本轮执行了该流程。真实私人训练截图只用于本机观察，不随审查文档加入仓库。

## 原生技术健康度

以下是按 Impeccable 0–4 量表的审查判断，不是自动测试得分，也不代替逐项发布门禁。

| 维度 | 分数 | 依据 |
| --- | ---: | --- |
| Accessibility | 1/4 | 公共正文字体固定尺寸、灰字低对比、部分开关无语义标签；大字号出现混合缩放 |
| Performance | 2/4 | 后台快照与观察隔离已有保护；当前真机帧时间、内存与能耗证据缺失 |
| Appearance & Theming | 3/4 | Paper token 总体一致；存在旧文档及成就页局部颜色/字号字面量 |
| Platform Conformance | 3/4 | 原生 TabView、NavigationStack、List 与 SF Symbols；定制浮层/菜单仍需手势和辅助功能验收 |
| Adaptivity | 2/4 | 计划展开区已有局部适配；公共字体、固定栅格和横屏/iPad 缺少全面验证 |
| **合计** | **11/20** | **Acceptable：仍需显著改善，不能作为放行结果** |

原生结构判断：当前产品具有清楚的原生层级与工具属性。浅色 Paper 是项目明确约定；本审查不将“不随系统切深色”判为产品缺陷，也不以套用网页卡片或强制更换视觉体系作为改进方案。

## UI／UE 启发式健康度

| 启发式 | 分数 | 关键证据 |
| --- | ---: | --- |
| 系统状态可见 | 2/4 | 有同步轻提示与训练状态，但失败后仅回到“空闲” |
| 符合真实训练语义 | 3/4 | 计划与实际训练分离，逐组、辅助重量与特殊组有明确模型 |
| 用户控制与自由 | 2/4 | 有返回和删除确认；活跃训练冲突突出破坏性动作，启动失败缺少出口 |
| 一致性与标准 | 3/4 | Paper 公共组件已成形；字体适配、部分设置交互和文档存在偏差 |
| 错误预防 | 2/4 | 创建计划防重入与保存失败可重试；部分其他保存路径吞错 |
| 识别优于记忆 | 3/4 | 主导航有文字、训练处方可见；次级动作通过更多菜单访问 |
| 熟练用户效率 | 3/4 | 历史预填、自研数字键盘与模板复用已有基础；收尾负担待实测 |
| 信息层级与简洁性 | 3/4 | 实际页面的核心指标与动作结构明确；低对比小字影响扫读 |
| 错误识别与恢复 | 1/4 | 启动重试耗尽无终态；同步吞错；HTTP/解码原文直接面向用户 |
| 帮助与解释 | 2/4 | 有计划模式规则与局部说明；缺少统一的错误恢复解释 |
| **合计** | **24/40** | **Acceptable；十项均适用于本 App，无 n/a** |

设计特性判断：纸感、等宽训练数据和训练账本与产品用途相符。最大的改善空间在失败状态、可读性和任务连续性。

## 已确认的问题

共 **12 项：P0 0 项、P1 6 项、P2 6 项、P3 0 项**。P0=阻断核心任务；P1=应在发布前修复的重大问题；P2=有可行路径但造成额外负担。P0 为 0 表示本轮没有证据足够的全局阻断缺陷，不能理解为已证明没有崩溃或数据丢失风险。

### UX-01 · P1 · 启动画像失败后没有可恢复终态

- 位置：[RootView.swift](../ios/DontLift/DontLift/RootView.swift#L141) 141–157；[SessionStore.swift](../ios/DontLift/DontLift/Auth/SessionStore.swift) `refreshProfile`。
- 已确认：有 token、本地称呼缺失、画像请求持续失败时，门控保持 nil；自动重试最多五次，结束后界面仍只有 ProgressView，没有重试或切换登录入口。不是“所有离线启动都失败”：已有本地称呼的分支可以进入 App。
- 影响：特定恢复场景中，用户无法判断等待是否还在进行，也无法从页面主动恢复。
- 建议：建立 loading/failed/retrying 路由状态；保留本地数据，提供“重试”和明确的重新登录入口。已有有效本地画像的离线进入行为继续保留；不能把网络失败误判成需要补全资料。
- 验收：模拟无本地称呼的超时/503；重试耗尽出现可操作终态；重新请求成功后正确路由；退出不删除记录。
- 对应命令：`$impeccable harden`、`$impeccable clarify`。

### UX-02 · P1 · 同步失败与成功在界面上无法区分

- 位置：[SyncEngine.swift](../ios/DontLift/DontLift/Sync/SyncEngine.swift#L83) 83–122；[ProfileView.swift](../ios/DontLift/DontLift/Profile/ProfileView.swift#L1111) 1111–1140；[GlobalSyncProgress.swift](../ios/DontLift/DontLift/App/GlobalSyncProgress.swift)。
- 已确认：单域请求异常和最终本地保存失败均被捕获，结束后 `isSyncing=false`；同步行只显示“同步中/空闲”，没有本轮失败、部分成功或待传的解释。现有轻提示并未宣称“同步成功”，问题是恢复信息缺失。
- 影响：用户不能区分“记录在本机，等待上传”与“服务端已经保存”，也不知道是否需要重试。
- 建议：保留轻量非阻塞提示，增加最近结果、部分失败及重试入口；明确本地保存状态与跨设备同步状态。仅在状态变化时更新，避免每行监听全域进度。
- 验收：离线、部分域 500、最终 save 失败、401、成功重试；失败不丢待传项，水位只在成功落盘后前进；完成广播不冒充成功广播。
- 对应命令：`$impeccable harden`、`$impeccable clarify`。

### DATA-01 · P1 · 部分本地保存失败会被成功流程掩盖

- 位置：[WorkoutViews.swift](../ios/DontLift/DontLift/Workout/WorkoutViews.swift#L2958) 2958–2977；[PlanViews.swift](../ios/DontLift/DontLift/Workout/PlanViews.swift#L2236) 2236–2242；[WorkoutDetailView.swift](../ios/DontLift/DontLift/Workout/WorkoutDetailView.swift#L382) 删除路径。
- 已确认：训练防抖保存与立即保存使用 `try?`；编辑已有计划在 `try? save` 后直接 dismiss；部分删除也直接结束页面流程。新建计划的 `PlanCreationSubmission` 已有失败保留与重试，可作为正向参考。
- 影响：磁盘/持久化异常时，用户可能在看到完成或返回后才发现编辑没有可靠落盘。此处是可确认的错误处理缺口，本轮未制造真实磁盘故障，不宣称已复现数据丢失。
- 建议：对训练完成、编辑保存、删除等明确提交边界处理异常，保留草稿与操作上下文，失败不继续成功提示或外部分享；高频录入保留 300ms 合并，不能改成每键强制同步写盘。
- 验收：注入可控 save 失败，断言不会成功退出/分享，重试只提交一次；其他未保存编辑保留；正常输入性能不退化。
- 对应命令：`$impeccable harden`。

### AX-01 · P1 · 字体采用不同缩放规则，放大后主次信息失衡

- 位置：[Theme+Font.swift](../ios/DontLift/DontLift/DesignSystem/Theme+Font.swift#L29) 29–50；[PlanViews.swift](../ios/DontLift/DontLift/Workout/PlanViews.swift#L1054) 动作行 18pt 序号列；多处固定高度文字容器。
- 已确认：常用正文/标题使用固定 `.system(size:)`，自定义 mono 与部分 `@ScaledMetric` 又会放大。在 accessibility XXXL 下，计划详情“规则/动作标签/序号”等放大，动作名称和处方仍很小，序号出现上下分行。
- 影响：需要大字的用户仍读不清关键处方，同时有限空间被另一部分文字占用。
- 建议：定义统一语义缩放，保留默认字号下的 Paper 密度；序号不按固定窄列挤压；辅助字号下按内容重排。不能用统一缩小比例掩盖大字号需求。
- 验收：默认、XXXL、accessibility XXXL；覆盖训练输入、计划折叠/展开、历史账本、设置、菜单和登录；长中文名称、三位数重量、小时计时均可读。
- 对应命令：`$impeccable typeset`、`$impeccable adapt`。

### AX-02 · P1 · 承载内容的小字对比度不足

- 位置：[Theme+Color.swift](../ios/DontLift/DontLift/DesignSystem/Theme+Color.swift)、实际 colorset；[Modifiers.swift](../ios/DontLift/DontLift/DesignSystem/Modifiers.swift) `eyebrowStyle`；首页、计划、日历和设置中的 muted 信息。
- 已确认：按 colorset 实际 sRGB 分量计算，`muted/bg=2.70:1`、`muted/surface=3.02:1`、`fg2/bg=6.21:1`；`accent/surface=4.28:1`、`ok/surface=3.51:1`。并非所有 accent/ok 用途都违规，需按具体字号、粗细和前景/背景检查；禁用与装饰元素另判。
- 影响：10–13pt 的栏目、训练量、历史日期与辅助说明在纸白底上较难阅读。
- 建议：分离“装饰弱色”和“可读次级文字”，增加可读强调/成功前景或高对比变体，逐用途选择。保留品牌色的装饰用途，不把整套 Paper 色板全部替换。
- 验收：信息性小字按 4.5:1 目标核对，适用大字/粗体按 3:1；检查 Increase Contrast。计算结论还要结合真实控件和叠加透明度验证。
- 依据：[Apple 无障碍 HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility)。
- 对应命令：`$impeccable colorize`、`$impeccable audit`。

### AX-03 · P1 · 设置中存在空标签开关和缺少按钮语义的行

- 位置：[ProfileView.swift](../ios/DontLift/DontLift/Profile/ProfileView.swift#L467) 震动、声音、消耗估算的 `Toggle("")` 与 `.labelsHidden()`；`SyncRow`、默认休息、体重、HealthKit 等 `.onTapGesture` 行。
- 已确认：这些开关未获得自身功能标签；可点击行有视觉文本，但没有统一的 Button 语义或对应辅助功能动作。未进行真实 VoiceOver 逐项朗读，本结论为源码语义缺口。
- 影响：读屏用户可能只听到“开关，开/关”，难以判断改变哪个偏好；可操作行的识别和激活也缺少统一保障。
- 建议：使用带实际标签的 Toggle 后隐藏视觉标签；动作行采用 Button，或补齐等价语义与默认动作。装饰图标从朗读中排除，状态值与操作名称分开表达。
- 验收：VoiceOver 完成进入设置、识别和切换偏好、手动同步及返回；名称、状态、顺序与默认动作正确。
- 对应命令：`$impeccable harden`、`$impeccable audit`。

### AX-04 · P2 · 高频次级控件的命中范围偏紧

- 位置：[HorizontalChipPicker.swift](../ios/DontLift/DontLift/DesignSystem/HorizontalChipPicker.swift) 32pt chip；[WorkoutKeypad.swift](../ios/DontLift/DontLift/Workout/WorkoutKeypad.swift#L65) 40×30pt 收键盘；[Components.swift](../ios/DontLift/DontLift/DesignSystem/Components.swift#L27) 默认 36pt 圆钮；Team 28pt 反应按钮。
- 已确认：公共组件没有统一声明 44pt 命中层；最终 toolbar 的系统命中扩展尚未实测，不能只凭 36pt 图形断言所有返回按钮都不达标。
- 建议：把 44×44pt 作为本项目高频任务的默认可触达目标，视觉尺寸可以保留；逐控件检查实际 hit frame、间距和重叠。
- 依据边界：当前 Apple HIG 区分 iOS 默认控制尺寸 44×44pt 与最小 28×28pt，不把所有 36pt/32pt 控件一概称为违反最低标准。
- 验收：窄屏、单手操作、键盘展开和相邻按钮误触检查；不能用扩大的重叠热区制造新问题。
- 对应命令：`$impeccable adapt`、`$impeccable layout`。

### UX-03 · P2 · 活跃训练冲突优先强调丢弃

- 位置：[WorkoutViews.swift](../ios/DontLift/DontLift/Workout/WorkoutViews.swift#L100) 100–121；计划/Team 开始入口同类守卫。
- 已确认：冲突说明完整，但“丢弃并开始新训练”是强调主按钮，“继续训练”是次按钮，取消依赖点击遮罩。
- 建议：以继续既有训练作为主要路径；丢弃使用破坏性次操作并保留明确取消入口。多个入口使用同一文案与顺序。
- 验收：触发所有开始入口的冲突；继续保留全部输入；取消不创建记录；丢弃需明确选择且只生成一场新会话。
- 对应命令：`$impeccable clarify`、`$impeccable harden`。

### UX-04 · P2 · 首次加载和空内容存在混用

- 位置：[TeamViews.swift](../ios/DontLift/DontLift/Team/TeamViews.swift#L20) TeamListView；[TeamCheckinHistoryModels.swift](../ios/DontLift/DontLift/Team/TeamCheckinHistoryModels.swift#L35) 未缓存月份回退空数组；WorkoutCalendarView 的初始快照路径。
- 已确认：Team 列表没有在空缓存时按 `isReloading` 区分正在获取与确实无 Team；历史月历部分统计在未加载月份使用零值。已有非阻塞进度提示，但内容语义仍可能被理解为“没有记录”。
- 建议：统一 unknown/loading/content/empty/failed 状态；有旧内容时保留旧内容并标明刷新，首次失败提供重试。只有成功确认的空集合才使用邀请/新建或无记录文案。
- 验收：首次慢网、离线、历史刷新失败；不把未知统计表示为真实零，不因刷新清空已有内容。
- 对应命令：`$impeccable harden`、`$impeccable onboard`。

### UX-05 · P2 · 网络错误直接包含 HTTP/解码技术正文

- 位置：[APIClient.swift](../ios/DontLift/DontLift/Networking/APIClient.swift#L13) 13–18；Team/Login 等将 `localizedDescription` 直接展示。
- 已确认：错误描述拼接状态码与原始 body，解码错误也直接转述。服务端已使用 ProblemDetail，但客户端没有相应的用户表达层。
- 建议：区分离线、会话过期、权限、冲突、服务不可用和数据异常，输出原因与下一步；保留诊断信息到日志，不清除用户草稿。
- 验收：使用真实形状的 ProblemDetail/非 JSON/空 body，页面显示短文案和适用的重试/重新登录/返回动作。
- 对应命令：`$impeccable clarify`、`$impeccable harden`。

### UX-06 · P2 · 消耗估算“关闭”与“体重必填”同时出现

- 位置：[ProfileView.swift](../ios/DontLift/DontLift/Profile/ProfileView.swift#L556) 556–610。
- 已确认：开关值为 `showsEstimates && bodyWeightKg != nil`，体重提示只依据 `showsEstimates`；当前无体重的页面实际显示关闭开关和红色“必填”。
- 建议：统一显示状态；未完成配置用“待设置/设置后启用”等可解释状态，或在开启动作中收集体重。具体呈现可在实现前对齐，不能把非必需体重写成全产品必填。
- 验收：初始未设置、设置后开启、关闭后保留体重、取消配置、输入无效值，状态与文案一致；不改变历史估算口径。
- 对应命令：`$impeccable clarify`、`$impeccable harden`。

### DS-01 · P2 · 设计依据和局部组件存在漂移

- 位置：[DesignSystem/README.md](../ios/DontLift/DontLift/DesignSystem/README.md) 3–33 的 Neon Techwear/霓虹示例；[BadgeWallView.swift](../ios/DontLift/DontLift/Workout/BadgeWallView.swift#L92) 的局部字号、颜色与渐变字面量。
- 已确认：README 与主规格 Paper 相矛盾；部分页面绕过集中 token。局部渲染是否难看不由字面量本身判断，问题是维护依据与一致性。
- 建议：先记录现有 Paper token、组件状态和无障碍变体，再按受影响组件归并使用；成就插画等内容资产不因 token 统一而被删除。若新增 DESIGN.md，应是记录现有系统的独立任务。
- 验收：文档与实现同源，新增组件可复用；默认/按下/选中/禁用/加载/失败状态有实际用途和样例。
- 对应命令：`$impeccable document`、`$impeccable extract`、`$impeccable polish`。

## 尚待实测的风险（不计入缺陷数量）

| 编号 | 风险与依据 | 必须取得的证据 | 决策原则 |
| --- | --- | --- | --- |
| H-01 | MainTabView 依次处理回写、PR、成就、生涯回顾和分享；实际触发组合未完整操作 | 合成同次命中回写+PR+成就的完整训练，记录弹层次数、操作数、能否跳过与返回 | 若有连续打断，收敛为一次完成回执和按需展开；保留原有回写/撤销/隐私语义 |
| H-02 | 动作缩略图冷命中同步读取、SHA256 与 UIImage 创建，但已限制 288×288、≤24KiB 并有 NSCache | 冷/热缓存滚动的主线程栈、帧时间、缓存驻留与内存峰值 | 有实测热点再异步预解码/调整缓存；不能仅因看见 UIImage 就新增复杂图片框架 |
| H-03 | 计划列表使用 VStack；动作筛选/分组在视图求值期派生；海报数据重复派生且 3× ImageRenderer 在 MainActor | 100 计划、长动作名、动作库快速查询、20 动作海报切换/导出各自的 trace | 按热点减少重复派生、缩小观察范围或懒加载；ImageRenderer 的 actor 要求不能靠盲目 Task.detached 绕过 |
| H-04 | target family 为 iPhone+iPad，支持横屏；动作库固定 92pt 侧栏与两列 88–104pt 卡片，休息卡有固定比例 | 小屏横屏、iPad 全屏和窄窗口实际布局/交互 | 用尺寸条件调整结构，不能凭 iPhone 截图宣称 iPad 通过 |

## 性能证据与待补测项

### 已存在并应保护的实现

- WorkoutHistoryReader/Projection 在后台提取 Sendable 值；WorkoutHistoryStore 合并在途读取，失败保留快照并按账号代数隔离。
- WorkoutEditingState、WorkoutObservationScope 与休息浮层把输入/计时观察限制在消费位置；完成组统计有单次重算路径。
- 训练保存保留 300ms 防抖与离开/后台立即保存；RestAudioExecutor 使用串行后台执行，Live Activity 跳过重复快照。
- 动作库有分页和 LazyVGrid；动作图本身已有尺寸/字节预算。服务端 workout pull 的动作/组使用批量读取，不能把旧的逐 workout 读取问题重新当作当前根因。

### 历史指标的正确读法

以下均来自 [2026-09-18 性能报告](workout-performance-2026-09-18.md)，**不是本轮测得的当前候选帧级结果**：

| 指标 | 历史报告值 | 能证明什么 |
| --- | ---: | --- |
| 600 条历史连续完成组处理，30 次 | P95 30.17ms | App 处理函数耗时，不含最终显示与 300ms 后保存 |
| 600 条历史冷恢复，10 次 | `onAppear` P95 268.22ms | 局部展示回调，不是冷启动或首次可操作帧 |
| 1000 条历史、20×5 组输入 | 数字键处理 P95 0.75ms | 函数耗时，不是按键到屏幕延迟 |
| 1000 条历史读取/聚合 | 后台约 4088/267ms | 后台计算成本仍存在；不能为读取快照重新阻塞输入 |

该历史报告自己列明触摸到显示、完整矩阵与真机 Release 尚未完成。本轮复核这些缺口仍无当前候选证据。Debug app 目录约 89MiB，仅作为本机未裁剪产物观察，不能当作 App Store 下载大小或包体违规结论。

## 规格与发布证据缺口

- **G-01 · 性能门禁未完成**：本候选缺帧级输入/滚动、CPU、内存与能耗基线/对照，以及真机 Release 结果。
- **G-02 · 交互与设备门禁未完成**：本轮无新的自动 UI 测试；VoiceOver、iPad/横屏、小屏、锁屏与权限链路未全面验收。`stabilize-plan-detail-gestures` 与 `finalize-active-rest-with-target-duration` 的 tasks 各有一项人工回归未勾选。
- **G-03 · OpenSpec strict 未通过**：35 项中 16 通过、19 未通过；21 个 change 中 8 未通过，14 个主 spec 中 11 未通过。合计 20 ERROR、33 WARNING；严格模式将警告也计为未通过。包含 MODIFIED 遗漏既有场景、占位 Purpose 与超长 Requirement。不得删场景或降低 strict 来制造通过。
- **G-04 · 候选未冻结**：工程 build 仍为已发布的 5；专项尚未实施，没有新的最终验证候选。多提供方登录 change 的 0/45 不表示本次应新增该功能；先明确当前发布范围，规格治理可单独处理。

## 认知负担与用户情境

- 熟练训练者：预填、逐组值与动作顺序应直接可见；用实际操作验证完成一组、查看上次表现、加一组的成本。不能为了简洁抹平递减组、超级组或辅助重量语义。
- 训练中被打断的单手用户：保存状态、休息、键盘、浮层、前后台应连续；冲突时优先保住已有会话。AX-04、UX-01/02 是具体风险。
- 需要读屏或大字的用户：当前固定字体/混合缩放、低对比和空标签开关是具体障碍；截图和静态标签搜索不足以证明完整可用。
- 情绪低点集中在启动转圈、保存后不确定、同步失败和训练结束。改善顺序应是解释当前状态、保留已输入内容、提供下一步，再呈现奖励与分享。
- 五个 Tab 是导航分区，不因“超过四个选项”的通用启发式而自动删减；复杂任务需要分层，不等于删除训练能力。

## 执行次序

1. `$impeccable harden` / `$impeccable clarify`：先处理 UX-01/02、DATA-01 与错误状态，形成不会掩盖失败的提交边界。
2. `$impeccable typeset` / `$impeccable colorize` / `$impeccable adapt`：以公共字体、可读色和语义控件覆盖五个模块。
3. `$impeccable shape` / `$impeccable distill`：实测 H-01 后决定收尾结构，统一加载空态与冲突提示。
4. `$impeccable optimize`：基于 trace 处理 H-02/03/04，并执行计划中的规模与设备矩阵。
5. `$impeccable polish`：在行为、性能和设备证据齐备后收口，重跑本审查；分数改善不能替代逐项门禁。

## 实施复核记录

S1 实施与定向验证见 [可靠性 change](../openspec/changes/harden-session-save-sync-recovery/tasks.md) 和 [验证结论汇总](ui-ux-release-readiness-plan-2026-11-07.md#验证结论)。UX-01、UX-02、UX-05 的目标行为已定向通过；DATA-01 已覆盖训练录入、结束、删除、丢弃和计划基本信息，但其他计划提交、开始训练与完成页另存失败路径仍待收口。其余无障碍、布局、流程与帧级性能问题尚未因此解决。

实际计划“编辑计划”入口是 `PlanRenameSheet`，此前依赖自动保存并立即关闭；实施中已补上显式保存与错误保留。初始审查引用的 `PlanEditorView` 既有计划分支也已修复。104 条逻辑/持久化用例、10 条具体 UI 用例及 Release 通用模拟器编译通过；这是定向覆盖，不是全产品、真实后端或真机验收通过。

本节补充实施后状态，前面的分数、问题描述、原始证据和 strict 失败数量仍代表审查基线。

2026-11-08 补充：[验证结论汇总](ui-ux-release-readiness-plan-2026-11-07.md#验证结论) 已累计去重通过 114 条逻辑/持久化用例和 17 条 UI 用例。计划其余提交、开始训练及完成页另存已验证；未读取训练子树的撤销快照崩溃与关系丢失已复现并修复，临时定位代码已删除。动作/资料编辑、回写撤销、迁移标记和删号清理仍有明确提交缺口，已列入 tasks 3.8–3.10，DATA-01 继续保持部分完成。当前 change strict 通过，全量 strict 仍有 19 项既有失败。

2026-11-08 S1 收口：tasks 3.8–3.10 已完成。资料旧 GET/PATCH/首登补全响应不会覆盖新编辑或新会话；自定义动作创建隔离失败候选，删除失败恢复原状态；回写撤销成功保存前保留回执；迁移失败不写完成标记；删号本机清理失败保留持久门控及重试，旧同步响应不回填或提交水位。最终轮 140 条逻辑/持久化及 2 条 UI 共 142 条通过、0 失败、0 跳过，累计去重 22 条 UI 通过。默认字号下已检查资料、动作、回执和清理失败状态的渲染结果；动作提交时收起键盘，错误与保存按钮保持可见。当前 S1 源码 Release 通用模拟器编译通过，日常数据库只读计数仍为 496 条训练、16 个计划。详细红灯、修复及最终证据见同一进展 JSON。

DATA-01 的 S1 追踪范围已定向修复；3 项 AX P1、其余流程、帧级性能和完整设备/真机门禁仍未完成。全量 strict 复核仍为 17/36 通过、19 项既有失败；本 change 自身通过。整体准发布结论继续为未通过，不因 S1 收口改写审查基线分数。

2026-11-08 S2 进展：公共字体已接入系统字号并覆盖注册／回退 Mono 的单次缩放；固定海报画布保留排版、以完整摘要向辅助功能提供内容，页面操作继续放大。muted、成功与操作色的实际资源对比通过。首批 19 条逻辑与 1 条最大字号海报交互通过，证据见 [验证结论汇总](ui-ux-release-readiness-plan-2026-11-07.md#验证结论)。公共菜单、Sheet、Chip、其余页面大字与语义仍在实施验证，AX-01/02/03/04 尚未整体关闭。全量 strict 更新为 18/37 通过、19 项原有失败；本次新增 change 自身通过。

后续 S2 公共圆钮、Chip、长文案 Sheet 与滚动菜单已通过三档字号交互；动作库也在真实索引／搜索／创建流程完成三档验证。详情统计的大字单位拆行由渲染核对发现并修复。当前 7/15 项完成；资料、海报及可靠保存定向回归保持通过，其余核心页面及真实读屏尚未验收，AX 项不整体关闭。

## 方法与限制

本次是原生审查，无网页 detector、浏览器覆盖层或独立 A/B 评估，不存在空扫描即“干净”的结论。XcodeBuildMCP 的语义 snapshot 在有实际页面时两次仅返回 1 元素/0 目标，故导航观察改用 Orca Simulator 窗口坐标，并在稳定后的原生截图核对结果；这属于工具证据不足，尚不能据此判定真实 VoiceOver 全部失效。

收尾尝试切回原 Team Tab 时，Orca 返回 `permission_denied`，提示 macOS 辅助功能窗口读取受阻。没有继续修改系统权限或重置模拟器；最后可确认页面为登录恢复后的训练首页。后续实际交互验证需先恢复工具访问，不能将此次权限错误计为 App 缺陷。

本次产品审查记录在本文及 evidence JSON；未运行正式的逐页面 critique 快照归档，也未更改既有 Impeccable 默认设置。设计优先级已由 PRODUCT.md 的记录/复盘效率定位确定，本轮无须重复定位访谈。

## 外部依据

- [Apple Accessibility HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility)：字号放大、对比度、控件尺寸与辅助功能审查；2026-11-07 查询。
- [Improving app responsiveness](https://developer.apple.com/documentation/xcode/improving-app-responsiveness)：离散交互主线程工作应短于 100ms、连续更新通常需约 5ms 内完成。不能把这两种指标互换。
- [Understanding and improving SwiftUI performance](https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance)：通过 Instruments 识别耗时和高频更新，再调整依赖与布局。

本项目的具体性能验收指标与测量口径见专项计划；其中产品自定目标不冒充 Apple 强制规定。


2026-11-08 S2 核心记录页面：task 4.1 完成，进度 8/15。最终核心 8 条 UI、独立超级组和颜色 17 条逻辑均 0 失败、0 跳过；结果与渲染路径见 S2 进展 JSON。针对实际发现的 36pt 数值格、单位重叠、递减组键盘遮挡、日历 Button 角色及历史详情裁切进行修复，不改变训练结构、处方或回填。当前不代表 S2 整体、性能、VoiceOver 或准发布通过。

2026-11-08 S2 推进至 9/15：计划详情、普通/递减/超级组编辑、创建/编辑/分组、真实排序及左边缘返回已完成定向验证。有效当前源码覆盖 9 条独立 UI；最大字号失败项在修正系统段落选择 helper 后通过，重复运行不累计。计划创建与展示逻辑 20 条通过。实际渲染发现的 Sheet 标题挤压、分组装饰图标重叠与悬浮添加遮挡已修正并复核；选中长分组可完整滚入。通用模拟器 arm64/x86_64 测试包编译通过，非当前 Release 验收。Team 空态与队头的大字缺陷已复现，任务 4.4 继续实施。

2026-11-08 S2 推进至 10/15：登录、首登补全、画像恢复与清理门控完成。有效覆盖 7 条独立 UI；最后对最大字号登录/首登/恢复复核，称呼和性别在失败后保留、重试进入主界面、恢复后历史仍在。滚动内容已裁剪，避免画到状态栏后；原生 Apple 登录按钮保留系统提供的 52pt 呈现，法律入口至少 44pt。未执行真实 Apple 认证、生产请求或真实账号清理。徽章、Team 与公共语义/状态色继续收口。

2026-11-08 S2 推进至 12/15：操作／状态色与公共语义核对完成。最大字号同步经隔离响应从部分失败重试到成功，文案保持完整；训练胶囊两档字号均通过44pt、拖动吸附及继续训练，补齐辅助功能默认动作。徽章原生Button角色和进度可被查询。最新6条UI为5通过1失败，默认详情关闭仅42.2pt，已调整公共短按钮最小48pt并继续复核，未将此失败批次记为全绿。胶囊与首页主CTA的默认位置重叠仍在S3跟进；真实VoiceOver与设备/性能门禁未通过。

2026-11-08 S2 最终定向验证：最新公共控件三档3/3通过；徽章详情三档、生涯回顾两档及最大字号计划在当前公共按钮48pt基础尺寸下通过。此前单独的同步状态和胶囊两档也通过。Release主App/widget通用模拟器arm64+x86_64编译通过（1.1/build5，最低部署17.4），并非设备运行或签名归档。并发相关警告按文件/信息归一后13类，与S1 Release一致，无新增。普通本地库只读仍为496条训练、16份计划；临时测试安装版本已恢复为项目正常元数据，未卸载、重置或启动真实账号流程。DS-01文档部分已修正为Paper、实际token/触达与历史色板脚本边界。全量strict仍18/37通过，19项既有问题待S0治理；真实读屏、设备、性能和最终准发布门禁继续待验收。

S2代码change最终15/15、all_done，自身strict和差异检查通过；AX的源代码及定向交互修复已完成，真实VoiceOver/设备验收仍未完成，不将基线审查分数或最终发布门禁改写为通过。

### UX-07 · P1 · 主动分享页把取消误表述为仅自己可见（2026-11-08新增）

`TeamShareSheet` 顶部写“默认仅自己可见”，关闭按钮写“仅自己可见”，但回调仅执行 `dismiss()`。后端V20与`TeamService.addMember`的新成员自动分享默认开启，已有checkin不受该关闭按钮影响。上述为当前源码确认，未对真实账户分享或撤回。S3需将关闭准确命名为取消本次选择，并解释既有分享保持不变；创建/加入Team处说明当前默认分享设置。不得为迎合旧文案而静默关闭用户偏好或撤回既有内容。此项为新增发布前P1，尚未修复。

S0记录：9个Purpose占位已替换为真实能力说明，Team已完成change语义合并入四个主规格。全量strict为26/38通过、12项未通过；新增team-workout-nudge主规格使分母增加1。隐私页面仓库源文案已按当前默认开启行为修订，尚未部署线上。原审查12项为当时基线，本次新增UX-07单独追踪。证据见[规格治理与最终结果](ui-ux-release-readiness-plan-2026-11-07.md#最终改动)。

2026-11-08 S3首批完成3/20：UX-07已修正并通过6条主动分享隔离UI，取消不发送分享、删除或偏好请求；提交仅作用于选中目标并保留既有分享。创建/加入默认及最大字号2条说明/失败恢复、拍一拍成员页两档2条真实下滑关闭与快照反应回归通过。10条均核对当前运行镜像，不包含真实后端/APNs。UX-03等后续项未因此关闭，证据见[验证结论汇总](ui-ux-release-readiness-plan-2026-11-07.md#验证结论)。

2026-11-08 S3推进至7/20：UX-03三个入口已统一继续/危险丢弃/显式取消，两档字号实际操作及替换失败恢复通过；13条逻辑/持久化回归通过。UX-04的Team列表4条、月历5条隔离UI已通过，验证首次未知、失败重试、保留缓存、真实空与月份响应隔离。个人历史状态仍待验证，UX-04整体未关闭。普通库只读计数仍496条训练、16份个人计划；未重置或卸载。

2026-11-08 S3推进至8/20：个人历史7个不同UI方法已验证。慢读时仍可空白开始、进入日历/月份选择；缓存失败保留旧快照并显式重试；未就绪不显示真实零统计。20秒慢读期间录入63.75公斤，等待快照完成并继续同一训练后输入保留，读取回调始终1次。原始首轮7条为5通过2失败，后续两条针对修复均通过，不误计为9个不同方法。下一项为可选消耗估算；排序、胶囊、收尾与集成仍未完成。

2026-11-08 S3推进至10/20：可选估算两项完成。无体重显示“未设置（可选）”，显式开启保存才启用，单独编辑体重保留可见开关，关闭保留体重。7个不同隔离UI方法及10条既有估算/海报逻辑通过；已开启的两条初轮失败来自页面刷新误读普通偏好，统一偏好来源后复跑通过，关闭路径也已在当前fixture补核。最大字号未设置提示与取消配置已核对渲染。排序、胶囊、收尾及集成继续待办，整体仍未准发布。

2026-11-08 S3推进至14/20：四类排序的显式取消/完成、禁下滑和局部失败恢复两项完成；四个排序逻辑方法覆盖13个参数场景及真实只读库，复用14条既有超级组结果。当前有8个不同排序UI方法通过，最后训练AX的来源计划核对因按需加载取不到行，改走真实计划排序面板继续补核，5.3未勾选。胶囊两项完成：5个几何逻辑方法与两档UI通过，实测胶囊底边715/689pt，主操作起点722.75/696.75pt，Tab Bar起点791pt；拖动、切页、同训练输入与计时保留、历史读取仍1次。真实VoiceOver、完整设备和帧级性能仍独立未验收。下一批收尾多结果基线仅用全新内存库，不动日常数据。

2026-11-08 S3推进至15/20：排序5.3已补核。9个不同排序UI方法均通过，最后训练AX通过真实来源计划排序面板确认未回写原顺序；此前失败批次与测试定位修正均单独留证。收尾首轮实际观察到计划回写→PR→徽章，三个单一模态及无重复检查通过，但方法在误查“返回”而非实际“关闭”按钮处失败，7.1继续待验证，不记为全绿。


2026-11-08 S3代码与定向验证收口（20/20、CLI all_done，自身strict及差异检查通过）：UX-03冲突、UX-04未知/缓存/空态、UX-06可选估算与新增UX-07客户端分享文案均已修复；四类排序支持显式取消/完成、失败保留草稿，胶囊两档避让主操作。H-01经实际结束流程定位并修复关闭动画与下一项PR交叉清理导致的空白Sheet；严格计划同一方法连续3次通过，普通/慢结果均无重复、可重看回执并返回。训练收尾相关13个不同UI方法按各自有效源码范围覆盖，原始失败批次仍保留，不将重复迭代计为新用例。完整问题映射、编译与复用边界见[专项最终改动汇总](ui-ux-release-readiness-plan-2026-11-07.md#最终改动)及[验证结论汇总](ui-ux-release-readiness-plan-2026-11-07.md#验证结论)。S0全量strict仍27/39通过；真实VoiceOver、设备、帧级性能、真实服务和真机门禁未通过，保持整体未准发布结论及原审查分数。


2026-11-08 S0治理收口：全量OpenSpec strict已由S3收口时的27/39推进到39/39（15主规格+24change），差异检查通过。原审查与S1/S2/S3各检查点的历史结果保留，不改写为当时已全绿。条款细则、完整别名/徽章矩阵与既有场景约束均保留，未来多身份仅治理规划；这项通过不代表所有active change已实现、人工验收已执行或整体准发布。详见[规格治理与最终结果](ui-ux-release-readiness-plan-2026-11-07.md#最终改动)。
