# v1.0-b11 发版功能介绍

> 适用版本：`1.0 (build 11)`
> 后端状态：待部署。本次包含生产后端代码和 Flyway 迁移，最新迁移为 `V13 strip extra weight fields from team plan shares`。
> iOS 状态：准备上传 TestFlight。

## 一句话摘要

本次 build 11 打通 Team 训练计划共享闭环：用户可把个人计划作为无重量快照分享到 Team，队友可复制或直接开始训练，完成后只回流聚合统计，不公开训练详情。

## 面向测试用户的更新说明

- Team 计划更清晰：Team 计划页按「我分享的计划」和「成员分享计划」分组展示，卡片只展示上次更新时间、分享者、动作预览和聚合统计。
- 分享更符合直觉：「发布到 Team」统一改为「分享到 Team」，分享的是当前计划快照，不会带出作者重量。
- 队友有两种使用方式：可复制为自己的训练计划，也可直接开始一次训练。
- 计划更新边界更明确：作者后续编辑原计划不会自动影响队友已复制的计划或已开始的训练；需要使用新版本时重新分享或重新复制。
- 反馈更隐私：基于分享计划完成训练只计入「总共完成次数」，不会公开训练重量、次数、动作组详情，也不会自动出现在 Team 动态。
- 首页入口更简单：首页按钮固定为「开始训练」，始终创建无计划训练，不再猜测从某个计划开始。
- 训练完成后可沉淀计划：无计划训练或直接从 Team 分享计划开始的训练，完成后可保存为个人计划模板。
- 训练中体验更顺：训练记录以全局浮层承接，收起后保留用户当前页面，任意页面都可通过悬浮窗快速回到训练。
- 同步反馈更可感知：自动同步时顶部展示轻量进度提示，不阻挡操作，过快完成也会保留短暂展示。

## 内部技术变更

- iOS 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 11`。
- 新增后端表：`team_plan_share`、`team_plan_share_version`、`team_plan_share_event`。
- 新增后端迁移：
  - `V12__team_plan_shares.sql`：创建 Team 计划分享、版本、事件表，并回填旧共享计划。
  - `V13__strip_extra_weight_fields_from_team_plan_shares.sql`：清理分享快照中可能残留的重量字段。
- 新增 Team 分享计划 API：分享计划、查询 Team 计划分享列表、从分享版本复制为个人计划、记录 `fork/direct_start/complete` 反馈事件。
- 旧 Team 计划接口保留兼容窗口，旧客户端仍可读取和 Fork。
- 分享请求支持客户端携带当前本地计划快照，服务端校验归属后生成无重量版本，避免先同步个人计划导致的旧内容分享。
- 反馈统计改为最小化事件模型：复制人数按 `fork` 用户去重，完成次数统计累计 `complete` 次数，不复用 Team checkin。
- iOS 新增 Team 计划分享 DTO、服务方法、pending 反馈事件队列和弱网重试。
- `Workout` / `WorkoutPlan` 同步模型增加分享来源软关联字段，用于跨设备保留 Team 分享来源。
- iOS 新增 `WorkoutPresentationCenter` 全局训练浮层和 `GlobalSyncProgress` 顶部同步提示。
- 完成页新增保存为计划模板能力，计划项由已完成正式组生成。
- `DontLift` scheme 的 TestAction 已配置 `DontLiftTests` 与 `DontLiftUITests`，可直接通过 XcodeBuildMCP 运行完整 simulator test。

## 兼容性说明

- 本次必须先部署后端，再上传或放量 TestFlight。新版 iOS 依赖 Team 分享计划新接口和 `V12/V13` 数据库结构。
- 后端保留旧 Team 计划接口兼容窗口，未升级 iOS 用户仍可使用旧 Team 计划读取和 Fork 路径。
- 新版分享计划不会携带作者重量；已存在旧共享计划会在迁移中回填为 v1 分享版本并去除重量字段。
- Team 训练动态可见性不变：只有既有自动分享或按次分享才会出现在 Team 动态；分享计划的完成反馈只用于聚合统计。
- 从分享计划直接开始训练不会创建个人计划；用户需要显式「保存为计划模板」或「复制到我的计划」。
- 全局训练浮层只影响进行中训练展示；已完成训练详情仍走普通页面。

## 已完成验证

- iOS build 号已递增到 `11`，App、widget、测试 target 同步，`MARKETING_VERSION` 保持 `1.0`。
- 后端构建和测试通过：`backend ./gradlew build`。
- OpenSpec 严格校验通过：`openspec validate --all --strict`，17 passed / 0 failed。
- iOS simulator 自动化测试通过：XcodeBuildMCP `test_sim`，`DontLift` scheme，`iPhone 17 Pro`，89 passed / 0 failed / 0 skipped。
- XcodeBuildMCP 结果：
  - log：`/Users/yu/Library/Developer/XcodeBuildMCP/workspaces/MeiGei-app-ea2c9008c01d/logs/test_sim_2026-06-28T14-19-22-836Z_pid54239_7bf4fc68.log`
  - xcresult：`/Users/yu/Library/Developer/XcodeBuildMCP/workspaces/MeiGei-app-ea2c9008c01d/result-bundles/test_sim_2026-06-28T14-19-22-837Z_pid54239_e2bb876b.xcresult`

## TestFlight 回归重点

- 后端部署后确认 `/actuator/health` 为 `UP`，并确认 `flyway_schema_history` 最新 `V13` 为 `success=true`。
- 从旧 build 升级到 build 11 后，登录、训练同步、历史训练、个人计划和 Team 首页正常。
- 个人计划详情可「分享到 Team」，分享弹窗区分首次分享、更新和取消分享，确认弹窗可正常执行。
- Team 计划页按「我分享的计划 / 成员分享计划」分组，卡片展示上次更新时间、分享者、动作预览、复制人数和总完成次数。
- 作者只能取消分享自己的计划，不能取消别人分享的计划；取消后列表刷新且后端记录软删除。
- 作者编辑原计划后再次分享到同一 Team，Team 列表展示最新快照内容。
- 队友从分享计划直接开始训练后，完成计入总完成次数，但不出现在 Team 动态。
- 队友从分享计划复制到我的计划后，复制人数按用户去重增加；再次复制新版会生成新个人计划。
- 首页「开始训练」始终创建无计划训练；完成后可保存为计划模板。
- 个人计划开始训练仍保留自适应预填和回写规则，完成后不重复提示保存为计划。
- 任意页面开始训练后，全局训练浮层可展开和收起，收起后保留原页面路由。
- 自动同步顶部提示出现时不阻挡页面操作，快速同步也有短暂可见展示。
- 训练中重量、次数、完成按钮完成态颜色和动画一致，只有完成按钮提供触点反馈。
- Team 解散、删除分组、取消分享等二次确认弹窗层级高于全局训练悬浮窗。
