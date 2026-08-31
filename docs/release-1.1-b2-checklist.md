# v1.1-b2 发版 Checklist

> 发布基线：`v1.1-b1`
> 目标版本：`1.1 (build 2)`
> 候选分支：`feature/v1.1-b2`
> iOS 候选源码 SHA：`092659a6a5883bd82a4117cecda7ef385ee8aa1c`
> 当前结论：**已上线，发布负责人已确认 TestFlight 打包发布完成**
> 发布确认：`2026-08-31`（未提供精确时刻、设备型号与 iOS 版本）
> 功能介绍：[release-1.1-b2-feature-intro.md](release-1.1-b2-feature-intro.md)

## 0. 当前发布摘要

| 项目 | 状态 | 说明 |
| --- | --- | --- |
| 发布范围 | ✅ 已盘点 | 基线 `v1.1-b1`，候选含 5 个 commit（计划休息设置、名称同步修复、历史动作卡、休息弹窗改版与按钮微调） |
| 版本号 | ✅ 已更新 | App、Widget 与测试 target 8 组 build configuration 均为 `1.1 (build 2)` |
| 后端部署 | ✅ 不需要 | 没有后端运行时代码、配置、API 或 Flyway 迁移；仅 `TeamPlanServiceTest` 测试更新 |
| 后端验证 | ✅ 通过 | 80 项测试通过；生产 health、privacy、terms、dev token 只读检查正常 |
| iOS 构建与测试 | ✅ 通过 | `1.1 (build 2)` 下 Debug build 成功，217 项测试通过（211 单元 + 6 UI），0 失败 |
| OpenSpec | ✅ 通过 | `--specs --strict` 14 份全部有效；`carry-plan-rest-defaults` 已归档 |
| 候选冻结 | ✅ 已提交 | iOS 候选源码 SHA `092659a6`；后续仅提交发版记录，不改变 App 代码或资源 |
| 人工回归 | ✅ 已完成 | 发布负责人于 2026-08-31 确认 TestFlight 打包发布完成；逐项明细未回填 |
| TestFlight | ✅ 已上线 | 发布负责人于 2026-08-31 确认 `1.1 (build 2)` 已完成打包发布 |
| 发布 tag | ✅ 已创建并推送 | `v1.1-b2` 指向 `main` 的最终发布记录提交 |

## 1. 发布范围与冻结

- [x] 已确认最近一个完成 TestFlight 发布并打 tag 的基线为 `v1.1-b1`。
- [x] 已按 `v1.1-b1...当前工作区` 盘点最终用户行为，不使用分支起点或单个中间 commit 作为发布基线。
- [x] 已确认目标版本为 `1.1 (build 2)`，目标 tag 为 `v1.1-b2`。
- [x] 已生成本 Checklist 与[发版功能介绍](release-1.1-b2-feature-intro.md)。
- [x] 已将所有 App、Widget 与测试 target 的 `MARKETING_VERSION` 保持 `1.1`，`CURRENT_PROJECT_VERSION` 改为 `2`。
- [x] 已重新检查候选 diff，确认没有密钥、临时文件、个人绝对路径或无关改动进入 iOS 候选源码。
- [x] 已提交并推送全部确认范围，冻结 TestFlight iOS 候选 SHA `092659a6a5883bd82a4117cecda7ef385ee8aa1c` 并回填两份文档。

## 2. 本次功能范围

### 计划休息设置（OpenSpec `carry-plan-rest-defaults`，已归档）

- [x] 计划普通动作/递减组支持跟随全局、关闭、常用秒数与自定义秒数默认休息。
- [x] 个人计划与 Team 分享计划开始训练时带入休息设置；超级组继续复用轮后休息。
- [x] 自适应计划完成训练后回写默认休息，纳入回执与撤销；严格计划不回写。
- [x] 计划编辑与详情展示休息设置；训练中休息菜单可恢复「跟随全局」。
- [x] 保存为模板、计划复制、Team 分享/Fork 保留休息设置并维持重量剥离规则。

### 训练体验

- [x] 休息计时从全屏弹窗改为居中卡片浮层，点击遮罩可收起且计时继续。
- [x] 卡片右上角最小化按钮与底部震动/声音图标开关。
- [x] 训练历史动作卡/超级组卡可点击收起展开；递减组显示结构图标。
- [x] 修复保存为计划时修改名称不同步到本次训练记录的问题（该问题存在于已发布的 `v1.1-b1`）。

