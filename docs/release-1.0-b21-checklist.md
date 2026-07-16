# 发版操作清单：别练了 1.0 (build 21)

> 生成于 2026-07-16 22:12 CST，分支 `feature/v1.0-b21`。
> 发布差异基线为最近已发布 tag `v1.0-b20`。
> 本次发版功能介绍见 [`release-1.0-b21-feature-intro.md`](./release-1.0-b21-feature-intro.md)。

## 0. 本次发版摘要

- 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 21`。
- 后端状态：本地 build/test 已通过；生产 health 为 `UP`，但 Flyway 当前仍为 `V18`，候选后端及 `V19/V20` 尚未部署。
- iOS 状态：Simulator build/test 已通过；TestFlight `1.0 (21)` 尚未上传。
- 发布顺序：提交并推送候选分支 → 部署后端并验证 `V19/V20` → Archive/上传 TestFlight → 等待 App Store Connect 状态 `VALID` → 真机回归 → 合并 `main` 并打 tag。
- Tag 策略：只有生产后端部署成功、TestFlight build 21 为 `VALID` 且真机主流程回归通过后，才创建 `v1.0-b21`。

## 1. 已完成准备

- [x] 发布文案规范已在 `AGENTS.md` 与 `CLAUDE.md` 同步强化，测试用户更新说明只描述 `v1.0-b20` 到 b21 候选版本的最终用户差异。
- [x] 当前分支为 `feature/v1.0-b21`，发布基线为 `v1.0-b20`。
- [x] 主 App、widget extension 与测试 target 的 build 号已统一递增到 `21`，版本保持 `1.0`。
- [x] 本次发版 checklist 与功能介绍已生成。
- [x] 后端 `./gradlew clean build` 通过。
- [x] 后端完整测试使用 `--rerun-tasks` 实际执行：`80` tests，`0` failure，`0` error，`0` skipped。
- [x] iOS Simulator Debug build 通过：iPhone 17 / iOS 26.4.1，`CODE_SIGNING_ALLOWED=NO`。
- [x] iOS Simulator test 通过：xcresult=`Passed`，`192` tests，`0` failed，`0` skipped。
- [x] 本次相关 8 个 OpenSpec change 均通过 strict validate。
- [x] Team 拍一拍本地 Simulator 端到端请求返回 `HTTP 200`，UI 与数据库状态一致。
- [x] `git diff --check` 通过。
- [x] 生产只读检查通过：health=`UP`、dev token=`404`、privacy=`200`、terms=`200`。
- [x] 生产 Flyway 已确认当前最新为 `V18`，明确 `V19/V20` 仍待部署。
- [x] 当前候选改动已完成最终 review，工作区范围无遗漏或意外文件。
- [x] 候选改动、版本号和两份发版文档已提交并推送到 `origin/feature/v1.0-b21`，功能候选 commit 为 `834aebd`。

## 2. 后端生产部署

> 本次 iOS 依赖新的 Team nudge 和消息偏好 API，必须先部署后端。真实部署入口为 `backend/deploy/release-update.sh`。

- [ ] 确认远程服务器备份目录和 PostgreSQL 备份可写。
- [ ] 在候选分支已提交、推送且最终 review 通过后执行：

```bash
cd backend
./deploy/release-update.sh
```

- [ ] 部署脚本完成数据库备份、代码同步和远程 `docker compose up -d --build`。
- [ ] 连续检查生产 health，确认多次返回 `UP`：

```bash
curl -fsS https://dontlift.peipadada.com/actuator/health
```

- [ ] 查询 Flyway，确认 `V19` 与 `V20` 均为 `success=true`，最新版本为 `20`：

```bash
ssh root@124.222.79.121 "docker exec shared-postgres psql -U dontlift -d dontlift -tAc \
  \"SELECT version || '  ' || description || '  success=' || success FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 8;\""
```

- [ ] 确认生产 dev token 仍关闭：

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X POST \
  https://dontlift.peipadada.com/auth/dev/token
```

期望返回 `404`。

- [ ] 确认 `/privacy` 与 `/terms` 均返回 `200`。
- [ ] 检查后端启动日志，无 Flyway、MyBatis、APNs 或持续 5xx 异常。
- [ ] 使用旧 TestFlight build 20 做最小兼容回归：Apple 登录、训练拉取/同步、Team 列表和动态正常。
- [ ] 记录后端部署时间、备份位置、部署 commit 和迁移结果。

## 3. iOS TestFlight 上传

- [ ] 打开 `ios/DontLift/DontLift.xcodeproj`，Scheme 选择 `DontLift`。
- [ ] 目标设备选择 `Any iOS Device (arm64)`。
- [ ] 确认 General 中版本为 `1.0`、build 为 `21`，主 App 与 widget extension signing 正常。
- [ ] 确认 App Group `group.com.yulinxi.app.DontLift` 和 Push Notifications entitlement 可用于 App Store 分发签名。
- [ ] 执行 `Product -> Archive`。
- [ ] 在 Organizer 中选择本次 `1.0 (21)` archive。
- [ ] 执行 `Distribute App -> App Store Connect -> Upload`。
- [ ] 等待 App Store Connect 处理完成；只有状态为 `VALID` 才算上传闭环完成。
- [ ] 在 TestFlight 中确认出现 `1.0 (21)`，并安装到至少两台设备或两个可独立登录的测试环境。
- [ ] 记录 Archive 时间、上传时间、处理完成时间和 App Store Connect build 状态。

