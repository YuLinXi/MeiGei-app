# 发版操作清单：别练了 1.0 (build 15)

> 生成于 2026-07-03，分支 `feature/v1.0-b15`。
> 本次发版功能介绍见 [`release-1.0-b15-feature-intro.md`](./release-1.0-b15-feature-intro.md)。

## 0. 本次发版摘要

- 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 15`。
- 后端部署：已完成。生产已应用 `V16__workout_set_segments.sql`。
- iOS 状态：TestFlight `1.0 (15)` 已由用户确认发布完成。
- iOS 重点：递减组训练记录、递减组计划模板处方、保存为计划、Team 分享/Fork 脱敏、Team 打卡展示、登录后 Team 请求 403 修复。
- 兼容策略：V16 对旧客户端兼容，旧 payload 缺少 `segments` 时按空数组处理。
- Tag 策略：TestFlight `1.0 (15)` 已发布完成、后端已部署完成，按本次发版顺序合并到 `main` 并创建推送 `v1.0-b15`。

## 1. 已完成准备

- [x] 当前分支为 `feature/v1.0-b15`。
- [x] iOS build 号已递增到 `15`，App、widget、测试 target 同步，`MARKETING_VERSION` 保持 `1.0`。
- [x] 本次发版功能介绍已生成。
- [x] OpenSpec 校验通过：`openspec validate add-drop-set-recording --strict`。
- [x] add-drop-set-recording 自动化验收已完成：iOS simulator 测试 `111 passed, 0 failed, 0 skipped`。
- [x] 后端测试通过：`JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ./gradlew test`。
- [x] 模拟器复测 Team 登录链路：`GET /teams auth=Y`，返回 `200`。
- [x] 版本号变更后的最终 iOS simulator build 通过。
- [x] 版本号变更后的最终 iOS simulator test 通过：`111 passed, 0 failed, 0 skipped`。
- [x] `git diff --check` 通过。
- [x] TestFlight `1.0 (15)` 已由用户确认发布完成。
- [x] 后端生产部署完成，生产 Flyway 最新为 `V16 workout set segments success=true`。
- [ ] TestFlight 真机主流程回归细节已补充到发版记录。
- [ ] `feature/v1.0-b15` 已合并回 `main`。
- [ ] `v1.0-b15` tag 已创建并推送。

## 2. iOS TestFlight 上传步骤

- [ ] 打开 `ios/DontLift/DontLift.xcodeproj`。
- [ ] Scheme 选择 `DontLift`。
- [ ] 目标设备选择 `Any iOS Device (arm64)`。
- [ ] 确认 General 中版本为 `1.0`，build 为 `15`。
- [ ] 确认 signing 使用正确 Apple Team，主 App 和 widget bundle 都可签名。
- [ ] 执行 `Product -> Archive`。
- [ ] Archive 完成后打开 Organizer。
- [ ] 选择本次 `1.0 (15)` archive。
- [ ] 执行 `Distribute App -> App Store Connect -> Upload`。
- [ ] 保持默认 App Store Connect 上传流程，等待上传成功。
- [ ] 到 App Store Connect 等待处理完成，TestFlight 出现 `1.0 (15)`。
- [x] 告知 Codex 继续后端部署。

## 3. 后端部署步骤

> 按用户指定顺序，后端部署在 TestFlight 上传之后执行。

- [x] 确认本地后端测试通过。
- [x] 确认生产部署目标和当前生产 health。
- [x] 部署后端当前分支代码。
- [x] 确认 Flyway 应用 `V16__workout_set_segments.sql`。
- [x] 确认生产健康检查返回 `UP`：

```bash
curl -fsS https://dontlift.peipadada.com/actuator/health
```

- [x] 查询生产 Flyway 最新记录：

```bash
ssh root@124.222.79.121 "docker exec shared-postgres psql -U dontlift -d dontlift -tAc \
  \"SELECT version || '  ' || description || '  success=' || success FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 5;\""
```

本次返回：

```text
16  workout set segments  success=true
15  checkin reaction push receipts  success=true
14  workout set rest seconds  success=true
13  strip extra weight fields from team plan shares  success=true
12  team plan shares  success=true
```

## 4. TestFlight 主流程回归

- [ ] Apple 登录和正式登录路径正常。
- [ ] 冷启动和首次进入主界面后同步正常，Team 页不出现 403。
- [ ] 普通训练中添加递减组，不自动弹键盘，首个内部组继承上一正式组重量/次数。
- [ ] 递减组内部「添加」新增内部组，删除后编号重新排序。
- [ ] 递减组折叠/展开、左侧区分线、内部组缩进和输入框尺寸正常。
- [ ] 普通组可改为递减组；递减组改回普通组前有确认，并保留第一个有效内部组。
- [ ] 热身组不直接展示「改为递减组」。
- [ ] 自定义数字键盘在递减组内部焦点顺序正确；键盘「加一组」新增父级普通组。
- [ ] 完成递减组后，完成组数按父级 1 组计算，训练量和次数按有效内部组展开计算。
- [ ] 训练详情、PR、历史曲线和分享海报正确展示递减组。
- [ ] 新建训练模板和计划详情编辑中可以添加、编辑、删除递减组处方。
- [ ] 从含递减组处方的计划开始训练时，能生成未完成的递减组父级 set。
- [ ] 保存训练为计划模板后，递减组结构被写入计划处方。
- [ ] Team 分享计划和 Fork 后保留递减组结构与次数，重量被清空。
- [ ] 后端部署后，递减组训练同步、Team 打卡列表和打卡详情正常。
- [ ] 计划分组下没有计划时，展开后不显示空分组文案。

## 5. 合并、Tag 与推送

> 仅在 TestFlight 可安装、后端部署完成、主流程回归通过后执行。

- [ ] 确认工作区只包含 build 15 预期改动。
- [ ] 推送发版分支：

```bash
git push origin feature/v1.0-b15
```

- [ ] 切换并更新 `main`：

```bash
git switch main
git pull --ff-only origin main
```

- [ ] 合并发版分支：

```bash
git merge --no-ff feature/v1.0-b15
```

- [ ] 创建并推送 tag：

```bash
git tag v1.0-b15
git push origin main
git push origin v1.0-b15
```

- [ ] 在发版记录中补充：
  - TestFlight 上传完成时间。
  - TestFlight 处理完成时间。
  - 后端部署完成时间。
  - 生产 Flyway 最新记录。
  - 真机回归设备和 iOS 版本。
  - 是否发现递减组、Team、计划模板或同步问题。
