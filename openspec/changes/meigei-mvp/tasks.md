## 1. 项目脚手架与基础设施

- [x] 1.1 [后端] 初始化 Spring Boot 3.3 + Java 21 + Gradle(Kotlin DSL) 项目，集成 MyBatis-Plus、Lombok、MapStruct、SpringDoc
- [x] 1.2 [后端] 接入 PostgreSQL 16 + Flyway，建立基线迁移与 MyBatis-Plus 配置（UUID v7 主键、客户端可预生成、逻辑删除 @TableLogic、乐观锁 @Version、自动填充 createTime/updateTime）
- [x] 1.3 [基础设施] 编写多阶段 Dockerfile，配置本地 docker-compose（app + postgres）
- [x] 1.4 [基础设施] 配置部署平台（Fly.io/Railway，选不休眠实例）、Sentry、Cloudflare（仓库内：fly.toml 不休眠 + Sentry 接入已写；实际开通账号/DSN/DNS 待用户侧执行）
- [x] 1.5 [iOS] 创建 SwiftUI 工程（最低 iOS 17.4），配置 Sign in with Apple、HealthKit、ActivityKit、Push capability
- [x] 1.6 [iOS] 搭建本地 SwiftData 数据层骨架（统一同步字段 serverId/localId/updatedAt/deletedAt/version + syncStatus），明确不开启 CloudKit 自动同步

## 2. 账户与同步基础（account-sync）

- [x] 2.1 [后端] 设计身份三层表：user / user_identity(provider, provider_user_id, email)，业务表外键指向 user.id
- [x] 2.2 [后端] 实现 Apple identityToken 校验（nimbus-jose-jwt + JWKS 缓存），首登建账户、老用户复用，签发自有 JWT
- [x] 2.3 [后端] 实现 Apple 授权撤销回调端点（验签 + 注销会话 + 删除/匿名化数据）
- [x] 2.4 [后端] 实现幂等键中间件（Idempotency-Key → 结果映射），覆盖所有写接口
- [x] 2.5 [后端] 设计通用同步协议：基于 updatedAt 的增量拉取 + 批量上传 + last-write-wins 冲突标记（AbstractSyncService 骨架；具体实体子类在训练任务实现）
- [x] 2.6 [后端] 接入 Pushy（APNs .p8 token 认证），实现设备 token 注册与推送下发
- [x] 2.7 [iOS] 实现 Apple 登录流程与会话管理，本地持久化用户与首登邮箱
- [x] 2.8 [iOS] 实现离线优先同步引擎：本地先写、syncStatus 标记、后台同步、失败重试队列、冲突人工提示
- [x] 2.9 [iOS] 注册 APNs，处理打卡/表情回应推送

## 3. 训练模块（workout-tracking）

- [ ] 3.1 [数据] 整理 150-200 个内置动作（名称/主要肌群/器械类型）与部位高亮图资源
  - [x] 动作清单：`BuiltinExercise.starter` 已扩至 153 个（8 肌群 × 6 器械类型，code 唯一、取值对齐枚举，编译通过）
  - [ ] 部位高亮图资源：图形素材待设计侧补齐（不阻塞动作浏览/筛选/记录）
- [x] 3.2 [后端] 设计训练表：workout_plan(items jsonb，每项含稳定 itemId) / workout / workout_set，及自定义动作表
- [x] 3.3 [后端] 实现训练计划模板与训练记录的 CRUD + 同步接口
- [x] 3.4 [iOS] 动作库浏览/按肌群筛选/搜索 + 自定义动作创建
- [x] 3.5 [iOS] 单次训练计划模板的创建与编辑（动作项带 itemId）
- [x] 3.6 [iOS] 训练记录界面：按动作记录组数/重量/次数 + 完成标记 + 单组备注（不自动预填重量）
- [x] 3.7 [iOS] 组间休息计时器：前台/后台/锁屏持续，结束提醒
- [x] 3.8 [iOS] Live Activity（锁屏/灵动岛显示剩余时间与下个动作）+ 配对 Watch Smart Stack 呈现 + 「提前结束休息」App Intent
- [x] 3.9 [iOS] 训练日历 + 单动作历史曲线（Swift Charts，默认重量趋势）
- [x] 3.10 [iOS] PR 自动识别与庆祝提示（由原始记录重算，不存冗余统计）
- [x] 3.11 [iOS] 训练完成写入 HealthKit（力量训练 Workout，含授权流程）

## 4. Team 模块（team-sharing）

- [x] 4.1 [后端] 设计 Team 相关表：team / team_member(角色 Owner|Member) / 邀请码 / 打卡 / 表情回应；约束 ≤10 人、用户 ≤3 Team
- [x] 4.2 [后端] 实现 Team 创建、邀请码加入（含上限校验）、成员管理、退出/解散
- [x] 4.3 [后端] 实现计划模板发布到 Team（全员可见）与 Fork（复制 jsonb + forked_from 软指针，原模板增删不影响副本）
- [x] 4.4 [后端] 实现训练即打卡（保存训练自动生成当日打卡）、Team 内训练数据可见、表情回应；事件触发 APNs 推送
- [x] 4.5 [iOS] Team 空间界面：创建/加入、成员列表、当日打卡列表（摘要 + 点击看每组详情）
- [x] 4.6 [iOS] Team 内浏览计划模板 + Fork 到个人
- [x] 4.7 [iOS] 4 个 emoji 表情回应交互（发送 + 展示 + 推送提醒）
- [x] 4.8 [iOS] 训练完成生成分享海报（客户端本地渲染，服务端只给结构化数据）

## 5. 联调与验收

> 决策（2026-05-31）：纯后端可脚本化链路由 `scripts/api-e2e.sh` 自动覆盖，验收基线见 `docs/acceptance-checklist.md`。需人盯 UI / 真机能力 / Apple 凭据的部分**不再维护人工 checklist**，留待真机/凭据到位后直接验。模拟器联调脚本 `scripts/ios-sim-dev.sh` 保留为联调辅助。

- [ ] 5.1 端到端联调：登录 → 离线记录 → 同步 → Team 打卡 → 推送 → 表情回应
  - [x] 服务端链路自动化：`scripts/api-e2e.sh` 双用户跑通 登录→同步(push/pull)→建团/加入→打卡 fan-out→表情（真库断言全过）
  - [ ] iOS App 内真实交互 + 真实 Apple 登录 / APNs 投递：硬阻塞，需真机 + Apple 凭据
- [ ] 5.2 弱网/离线/多设备冲突场景验证（幂等、last-write-wins、人工提示）
  - [x] 服务端正确性自动化：`scripts/api-e2e.sh` 断言 幂等(serverTime 重放一致)/LWW 冲突回传 serverValue/较新覆盖
  - [ ] iOS 端时序与冲突提示 UI：待真机/多设备实测
- [ ] 5.3 HealthKit、Live Activity、Watch Smart Stack 真机验证
  - [ ] 硬阻塞（真机 + 签名），待用户侧真机执行
- [ ] 5.4 TestFlight 灰度发布与回归
  - [ ] 硬阻塞（Apple Developer 账号 + 发布签名 + 生产部署），待用户侧执行