## 4. TestFlight 主流程回归

### 4.1 基础回归

- [ ] Apple 登录、冷启动、退出重登和正式同步路径正常。
- [ ] 训练首页、计划页、动作库、Team 页和我的页面加载正常，无 401/403、持续 Loading 或空白卡死。
- [ ] Live Activity、组间休息通知、HealthKit 写入和训练摘要小组件没有回归。

### 4.2 Team 拍一拍与消息设置

- [ ] 账号 A、B 加入同一 Team，尚无今日动态的队友出现在可拍列表，当前用户本人不出现。
- [ ] 账号 A 拍账号 B 后立即显示“已拍”，重复进入页面仍保持；同日不能重复发送第二条。
- [ ] 账号 B 收到包含发送者与 Team 名称的通知，点击后进入对应 Team。
- [ ] 已有今日 Team 动态或已关闭当前 Team 消息的成员不可拍。
- [ ] 关闭“Team消息”后，当前 Team 的拍一拍、队友打卡和表情回应通知均停止；其他 Team 不受影响。
- [ ] “分享动态”和“Team消息”分别切换、快速返回、重进页面后状态正确，保存过程中设置卡不抖动。
- [ ] 关闭“分享动态”后完成训练不产生新 Team 动态；重新开启流程与隐私确认正常。

### 4.3 计划与备选动作

- [ ] 普通计划动作可添加、排序和移除备选；递减组和超级组不出现备选入口。
- [ ] 个人计划、Team 分享版本、Fork 和离线重启后备选动作仍存在，Team 分享不泄露重量。
- [ ] 从计划开始训练后，在没有完成任何组时可切换备选；完成热身或正式组后不可切换。
- [ ] 严格模式切换备选后保留组次结构并清空重量；切回默认动作恢复默认落值。
- [ ] 自适应模式只使用该计划动作位下该备选自身的历史，不借用默认动作重量。
- [ ] 完成备选动作后实际历史和 PR 正常，默认计划动作与安排不被覆盖。
- [ ] 计划详情默认折叠，最多展开一个动作；普通、递减组、超级组的组次详情和下次重量正确。
- [ ] 长计划可连续滚动和左边缘侧滑返回；右侧 `…` 菜单可编辑、删除并保留二次确认。

### 4.4 分享海报

- [ ] 普通训练、PR、Team 来源和复杂训练分别得到合理的初始背景推荐。
- [ ] 左右滑动海报、左右按钮和小预览均能在 5 款背景间切换，页码与选中态同步。
- [ ] 海报至少展示 6 个动作，超过 6 个时显示剩余数量，文字不遮挡主要人物或器械。
- [ ] 当前海报保存到相册和系统分享后的图片均为 `1080×1920`，与屏幕预览背景和数据一致。
- [ ] 离线状态下仍可切换全部背景、保存和分享。

### 4.5 可靠性回归

- [ ] 正式组标记为热身再取消后恢复原相对顺序；旧热身数据一次操作即可取消。
- [ ] 最后一组休息尚未结束时直接结束训练，休息记录按本段目标时长保存，计时器和 Live Activity 正常停止。
- [ ] 历史日期训练跨日补同步后仍出现在原日期，队友不会收到“今天完成训练”通知。
- [ ] 训练摘要小组件跨日和跨周后使用当前日期与周范围，不残留旧日高亮。
- [ ] 设置页休息时长、估算体重和法律页 sheet 高度稳定，保存、取消和键盘交互正常。

## 5. 合并、Tag 与推送

> 当前后端尚未部署，TestFlight `1.0 (21)` 尚未上传；不要现在创建 `v1.0-b21` tag。

- [ ] 生产后端 health 与 Flyway `V20` 验证通过。
- [ ] TestFlight `1.0 (21)` 状态为 `VALID`，可安装。
- [ ] TestFlight 主流程回归全部通过，阻塞问题已清零。
- [ ] 将 `feature/v1.0-b21` 合并到最新 `main`，解决冲突后重新运行必要门禁。
- [ ] 推送 `main`。
- [ ] 创建并推送 tag：

```bash
git tag -a v1.0-b21 -m "TestFlight 发版：1.0 (build 21)"
git push origin v1.0-b21
```

- [ ] 在本 checklist 和功能介绍中回填生产部署、TestFlight `VALID`、真机回归和 tag 状态。

## 6. 回滚与异常处理

- 后端 `V19/V20` 以新增表、索引和默认值调整为主；若应用代码需回滚，先保留 schema，恢复上一后端镜像并再次验证旧 build 20。
- 若 Flyway 迁移失败，立即停止 TestFlight 上传，保留数据库备份和失败日志，不手工修改 `flyway_schema_history`。
- 若 build 21 上传失败或真机回归发现阻塞问题，修复后递增 build 号，不复用已经上传到 App Store Connect 的 build 21。
- 若只有新版 Team nudge 异常，停止 build 21 测试并回滚后端应用代码；不要删除已经写入的 nudge 表或历史记录。

## 7. 发布记录待回填

- 后端部署 commit：
- 数据库备份位置：
- Flyway `V19/V20` 完成时间：
- TestFlight 上传时间：
- App Store Connect `VALID` 时间：
- 真机回归设备与 iOS 版本：
- 回归结论与已知问题：
- `main` 合并 commit：
- `v1.0-b21` tag：
