# 1.1 build 9 发版检查清单

## 版本、基线与候选范围

- 日期：2026-11-10（上海时区）。状态：**build 9 上传、Apple 处理、用户验收与 Git 发布收口已完成；main 已合并推送，annotated tag `v1.1-b9` 已推送。内部测试可安装；外部 Beta 已批准、群组已关联，通知／启动外测仍未执行。**
- `MARKETING_VERSION=1.1`、`CURRENT_PROJECT_VERSION=9`，App、widget、单元测试和 UI 测试的 Debug／Release 共 8 处一致。
- 本次功能差异基线为上一已发布版本 `v1.1-b5`（`ea6d1c0fc05e70c3227a76202d7223e1062919c1`）。build 6 用户确认已占用，build 7／8 实际上传均被合同门禁拒绝，不复用；失败候选不是发布基线。
- 分支沿用 `feature/v1.1-b6`，业务实现冻结于 `b9333e5`；build 9 归档输入为 `5793709`，之后只有发布文档变化。验收记录 `a1e1735` 已推送，发布合并提交为 `019ca8a`，归档业务代码没有漂移。
- 保留且排除既有未跟踪 `.codex/hooks.json`；源分支及工作区保留。main 与 tag 的实际执行和远端核验见收口记录。
- [功能介绍及 TestFlight 测试内容](release-1.1-b9-feature-intro.md) · [用户公告](release-1.1-b9-user-announcement.md) · [build 8 上传失败记录](release-1.1-b8-checklist.md)

## 功能范围

相对 `v1.1-b5`：历史训练另存个人计划；保存失败恢复与同步反馈；大字号、可读色和键盘输入；继续训练、排序、浮层和结束后的衔接；大量历史同步、个人／Team 加载与分享提示。最终行为详见功能介绍。

没有动作图、动作库条目或 manifest 变化，不重复动作图发布；饮食模块保持移除，不将仅有规划的多身份登录写成实现。

## 准备与本地验证

