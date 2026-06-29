# 发版操作清单：别练了 1.0 (build 12)

> 生成于 2026-06-29，分支 `feature/v1.0-b12`。
> 本次发版功能介绍见 [`release-1.0-b12-feature-intro.md`](./release-1.0-b12-feature-intro.md)。

## 0. 本次发版摘要

- 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 12`。
- 后端部署：需要。本次包含 `workout_set` 休息秒数字段和 Flyway `V14`。
- 生产后端状态：健康检查返回 `UP`，但 `flyway_schema_history` 最新仍为 `V13`，`V14` 待部署。
- iOS 状态：准备上传 TestFlight。
- iOS 重点：组间休息秒数同步、休息提醒声音策略、回前台同步门控、Team 计划卡片详情热区、动作库标准名和别名补齐。
- Tag 策略：TestFlight `1.0 (12)` 处理完成并确认可安装后，再创建并推送 `v1.0-b12`。

## 1. 已完成准备

- [x] iOS build 号已递增到 `12`，App、widget、测试 target 同步，`MARKETING_VERSION` 保持 `1.0`。
- [x] 确认本次包含后端 schema 变更：`V14__workout_set_rest_seconds.sql`。
- [x] 生产健康检查通过：`https://dontlift.peipadada.com/actuator/health` 返回 `UP`。
- [x] 当前生产 Flyway 最新为 `V13`，`V14` 尚未部署。
- [x] 后端构建通过：`JAVA_HOME=/Users/yumengyuan/Library/Java/JavaVirtualMachines/ms-21.0.11/Contents/Home ./gradlew build`。
- [x] OpenSpec 严格校验通过：`openspec validate --all --strict`，13 passed / 0 failed。
- [x] 动作库 manifest 校验通过：`node scripts/exercise-library-v1.mjs validate`。
- [x] iOS simulator build 通过：`xcodebuild ... CODE_SIGNING_ALLOWED=NO build`。
- [x] iOS simulator test 通过：`xcodebuild ... CODE_SIGNING_ALLOWED=NO test`，`totalTestCount = 100`，0 failed，0 skipped。
- [x] 本次发版功能介绍已生成。
- [ ] 后端生产部署完成并确认 `V14` 迁移成功。
- [ ] TestFlight `1.0 (12)` 上传完成并可安装。
- [ ] `v1.0-b12` tag 已在 TestFlight 可用后创建并推送。

## 2. 提交与推送

- [ ] 确认当前分支为 `feature/v1.0-b12`。
- [ ] 确认提交已包含后端 `V14` 迁移、iOS 版本号、动作库资源、Team 热区修复、测试和发版文档。
- [ ] 推送分支：

```bash
git push origin feature/v1.0-b12
```

## 3. 后端生产部署步骤

> 必须先部署后端，再上传或放量 iOS build 12。新版 iOS 会同步每组预计休息秒数和真实休息秒数，需要生产库完成 `V14`。

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
  - 断言本地最新 Flyway 版本 `14` 已在 `flyway_schema_history` 中 `success=true`。
- [ ] 若脚本失败，停止 iOS 上传，先保留日志并修复后端部署问题。

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
14  workout set rest seconds  success=true
```

## 4. iOS TestFlight 上传步骤

- [ ] 打开 `ios/DontLift/DontLift.xcodeproj`。
- [ ] Scheme 选择 `DontLift`。
- [ ] 目标设备选择 `Any iOS Device (arm64)`。
- [ ] 确认 General 中版本为 `1.0`，build 为 `12`。
- [ ] 确认 signing 使用正确 Apple Team，主 App 和 widget bundle 都可签名。
- [ ] 执行 `Product -> Archive`。
- [ ] Archive 完成后打开 Organizer。
- [ ] 选择本次 `1.0 (12)` archive。
- [ ] 执行 `Distribute App -> App Store Connect -> Upload`。
- [ ] 保持默认 App Store Connect 上传流程，等待上传成功。
- [ ] 到 App Store Connect 等待处理完成，TestFlight 出现 `1.0 (12)`。
- [ ] 添加内部测试或提交外部测试前，先安装到测试设备完成第 5 节回归。

## 5. TestFlight 主流程回归

- [ ] 后端已部署并确认 `V14` 成功后，再开始 iOS 回归。
- [ ] Apple 登录和正式登录路径正常。
- [ ] 冷启动和首次进入主界面后同步正常，顶部同步提示不阻挡操作。
- [ ] 后台短切回前台时，不应立即出现明显同步卡顿。
- [ ] 有非当前训练 pending 或 Team 待补发时，回前台延迟同步仍能完成。
- [ ] 前台休息到点：声音开时只响一次，声音关时不响，banner 仍展示。
- [ ] 后台/锁屏休息到点：声音开时系统通知播放 `rest_complete.caf`，声音关时静音展示。
- [ ] 休息通知仍显示系统“即时通知”标签，这是 Time Sensitive 预期行为。
- [ ] 完成组间休息后，预计休息秒数和真实休息秒数能随训练同步保存。
- [ ] Team 计划列表中，点击卡片标题、箭头、右侧空白区域都能进入计划详情。
- [ ] Team 计划卡片底部「开始训练」和「复制」操作不被详情热区截获。
- [ ] 自己分享的计划不展示复制按钮，右上操作菜单可取消分享。
- [ ] 别人分享的计划可直接开始训练，也可复制到我的计划。
- [ ] 动作库搜索 `哑铃臂屈伸后踢`、`哑铃三头后踢`、`肩关节外旋训练`、`招财猫式肩外旋` 都能命中标准动作。
- [ ] 旧计划或历史动作名通过 alias 显示为标准动作名，不丢失历史归并。
- [ ] 普通训练记录、计划开始训练、Team 分享计划直接开始训练和完成页保存为计划模板路径仍正常。

## 6. 发布后处理

- [ ] TestFlight `1.0 (12)` 可安装并完成主流程回归后，创建 tag：

```bash
git tag v1.0-b12
git push origin v1.0-b12
```

- [ ] 在发版记录中补充：
  - TestFlight 上传完成时间。
  - TestFlight 处理完成时间。
  - 实机回归设备和 iOS 版本。
  - 是否发现休息通知、回前台同步、Team 计划热区或动作库搜索问题。
- [ ] 若需要回滚 iOS，先停止 TestFlight build 12 测试；后端 `V14` 是向后兼容加字段，通常不需要回滚。
