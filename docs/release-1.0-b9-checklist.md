# 发版操作清单 — 别练了 1.0 (build 9)

> 生成于 2026-06-25，分支 `main`。
> 本次发版功能介绍见 [`release-1.0-b9-feature-intro.md`](./release-1.0-b9-feature-intro.md)。

## 0. 本次发版摘要

- 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 9`。
- 后端已上线：2026-06-24 23:34 CST，备份 `dontlift_2026-06-24_233403.sql.gz`。
- 后端 Flyway：`V10 team auto share preference success=true`。
- iOS 重点：Apple 登录可靠性、网络权限前置、休息结束双击 bell、账号删除和 Team 分享稳定性。

## 1. 已完成准备

- [x] iOS build 号已递增到 `9`，App、widget、测试 target 同步，`MARKETING_VERSION` 保持 `1.0`。
- [x] 后端生产发布完成，health 返回 `UP`。
- [x] Apple JWKS 生产启动预热成功：`keys=3`。
- [x] iOS simulator 构建通过。
- [x] `v1.0-b9` tag 已推送远端。

## 2. iOS TestFlight 上传步骤

- [ ] 打开 `ios/DontLift/DontLift.xcodeproj`。
- [ ] Scheme 选择 `DontLift`，目标设备选择 `Any iOS Device (arm64)`。
- [ ] 确认 General 里版本为 `1.0`、build 为 `9`。
- [ ] 执行 `Product -> Archive`。
- [ ] 在 Organizer 里选择 `Distribute App -> App Store Connect -> Upload`。
- [ ] 等 App Store Connect 处理完成，TestFlight 出现 `1.0 (9)`。

## 3. TestFlight 回归重点

- [ ] 首次安装后进入登录页，网络权限弹窗应尽量在点击 Apple 登录前出现。
- [ ] Apple 登录生产链路可用；登录失败时不应统一显示“登录已失效，请重新登录”。
- [ ] 休息结束前台音效和后台/锁屏本地通知使用双击 bell，且不双响。
- [ ] 手动 Team 分享、自动 Team 分享、离线重放均正常。
- [ ] 删号影响面展示正确，删除后本地数据和分享队列清理完整。
- [ ] Live Activity / Dynamic Island / 提前结束休息正常。
