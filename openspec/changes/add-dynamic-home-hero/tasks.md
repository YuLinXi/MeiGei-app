## 1. iOS 端

- [x] 1.1 将用户提供的三张首页背景图导入 `Assets.xcassets`，命名为 `homeHeroStreak`、`homeHeroPending`、`homeHeroDone`。
- [x] 1.2 扩展首页轻量快照，提供今日已完成训练次数与连续训练天数，确保派生逻辑不在 SwiftUI `body` 中扫描完整历史聚合树。
- [x] 1.3 将训练首页 `heroSection` 替换为动态图片 Hero，按连续打卡、今日完成、待完成优先级切换图片和文案。
- [x] 1.4 为 Hero 补齐 Dynamic Type、VoiceOver 和图片装饰语义处理，保持底部「开始训练」CTA 行为不变。

## 2. 后端

- [x] 2.1 确认本变更不涉及后端接口、数据库 migration、DTO 或同步协议改动。

## 3. 基础设施 / 验证

- [x] 3.1 运行 OpenSpec 校验，确认 change artifact 可被解析。
- [x] 3.2 运行 iOS simulator build，确认 SwiftUI 与资产编译通过。
