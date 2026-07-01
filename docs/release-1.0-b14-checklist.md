# 发版操作清单：别练了 1.0 (build 14)

> 生成于 2026-07-01，分支 `feature/v1.0-b14`。
> 本次发版功能介绍见 [`release-1.0-b14-feature-intro.md`](./release-1.0-b14-feature-intro.md)。

## 0. 本次发版摘要

- 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 14`。
- 后端部署：不需要。本次无后端代码和数据库迁移变更。
- 生产后端状态：健康检查返回 `UP`；生产 Flyway 最新为 `V15 checkin reaction push receipts success=true`。
- iOS 状态：准备上传 TestFlight。
- iOS 重点：动作库肌肉缩略图、动作库懒加载、筛选区展开动画修复、计划页类风琴分组、训练中悬浮窗可读性。
- 明确排除：超级组、递增组、递减组等高级计划编排功能不进入 build 14，已迁移到 `feature/v1.0-b15`。
- Tag 策略：TestFlight `1.0 (14)` 处理完成并确认可安装后，再创建并推送 `v1.0-b14`。

## 1. 已完成准备

- [x] iOS build 号已递增到 `14`，App、widget、测试 target 同步，`MARKETING_VERSION` 保持 `1.0`。
- [x] 确认本次无新增后端迁移，本地最新迁移仍为 `V15__checkin_reaction_push_receipts.sql`。
- [x] 生产健康检查通过：`https://dontlift.peipadada.com/actuator/health` 返回 `UP`。
- [x] 当前生产 Flyway 最新为 `V15 checkin reaction push receipts success=true`。
- [x] 后端构建通过：`export JAVA_HOME=/Users/yumengyuan/Library/Java/JavaVirtualMachines/ms-21.0.11/Contents/Home && ./gradlew build --rerun-tasks`。
- [x] iOS simulator build 通过：`xcodebuild ... CODE_SIGNING_ALLOWED=NO build`。
- [x] iOS simulator test 通过：`xcodebuild ... CODE_SIGNING_ALLOWED=NO test`，`totalTestCount = 100`，0 failed，0 skipped。
- [x] 本次发版功能介绍已生成。
- [x] `git diff --check` 通过。
- [ ] TestFlight `1.0 (14)` 上传完成并可安装。
- [ ] `v1.0-b14` tag 已在 TestFlight 可用后创建并推送。

## 2. 提交与推送

- [x] 确认当前分支为 `feature/v1.0-b14`。
- [x] 确认提交已包含动作库肌肉缩略图、动作库懒加载、计划页类风琴、训练中悬浮窗视觉、版本号和发版文档。
- [x] 确认 `feature/v1.0-b14` 不包含超级组、递增组、递减组相关代码。
- [ ] 推送分支：

```bash
git push origin feature/v1.0-b14
```

## 3. 后端生产状态

> build 14 无后端变更，因此不执行生产部署。只确认当前生产后端健康和 Flyway 状态。

健康检查命令：

```bash
curl -fsS https://dontlift.peipadada.com/actuator/health
```

本次返回：

```json
{"status":"UP","groups":["liveness","readiness"]}
```

生产 Flyway 查询：

```bash
ssh root@124.222.79.121 "docker exec shared-postgres psql -U dontlift -d dontlift -tAc \
  \"SELECT version || '  ' || description || '  success=' || success FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 5;\""
```

本次返回：

```text
15  checkin reaction push receipts  success=true
14  workout set rest seconds  success=true
13  strip extra weight fields from team plan shares  success=true
12  team plan shares  success=true
11  team checkin history index  success=true
```

## 4. iOS TestFlight 上传步骤

- [ ] 打开 `ios/DontLift/DontLift.xcodeproj`。
- [ ] Scheme 选择 `DontLift`。
- [ ] 目标设备选择 `Any iOS Device (arm64)`。
- [ ] 确认 General 中版本为 `1.0`，build 为 `14`。
- [ ] 确认 signing 使用正确 Apple Team，主 App 和 widget bundle 都可签名。
- [ ] 执行 `Product -> Archive`。
- [ ] Archive 完成后打开 Organizer。
- [ ] 选择本次 `1.0 (14)` archive。
- [ ] 执行 `Distribute App -> App Store Connect -> Upload`。
- [ ] 保持默认 App Store Connect 上传流程，等待上传成功。
- [ ] 到 App Store Connect 等待处理完成，TestFlight 出现 `1.0 (14)`。
- [ ] 添加内部测试或提交外部测试前，先安装到测试设备完成第 5 节回归。

## 5. TestFlight 主流程回归

- [ ] Apple 登录和正式登录路径正常。
- [ ] 冷启动和首次进入主界面后同步正常，顶部同步提示不阻挡操作。
- [ ] 进入动作库默认“全部”，首屏加载和滚动不明显卡顿。
- [ ] 动作库滚动到底部能继续加载更多动作，没有重复行或跳动。
- [ ] 动作库缩略图显示男性肌肉图，目标肌肉高亮准确，无空白、无女性资源。
- [ ] 肱二头肌、肱三头肌、前臂、臀大肌、臀中肌、内收肌、小腿肌群缩略图按验收效果显示。
- [ ] 动作库左侧筛选区展开新分组时，上一个分组自动收起，选中背景无异常滑入动画。
- [ ] 计划页分组为类风琴效果，展开一个分组时其它分组自动收起。
- [ ] 计划列表新增、重命名、删除、排序后，展开状态和列表展示仍正常。
- [ ] 训练完成分享图展示正常，内容不挤压、不错位。
- [ ] 开始训练后最小化，训练中悬浮窗计时、动作名、箭头和边距清晰舒适。
- [ ] 悬浮窗点击回到训练页，拖拽和左右吸附正常。
- [ ] 普通训练记录、计划开始训练、Team 分享计划直接开始训练和完成页保存为计划模板路径仍正常。
- [ ] build 14 中不出现超级组、递增组、递减组入口或高级计划编排 UI。

## 6. 发布后处理

- [ ] TestFlight `1.0 (14)` 可安装并完成主流程回归后，创建 tag：

```bash
git tag v1.0-b14
git push origin v1.0-b14
```

- [ ] 在发版记录中补充：
  - TestFlight 上传完成时间。
  - TestFlight 处理完成时间。
  - 实机回归设备和 iOS 版本。
  - 是否发现动作库加载、肌肉缩略图、计划页类风琴或训练中悬浮窗问题。
- [ ] 若需要回滚 iOS，停止 TestFlight build 14 测试即可；本次无后端迁移，不涉及后端回滚。
