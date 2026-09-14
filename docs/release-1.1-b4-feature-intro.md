# v1.1-b4 肌群容量复盘与训练交互优化功能介绍

> 发布基线：`v1.1-b3`
> 目标候选：`MARKETING_VERSION = 1.1`，`CURRENT_PROJECT_VERSION = 4`
> 当前工程实际版本：App、Widget、测试 target 均为 `1.1 (build 4)`
> 候选分支：`feature/v1.1-b4`
> 候选提交：`0705e4fddff1a7b75bc7c26c1d71783035eb1ae5`
> 文档状态：**候选已提交并推送；main 已本地合并；TestFlight 已可安装；待推送 main、创建 tag**
> 关联清单：[release-1.1-b4-checklist.md](release-1.1-b4-checklist.md)
> 用户公告：[release-1.1-b4-user-announcement.md](release-1.1-b4-user-announcement.md)

## 版本与状态

| 项目 | 当前状态 |
| --- | --- |
| 最近已发布基线 | `v1.1-b3`，历史记录确认已完成 TestFlight 发布 |
| 目标 iOS 版本 | `1.1 (build 4)` |
| 工程内实际版本 | `MARKETING_VERSION = 1.1`、`CURRENT_PROJECT_VERSION = 4`，8 组 configuration 一致 |
| 后端部署 | **无需部署**。`v1.1-b3..HEAD` 与工作树均无 `backend/` 改动，无 API、迁移或同步契约变更 |
| 后端生产状态 | 只读检查通过：health 200/`UP`，`/privacy` 200，`/terms` 200，生产 dev token 404；Flyway V22 `success=true` |
| iOS build | build 4：iPhone 17 Pro / iOS 26.5 Simulator Debug build 成功 |
| iOS 自动化测试 | xcresult 汇总 274/274 通过；UI target 9/9 通过，0 失败、0 跳过 |
| OpenSpec | 14 份主 spec 严格校验通过；相关 change 已归档，归档 change ID 不作为 active delta 通过项 |
| App Store Connect build 4 | 用户已确认未重复使用 |
| TestFlight | 用户确认已上传，状态为 `VALID` 且可安装 |
| 发布收口 | 未合并 `main`，未创建 `v1.1-b4` tag |

## 一句话摘要

本次候选让肌群周负荷从“只看组数”扩展为“组数与容量一起复盘”，并将排序和训练进行页的高频交互调整得更稳定、更符合系统操作习惯。

## 面向测试用户的更新说明

以下内容只汇总相对最近已发布版本 `v1.1-b3` 的最终可感知差异：

### 1. 肌群负荷复盘新增容量

- 首页「本周肌群负荷」小卡的每个肌群现在同时展示有效组数和训练容量，例如「12 组 · 8.6 t」，摘要也会显示本周总容量。
- 周复盘页的总览、肌群条目和贡献明细均可查看容量；容量按 kg/t 自动格式化，便于同时判断训练次数和训练量。
- 本周对比改为与上周完整一周对账，同时比较组数和容量；没有变化的分量不再显示。切换到上周时只看完整历史数据，不再展示多余的上上周对比。

### 2. 排序交互统一为系统弹窗

- 训练进行中、计划详情和计划列表的动作排序统一改为系统 sheet，支持自然下滑关闭。
- 排序期间底层页面保持封锁，点击「完成」或关闭弹窗后一次性保存顺序。

### 3. 训练进行页交互更流畅

- 高频勾选、连续录入和休息提示的页面更新与保存路径经过优化，减少训练中输入时的卡顿和重复刷新。
- 训练状态、Live Activity 快照和本地保存仍在离开页面、结束或丢弃训练前强制落盘。

## 内部技术变更

- 本次没有后端代码、数据库迁移、REST API、同步 envelope 或 Team 服务端契约变更。
- `MuscleLoadAggregator` 保持原有有效组数与容量聚合口径，新增容量读取入口；UI 补齐首页小卡和周复盘页的容量展示，并将对比基线统一为上周整周。
- `MuscleLoadRowView` 继续由首页小卡和周复盘页共用；趋势柱与排序仍保持按有效组数口径，不因新增容量展示而改变。
- 排序面板由自绘就地浮层收敛为系统 `.sheet`，三处宿主共享同一组件，关闭时统一提交草稿顺序。
- 训练进行页通过统计快照、查找缓存、300ms 防抖落盘和离开关键节点强制 flush，降低高频编辑的全量重估与持久化放大。
- OpenSpec `add-muscle-load-volume-display` 已随实现归档，主 `workout-tracking` spec 已同步更新。

