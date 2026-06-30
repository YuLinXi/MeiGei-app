# 发版操作清单：别练了 1.0 (build 13)

> 生成于 2026-06-30，分支 `feature/v1.0-b13`。
> 本次发版功能介绍见 [`release-1.0-b13-feature-intro.md`](./release-1.0-b13-feature-intro.md)。

## 0. 本次发版摘要

- 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 13`。
- 后端部署：需要。本次包含 Flyway `V15__checkin_reaction_push_receipts.sql`。
- 生产后端状态：已部署，健康检查返回 `UP`；生产 Flyway 最新为 `V15`。
- iOS 状态：准备上传 TestFlight。
- iOS 重点：分享海报体验、全局 message 顶层显示、Live Activity 串行化与提前结束休息、iPad 分享面板锚点。
- 后端重点：Team reaction 幂等键、并发首次插入兜底、reaction push receipt 历史回填。
- Tag 策略：TestFlight `1.0 (13)` 处理完成并确认可安装后，再创建并推送 `v1.0-b13`。

## 1. 已完成准备

- [x] iOS build 号已递增到 `13`，App、widget、测试 target 同步，`MARKETING_VERSION` 保持 `1.0`。
- [x] 确认本次包含后端 schema 变更：`V15__checkin_reaction_push_receipts.sql`。
- [x] 生产健康检查通过：`https://dontlift.peipadada.com/actuator/health` 返回 `UP`。
- [x] 当前生产 Flyway 最新为 `V15 checkin reaction push receipts success=true`。
- [x] 后端构建通过：`export JAVA_HOME=$(/usr/libexec/java_home -v 21) && ./gradlew build`。
- [x] iOS simulator build 通过：`xcodebuild ... CODE_SIGNING_ALLOWED=NO build`。
- [x] iOS simulator test 通过：`xcodebuild ... CODE_SIGNING_ALLOWED=NO test`，`totalTestCount = 100`，0 failed，0 skipped。
- [x] 本次发版功能介绍已生成。
- [x] `git diff --check` 最终收尾通过。
- [x] 后端生产部署完成并确认 `V15` 迁移成功。
- [ ] TestFlight `1.0 (13)` 上传完成并可安装。
- [ ] `v1.0-b13` tag 已在 TestFlight 可用后创建并推送。

## 2. 提交与推送

- [ ] 确认当前分支为 `feature/v1.0-b13`。
- [ ] 确认提交已包含分享海报、Live Activity、Team reaction、V15 迁移、iOS 版本号和发版文档。
- [ ] 推送分支：

```bash
git push origin feature/v1.0-b13
```

## 3. 后端生产部署步骤

> 必须先部署后端，再开始 iOS build 13 的 TestFlight 回归。新版 iOS 会为 Team reaction 写接口发送 `Idempotency-Key`；后端 `V15` 负责 reaction push receipt 表和历史回填。

- [ ] 确认本机在仓库根目录，且工作区没有未提交的无关变更。
- [ ] 确认服务器 `.env.prod` 中生产机密仍正确：`APP_DEV_TOKEN=false`、`JWT_SECRET` 强随机、`APPLE_AUDIENCES` 为真实 Bundle ID、数据库密码正确。
- [ ] 执行例行发版脚本：

```bash
./backend/deploy/release-update.sh
```

- [ ] 如需指定目标和健康检查地址：

```bash
./backend/deploy/release-update.sh root@124.222.79.121 https://dontlift.peipadada.com/actuator/health
```

- [ ] 等脚本完成以下步骤：
  - 迁移前备份生产 DB。
  - rsync 后端源码到服务器，不覆盖 `.env.prod`、`secrets/`、`backups/`。
  - 远程重建并启动 `dontlift-app`。
  - 通过公网 HTTPS 验证 `/actuator/health`。
  - 断言本地最新 Flyway 版本 `15` 已在 `flyway_schema_history` 中 `success=true`。
- [ ] 若脚本失败，停止 iOS 上传，先保留日志并修复后端部署问题。

本次执行记录：

