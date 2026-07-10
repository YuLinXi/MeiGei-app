## 1. iOS 端：共享快照

- [x] 1.1 新增训练摘要 Widget 快照模型，字段覆盖今日状态、本周摘要、7 天节奏、最近训练与进行中训练。
- [x] 1.2 新增 App Group 快照读写 store，支持缺失快照时返回默认空状态。
- [x] 1.3 在主 App 历史摘要刷新、训练会话变化和启动路径写入快照并请求 Widget timeline 刷新。

## 2. iOS 端：Widget 展示与打开 App

- [x] 2.1 新增 small/medium 训练摘要 Widget timeline provider 与 SwiftUI 视图。
- [x] 2.2 在 Widget bundle 中注册训练摘要 Widget，同时保留现有训练会话 Live Activity。
- [x] 2.3 为 Widget 设置训练区深链，进行中训练状态使用继续训练深链。

## 3. iOS 端：工程配置

- [x] 3.1 为主 App 与 `DontLiftWidgetsExtension` 配置同一个 App Group entitlement。
- [x] 3.2 将新增 Widget 源文件加入 `DontLiftWidgetsExtension` Sources，确保 app 侧需要的共享源文件也加入主 App target。

## 4. 后端 / 基础设施

- [x] 4.1 确认本变更不需要后端 API、数据库迁移或同步契约变更。
- [x] 4.2 记录真机签名阶段需要在 Apple Developer Portal 创建对应 App Group。

## 5. 验证

- [x] 5.1 运行 OpenSpec 校验。
- [x] 5.2 运行 iOS simulator 构建，验证主 App 与 Widget extension 编译通过。
