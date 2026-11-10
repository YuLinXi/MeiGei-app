# 1.1 build 8 发版检查清单

## 版本、基线与候选范围

- 准备日期：2026-11-10（上海时区）。状态：**build 7 因 Apple 必需合同未完成而上传失败，现准备 build 8；尚未 Archive／上传，不可安装。**
- `MARKETING_VERSION=1.1`，`CURRENT_PROJECT_VERSION=8`；App、widget、单元测试和 UI 测试的 Debug／Release 共 8 处配置一致。
- build 6 按用户确认已占用；build 7 虽完成归档与分发重签，实际上传返回 ContentDelivery 403，按发版流程不复用。失败事实及日志见 [build 7 记录](release-1.1-b7-checklist.md)。
- 已发布基线仍为 `v1.1-b5`（`ea6d1c0fc05e70c3227a76202d7223e1062919c1`）；不把失败的 build 7 作为已发布基线。
- 分支沿用 `feature/v1.1-b6`。业务源码为 `b9333e5`，build 7 版本准备提交 `df70ed8`、状态记录 `039ac7b` 已推送；build 8 只递增版本并维护发布文档，业务代码及资源不变。
- App Store Connect 的构建和全部状态上传列表已独立查看，当前未见 build 8。上传前若出现并发占用，使用新的更高 build。
- `.codex/hooks.json` 继续保留且排除，不自动暂存；main 与 tag 尚未变更。
- [功能介绍与 TestFlight 测试内容](release-1.1-b8-feature-intro.md) · [用户公告](release-1.1-b8-user-announcement.md)

## 功能范围

相对 `v1.1-b5`：历史训练另存个人计划；保存失败恢复与同步结果；大字号、可读色、原生输入和键盘；训练继续／取消、排序、浮层与收尾衔接；大量历史同步、个人／Team 加载及分享提示。最终实现与 build 7 相同，细节见功能介绍。

动作库条目、正式动作图与 manifest 没有变化，不重复执行动作图发布。饮食模块保持移除，不增加多身份登录等仅有规划的能力。

## 准备与本地验证

