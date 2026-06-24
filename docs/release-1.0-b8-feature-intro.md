# v1.0-b8 发版功能介绍

> 适用版本：`1.0 (build 8)`  
> 后端状态：已于 2026-06-24 23:34 CST 部署，Flyway V10 已成功应用，Apple JWKS 已预热成功。
> iOS 状态：等待上传 TestFlight。

## 一句话摘要

本次 build 8 主要补齐 TestFlight 前的 MVP 风险收口：强化账号删除、Team 训练分享、离线同步、设备时间异常处理、Live Activity 展示和法务链接，重点降低数据错乱、隐私串号和发布审核风险。

## 面向测试用户的更新说明

- Team 训练分享更完整：完成训练后可以选择分享到指定 Team，也可以为 Team 设置自动分享偏好。
- 离线分享更稳：离线完成训练后，App 会等待对应 workout 同步成功，再补发 Team 分享，避免 Team feed 出现孤立或过期训练摘要。
- 账号删除更可靠：删除账号前会展示影响范围；删除时会清理本地训练数据、JWT、同步水位、Team 分享队列和自动分享缓存。
- Team 数据边界更清晰：已解散 Team、owner 转移、checkin 归属和 reaction 状态都做了更严格校验，减少删号失败和跨用户数据串用。
- 同步时间更安全：当设备时间异常偏移时，后端会裁剪未来时间戳并把校正信息回传给客户端，降低同步水位异常风险。
- 登录体验更顺：登录页会先发起一次轻量网络预热请求，让 iOS 首次网络权限弹窗尽量出现在点击 Apple 登录前。
- Apple 登录更稳：后端加长 Apple JWKS 拉取超时、开启 retry 和缓存预热，避免 Apple key 拉取慢时把正常登录误报为“登录已失效”。
- 休息计时体验增强：Live Activity 和 Dynamic Island 展示更新，提前结束休息的链路继续可用。
- 法务入口补齐：隐私政策和服务条款使用线上 HTTPS 页面，便于 TestFlight 和后续审核检查。

## 内部技术变更

- 后端新增并已部署 Flyway 迁移：
  - `V8__team_owner_transfer.sql`：记录删号时 Team owner 转移来源与时间。
  - `V9__clamp_future_sync_timestamps.sql`：支持同步时间戳裁剪与校正回传。
  - `V10__team_auto_share_preference.sql`：为 `team_member` 增加自动分享偏好。
- 账号删除补强：
  - 清理 active owned Team 的同时处理已软删 owned Team 残留，避免 FK 阻断用户硬删除。
  - 删除账号后清空本地 pending share 队列和自动分享缓存，避免下一个登录用户重放上一位用户的分享意图。
- Team checkin 补强：
  - 创建 checkin 前校验 workout 存在、属于当前用户且未删除。
  - pending share 队列按 `currentUserId` 隔离。
  - 仅在 workout 同步成功后重放 pending share。
- 同步补强：
  - push 结果支持 timestamp adjustment 回传。
  - workout、plan、custom exercise、plan group 同步路径接入未来时间戳防护。
- iOS 发布准备：
  - `MARKETING_VERSION = 1.0`。
  - `CURRENT_PROJECT_VERSION = 8`。
  - 登录页前置匿名 health check，用于提前触发系统首次网络权限弹窗。
  - 未登录接口的 `401` 不再映射为全局“登录已失效”，仅已鉴权请求触发重新登录。
  - Release simulator build 与 `DontLiftTests` 已通过。

## 兼容性说明

- 后端已先行上线，数据库迁移向前兼容，现有线上数据无需人工处理。
- 未升级到 build 8 的 iOS 用户仍可继续使用基础登录、训练同步和 Team 读取能力。
- build 8 新增的自动分享偏好、删号影响面优化、离线分享队列隔离、同步时间校正提示等能力需要安装新版客户端后生效。
- 如果用户长期离线，Team 分享意图会保留到后续同步周期；只有对应 workout 成功同步后才会发布到 Team feed。

## 已完成验证

- 后端本地 `./gradlew build` 通过。
- iOS Release simulator build 通过。
- iOS `DontLiftTests` 单元测试通过。
- 生产 health 返回 `UP`。
- 生产 Flyway 最新迁移为 `V10 team auto share preference success=true`。
- 生产启动日志显示 `Apple JWKS 预热成功 keys=3`。
- 生产 `POST /auth/dev/token` 返回 `404`，确认 dev token 未开启。

## TestFlight 回归重点

- Apple 登录生产链路可用。
- 首次安装后进入登录页，系统网络权限弹窗应在点击 Apple 登录前尽量前置出现。
- Apple 登录失败时不应再统一显示“登录已失效，请重新登录”；只有真实已登录会话过期才显示该提示。
- 新建训练、完成训练、手动分享 Team、自动分享 Team 均正常。
- 离线完成训练后恢复网络，Team 分享在 workout 同步成功后补发。
- 删除账号前影响面展示正确，删除后本地数据和分享队列清理完整。
- 已解散 owned Team 不阻断删号。
- Live Activity、Dynamic Island、本地休息通知和提前结束休息可用。
- 隐私政策、服务条款链接均可打开且为 HTTPS。
