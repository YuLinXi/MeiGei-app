# 发版操作清单：别练了 1.0 (build 19)

> 生成于 2026-07-09 00:10 CST，分支 `feature/v1.0-b19`。
> TestFlight 状态更新于 2026-07-09 00:13 CST，用户确认 `1.0 (19)` 已上传并完成真机回归。
> 合并与 tag 状态更新于 2026-07-09 00:16 CST。
> 本次发版功能介绍见 [`release-1.0-b19-feature-intro.md`](./release-1.0-b19-feature-intro.md)。

## 0. 本次发版摘要

- 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 19`。
- 后端部署：本次无需部署；生产当前 health 为 `UP`，Flyway 最新为 `V18 workout set is warmup success=true`。
- iOS 状态：本地 build/test 已通过，TestFlight `1.0 (19)` 已上传并完成真机回归，用户已确认。
- iOS 重点：训练首页动态图片 Hero、动作库搜索框真机键盘稳定性、自定义休息秒数按钮展示优化。
- 调试配置：真机局域网调试地址已切回普通 DEBUG `localhost:8001`；Release 仍强制走线上 HTTPS。
- 发布顺序：本次可直接上传 iOS TestFlight；后端仅需保持生产健康。
- Tag 策略：TestFlight `1.0 (19)` 已上传并完成真机主流程回归，本次发布合并回 `main` 后创建并推送 `v1.0-b19`。

## 1. 已完成准备

- [x] 当前分支为 `feature/v1.0-b19`。
- [x] iOS build 号已递增到 `19`，App、widget、测试 target 同步，`MARKETING_VERSION` 保持 `1.0`。
- [x] 发版前已将 DEBUG 本地后端从真机局域网 IP 切回 `http://localhost:8001`。
- [x] Release 配置仍固定使用 `https://dontlift.peipadada.com`。
- [x] 本次发版功能介绍已生成。
- [x] OpenSpec strict validate 通过：`add-dynamic-home-hero`。
- [x] OpenSpec strict validate 通过：`stabilize-exercise-library-search-keyboard`。
- [x] 后端构建通过：`JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ./gradlew build`。
- [x] iOS simulator build/run 通过：XcodeBuildMCP `build_run_sim`，`CODE_SIGNING_ALLOWED=NO`。
- [x] iOS simulator test 通过：XcodeBuildMCP `test_sim`，`160` 个测试，`0` failure。
- [x] `git diff --check` 通过。
- [x] 生产 health 当前为 `UP`。
- [x] 生产 dev token 当前返回 `404`，确认关闭。
- [x] 生产 Flyway 当前最新记录已查询：`18  workout set is warmup  success=true`。
- [x] TestFlight `1.0 (19)` 已上传。
- [x] TestFlight `1.0 (19)` 已处理完成并可安装。
- [x] TestFlight 真机主流程回归已完成，2026-07-09 00:13 CST 由用户确认。

## 2. 后端生产状态

> 本次 build 19 无后端运行时代码和数据库迁移变更，不需要运行 `./backend/deploy/release-update.sh`。

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
curl -s -o /tmp/dontlift_dev_token_status.txt -w '%{http_code}\n' \
  -X POST https://dontlift.peipadada.com/auth/dev/token
```

当前返回 `404`。

## 3. iOS TestFlight 上传步骤

- [x] 打开 `ios/DontLift/DontLift.xcodeproj`。
- [x] Scheme 选择 `DontLift`。
- [x] 目标设备选择 `Any iOS Device (arm64)`。
- [x] 确认 General 中版本为 `1.0`，build 为 `19`。
- [x] 确认 signing 使用正确 Apple Team，主 App 与 widget bundle 都可签名。
- [x] 执行 `Product -> Archive`。
- [x] Archive 完成后打开 Organizer。
- [x] 选择本次 `1.0 (19)` archive。
- [x] 执行 `Distribute App -> App Store Connect -> Upload`。
- [x] 保持默认 App Store Connect 上传流程，等待上传成功。
- [x] 到 App Store Connect 等待处理完成，TestFlight 出现 `1.0 (19)`。
- [x] 安装 TestFlight build `1.0 (19)` 后开始真机回归。

## 4. TestFlight 主流程回归

- [x] Apple 登录和正式登录路径正常。
- [x] 冷启动、同步、Team 页加载正常，不出现 401/403 或空白卡死。
- [x] 训练首页今日未完成时，Hero 展示待完成背景图与轻量文案。
- [x] 训练首页今日已完成但连续训练小于 3 天时，Hero 展示今日完成背景图。
- [x] 训练首页今日已完成且连续训练大于等于 3 天时，Hero 展示连续训练背景图和天数。
- [x] 有进行中训练时，Hero 不展示下一组、计时或继续训练文案；继续训练入口仍由全局浮层或既有冲突流程承担。
- [x] 动作库 Tab 点击「搜索动作」输入框，键盘弹起后搜索框完整可见。
- [x] 训练中点击底部「添加动作」，打开动作库抽屉，重复搜索框键盘回归。
- [x] 计划编辑中打开动作选择器，重复搜索框键盘回归。
- [x] 中文输入法候选栏、英文输入、收起键盘后，左侧分类栏和右侧动作列表位置正常。
- [x] 从搜索结果选择动作后，抽屉关闭并成功添加动作。
- [x] 训练中打开组间休息设置，自定义秒数按钮编辑、保存、清空和读法正常。
- [x] Live Activity、休息提醒、本地通知和触感路径做基础回归。

## 5. 合并、Tag 与推送

> TestFlight `1.0 (19)` 已可安装并通过真机回归。本次不需要等待后端部署。

- [x] 确认工作区只包含 build 19 与本次预期改动。
- [x] 推送发版分支：

```bash
git push origin feature/v1.0-b19
```

- [x] 切换并更新 `main`：

```bash
git switch main
git pull --ff-only origin main
```

- [x] 合并发版分支：

```bash
git merge --no-ff feature/v1.0-b19
```

- [x] 创建并推送 tag：

```bash
git tag v1.0-b19
git push origin main
git push origin v1.0-b19
```

- [x] 在发版记录中补充：
  - TestFlight 上传和真机回归：2026-07-09 00:13 CST 用户确认。
  - 真机回归设备和 iOS 版本：用户未提供。
  - 首页 Hero 三态：用户确认真机回归完成，未反馈异常。
  - 动作库搜索框：用户确认真机回归完成，未反馈遮挡或异常跳动。
