# 发版操作清单：别练了 1.0 (build 11)

> 生成于 2026-06-28，分支 `feature/v1.0-b11`。
> 本次发版功能介绍见 [`release-1.0-b11-feature-intro.md`](./release-1.0-b11-feature-intro.md)。

## 0. 本次发版摘要

- 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 11`。
- 后端部署：需要部署。包含 Team 计划分享 API、反馈统计链路和 Flyway `V12/V13`。
- iOS 状态：准备上传 TestFlight。
- iOS 重点：Team 计划共享闭环、无计划开始训练、完成后保存计划模板、全局训练浮层、全局同步提示。
- Tag 策略：TestFlight `1.0 (11)` 处理完成并确认可安装后，再创建并推送 `v1.0-b11`。

## 1. 已完成准备

- [x] iOS build 号已递增到 `11`，App、widget、测试 target 同步，`MARKETING_VERSION` 保持 `1.0`。
- [x] 后端构建和测试通过：`cd backend && JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ./gradlew build`。
- [x] OpenSpec 严格校验通过：`openspec validate --all --strict`，17 passed / 0 failed。
- [x] iOS 自动化测试通过：XcodeBuildMCP `test_sim`，89 passed / 0 failed / 0 skipped。
- [x] 本次发版功能介绍已生成。
- [ ] 后端生产部署完成并确认 `V13` 迁移成功。
- [ ] TestFlight `1.0 (11)` 上传完成并可安装。
- [ ] `v1.0-b11` tag 已在 TestFlight 可用后创建并推送。

## 2. 提交与推送

- [ ] 确认当前分支为 `feature/v1.0-b11`。
- [ ] 确认提交已包含后端、iOS、OpenSpec、发版文档和版本号变更。
- [ ] 推送分支：

```bash
git push origin feature/v1.0-b11
```

## 3. 后端生产部署步骤

> 必须先部署后端，再上传或放量 iOS build 11。新版 iOS 依赖新 Team 分享计划接口和 `V12/V13` 数据库结构。

- [ ] 确认本机在仓库根目录，且工作区没有未提交的功能变更。
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
  - 断言本地最新 Flyway 版本 `13` 已在 `flyway_schema_history` 中 `success=true`。
- [ ] 若脚本失败，停止 iOS 上传，先保留日志并修复后端部署问题。

## 4. 后端部署后冒烟检查

- [ ] 健康检查：

```bash
curl -s https://dontlift.peipadada.com/actuator/health
```

- [ ] 期望返回：

```json
{"status":"UP"}
```

- [ ] 查看最新 Flyway 记录：

```bash
ssh root@124.222.79.121 "docker exec shared-postgres psql -U dontlift -d dontlift -tAc \
  \"SELECT version || '  ' || description || '  success=' || success FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 5;\""
```

- [ ] 期望看到 `13  strip extra weight fields from team plan shares  success=true`。
- [ ] 抽查后端日志没有启动失败、Flyway checksum、SQL 权限或 JSONB 解析异常。

## 5. iOS TestFlight 上传步骤

- [ ] 打开 `ios/DontLift/DontLift.xcodeproj`。
- [ ] Scheme 选择 `DontLift`。
- [ ] 目标设备选择 `Any iOS Device (arm64)`。
- [ ] 确认 General 中版本为 `1.0`，build 为 `11`。
- [ ] 确认 signing 使用正确 Apple Team，主 App 和 widget bundle 都可签名。
- [ ] 执行 `Product -> Archive`。
- [ ] Archive 完成后打开 Organizer。
- [ ] 选择本次 `1.0 (11)` archive。
- [ ] 执行 `Distribute App -> App Store Connect -> Upload`。
- [ ] 保持默认 App Store Connect 上传流程，等待上传成功。
- [ ] 到 App Store Connect 等待处理完成，TestFlight 出现 `1.0 (11)`。
- [ ] 添加内部测试或提交外部测试前，先安装到测试设备完成第 6 节回归。

## 6. TestFlight 主流程回归

- [ ] Apple 登录和 dev token 以外的正式登录路径正常。
- [ ] 首次进入 App 后同步提示出现时不阻挡操作。
- [ ] 首页 CTA 文案为「开始训练」，点击后创建无计划训练。
- [ ] 无计划训练完成后出现「保存为计划模板」，可选择分组并保存。
- [ ] 个人计划详情页点击「开始训练」仍按个人计划预填，并可正常回写自适应计划。
- [ ] 个人计划详情页点击「分享到 Team」，首次分享展示分享确认，已分享 Team 展示更新和取消能力。
- [ ] 分享计划快照不展示作者重量，只展示动作、组数、次数等必要处方。
- [ ] Team 计划页展示「我分享的计划」和「成员分享计划」分组。
- [ ] 自己分享的计划不展示复制按钮，主按钮为「开始训练」，右上操作菜单可取消分享。
- [ ] 别人分享的计划可直接开始训练，也可复制到我的计划。
- [ ] 进入分享计划详情后可查看动作详情，右上菜单采用统一 UI。
- [ ] 直接开始 Team 分享计划并完成后，Team 计划卡「总共完成次数」增加，不创建 Team 动态。
- [ ] 复制 Team 分享计划后，「N 人复制」增加；直接开始训练不计入复制。
- [ ] 作者编辑原计划后再次分享到同一 Team，Team 计划列表展示新快照。
- [ ] 取消分享后，Team 计划列表不再展示该计划。
- [ ] Team 解散二次确认弹窗层级高于训练悬浮窗。
- [ ] 删除计划分组有二次确认和成功反馈，确认按钮文案为「删除」。
- [ ] 任意页面开始训练后，全局训练浮层可展开和收起，收起后保持当前页面路由。
- [ ] 训练中完成组后，重量、次数、完成按钮背景色和动画同步一致。
- [ ] 训练结束后自动分享 Team 动态路径仍正常。

## 7. 发布后处理

- [ ] TestFlight `1.0 (11)` 可安装并完成主流程回归后，创建 tag：

```bash
git tag v1.0-b11
git push origin v1.0-b11
```

- [ ] 在发版记录中补充：
  - 后端部署完成时间。
  - `flyway_schema_history` 最新版本。
  - TestFlight 处理完成时间。
  - 实机回归设备和 iOS 版本。
- [ ] 若需要回滚 iOS，仅停止 TestFlight build 11 测试，不影响后端兼容旧客户端。
- [ ] 若后端部署后出现严重问题，先保留 DB 备份和日志，再评估是否回滚容器镜像或修复后再次运行 `release-update.sh`。
