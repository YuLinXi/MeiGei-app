# 发版操作清单：别练了 1.0 (build 20)

> 生成于 2026-07-09 18:10 CST，分支 `feature/v1.0-b20`。
> 本次发版功能介绍见 [`release-1.0-b20-feature-intro.md`](./release-1.0-b20-feature-intro.md)。

## 0. 本次发版摘要

- 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 20`。
- 后端部署：本次无需部署；生产当前 health 为 `UP`，Flyway 最新为 `V18 workout set is warmup success=true`。
- iOS 状态：本地 build/test 已通过；TestFlight `1.0 (20)` 尚未上传。
- iOS 重点：训练摘要小组件、设置页偏好编辑体验、OpenSpec workflow 工具补齐。
- 发布顺序：本次可直接上传 iOS TestFlight；后端仅需保持生产健康。
- Tag 策略：只有 TestFlight `1.0 (20)` 上传并完成真机主流程回归后，才建议合并并创建 `v1.0-b20` tag。

## 1. 已完成准备

- [x] 当前分支为 `feature/v1.0-b20`。
- [x] iOS build 号已递增到 `20`，App、widget、测试 target 同步，`MARKETING_VERSION` 保持 `1.0`。
- [x] 本次发版功能介绍已生成。
- [x] OpenSpec strict validate 通过：`add-workout-summary-widget`。
- [x] 后端构建通过：`JAVA_HOME=/Users/yumengyuan/Library/Java/JavaVirtualMachines/ms-21.0.11/Contents/Home ./gradlew build`。
- [x] iOS simulator build 通过：`xcodebuild ... CODE_SIGNING_ALLOWED=NO build`。
- [x] iOS simulator test 通过：`xcodebuild test ... CODE_SIGNING_ALLOWED=NO`，`162` 个测试，`0` failure。
- [x] `git diff --check` 通过。
- [x] 生产 health 当前为 `UP`。
- [x] 生产 dev token 当前返回 `404`，确认关闭。
- [x] 生产 Flyway 当前最新记录已查询：`18  workout set is warmup  success=true`。

## 2. 后端生产状态

> 本次 build 20 无后端运行时代码和数据库迁移变更，不需要运行 `./backend/deploy/release-update.sh`。

- [x] 确认本地后端构建已通过。
- [x] 确认生产健康检查当前返回 `UP`：

```bash
curl -fsS https://dontlift.peipadada.com/actuator/health
```

当前返回：

```json
{"status":"UP","groups":["liveness","readiness"]}
```

- [x] 查询生产 Flyway：

```bash
ssh root@124.222.79.121 "docker exec shared-postgres psql -U dontlift -d dontlift -tAc \
  \"SELECT version || '  ' || description || '  success=' || success FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 5;\""
```

当前记录：

```text
18  workout set is warmup  success=true
17  workout units  success=true
16  workout set segments  success=true
15  checkin reaction push receipts  success=true
14  workout set rest seconds  success=true
```

- [x] 确认生产 dev token 仍关闭：

```bash
curl -s -o /tmp/dontlift_dev_token_status_b20.txt -w '%{http_code}\n' \
  -X POST https://dontlift.peipadada.com/auth/dev/token
```

当前返回 `404`。

## 3. iOS TestFlight 上传步骤

- [ ] 确认 Apple Developer Portal 中已创建并分配 App Group：`group.com.yulinxi.app.DontLift`。
- [ ] 确认主 App 与 `DontLiftWidgetsExtension` signing 均可使用该 App Group entitlement。
- [ ] 打开 `ios/DontLift/DontLift.xcodeproj`。
- [ ] Scheme 选择 `DontLift`。
- [ ] 目标设备选择 `Any iOS Device (arm64)`。
- [ ] 确认 General 中版本为 `1.0`，build 为 `20`。
- [ ] 执行 `Product -> Archive`。
- [ ] Archive 完成后打开 Organizer。
- [ ] 选择本次 `1.0 (20)` archive。
- [ ] 执行 `Distribute App -> App Store Connect -> Upload`。
- [ ] 保持默认 App Store Connect 上传流程，等待上传成功。
- [ ] 到 App Store Connect 等待处理完成，TestFlight 出现 `1.0 (20)`。
- [ ] 安装 TestFlight build `1.0 (20)` 后开始真机回归。

## 4. TestFlight 主流程回归

- [ ] Apple 登录和正式登录路径正常。
- [ ] 冷启动、同步、Team 页加载正常，不出现 401/403 或空白卡死。
- [ ] 主屏添加 small 训练摘要小组件，首次/空状态展示正常，点击能打开 App 训练区。
- [ ] 主屏添加 medium 训练摘要小组件，本周训练次数、训练量、组数、次数、7 天节奏与最近训练展示正常。
- [ ] 存在进行中训练时，小组件展示「训练进行中」与当前训练名，不显示“继续 训练”。
- [ ] 点击进行中训练小组件后，App 打开训练页并进入或引导到当前训练会话。
- [ ] 完成或放弃训练后，回到主屏观察小组件在系统刷新后更新，不崩溃、不显示伪造数据。
- [ ] Live Activity、组间休息倒计时、提前结束休息仍按旧路径工作。
- [ ] 设置页「默认休息时长」打开 sheet，输入 15 秒到 10 分钟范围内的值后保存正常。
- [ ] 设置页「消耗估算」在未设置体重时会先要求填写体重，保存后开关状态正确。
- [ ] 设置页「估算体重」输入 30–250 kg 内外值时，校验、保存、取消表现正常。
- [ ] 法律页入口仍能以 sheet 打开。

## 5. 合并、Tag 与推送

> 当前 TestFlight `1.0 (20)` 尚未上传；不要现在创建 `v1.0-b20` tag。

- [ ] 确认工作区只包含 build 20 与本次预期改动。
- [ ] 提交本次发版准备改动。
- [ ] 推送发版分支：

```bash
git push origin feature/v1.0-b20
```

- [ ] TestFlight `1.0 (20)` 上传并完成真机主流程回归。
- [ ] 切换并更新 `main`：

```bash
git switch main
git pull --ff-only origin main
```

- [ ] 合并发版分支：

```bash
git merge --no-ff feature/v1.0-b20
```

- [ ] 创建并推送 tag：

```bash
git tag v1.0-b20
git push origin main
git push origin v1.0-b20
```

- [ ] 在本清单中补充：
  - TestFlight 上传时间和处理完成时间。
  - 真机回归设备和 iOS 版本。
  - 小组件主屏刷新与深链结果。
  - 设置页偏好编辑回归结果。
