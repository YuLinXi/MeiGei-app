# 发版操作清单 — 别练了 1.0 (build 10)

> 生成于 2026-06-25，分支 `feature/v1.0-b10`。
> 本次发版功能介绍见 [`release-1.0-b10-feature-intro.md`](./release-1.0-b10-feature-intro.md)。

## 0. 本次发版摘要

- 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 10`。
- 后端部署：本次不需要部署 backend；线上沿用 2026-06-24 23:34 CST 已发布版本，Flyway 最新为 `V10 team auto share preference success=true`。
- iOS 状态：准备上传 TestFlight。
- iOS 重点：预置动作库收敛、动作别名兼容归并、动作分类审核、训练中交互细节和休息计时稳定性。

## 1. 已完成准备

- [x] iOS build 号已递增到 `10`，App、widget、测试 target 同步，`MARKETING_VERSION` 保持 `1.0`。
- [x] 后端生产部署判断完成：本次只改本机开发脚本和 `.gitignore`，无生产后端代码、API、配置或数据库迁移变更。
- [x] 动作库兼容策略已落地：旧 code/name 通过 alias 归并到 canonical code，历史记录和 PR 不做破坏性迁移。
- [x] iOS simulator 构建通过：`DontLift` scheme，`CODE_SIGNING_ALLOWED=NO`。
- [x] iOS 测试通过：`DontLiftTests` scheme，78 passed / 0 failed。
- [ ] `v1.0-b10` tag 已在 TestFlight 可用后创建并推送。

## 2. iOS TestFlight 上传步骤

- [ ] 打开 `ios/DontLift/DontLift.xcodeproj`。
- [ ] Scheme 选择 `DontLift`，目标设备选择 `Any iOS Device (arm64)`。
- [ ] 确认 General 里版本为 `1.0`、build 为 `10`。
- [ ] 执行 `Product -> Archive`。
- [ ] 在 Organizer 里选择 `Distribute App -> App Store Connect -> Upload`。
- [ ] 等 App Store Connect 处理完成，TestFlight 出现 `1.0 (10)`。
- [ ] 安装 TestFlight build `1.0 (10)` 后再创建并推送 `v1.0-b10` tag。

## 3. TestFlight 回归重点

- [ ] 从 build 9 升级到 build 10 后，历史训练记录仍能正常展示。
- [ ] 旧动作名或旧 code 的历史 PR 能归并到标准动作，例如 `CABLE_FLY` / `CABLE_CROSSOVER`。
- [ ] 动作搜索能命中标准名、别名和旧名称，移除动作不再作为新选择入口出现。
- [ ] 热身拉伸动作在可浏览子类下正常出现，壶铃摆荡器械类型显示为壶铃。
- [ ] 新建训练、完成组、加一组、删除动作、放弃训练、结束训练均正常。
- [ ] 训练中的悬浮胶囊显示计时并可点击回到进行中训练。
- [ ] 休息计时前台、后台、锁屏、本地通知和提前结束路径正常。
- [ ] Team 分享、账号删除、Apple 登录等 build 9 关键路径未回归。

## 4. 后端处理结论

- [x] 本次不部署 backend。
- [x] 不需要执行 Flyway。
- [x] 不需要重启生产后端。
- [x] 不需要生产数据库备份。

原因：`v1.0-b9..HEAD` 中 backend 目录只有 `backend/.gitignore` 和 `backend/scripts/dev-start.sh` 变化，均为本机开发体验调整；没有后端生产运行代码、接口契约、配置项、数据库迁移或部署脚本变更。
