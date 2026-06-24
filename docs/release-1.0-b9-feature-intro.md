# v1.0-b9 发版功能介绍

> 适用版本：`1.0 (build 9)`
> 后端状态：已于 2026-06-24 23:34 CST 部署，Flyway V10 已成功应用，Apple JWKS 已预热成功。
> iOS 状态：准备上传 TestFlight。

## 一句话摘要

本次 build 9 是 TestFlight 发版候选版，聚焦登录可靠性、首次网络权限体验、休息结束提醒音、账号删除和 Team 分享数据边界。

## 面向测试用户的更新说明

- Apple 登录更稳定：后端已优化 Apple JWKS 拉取、缓存和预热，减少正常登录被误判为失效的情况。
- 登录体验更顺：登录页会先发起轻量网络预热，让 iOS 首次网络权限弹窗尽量出现在点击 Apple 登录前。
- 休息结束更容易听到：提示音改为更清晰的双击 bell，前台提醒和后台/锁屏本地通知共用同一音效。
- Team 训练分享更完整：完成训练后可手动选择 Team，也支持 Team 自动分享偏好。
- 离线分享更稳：等待对应 workout 同步成功后再补发 Team 分享，避免孤立或过期训练摘要。
- 账号删除更可靠：删除前展示影响范围，删除时清理本地训练数据、JWT、同步水位、Team 分享队列和自动分享缓存。
- 同步时间更安全：设备时间异常偏移时，后端会裁剪未来时间戳并回传校正信息。
- 法务入口补齐：隐私政策和服务条款使用线上 HTTPS 页面。

## 内部技术变更

- iOS 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 9`。
- 后端已部署 Flyway `V8`、`V9`、`V10`。
- 后端 Apple token 校验：
  - Apple JWKS connect/read timeout 调整为 5 秒。
  - 开启 JWKS retry、缓存和启动预热。
  - JWKS 暂不可用时返回 `503`，不再误报为 token `401`。
- iOS 网络错误映射：
  - 只有已鉴权请求的 `401` 才显示“登录已失效”并触发登出。
  - `/auth/apple` 这类未登录接口的 `401` 不再走全局会话失效文案。
- 休息提示音：
  - `rest_complete.caf` 替换为 `Gym Bell Double Tap`，时长约 `1.18s`。

## 兼容性说明

- 后端已先行上线，数据库迁移向前兼容，现有线上数据无需人工处理。
- 未升级到 build 9 的 iOS 用户仍可使用基础登录、训练同步和 Team 读取能力。
- build 9 新增的登录页网络预热、错误文案修正和双击 bell 提示音需要安装新版客户端后生效。

## 已完成验证

- 后端本地 `./gradlew build` 通过。
- iOS Debug simulator build 通过。
- 生产 health 返回 `UP`。
- 生产 Flyway 最新迁移为 `V10 team auto share preference success=true`。
- 生产启动日志显示 `Apple JWKS 预热成功 keys=3`。

## TestFlight 回归重点

- 首次安装后进入登录页，网络权限弹窗应尽量在点击 Apple 登录前出现。
- Apple 登录生产链路可用；登录失败时不应统一显示“登录已失效，请重新登录”。
- 新建训练、完成训练、手动分享 Team、自动分享 Team 均正常。
- 离线完成训练后恢复网络，Team 分享在 workout 同步成功后补发。
- 删除账号前影响面展示正确，删除后本地数据和分享队列清理完整。
- Live Activity、Dynamic Island、本地休息通知、双击 bell 提示音和提前结束休息可用。
