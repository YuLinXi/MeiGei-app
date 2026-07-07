# 发版操作清单：别练了 1.0 (build 17)

> 生成于 2026-07-07 22:34 CST，分支 `feature/v1.0-b17`。
> TestFlight 状态更新于 2026-07-07 22:43 CST，用户确认 `1.0 (17)` 已发布并完成回归。
> 合并与 tag 状态更新于 2026-07-07 22:45 CST。
> 本次发版功能介绍见 [`release-1.0-b17-feature-intro.md`](./release-1.0-b17-feature-intro.md)。

## 0. 本次发版摘要

- 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 17`。
- 后端部署：本次无需部署；生产当前 health 为 `UP`，Flyway 最新为 `V18 workout set is warmup success=true`。
- iOS 状态：TestFlight `1.0 (17)` 已发布并完成回归，用户已确认。
- iOS 重点：计划热身处方、计划详情动作卡片精简、Team 计划详情结构图标与动作跳转、编辑动作键盘滚动、休息提示和分享/kcal 细节修正。
- 发布顺序：本次可直接上传 iOS TestFlight；后端仅需保持生产健康。
- Tag 策略：TestFlight `1.0 (17)` 已可安装并通过主流程回归，本次发布合并回 `main` 后创建并推送 `v1.0-b17`。

## 1. 已完成准备

- [x] 当前分支为 `feature/v1.0-b17`。
- [x] iOS build 号已递增到 `17`，App、widget、测试 target 同步，`MARKETING_VERSION` 保持 `1.0`。
- [x] 本次发版功能介绍已生成。
- [x] OpenSpec 校验通过：`openspec validate add-plan-warmup-prescriptions --type change --strict`。
- [x] OpenSpec 校验通过：`openspec validate add-workout-calorie-estimates --type change --strict`。
- [x] 后端构建通过：`JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ./gradlew build`。
- [x] iOS simulator build 通过：`xcodebuild -project DontLift.xcodeproj -scheme DontLift -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build`。
- [x] iOS simulator test 通过：单元测试 `157` 个、UI 测试 `6` 个，`0` failure。
- [x] `git diff --check` 通过。
- [x] 生产 health 当前为 `UP`。
- [x] 生产 dev token 当前返回 `404`，确认关闭。
- [x] 生产 Flyway 当前最新记录已查询：`18  workout set is warmup  success=true`。
- [x] TestFlight `1.0 (17)` 已上传。
- [x] TestFlight `1.0 (17)` 已处理完成并可安装。
- [x] TestFlight 真机主流程回归已完成，2026-07-07 22:43 CST 由用户确认。
- [x] `feature/v1.0-b17` 已合并回 `main`。
- [x] `v1.0-b17` tag 已创建并推送。

## 2. 后端生产状态

> 本次 build 17 无后端运行时代码和数据库迁移变更，不需要运行 `./backend/deploy/release-update.sh`。

- [x] 确认本地后端构建已通过。
- [x] 确认生产健康检查当前返回 `UP`：

```bash
curl -fsS https://dontlift.peipadada.com/actuator/health
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
curl -s -o /tmp/dontlift_dev_token_status.txt -w '%{http_code}\n' \
  -X POST https://dontlift.peipadada.com/auth/dev/token
```

当前返回 `404`。

## 3. iOS TestFlight 上传步骤

- [ ] 打开 `ios/DontLift/DontLift.xcodeproj`。
- [ ] Scheme 选择 `DontLift`。
- [ ] 目标设备选择 `Any iOS Device (arm64)`。
- [ ] 确认 General 中版本为 `1.0`，build 为 `17`。
- [ ] 确认 signing 使用正确 Apple Team，主 App 与 widget bundle 都可签名。
- [ ] 执行 `Product -> Archive`。
- [ ] Archive 完成后打开 Organizer。
- [ ] 选择本次 `1.0 (17)` archive。
- [ ] 执行 `Distribute App -> App Store Connect -> Upload`。
- [ ] 保持默认 App Store Connect 上传流程，等待上传成功。
- [ ] 到 App Store Connect 等待处理完成，TestFlight 出现 `1.0 (17)`。
- [ ] 安装 TestFlight build `1.0 (17)` 后开始真机回归。

## 4. TestFlight 主流程回归

- [ ] Apple 登录和正式登录路径正常。
- [ ] 冷启动、同步、Team 页加载正常，不出现 401/403 或空白卡死。
- [ ] 计划编辑中添加、删除、修改普通动作热身组正常。
- [ ] 编辑动作时键盘弹出后，热身组和正式组输入框可滚动到可见区域。
- [ ] 热身行左侧 `热1` / `热2` 与后方重量、次数输入框垂直居中，删除按钮同样居中。
- [ ] 从计划开始训练时，热身组和正式组都按计划处方生成。
- [ ] 完成训练后回写计划，热身处方保留，正式组摘要不被热身组覆盖。
- [ ] 只有热身组的历史记录不影响下一次正式组预填。
- [ ] 计划详情中普通组、递减组、超级组结构展示正确。
- [ ] Team 计划详情动作卡片只保留动作名称、计划组数和次数。
- [ ] Team 计划详情用普通/递减/超级组图标区分动作结构。
- [ ] Team 计划详情中可跳转的动作进入对应动作库详情。
- [ ] 超级组在 Team 计划详情保持整体结构，成员动作跳转不破坏超级组语义。
- [ ] Team 分享计划与 Fork 保留热身、递减组、超级组结构和次数，重量字段仍被清空。
- [ ] 训练中跳过部分组后，休息完成后的下一组推荐符合训练顺序。
- [ ] 动作库搜索或编辑动作时键盘不造成异常页面跳动。
- [ ] 分享海报展示 kcal 时仍保持时长、训练量、组数、动作列表可读。
- [ ] 未设置体重或关闭消耗估算时，训练详情和分享海报不展示 kcal。
- [ ] 跨设备同步一条包含计划热身、递减组和超级组的训练后，另一设备展示一致。

## 5. 合并、Tag 与推送

> TestFlight `1.0 (17)` 已可安装并通过主流程回归。本次不需要等待后端部署。

- [x] 确认工作区只包含 build 17 与发版文档预期改动。
- [x] 推送发版分支：

```bash
git push origin feature/v1.0-b17
```

- [x] 切换并更新 `main`：

```bash
git switch main
git pull --ff-only origin main
```

- [x] 合并发版分支：

```bash
git merge --no-ff feature/v1.0-b17
```

- [x] 创建并推送 tag：

```bash
git tag v1.0-b17
git push origin main
git push origin v1.0-b17
```

- [ ] 在发版记录中补充：
  - TestFlight 上传完成时间。
  - TestFlight 处理完成时间。
  - 真机回归设备和 iOS 版本。
  - 是否发现计划热身、Team 计划详情、动作详情跳转、键盘滚动或休息提示问题。
