## 1. 后端：Team 分享与撤回

- [x] 1.1 [后端] 调整 checkin 请求 DTO，新增显式 `teamIds` 字段，缺失或为空时不得 fan-out 到所有 Team
- [x] 1.2 [后端] 修改 `CheckinController` / `CheckinService`，仅对请求中的 Team 执行 checkin upsert
- [x] 1.3 [后端] 为 checkin 分享增加 Team 成员校验，非成员目标返回 403
- [x] 1.4 [后端] 保持 `(team_id,user_id,workout_id)` 唯一语义与幂等键重试安全
- [x] 1.5 [后端] 新增按 `teamId + workoutId` 撤回 checkin 的 API，撤回时同步删除或隐藏 reaction
- [x] 1.6 [后端] 删除或拒绝旧 fan-out 入口的无目标 Team 调用，避免老路径继续默认公开
- [x] 1.7 [后端] 补充 Team 分享 API 单元/集成测试：默认不打卡、单 Team、多 Team、非成员拒绝、撤回不删个人训练
- [x] 1.8 [后端] 为 `team_member` 新增 `autoShareWorkouts` 偏好、当前用户查询/更新 API 与测试

## 2. iOS：训练完成分享流程

- [x] 2.1 [iOS] 将结束训练流程拆分为个人归档与 Team 分享两个阶段，归档后默认「仅自己可见」
- [x] 2.2 [iOS] 在 Team 详情增加“训练完成后自动分享”开关，首次开启需确认分享范围
- [x] 2.3 [iOS] 调整 `TeamService.checkIn` 请求模型，传递显式 `teamIds`，不再隐式 fan-out
- [x] 2.4 [iOS] 为离线/弱网下用户已开启自动分享的 Team 保存 pending share intent
- [x] 2.5 [iOS] 在网络恢复且 workout 同步成功后重试 pending share intent，并保证幂等键稳定
- [x] 2.6 [iOS] 在已完成训练或 Team feed 入口提供“撤回此 Team 可见性”操作
- [x] 2.7 [iOS] 撤回后刷新对应 Team feed，并保留其他 Team 的 checkin 与个人训练
- [x] 2.8 [iOS] 补充完成训练 UI/服务层测试或可执行手测脚本：默认不打卡、开启自动分享后打卡、关闭后不打卡、离线排队、撤回
- [x] 2.9 [iOS] 训练完成后读取已授权 Team 自动分享偏好；未开启任何 Team 时不弹强制分享 sheet

## 3. 共享计划跨版本兼容

- [x] 3.1 [iOS] 扩展 `PlanItem` JSON，新增 `exerciseName`、`primaryMuscle`、`equipmentType` fallback 字段
- [x] 3.2 [iOS] 新建/编辑/发布/Fork/复制计划时写入并保留动作快照字段
- [x] 3.3 [iOS] Team 计划展示与开始训练时，未知 `exerciseRef` 使用快照字段 fallback
- [x] 3.4 [iOS] 缺失快照且无法解析动作时展示计划数据损坏提示，并阻止直接开始训练
- [x] 3.5 [后端] Team 计划发布与 Fork 保持 items JSON 中的动作快照字段，不在 strip weights 时误删
- [x] 3.6 [后端/iOS] 增加跨版本 fixtures：包含未知 builtin code 但带快照的 Team 计划可展示、Fork、开始训练

## 4. 后端：账号删除与 Team owner 转移

- [x] 4.1 [后端] 修改账号删除事务：只删除删号用户自己的 checkin/reaction/member，不删除其他成员历史
- [x] 4.2 [后端] 实现 owner 删除账号时的 Team owner 转移策略，默认转给 `joined_at` 最早的剩余成员
- [x] 4.3 [后端] owner 删除账号且 Team 无其他成员时删除该空 Team
- [x] 4.4 [后端] 被删 owner 发布的 Team 计划从 Team 列表移除或匿名化处理，已 Fork 副本不受影响
- [x] 4.5 [后端] 更新 `GET /account/deletion-impact`，返回 owner 转移数、空 Team 删除数与本人数据影响摘要
- [x] 4.6 [后端] 确认独立解散 Team 流程仍保留强确认语义所需 API，不与账号删除混用
- [x] 4.7 [后端] 增加账号删除集成测试：owner 有成员时转移、owner 空 Team 删除、普通成员删号、事务失败回滚