## 兼容性说明

- **后端无需先发或配套发版**：本次为纯客户端展示和交互变更，生产 V22 已是当前后端最新成功迁移，未新增服务端要求。
- `v1.1-b3` 及更早客户端仍可继续使用现有后端能力；本次肌群容量展示、上周整周对比口径和系统排序体验只有安装候选 iOS build 后才会生效。
- 不涉及数据表、同步字段和 API 兼容别名，不需要旧客户端强制升级。

## 已完成验证

- Git：版本递增前工作树无既有改动；本次候选提交为 `0705e4fddff1a7b75bc7c26c1d71783035eb1ae5`，包含 build 4 工程版本修改与 3 份发版文档；`git diff --check` 及基线差异检查通过。
- 后端：JDK 21 下 `./gradlew clean build` 通过；`./gradlew test --rerun-tasks` 通过。
- iOS：build 4 在 iPhone 17 Pro / iOS 26.5 Simulator Debug build 通过；`xcodebuild test` 为 `TEST SUCCEEDED`，xcresult 汇总 274 项测试全部通过，UI target 9 项全部通过。
- OpenSpec：`openspec validate --specs --strict --no-interactive` 通过，14/14 主 spec 有效。
- 生产只读：`/actuator/health` HTTP 200 且 `status=UP`；`/privacy`、`/terms` HTTP 200；`POST /auth/dev/token` HTTP 404；生产 Flyway 最新 V22 `success=true`。
- 当前仍有既有 Swift concurrency/main-actor 编译 warning，但没有编译失败；应在后续技术债处理中单独治理，不阻塞本次候选的当前构建门禁。
- 用户已确认 build 4 的人工 UI 回归和 TestFlight 安装验证全部通过；本轮未提供设备/iOS 版本和时间明细，因此不在文档中虚构具体测试环境。

## TestFlight 回归重点

1. 首页小卡：验证「N 组 · 容量」与「共 N 组 · 总容量」在短容量、长容量、零值和「其他」桶场景下不截断、不挤压。
2. 周复盘本周页：验证总容量、组数/容量双分量对比、持平分量省略，以及与上周完整数据可对账。
3. 周复盘上周页：验证切换后展示完整周数据，头部和展开贡献明细不出现对比文案。
4. 排序：在训练进行中、计划详情、计划列表分别测试长按拖拽、点击完成、下滑关闭和重新进入后的顺序持久化。
5. 训练性能：连续快速勾选多组、快速编辑重量/次数、启动休息计时并切换前后台，确认页面无明显卡顿、重复刷新、数据回退或 Live Activity 状态滞后。
6. 既有关键回归：冷启动、Apple 登录、同步、Team、Live Activity、通知、HealthKit 和 Widget。

## TestFlight 用户文案（可直接复制）

本次更新（1.1 build 4）重点体验：

1. 肌群负荷复盘新增容量：训练首页和周复盘页现在会同时显示各肌群有效组数与训练容量，帮助你同时判断训练频率和训练量。
2. 周对比更容易核对：本周会与上周完整一周同时比较组数和容量；切换查看上周时展示完整历史数据，不再显示多余的上上周对比。
3. 动作排序更顺手：训练进行中、计划详情和计划列表统一使用系统排序弹窗，支持下滑关闭，完成或关闭后保存排序结果。
4. 训练录入更流畅：优化了连续勾选、录入和休息提示时的页面刷新与保存体验。

TestFlight 已可安装，请重点反馈肌群容量排版、周复盘对比和三处排序拖拽/关闭体验。

## 发布收口

- [x] 将所有 target 的 build 从 3 递增为 4，并重新执行必要的 build/test；8 组 configuration 已统一，build/test 均通过。
- [x] 用户确认完成 Simulator/真机人工回归和 TestFlight 安装验证；设备/iOS 详细信息待补充时不作虚构记录。
- [x] 用户确认已完成 Archive、上传 TestFlight，状态为 `VALID` 且可安装。
- [x] 用户已确认收口授权，main 已本地合并；待推送合并结果并创建 `v1.1-b4` annotated tag。
