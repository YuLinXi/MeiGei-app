# v1.1-b4 发版前检查 Checklist

> 检查日期：2026-09-14（上海时区）
> 发布基线：`v1.1-b3`（历史发版记录确认已完成 TestFlight 发布）
> 目标版本：`1.1 (build 4)`
> 候选分支：`feature/v1.1-b4`
> 当前候选提交：`0705e4fddff1a7b75bc7c26c1d71783035eb1ae5`
> 当前工作树：候选已提交并推送，工作树干净
> 当前结论：**自动化与人工验证已通过，待用户执行 Archive/TestFlight 上传**
> 功能介绍：[release-1.1-b4-feature-intro.md](release-1.1-b4-feature-intro.md)
> 用户公告：[release-1.1-b4-user-announcement.md](release-1.1-b4-user-announcement.md)

## 0. 结论摘要

| 项目 | 当前状态 | 事实与下一步 |
| --- | --- | --- |
| 发布基线 | ✅ 已锁定 | 最近已发布 tag 为 `v1.1-b3`，本次只比较 `v1.1-b3..HEAD` 的最终差异 |
| 候选范围 | ✅ 已锁定 | 功能候选为 3 个提交、17 个文件；本次另加入 build 4 版本修改和 3 份发版文档 |
| 工作树 | ✅ 已提交并推送 | 既有工作树无未提交改动；本次 build 4 版本修改和 3 份发版文档已提交并推送到候选分支 |
| 工程版本 | ✅ 已确认 | App、Widget、测试 target 的 8 组 configuration 已统一为 `MARKETING_VERSION = 1.1`、`CURRENT_PROJECT_VERSION = 4`；用户已确认 App Store Connect 未使用 build 4 |
| 后端部署 | ✅ 无需部署 | `v1.1-b3..HEAD` 与工作树均无 `backend/` 改动；无 API、数据库迁移或同步协议变更 |
| 后端生产状态 | ✅ 只读检查通过 | health 200/`UP`，`/privacy` 200，`/terms` 200，生产 `/auth/dev/token` 404；Flyway 最新 V22 `success=true` |
| 后端本地验证 | ✅ 通过 | JDK 21 下 `./gradlew clean build`、`./gradlew test --rerun-tasks` 均成功 |
| OpenSpec | ✅ 主规格通过 | `openspec validate --specs --strict --no-interactive`：14/14 通过；相关 change 已归档，直接按归档 change ID 校验不被当前 CLI 识别为 delta，不作为通过项记录 |
| iOS build | ✅ 通过 | iPhone 17 Pro / iOS 26.5 Simulator，Debug build 成功 |
| iOS 自动化测试 | ✅ 通过 | xcresult 汇总 274/274 通过；UI target 9/9 通过，0 失败、0 跳过 |
| 人工 UI 回归 | ✅ 用户确认通过 | 用户已确认 build 4 相关人工路径全部验证通过；本轮未提供设备/iOS 版本明细，文档不虚构测试环境 |
| TestFlight 上传 | ⏳ 待执行 | 当前未 Archive、未上传，未确认 `VALID`，候选不可安装 |
| `main` 合并与 tag | ⏳ 禁止执行 | 在版本递增、人工回归、TestFlight `VALID` 前不要合并 `main` 或创建 `v1.1-b4` |

## 1. 发布范围与候选冻结

- [x] 已确认真实 Git 根目录、当前分支、远端和工作树状态。
- [x] 已确认最近一个已发布并打 tag 的基线为 `v1.1-b3`；基线历史发版记录明确写明 TestFlight 可用。
- [x] 已读取 `v1.1-b3..HEAD` 的提交、文件差异和相关最终实现，没有把开发过程中的中间状态写入用户说明。
- [x] 已确认当前差异不涉及 `backend/`、API、数据库、同步协议、资源动作图或后端部署脚本。
- [x] 已完成 `git diff --check` 与 `git diff --check v1.1-b3..HEAD`。
- [x] 归档前冻结新的候选范围：版本提交 `0705e4fddff1a7b75bc7c26c1d71783035eb1ae5`，状态回填提交 `ff94abd`，均已推送到候选分支。

## 2. 本次最终用户功能

### 肌群负荷容量与周复盘口径

- [x] 首页「本周肌群负荷」小卡的肌群行展示「N 组 · 容量」，摘要增加总容量。
- [x] 周复盘页的肌群行与头部总览展示容量，容量按既有聚合数据格式化为 kg 或 t。
- [x] 本周与上周整周进行组数和容量双维度对比；持平分量省略。
- [x] 上周页签改为纯数据回看，不再展示上上周对比；行内变化信息下沉到展开的贡献明细。
- [x] 用户确认已完成首页小卡、周复盘页、零值肌群、长容量文本和上周页签排版验证。

### 训练进行页与排序体验

- [x] 训练进行页、计划详情、计划列表共用系统 `.sheet` 排序弹窗，支持系统下滑关闭。
- [x] 排序弹窗关闭时统一提交草稿顺序；UI test 已验证弹窗呈现、底层封锁和关闭恢复。
- [x] 用户确认已完成排序手柄长按拖拽、下滑关闭和顺序保存验证；XCUI 合成拖拽已知无法可靠触发 sheet 内行重排。
- [x] 训练进行页对高频勾选、输入、休息提示和持久化路径做了重估/保存放大治理；自动化测试通过。

## 3. 后端判断与兼容性