## 3. 自动化验证

### OpenSpec

- [x] `openspec validate --specs --strict`：14 份 spec 全部通过。
- [x] `carry-plan-rest-defaults` 任务全部完成并归档至 `openspec/changes/archive/`。

### 后端

- [x] 使用 JDK 21 执行 `./gradlew test`，80 项测试通过，0 失败、0 跳过。
- [x] Team 计划分享测试覆盖剥离重量时保留休息键。
- [x] 已确认候选工作区没有后端运行时代码、配置或数据库迁移变更。
- [x] 本机 `JAVA_HOME` 实际路径为 `ms-21.0.11`（AGENTS.md 中 Homebrew openjdk@21 路径已不存在），未影响构建。

### iOS

- [x] iPhone 17 Pro Simulator 上执行签名关闭的 Debug build，`BUILD SUCCEEDED`。
- [x] `1.1 (build 2)` 下执行 iOS 测试，217 项测试通过（211 项单元测试 + 6 项 UI 测试），0 失败。
- [x] 工程内 8 组 build configuration 的 `CURRENT_PROJECT_VERSION` 均已更新为 `2`。
- [x] Simulator 调试器版本告警（`DebuggerVersionStore`）与既有 warning 未造成测试失败。

### 通用检查

- [x] `git diff --check` 通过。

## 4. 后端生产状态

本次是 iOS-only 发布，不执行后端部署。

- [x] 生产 `https://dontlift.peipadada.com/actuator/health` 连续 3 次返回 200。
- [x] 生产 `/privacy`、`/terms` 返回 200。
- [x] 生产 `POST /auth/dev/token` 返回 404，开发 token 未开启。
- [x] 已确认旧版 `v1.1-b1` 不需要等待新后端即可继续使用现有 API。

## 5. TestFlight 前人工回归

> 发布负责人于 2026-08-31 确认 TestFlight 打包发布完成，且无阻塞问题；未提供逐项设备型号、iOS 版本和执行时间，因此下列条目保留为回归范围留档。

### 计划休息设置

- [ ] 计划编辑中为普通动作和递减组分别设置跟随全局、关闭、显式秒数，开始训练后计时时长与设置一致。
- [ ] 自适应计划完成训练并显式调整休息，回执包含休息变化、写回正确、撤销恢复原值；严格计划不回写。
- [ ] 保存为模板、复制计划、Team 分享直接开始与 Fork 后休息设置保留；训练中可恢复「跟随全局」。

### 休息计时卡片

- [ ] 点击遮罩收起、FAB 重新展开、右上角最小化，计时均不中断。
- [ ] 震动/声音图标开关生效；自然结束与提前结束提醒（含 Live Activity）正常。

### 历史详情与名称同步

- [ ] 动作卡与超级组卡收起/展开正常；递减组图标、PR 标记、备注展示正常。
- [ ] 保存为计划时修改名称，历史记录中的训练名称同步更新。

### 兼容冒烟

- [ ] 使用 `v1.1-b1` 客户端连接当前生产后端完成登录、拉取和同步兼容检查。

## 6. TestFlight 上传

- [x] 候选 SHA 已冻结，工作区干净，版本号为 `1.1 (build 2)`。
- [x] 发布负责人于 2026-08-31 确认 Xcode Archive 与 App Store Connect/TestFlight 打包发布完成（Archive 版本明细、设备型号与 iOS 版本未回填）。
- [x] 已更新[发版功能介绍](release-1.1-b2-feature-intro.md)的 iOS 上线状态。

## 7. 合并、tag 与发布记录

- [x] 发布负责人于 2026-08-31 确认 TestFlight 打包发布完成。
- [x] 候选分支已 fast-forward 合并 `main`，合并前后未产生冲突或额外 merge commit。
- [x] 在最终发布记录提交创建 annotated tag `v1.1-b2`。
- [x] 已推送 `main` 与 `v1.1-b2`。
- [x] 已写入发布记录：发布负责人于 2026-08-31 确认 TestFlight 打包发布完成；未提供精确时间、设备型号与 iOS 版本。
- [ ] 若发版后发现阻塞问题，优先停止测试分发并递增 build 修复，不复用或移动已发布 tag。

## 8. 发布负责人结论

`v1.1-b2` 已上线并完成 Git 收口。若后续发现阻塞问题，保持已发布 tag 不变，递增 build 后重新走完整发布流程。