## 5. iOS：删号影响面与 Team 接管提示

- [x] 5.1 [iOS] 更新删除账号确认文案：说明多人 Team 将保留并转移 owner，空 Team 将删除
- [x] 5.2 [iOS] 适配新的 deletion-impact 响应字段
- [x] 5.3 [iOS] 新 owner 首次进入被转移 Team 时展示接管提示，并保留解散/退出管理路径
- [x] 5.4 [iOS] 回归普通成员删号、owner 删号后其他成员 Team feed 保留

## 6. 同步时间偏移防护

- [x] 6.1 [后端] 在通用同步 push 服务中计算客户端 `updatedAt` 与服务端时间偏移
- [x] 6.2 [后端] 对明显未来时间戳进行校正或冲突返回，禁止持久化长期未来 `updated_at`
- [x] 6.3 [后端] 扩展同步 push 响应，返回 timestamp adjustment notice（实体 id、domain、校正后时间）
- [x] 6.4 [后端] 为 workout 聚合同步实现同等时间偏移防护
- [x] 6.5 [后端] 新增迁移或启动修复任务，clamp 既有明显未来 `updated_at`
- [x] 6.6 [iOS] 解析同步时间校正通知，更新本地实体时间并展示/记录冲突提示
- [x] 6.7 [后端/iOS] 增加测试：未来时钟、慢时钟、正常时间、多设备冲突、墓碑软删不丢

## 7. Live Activity / Watch 降级

- [x] 7.1 [iOS] 更新 Live Activity / Watch Smart Stack 文案与验收注释：Watch 为平台条件能力
- [x] 7.2 [iOS] 确认 iPhone 锁屏 Live Activity、本地通知、前台声音/震动在无 Watch 或不支持 watchOS 时完整可用
- [x] 7.3 [iOS] 如引入 Watch Smart Stack 自定义小尺寸布局，使用 `supplementalActivityFamilies` 并保证小尺寸文字不截断
- [x] 7.4 [验收] 拆分 5.3 真机验收：iPhone 必测；iOS 18 + watchOS 11+ Watch 条件测试

## 8. 发布合规与文档

- [x] 8.1 [基础设施] 新增 `backend/deploy/shared-infra/edge/site/dontlift/terms/index.html` 独立服务条款静态页
- [x] 8.2 [基础设施] 更新 Caddy 静态路由，确保 `/terms` HTTPS 可访问
- [x] 8.3 [iOS] 将 `AppConfig.termsOfServiceURL` 改为 `https://dontlift.peipadada.com/terms`
- [x] 8.4 [iOS] 增加 DEBUG 断言或测试，确保 `termsOfServiceURL != privacyPolicyURL`
- [x] 8.5 [文档] 更新 `docs/testflight-checklist.md`，把独立 `/terms` 页面作为外部 TestFlight / App Store 提交硬门禁
- [x] 8.6 [文档] 更新隐私政策，说明 Team 自动分享偏好、撤回、账号删除时多人 Team 历史保留边界
- [x] 8.7 [OpenSpec] 在 `meigei-mvp` proposal 或后续归档说明中标注 strict/adaptive、历史预填与回写已被后续规格 supersede

## 9. 综合回归

- [x] 9.1 [后端] 运行 `./gradlew test`，覆盖新增 Team 分享、账号删除、同步偏移测试
- [x] 9.2 [后端] 运行 `scripts/api-e2e.sh`，更新断言：训练完成不再自动 fan-out，Team 自动分享偏好默认关闭，checkin API 必须显式传 `teamIds`
- [x] 9.3 [iOS] 运行模拟器构建 `xcodebuild -project DontLift.xcodeproj -scheme DontLift -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build`
- [ ] 9.4 [真机] 验证 HealthKit、Live Activity、本地通知、Team 自动分享偏好与撤回
- [ ] 9.5 [真机/条件] 在 iOS 18 + watchOS 11+ 设备上验证 Watch Smart Stack；无匹配设备时记录为条件未测而非失败
- [ ] 9.6 [发布] 在外部 TestFlight 或 App Store 提交前逐项确认发布清单法律链接、隐私问卷、账号删除、Team 分享默认私有