- [x] 2026-06-30 18:02 CST 执行 `./backend/deploy/release-update.sh`。
- [x] 迁移前备份完成：`./backups/dontlift_2026-06-30_180248.sql.gz`。
- [x] 远程 Docker build 与 `dontlift-app` 重启完成。
- [x] 公网健康检查通过：`status=UP`。
- [x] Flyway 已确认：`15  checkin reaction push receipts  success=true`。

健康检查命令：

```bash
curl -sS https://dontlift.peipadada.com/actuator/health
```

期望返回：

```json
{"status":"UP","groups":["liveness","readiness"]}
```

查看最新 Flyway 记录：

```bash
ssh root@124.222.79.121 "docker exec shared-postgres psql -U dontlift -d dontlift -tAc \
  \"SELECT version || '  ' || description || '  success=' || success FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 5;\""
```

期望看到：

```text
15  checkin reaction push receipts  success=true
```

## 4. iOS TestFlight 上传步骤

- [ ] 打开 `ios/DontLift/DontLift.xcodeproj`。
- [ ] Scheme 选择 `DontLift`。
- [ ] 目标设备选择 `Any iOS Device (arm64)`。
- [ ] 确认 General 中版本为 `1.0`，build 为 `13`。
- [ ] 确认 signing 使用正确 Apple Team，主 App 和 widget bundle 都可签名。
- [ ] 执行 `Product -> Archive`。
- [ ] Archive 完成后打开 Organizer。
- [ ] 选择本次 `1.0 (13)` archive。
- [ ] 执行 `Distribute App -> App Store Connect -> Upload`。
- [ ] 保持默认 App Store Connect 上传流程，等待上传成功。
- [ ] 到 App Store Connect 等待处理完成，TestFlight 出现 `1.0 (13)`。
- [ ] 添加内部测试或提交外部测试前，先安装到测试设备完成第 5 节回归。

## 5. TestFlight 主流程回归

- [ ] 后端已部署并确认 `V15` 成功后，再开始 iOS 回归。
- [ ] Apple 登录和正式登录路径正常。
- [ ] 冷启动和首次进入主界面后同步正常，顶部同步提示不阻挡操作。
- [ ] 训练完成后点击分享，弹出通用底部弹窗；顶部无标题，可下拉关闭。
- [ ] 海报预览距离顶部留白合理，图片不再强制居中到奇怪位置。
- [ ] 海报指标为中文，动作和组数文字可读；无重量动作展示次数或组数，不显示“未记录重量”。
- [ ] 保存海报成功后全局 message 显示在弹窗之上，按钮变为“已保存”并禁用。
- [ ] 再次打开分享海报重新生成预览，保存状态按当前弹窗会话重新计算。
- [ ] iPad 上点击系统分享按钮不崩溃，popover 位置合理。
- [ ] Live Activity 训练中、休息中、提前结束休息、结束训练状态正确切换。
- [ ] 锁屏/灵动岛“结束休息”可用，回到 App 后本地休息计时与通知状态已清理。
- [ ] Team 动态点表情、取消表情、切换表情后状态正确回拉。
- [ ] 自己给自己的打卡点表情不发 push；队友首次点表情只推送一次。
- [ ] 并发或快速重复点表情不应产生重复 reaction 或重复 push。
- [ ] 普通训练记录、计划开始训练、Team 分享计划直接开始训练和完成页保存为计划模板路径仍正常。

## 6. 发布后处理

- [ ] TestFlight `1.0 (13)` 可安装并完成主流程回归后，创建 tag：

```bash
git tag v1.0-b13
git push origin v1.0-b13
```

- [ ] 在发版记录中补充：
  - 后端部署完成时间和 `V15` 迁移确认结果：已完成，2026-06-30 18:03 CST。
  - TestFlight 上传完成时间。
  - TestFlight 处理完成时间。
  - 实机回归设备和 iOS 版本。
  - 是否发现分享海报、全局 message 层级、Live Activity 或 Team reaction 问题。
- [ ] 若需要回滚 iOS，先停止 TestFlight build 13 测试；后端 `V15` 是新增表和回填，通常不需要回滚。
