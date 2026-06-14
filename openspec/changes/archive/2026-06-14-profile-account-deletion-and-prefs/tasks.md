## 1. 后端 · 账号删除接口与级联硬删

- [x] 1.1 后端 · 新增删号接口骨架:`AccountController`(或扩展 `AuthController`)暴露 `DELETE /account`,JWT 鉴权(仅删自身)、携带幂等键,`SecurityConfig` 放行规则确认
- [x] 1.2 后端 · 实现 `AccountDeletionService.deleteSelf(userId)`,`@Transactional`,按 FK 拓扑先子后父逐表 DELETE(team 解散维度 + user 自身维度,见 design D1)
- [x] 1.3 后端 · 团主解散逻辑:收集 `ownedTeamIds`,删该 teams 的 reaction/checkin/member/team;成员维度按 `user_id` 删本人 reaction/checkin/member
- [x] 1.4 后端 · user 自身数据删除:workout(子树 CASCADE)/workout_plan/custom_exercise/device_token/idempotency_key/user_identity/app_user
- [x] 1.5 后端 · 各表 mapper 补显式删除方法(MyBatis-Plus 按 user_id / team_id 物理 delete)
- [x] 1.6 后端 · 幂等与边界:重复删除(user 已不存在)返回 2xx 空操作;事务异常整体回滚
- [x] 1.7 后端 · 错误经 `AppException` + `GlobalExceptionHandler` 转 ProblemDetail
- [x] 1.8 后端 · `AccountController` 增 `GET /account/deletion-impact`(返回 `ownedTeams` / `affectedMembers`,只读不改数据)

## 2. 后端 · Apple 凭据链路与主动撤销(决策 B)

- [x] 2.1 后端 · 新增迁移 `V2__add_apple_refresh_token.sql`(`user_identity` 加 `apple_refresh_token text` 可空列);`UserIdentity` 实体加字段
- [x] 2.2 后端 · `AppleLoginRequest` 加可选 `authorizationCode`;新增 client_secret 签发组件(`.p8` / Key ID / Team ID,ES256 JWT,`aud=appleid.apple.com`,复用 nimbus-jose-jwt)
- [x] 2.3 后端 · 登录时若有 `authorizationCode` + 凭据,调 Apple `POST /auth/token` 换 `refresh_token` 持久化到 `user_identity`;无 code/无凭据则跳过、不阻断登录;`refresh_token` 不入日志
- [x] 2.4 后端 · 删号 service 用 `refresh_token` + client_secret 调 Apple `POST /auth/revoke` 真正撤销授权
- [x] 2.5 后端 · 降级:无 `.p8` 或该 user 无 `refresh_token` 时记 `warn`、跳过 revoke、不阻断删除主流程
- [x] 2.6 后端 · 与 `handleRevokeNotification`/`revokeBySub` 对齐:已主动删除的 user 再收 S2S `account-delete` 通知为幂等空操作

## 3. 后端 · 测试

- [x] 3.1 后端 · 单测:团主删号后该 team 及全部成员关系/打卡/表情清零;普通成员删号不影响团队
- [x] 3.2 后端 · 单测:删号后该 user 在所有表无残留;事务失败回滚
- [x] 3.3 后端 · 单测:revoke 凭据缺失时降级仍完成删除并返回 2xx
- [x] 3.4 后端 · 单测:登录回传 code 持久化 refresh_token;删号触发 revoke 调用(mock Apple);`deletion-impact` 计数正确

## 4. iOS · 删除账号入口与流程

- [x] 4.1 iOS · `ProfileView` 新增「账号」分组:含「退出登录」(迁入)与「删除账号」(danger 红字)
- [x] 4.2 iOS · 「删除账号」点击弹 `paperConfirmDialog`,文案强调账号与全部数据永久删除、不可恢复
- [x] 4.3 iOS · 网络层新增删号调用 `DELETE /account`(带幂等键)
- [x] 4.4 iOS · 删号成功:清空本地 SwiftData store + 清 Keychain JWT + `SessionStore.logout()` → 回 LoginView
- [x] 4.5 iOS · 删号进行中加载态、禁重复;失败保留现场 + 错误提示 + 可重试
- [x] 4.6 iOS · `AuthService.swift` 登录回传 `credential.authorizationCode`(`AppleLoginRequest` 加字段)
- [x] 4.7 iOS · 删号前调 `GET /account/deletion-impact`,二次确认框展示「将解散 N 个团队、影响 M 名成员」

## 5. iOS · 隐私政策 / 服务条款链接

- [x] 5.1 iOS · `AppConfig` 收敛隐私政策 / 服务条款 URL 为单一配置项
- [x] 5.2 iOS · 封装 `SFSafariViewController`(SwiftUI 包装),供登录页与我的页共用
- [x] 5.3 iOS · `ProfileView`「关于」组新增「隐私政策」「服务条款」两行,点击打开对应页面
- [x] 5.4 iOS · 修 `LoginView.swift:113/116` 两个占位按钮 → 接通真实页面

## 6. iOS · 训练偏好分组

- [x] 6.1 iOS · `ProfileView` 新增「训练偏好」分组(`groupCard`)
- [x] 6.2 iOS · 默认休息时长行:stepper/picker 读写 `RestTimer.defaultDuration`(UserDefaults),即时落盘
- [x] 6.3 iOS · 震动开关行:读写 `RestTimer.hapticsEnabled`
- [x] 6.4 iOS · 通知行:展示系统授权态 + 点击 `openSettingsURLString` 跳系统设置

## 7. iOS · HealthKit 授权交互

- [x] 7.1 iOS · 将「数据 · 同步」组 HealthKit 行由纯展示改为可点击发起授权(复用 `HealthKitManager.requestAuthorization`)
- [x] 7.2 iOS · 授权后实时刷新行 value(已连接 / 未授权)与配色

## 8. 验证与收尾

- [x] 8.1 后端 · `./gradlew test` 通过;手测删号接口(dev token)级联清零
- [x] 8.2 iOS · `xcodebuild` 编译通过;模拟器走查删号确认流 / 隐私链接 / 偏好读写 / HealthKit 授权
- [x] 8.3 文档 · 更新 TestFlight 上架清单(删除账号、隐私/条款可达已补齐),`openspec validate` 通过
