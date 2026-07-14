## 1. 后端

- [x] 1.1 扩展 `POST /checkins` 请求并让 `CheckinService` 仅在首次创建且未静默时通知其他成员
- [x] 1.2 补充当日通知、跨日静默、已有 checkin 更新和旧请求兼容的单元测试

## 2. iOS 端

- [x] 2.1 为 `CheckInRequest` 增加静默字段，并在即时发送和 pending 重放的实际发送时按本地日期计算
- [x] 2.2 补充同一自然日不静默、前一自然日静默的单元测试

## 3. 基础设施与验证

- [x] 3.1 运行后端 `CheckinServiceTest` 和完整测试
- [x] 3.2 运行 iOS 单元测试和无签名 Simulator build
- [x] 3.3 校验 OpenSpec change 并确认没有数据库迁移或无关改动
