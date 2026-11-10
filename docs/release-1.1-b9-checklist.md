# 1.1 build 9 发版检查清单

## 版本、基线与候选范围

- 日期：2026-11-10（上海时区）。状态：**Apple 协议页面告警已解除，build 9 准备中，尚未归档、上传或可安装。**
- `MARKETING_VERSION=1.1`、`CURRENT_PROJECT_VERSION=9`，App、widget、单元测试和 UI 测试的 Debug／Release 共 8 处一致。
- 已发布基线为 `v1.1-b5`（`ea6d1c0fc05e70c3227a76202d7223e1062919c1`）。build 6 用户确认已占用，build 7／8 实际上传均被合同门禁拒绝，不复用；失败候选不是发布基线。
- 分支沿用 `feature/v1.1-b6`，业务实现冻结于 `b9333e5`；build 9 只递增版本并维护发版记录。已推送的 build 8 准备与记录为 `3683cff`、`3af8f54`。
- 保留且排除既有未跟踪 `.codex/hooks.json`。main 与发布 tag 均未变更。
- [功能介绍及 TestFlight 测试内容](release-1.1-b9-feature-intro.md) · [用户公告](release-1.1-b9-user-announcement.md) · [build 8 上传失败记录](release-1.1-b8-checklist.md)

## 功能范围

相对 `v1.1-b5`：历史训练另存个人计划；保存失败恢复与同步反馈；大字号、可读色和键盘输入；继续训练、排序、浮层和结束后的衔接；大量历史同步、个人／Team 加载与分享提示。最终行为详见功能介绍。

没有动作图、动作库条目或 manifest 变化，不重复动作图发布；饮食模块保持移除，不将仅有规划的多身份登录写成实现。

## 准备与本地验证

- [x] build 8 上传最终返回合同 403，日志与请求 ID 已保存，未记为上传成功。
- [x] 用户确认已同意同一份 2026-10-29 Apple Developer Program 协议；刷新会话后再次提交同意，13:50 账户页刷新时告警消失、证书／标识符／描述文件入口恢复。没有更改账号、团队、角色或密钥。新 build 上传回执仍待核对。
- [x] 工程 8 处 build 递增到 9，业务源码和资源不变。
- [x] 复用相同业务候选的 Gradle build、95 项缓存测试报告、15 个相关 change／15 份主规格 strict、Release 模拟器编译及已有行为验证。本轮不重新运行业务／UI 测试，数量、失败批次及 warning 边界见 [build 7 记录](release-1.1-b7-checklist.md) 和 [专项收口记录](ui-ux-release-readiness-plan-2026-11-07.md#验证结论)。
- [x] 当前 iOS 26.5 正常进程两条 HID 返回路径通过，用户确认手动边缘返回核对通过；不扩大为最低系统、全部导航或真机验收。
- [x] App 内关于页实际打开两张法律页面，App Store Connect 隐私政策 URL 正确；登录页复用已有可达 UI 证据与相同 URL 引用核对，本轮未登出日常账号重复操作。
- [x] 已恢复模拟器原 1.1／3 安装包，日常数据库和 wal／shm 哈希与检查前一致；复用单个现有设备，无新增、重置或清空。
- [x] build 9 的 8 处版本、三份文档、本地链接与 `git diff --check` 复核通过。
- [ ] 提交、推送候选，冻结归档输入。
- [ ] 独立完成 build 9 Release 设备 Archive，核对主 App／widget 的 1.1／9、arm64、团队 `D566UZ8QG4`、App Group `group.com.yulinxi.app.DontLift`、签名及 profile。

仅版本元数据变化不重复运行已有效验证的业务测试；设备 Archive 本身包含编译。归档的 Apple Development 签名与 Store 分发重签、可安装、真机回归分别记录。

## 后端与生产状态

**无需部署后端应用服务或数据库；本次法律静态页已更新。**

- 后端运行时差异仅默认关闭的本地开发账号支持；没有新 API、Flyway 迁移或 iOS 生产依赖，继续沿用现有契约。
- 法律页面来源 `df70ed8`，2026-11-10 10:41:47 已发布至 `/opt/stacks/edge/site/dontlift/{privacy,terms}/index.html`，公网字节及 App 内实际打开已核对。
- 已保存原文件备份 `/opt/stacks/edge/backups/dontlift-legal-b7-20261110-104124`，校验与日志见 build 7 记录。
- 发布后 health 连续 3 次 HTTP 200／UP，Flyway V22 成功，GET 开发 token 入口 404、未登录 Team 401；应用、Caddy、PostgreSQL 启动时间与重启计数不变。
- 若以后另行更新后端应用，只使用 `backend/deploy/release-update.sh` 并满足备份及兼容门禁；本次不为递增 build 重启服务。

## Archive 与 TestFlight

顺序：候选冻结推送 → build 9 设备 Archive／分发签名 → 实际上传 → `VALID`／可安装 → 真机回归 → main／tag。

- [ ] 使用标准 Xcode 分发或 `xcodebuild -exportArchive`，App Store Connect Upload、自动管理签名、固定 1.1／9，不自动改 build。
- [ ] 上传成功，记录时间、回执和构建身份。若失败，保留真实错误并使用新的未占用 build，不把尝试记为上传成功。
- [ ] App Store Connect build 9 处理完成且为 `VALID`、TestFlight 可安装；外部测试审核单独记录。
- [ ] 填写[测试内容](release-1.1-b9-feature-intro.md#testflight测试内容文案)，核对既有“内部测试”和“朋友内侧”群组，不默认外部审核已通过。

## 真机回归

此前三台已配对真机均不可连接，本轮尚未执行真机验收。可安装后记录具体设备、系统、时间、入口与结论：

| 路径 | 核对内容 | 状态 |
| --- | --- | --- |
| 升级与登录 | 旧数据保留、冷启动、真实 Apple 登录、画像恢复、登录页法律入口 | 待验 |
| 历史另存计划 | 首页／日历入口、逐组差异、热身／递减组、备注／休息／分组，取消与保存，原训练不改名 | 待验 |
| 训练与计划 | 大字号／键盘、继续／取消／丢弃、四类排序、结束、计划更新／撤销、PR／徽章、边缘返回 | 待验 |
| 离线与同步 | 离线保存和重试、同步期间编辑／丢弃、完整子树、多设备一致、失败反馈 | 待验 |
| Team | 加载／重试、默认分享、分享取消与显式撤回、登录态操作 | 待验 |
| 系统能力与复盘 | 锁屏／后台、休息回填、Live Activity、通知、HealthKit、widget、VoiceOver、海报与徽章 | 待验 |

## 合并、Tag、回滚与收口

- [ ] 必要线上变更与生产健康核对完成，候选及三份发布文档已推送。
- [ ] 对应 build 为 `VALID`、可安装，真机主流程通过、阻塞问题清零并由用户确认。
- [ ] 满足条件后合并 main；冲突解决或新差异需补验受影响范围，代码相同则复用结果。
- [ ] 创建并推送 annotated tag `v1.1-b9`，回填完成时间。**当前不要打 tag。**

回滚：停止问题候选分发，保留已确认可用历史版本，修复使用新 build；不清理用户训练库，无迁移则不降库。法律页可从已保存备份恢复，恢复旧正文后对应文案门禁重新待验。

当前 build 9 尚未有 Archive、分发重签、上传、`VALID`、真机、main 合并或 tag 结果；不套用其他 build 的产物结论。