- [x] 已确认失败上传原因属于 Apple 账户合同门禁，不是本地编译或签名错误；保留 build 7 原始日志，不把它记为已上传。
- [x] 8 处 build 递增到 8，版本仍为 1.1；业务源码与已验证候选一致。
- [x] 复用同一业务实现的后端 Gradle build、95 项缓存测试报告、15 个相关 change／15 份主规格 strict、Release 模拟器编译及相关行为回归；完整证据及 warning 边界见 build 7 checklist 和 [专项收口记录](ui-ux-release-readiness-plan-2026-11-07.md#验证结论)。本轮没有重新执行这些测试。
- [x] 当前 iOS 26.5 正常进程两条 HID 返回路径通过，用户确认手动边缘返回核对通过；不扩大为最低系统、全部导航或真机验收。
- [x] App 内关于页实际打开隐私政策和独立服务条款，App Store Connect 隐私政策 URL 正确。登录页复用已有按钮可达 UI 证据及相同 URL／SafariView 静态引用核对，本轮未登出日常账号重复操作。
- [x] 已停止隔离候选，恢复原模拟器 1.1／3 安装包；日常 `default.store` 及 wal／shm 三个文件哈希与检查前一致。复用同一现存设备，没有新增运行时、设备或清空数据。
- [x] build 8 版本／文档差异、内部链接和 `git diff --check` 最终复核通过。
- [ ] build 8 候选提交并推送，冻结归档输入。
- [ ] build 8 Release 设备 Archive，复核主 App／widget 的 1.1／8、arm64、团队、App Group、签名及 profile。

版本元数据变化不重复运行业务／UI 测试；设备 Archive 本身包含编译。签名 Archive 不等于真机运行验收。

## 后端与生产状态

**无需更新后端应用服务或数据库；法律静态页面已于本次发布准备阶段更新。**

- 后端运行时代码差异只有默认关闭的本地开发账号登录支持，不改变生产登录或同步契约；没有新增 Flyway 迁移。
- 本次 iOS 行为沿用既有 API、Workout 聚合、计划 JSON、LWW 与墓碑规则，没有服务端新依赖。
- 法律页面来源提交 `df70ed8`，2026-11-10 10:41:47 公网正文逐字节与提交一致；生产实际目录 `/opt/stacks/edge/site/dontlift/{privacy,terms}/index.html`。
- 备份目录 `/opt/stacks/edge/backups/dontlift-legal-b7-20261110-104124`，两个 `*.before.html` 与原线上文件校验一致；完整校验和与日志见 build 7 checklist。
- 发布后 health 连续 3 次 HTTP 200／UP，Flyway V22 `success=true`，GET 开发 token 入口 404，未登录 Team 401；应用、Caddy、PostgreSQL 启动时间及重启计数均未变。
- 后续如需另行对齐应用容器源码，只能按 `backend/deploy/release-update.sh`、备份与对应门禁执行；这不是 build 8 的客户端依赖，不为递增 build 重启服务。

## Apple 合同、Archive 与 TestFlight

发布顺序：build 8 冻结推送 → 完成设备 Archive／分发准备 → 账户持有人接受新版 Apple Developer Program 许可协议 → 验证合同门禁解除 → 上传 → `VALID`／可安装 → 真机回归 → main／tag。

- [ ] 账户持有人自行阅读并接受 Apple Developer 账号页的新许可协议。页面已打开到协议接受步骤；没有代用户勾选或点击“同意”。
- [ ] 确认账户的合同告警解除，Xcode／App Store Connect 对应权限恢复。
- [ ] 使用标准 Xcode 分发流程或 `xcodebuild -exportArchive`，目标为 App Store Connect Upload，保留 1.1／8，不自动改成其他 build；使用现有团队自动管理分发签名。
- [ ] 上传成功并记录准确时间、回执及构建身份。若失败，不将尝试记为提交成功，并按流程改用新的未占用 build。
- [ ] App Store Connect 中 build 8 为 `VALID` 且 TestFlight 可安装；处理完成、可安装及外部测试审核是不同状态，按实际结果回填。
- [ ] 填写[测试内容](release-1.1-b8-feature-intro.md#testflight测试内容文案)，核对既有内部／外部群组的实际分发状态，不默认外部测试已通过审核。

## 真机回归

当前三台已配对设备最近查询均不可连接，未据此执行真机验收。可安装后记录设备、iOS、时间、实际入口与结论：

| 路径 | 必须核对的行为 | 状态 |
| --- | --- | --- |
| 升级与登录 | 旧数据保留、冷启动、真实 Apple 登录、画像恢复及登录页法律入口 | 待验 |
| 历史另存计划 | 首页／日历两入口，逐组差异、热身／递减组、备注／休息／分组，取消与保存，原训练不改名 | 待验 |
| 训练与计划 | 大字号／键盘、继续／取消／丢弃、四类排序、结束、计划更新及撤销、PR／徽章关闭、真实边缘返回 | 待验 |
| 离线与同步 | 离线保存、重试、同步期间编辑／丢弃、完整子树与多设备一致性，失败反馈 | 待验 |
| Team | 加载／失败重试、默认分享说明、分享取消与显式撤回、已登录操作 | 待验 |
| 系统能力与复盘 | 锁屏／后台、活动休息回填、Live Activity、真实通知、HealthKit、widget、VoiceOver、海报与徽章 | 待验 |

## 合并、Tag、回滚与状态回填

- [ ] 必要的线上变更及健康／兼容核对完成，候选与三份发布文档已推送。
- [ ] 对应 build 为 `VALID`、可安装，真机主路径通过，阻塞问题清零并由用户确认。
- [ ] 条件满足后合并 main；如引入冲突解决或新差异，补验受影响范围，代码一致则复用有效结果。
- [ ] 创建并推送 annotated tag `v1.1-b8`，回填准确完成时间及发布状态。**当前不要打 tag。**

回滚：停止分发有阻塞问题的候选，保留已确认可用历史版本，修复后用新 build；不清理用户训练库。本次没有数据库迁移，不执行降库。法律页面可用已保存备份恢复，但旧文案恢复后对应正文门禁重新变为未完成。

当前没有 build 8 的 Archive、成功上传、`VALID`、真机、main 合并或 tag 结果，不把 build 7 的签名成功套到 build 8。