- [x] `v1.1-b3..HEAD` 没有 `backend/` 文件差异。
- [x] 当前候选没有新增或修改数据库迁移，最新本地迁移仍为 `V22__workout_body_weight_snapshot.sql`。
- [x] 当前候选没有修改 API、同步 envelope 或服务端权威 Team 数据契约。
- [x] 判定本次不需要执行 `backend/deploy/release-update.sh`。
- [x] 已执行生产只读检查：`/actuator/health` 返回 200 且 `status=UP`；`/privacy`、`/terms` 返回 200；生产 dev token 返回 404。
- [x] 已通过 SSH 只读查询确认生产 Flyway 最新 5 条迁移中 V22、V21、V20、V19、V18 均 `success=true`。
- [ ] 若版本递增后发现候选新增后端或契约变更，必须重新判断部署顺序，不能沿用本结论。

## 4. 本地自动化门禁

### 后端

- [x] 使用 JDK 21 执行 `backend/./gradlew clean build`：`BUILD SUCCESSFUL`。
- [x] 使用 JDK 21 执行 `backend/./gradlew test --rerun-tasks`：`BUILD SUCCESSFUL`。
- [x] 当前候选无后端生产代码、测试或迁移变更。

### iOS

- [x] 执行 iPhone 17 Pro / iOS 26.5 Simulator Debug build，结果 `BUILD SUCCEEDED`。
- [x] 执行全量 `xcodebuild test`，结果 `TEST SUCCEEDED`。
- [x] xcresult 汇总：274 项测试全部通过；UI target 9 项全部通过，0 失败、0 跳过。
- [x] `MuscleLoadAggregatorTests` 相关组数、容量、整周基线、贡献明细测试通过。
- [x] `testReorderSheetBlocksOtherAreas` 通过；其合成拖拽仅输出已知限制告警，真机拖拽仍需人工验证。
- [x] 版本号递增到 build 4 后重新执行 build 与 test；不能直接复用 build 3 的自动化结果作为最终归档证据。

### 规格与静态检查

- [x] `openspec validate --specs --strict --no-interactive`：14 份主 spec 全部通过。
- [x] 归档 change `add-muscle-load-volume-display` 的 proposal、tasks、spec 与实现已核对；归档后直接按 change ID 校验时，CLI 报无可识别 delta，未将其误记为通过。
- [x] `git diff --check` 通过。
- [x] 完成 build 号更新后再次执行版本配置核对、`git diff --check` 和工作树检查；最终提交前仍需再做一次敏感信息检查。

## 5. TestFlight 前人工回归

用户已确认以下 build 4 路径人工验证通过；Archive/TestFlight 安装后的真机复验仍需在上传后执行并补充设备、iOS 版本、结果和问题：

- [ ] 首页肌群负荷：有训练数据时每行显示「组数 · 容量」，摘要显示总容量，长容量文本不截断。
- [ ] 周复盘本周页：头部显示总容量；组数/容量对比可与上周整周数据对账；持平分量不显示。
- [ ] 周复盘上周页：显示完整上一周数据，头部和展开贡献面板均不出现对比文案。
- [ ] 周复盘零值肌群与「其他」桶：零值行不崩版，「其他」按规格显示且不参与排序/对比。
- [ ] 贡献明细：展开胸/背等肌群，确认肌群级组数与容量变化、动作级组数与训练量均正确。
- [ ] 三处排序入口：训练进行中、计划详情、计划列表均能打开系统 sheet；完成、下滑关闭和重进页面后顺序正确。
- [ ] 训练进行页快速连续勾选/编辑多组：无明显卡顿、错位、重复保存或 Live Activity 状态滞后。
- [ ] 本版本受影响的既有主路径：冷启动、登录、同步、Team、Live Activity、休息通知、HealthKit 和 Widget。

## 6. 版本、Archive 与 TestFlight

- [x] 将 App、Widget、单元测试、UI 测试的全部 8 组 build configuration 统一从 `CURRENT_PROJECT_VERSION = 3` 更新为 `4`；`MARKETING_VERSION` 保持 `1.1`。
- [x] 已核对目标版本为 `1.1 (build 4)`；用户确认 build 4 未在 App Store Connect 使用过。
- [x] 版本递增后重新运行 iOS build/test 必要门禁；后端无需重跑部署门禁，最终候选 SHA 仍待提交前冻结。
- [ ] 用户在 Xcode 中选择 `DontLift` + `Any iOS Device (arm64)` 执行 Archive。
- [ ] 核对 App、Widget 的签名、App Group、Push Notifications entitlement。
- [ ] Organizer 执行 `Distribute App -> App Store Connect -> Upload`。
- [ ] 等待 App Store Connect 状态为 `VALID` 且 TestFlight 可安装；未确认前不得写成已上传或可用。
- [x] 用户确认当前 build 4 人工回归全部通过；TestFlight 安装后的真机复验仍待上传后执行，本轮未提供设备/iOS 版本和时间明细，文档不虚构测试环境。

## 7. 发布收口（当前禁止执行）

- [ ] 后端部署：本候选无需部署；若范围发生变化，重新执行部署判断。
- [ ] iOS 上传：当前未执行。
- [ ] TestFlight 可安装：当前未确认。
- [ ] 候选分支合并 `main`：当前未执行。
- [ ] 创建并推送 annotated tag `v1.1-b4`：当前禁止；只有 TestFlight `VALID`、真机回归通过、用户确认后才能执行。
- [x] 已回填当前候选提交、人工验证状态和推送状态；Archive、TestFlight、合并 SHA、tag 和完成时间待后续真实操作后回填。

## 8. 回滚与异常处理

- 本次无后端变更，不需要数据库回滚或服务端兼容切换。
- 若 TestFlight 或真机发现阻塞问题，保留 `v1.1-b3` 不动；修复后继续使用新的 build 号，不复用已上传 build。
- 若 build 4 已上传但不可用，继续递增 build；不要移动、覆盖或删除既有 tag。
- 若发现新增后端契约变更，先暂停 iOS 上传，完成后端候选部署、Flyway、旧客户端兼容和生产只读检查。
