# 发版操作清单：别练了 1.0 (build 18)

> 生成于 2026-07-07 23:19 CST，分支 `codex/fix-exercise-library-keyboard`。
> 本次发版功能介绍见 [`release-1.0-b18-feature-intro.md`](./release-1.0-b18-feature-intro.md)。

## 0. 本次发版摘要

- 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 18`。
- 后端部署：本次无需部署；生产当前 health 为 `UP`，Flyway 最新为 `V18 workout set is warmup success=true`。
- iOS 状态：已准备 `1.0 (18)`，TestFlight 尚未上传。
- iOS 重点：临时修复训练/计划里「添加动作」动作库抽屉点击搜索框后，真机键盘弹起导致顶部输入框被遮挡的问题。
- 发布顺序：本次可直接上传 iOS TestFlight；后端仅需保持生产健康。
- Tag 策略：仅在 TestFlight `1.0 (18)` 上传、处理完成、可安装并通过主流程回归后，创建并推送 `v1.0-b18`。

## 1. 已完成准备

- [x] 当前分支为 `codex/fix-exercise-library-keyboard`。
- [x] iOS build 号已递增到 `18`，App、widget、测试 target 同步，`MARKETING_VERSION` 保持 `1.0`。
- [x] 本次发版功能介绍已生成。
- [x] 后端构建通过：`JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ./gradlew build`。
- [x] iOS simulator build 通过：`xcodebuild -project DontLift.xcodeproj -scheme DontLift -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build`。
- [x] iOS simulator test 通过：单元测试 `157` 个、UI 测试 `6` 个，`0` failure。
- [x] XcodeBuildMCP 模拟器路径验证通过：打开添加动作抽屉并输入搜索词后，搜索框保持顶部可见。
- [x] `git diff --check` 通过。
- [x] 生产 health 当前为 `UP`。
- [x] 生产 dev token 当前返回 `404`，确认关闭。
- [x] 生产 Flyway 当前最新记录已查询：`18  workout set is warmup  success=true`。
- [ ] TestFlight `1.0 (18)` 已上传。
- [ ] TestFlight `1.0 (18)` 已处理完成并可安装。
- [ ] TestFlight 真机主流程回归已完成。
- [ ] hotfix 分支已合并回 `main`。
- [ ] `v1.0-b18` tag 已创建并推送。

## 2. 后端生产状态

> 本次 build 18 无后端运行时代码和数据库迁移变更，不需要运行 `./backend/deploy/release-update.sh`。

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
- [ ] 确认 General 中版本为 `1.0`，build 为 `18`。
- [ ] 确认 signing 使用正确 Apple Team，主 App 与 widget bundle 都可签名。
- [ ] 执行 `Product -> Archive`。
- [ ] Archive 完成后打开 Organizer。
- [ ] 选择本次 `1.0 (18)` archive。
- [ ] 执行 `Distribute App -> App Store Connect -> Upload`。
- [ ] 保持默认 App Store Connect 上传流程，等待上传成功。
- [ ] 到 App Store Connect 等待处理完成，TestFlight 出现 `1.0 (18)`。
- [ ] 安装 TestFlight build `1.0 (18)` 后开始真机回归。

## 4. TestFlight 主流程回归

- [ ] Apple 登录和正式登录路径正常。
- [ ] 冷启动、同步、Team 页加载正常，不出现 401/403 或空白卡死。
- [ ] 训练中点击底部「添加动作」，打开动作库抽屉。
- [ ] 点击顶部「搜索动作」输入框，键盘弹起后输入框完整可见。
- [ ] 搜索框不被 sheet 顶部拖拽条、圆角区域或状态栏遮挡。
- [ ] 输入中文关键词后列表过滤正常，左侧分类栏和右侧动作列表不异常跳动。
- [ ] 输入英文关键词后列表过滤正常。
- [ ] 收起键盘后，搜索框、列表、右侧器械快捷索引位置正常。
- [ ] 从搜索结果选择动作后，抽屉关闭并成功添加动作。
- [ ] 计划编辑中打开动作选择器，重复搜索框键盘回归。
- [ ] 动作库 Tab 根页搜索仍正常，不出现新的顶部位移或遮挡。

## 5. 合并、Tag 与推送

> 仅在 TestFlight 可安装、主流程回归通过后执行。本次不需要等待后端部署。

- [ ] 确认工作区只包含 build 18 与本次 hotfix 预期改动。
- [ ] 推送 hotfix 分支：

```bash
git push origin codex/fix-exercise-library-keyboard
```

- [ ] 切换并更新 `main`：

```bash
git switch main
git pull --ff-only origin main
```

- [ ] 合并 hotfix 分支：

```bash
git merge --no-ff codex/fix-exercise-library-keyboard
```

- [ ] 创建并推送 tag：

```bash
git tag v1.0-b18
git push origin main
git push origin v1.0-b18
```

- [ ] 在发版记录中补充：
  - TestFlight 上传完成时间。
  - TestFlight 处理完成时间。
  - 真机回归设备和 iOS 版本。
  - 添加动作抽屉搜索框是否仍有键盘遮挡或异常跳动。