- [x] build 8 上传最终返回合同 403，日志与请求 ID 已保存，未记为上传成功。
- [x] 用户确认已同意同一份 2026-10-29 Apple Developer Program 协议；刷新会话后再次提交同意，13:50 账户页刷新时告警消失、证书／标识符／描述文件入口恢复。没有更改账号、团队、角色或密钥，build 9 后续实际上传已成功。
- [x] 工程 8 处 build 递增到 9，业务源码和资源不变。
- [x] 复用相同业务候选的 Gradle build、95 项缓存测试报告、15 个相关 change／15 份主规格 strict、Release 模拟器编译及已有行为验证。本轮不重新运行业务／UI 测试，数量、失败批次及 warning 边界见 [build 7 记录](release-1.1-b7-checklist.md) 和 [专项收口记录](ui-ux-release-readiness-plan-2026-11-07.md#验证结论)。
- [x] 当前 iOS 26.5 正常进程两条 HID 返回路径通过，用户确认手动边缘返回核对通过；不扩大为最低系统、全部导航或真机验收。
- [x] App 内关于页实际打开两张法律页面，App Store Connect 隐私政策 URL 正确；登录页复用已有可达 UI 证据与相同 URL 引用核对，本轮未登出日常账号重复操作。
- [x] 已恢复模拟器原 1.1／3 安装包，日常数据库和 wal／shm 哈希与检查前一致；复用单个现有设备，无新增、重置或清空。
- [x] build 9 的 8 处版本、三份文档、本地链接与 `git diff --check` 复核通过。
- [x] 候选 `5793709` 已提交并推送，归档输入冻结。
- [x] 13:54:56 独立完成 build 9 Release 设备 Archive；主 App／widget 均为 1.1／9、arm64、团队 `D566UZ8QG4`、App Group `group.com.yulinxi.app.DontLift`，`codesign --verify --deep --strict` 均通过，两个开发 profile 均有效至 2027-09-06。

仅版本元数据变化不重复运行已有效验证的业务测试；设备 Archive 本身包含编译。归档的 Apple Development 签名与 Store 分发重签、可安装、真机回归分别记录。

归档 `/Users/yu/Library/Developer/Xcode/Archives/2026-11-10/DontLift-1.1-b9.xcarchive`；编译日志 `/tmp/dontlift-release-b9-archive-20261110.log`；13:55:18 独立核验记录 `/tmp/dontlift-release-b9-archive-verified-20261110.json`。

## 后端与生产状态

**无需部署后端应用服务或数据库；本次法律静态页已更新。**

- 后端运行时差异仅默认关闭的本地开发账号支持；没有新 API、Flyway 迁移或 iOS 生产依赖，继续沿用现有契约。
- 法律页面来源 `df70ed8`，2026-11-10 10:41:47 已发布至 `/opt/stacks/edge/site/dontlift/{privacy,terms}/index.html`，公网字节及 App 内实际打开已核对。
- 已保存原文件备份 `/opt/stacks/edge/backups/dontlift-legal-b7-20261110-104124`，校验与日志见 build 7 记录。
- 发布后 health 连续 3 次 HTTP 200／UP，Flyway V22 成功，GET 开发 token 入口 404、未登录 Team 401；应用、Caddy、PostgreSQL 启动时间与重启计数不变。
- 若以后另行更新后端应用，只使用 `backend/deploy/release-update.sh` 并满足备份及兼容门禁；本次不为递增 build 重启服务。

## Archive 与 TestFlight

顺序：候选冻结推送 → build 9 设备 Archive／分发签名 → 实际上传 → `VALID`／可安装 → 真机回归 → main／tag。

- [x] 使用 `xcodebuild -exportArchive` 完成 App Store Connect Upload、自动分发签名、固定 1.1／9，不自动改 build。
- [x] 13:58:46 收到 `Upload succeeded`／`EXPORT SUCCEEDED`，命令退出 0。归档分发记录确认 App ID `6779657886`、团队 `D566UZ8QG4`、build 9；分发签名证书为 Apple Distribution: Linxi Yu (D566UZ8QG4)，分发记录 ID `3af6ecc3-8de4-4224-b490-74cdd0c44fc3`。
- [x] App Store Connect 处理门禁通过、TestFlight 内部测试可安装：上传列表为“完成”，内部群组的 1.1 (9) 行为“正在测试”、90 天后过期。这里记录实际 UI 可测试状态，未把上传命令成功直接当作处理完成或真机安装结果。
- [x] 简体中文[测试内容](release-1.1-b9-feature-intro.md#testflight测试内容文案)共 230 字符已保存，刷新后逐字与文档一致。
- [x] 已关联现有“内部测试”（1 人）和“朋友内侧”（外部 3 人）；没有创建群组或更改成员。外部“提交以供审核”已执行，列表随后为“已批准”。
- [ ] 明确指示后执行“通知测试员”，向现有外部 3 人发送 TestFlight 通知并启动外测。此次提交关闭了“自动通知测试员”，尚未点击手动通知；不把“已批准”记为外部正在测试。Apple 对该步骤的说明见[外部测试通知](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers#notify-external-testers-after-your-build-is-approved)。

上传日志 `/tmp/dontlift-release-b9-upload-20261110.log`、分发日志 `/var/folders/yx/jf84mf0d6gd0hsk5wpftv2rm0000gn/T/DontLift_2026-11-10_13-55-19.225.xcdistributionlogs`、真实回执 `/tmp/dontlift-release-b9-upload-result-20261110.json`、UI 状态记录 `/tmp/dontlift-release-b9-testflight-status-20261110.json`。既有内部群组采用手动分发，本次已显式加入 build 9；[构建详情](https://appstoreconnect.apple.com/teams/0df9b076-827a-40cb-8361-50de912bb16d/apps/6779657886/testflight/ios/3af6ecc3-8de4-4224-b490-74cdd0c44fc3)。

## 真机回归

助手此前查询三台已配对真机（iOS 18.2.1、26.4.2、26.5）均为 unavailable，未代表用户执行真机安装或验收，记录 `/tmp/dontlift-release-b9-devices-20261110.json`。随后用户在当前会话明确回复“验收通过。继续进行分支、tag处理”，作为 build 9 的整体验收结论与收口授权，真机验收门禁据此通过；本轮确认登记时间为 2026-11-10 14:20:16（上海时区）。用户未提供实际验收时间、设备型号、iOS 版本及逐项明细，这些信息保持未提供，不套用已配对设备资料，也不记为助手自动化验证。

| 路径 | 核对内容 | 状态 |
| --- | --- | --- |
| 升级与登录 | 旧数据保留、冷启动、真实 Apple 登录、画像恢复、登录页法律入口 | 用户整体验收通过，未逐项回报 |
| 历史另存计划 | 首页／日历入口、逐组差异、热身／递减组、备注／休息／分组，取消与保存，原训练不改名 | 用户整体验收通过，未逐项回报 |
| 训练与计划 | 大字号／键盘、继续／取消／丢弃、四类排序、结束、计划更新／撤销、PR／徽章、边缘返回 | 用户整体验收通过，未逐项回报 |
| 离线与同步 | 离线保存和重试、同步期间编辑／丢弃、完整子树、多设备一致、失败反馈 | 用户整体验收通过，未逐项回报 |
| Team | 加载／重试、默认分享、分享取消与显式撤回、登录态操作 | 用户整体验收通过，未逐项回报 |
| 系统能力与复盘 | 锁屏／后台、休息回填、Live Activity、通知、HealthKit、widget、VoiceOver、海报与徽章 | 用户整体验收通过，未逐项回报 |

## 合并、Tag、回滚与收口

- [x] 必要线上变更与生产健康核对完成，候选及三份发布文档已推送，最新上传状态随本次记录回填。
- [x] build 9 处理完成、内部可安装；用户确认整体验收通过，未报告阻塞问题，并明确授权继续处理分支与 tag。
- [x] 14:21:32 使用 `--no-ff` 将已验收候选 `a1e1735` 合并到 main，发布提交 `019ca8a404e3dcc81b7dc5e1fdf15bfd8810b4a0`。合并树与候选完整一致，没有冲突解决或新增业务代码，复用已有验证结果。
- [x] 14:21:51 创建 annotated tag `v1.1-b9`，指向发布合并提交 `019ca8a`，tag 对象为 `2ad7312490f63f8588d966c71ab1f92538c6baca`；main 与 tag 已在同一次 atomic push 中成功推送。
- [x] 14:23:01 对远端引用独立核验：main 为发布合并提交，tag 对象与本地一致，tag 解引用仍为 `019ca8a`。本次后续收口提交只更新发布文档，发布 tag 固定在该合并提交。

Git 收口证据：`/tmp/dontlift-release-b9-git-close-20261110.json`。最后记录本次 main／tag 状态后，保持源分支与 main 同步，工作区中的未跟踪文件不纳入提交。

回滚：停止问题候选分发，保留已确认可用历史版本，修复使用新 build；不清理用户训练库，无迁移则不降库。法律页可从已保存备份恢复，恢复旧正文后对应文案门禁重新待验。

当前 build 9 的 Archive、归档签名核验、Apple Distribution 分发、实际上传与 Apple 处理成功，内部测试可安装、外部审核已批准，用户已确认整体验收通过；main 合并与 tag 创建、推送和远端核验完成。外部通知／启动仍为独立未执行事项，不把 TestFlight Git 收口表述为 App Store 正式上架。上传参数 `/tmp/dontlift-release-b9-ExportOptions-20261110.plist` 固定 App Store Connect upload、自动签名且不自动更改 build。
