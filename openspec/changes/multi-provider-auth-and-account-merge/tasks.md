## 1. 后端数据模型与迁移

- [ ] 1.1 [后端] 新增 Flyway 迁移：放宽 `user_identity.provider` 约束为 `apple/wechat/phone`，增加同一 `user_id + provider` 活跃唯一约束。
- [ ] 1.2 [后端] 新增手机号身份表：保存 `phone_lookup_hash`、手机号密文、尾号、国家码、密钥版本与 verified_at。
- [ ] 1.3 [后端] 新增短信 challenge 表：purpose、phone_lookup_hash、code_hash、过期时间、消费时间、尝试次数、IP/设备 hash。
- [ ] 1.4 [后端] 新增账号合并审计/临时 token 所需表或字段，支持 source/target、provider、过期时间、trace 记录。
- [ ] 1.5 [后端] 为 `app_user` 或认证层增加账号活跃性/会话失效所需字段或查询，保证删除/合并后的旧 JWT 被拒。

## 2. 后端多 Provider 登录与绑定

- [ ] 2.1 [后端] 抽象 provider 身份解析模型，统一返回 provider、providerUserId、显示摘要和可选凭据。
- [ ] 2.2 [后端] 保持 Apple 登录兼容，并将“仅 Apple”逻辑调整为多 provider 共用建号/复用流程。
- [ ] 2.3 [后端] 实现微信登录接口：接收 iOS code，后端调用微信接口换取 `openid/unionid`，以 unionid 创建或复用身份。
- [ ] 2.4 [后端] 实现手机号登录接口：校验短信 challenge，通过 phone_lookup_hash 创建或复用 phone identity。
- [ ] 2.5 [后端] 实现已登录身份绑定接口：未占用则绑定，已属当前账号则幂等成功，属于其它账号则返回 merge preview。
- [ ] 2.6 [后端] 调整 Apple S2S 撤销：多身份账号仅解绑 Apple；最后一个身份时才注销/删除或标记不可登录。
- [ ] 2.7 [后端] 更新 `JwtAuthFilter` 或认证服务，JWT 解析后校验 `app_user` 存在、未删除、未合并且未早于失效时间。

## 3. 后端短信验证码与手机号安全

- [ ] 3.1 [后端] 实现手机号规范化与校验，仅接受中国大陆 `+86` 手机号。
- [ ] 3.2 [后端] 实现 phone_lookup_hash 计算与手机号 AES-GCM/KMS 加密解密，支持 key_version。
- [ ] 3.3 [后端] 实现短信验证码生成、hash 存储、过期、消费、尝试次数限制。
- [ ] 3.4 [后端] 实现短信发送限流：手机号、IP、设备、账号、手机号+IP 组合维度。
- [ ] 3.5 [后端] 接入短信供应商接口与 mock provider，支持全局 kill switch、每日预算和供应商失败降级。
- [ ] 3.6 [后端] 确保手机号、验证码、微信 token、Apple refresh token 不进入日志、ProblemDetail 或 Sentry 明文。

## 4. 后端账号合并

- [ ] 4.1 [后端] 实现 mergeToken 生成与校验，绑定 targetUserId、sourceUserId、provider、过期时间和当前 JWT。
- [ ] 4.2 [后端] 实现合并预览接口/响应，返回 source 与 target 的安全摘要，不泄露完整手机号或外部 provider 原始 ID。
- [ ] 4.3 [后端] 实现合并冲突检测：同 provider 不同活跃身份时阻断并返回可解释错误。
- [ ] 4.4 [后端] 实现单事务合并迁移：身份、手机号详情、设备 token、幂等缓存、训练/计划/自定义动作、Team 数据、计划分享事件。
- [ ] 4.5 [后端] 实现 source 账号失效：合并后 source 旧 JWT 返回 401，target 当前会话继续有效或获得新 JWT。
- [ ] 4.6 [后端] 扩展账号删除服务，覆盖微信、手机号密文/盲索引、短信 challenge、合并临时凭据和多 provider 身份。

## 5. iOS 微信与手机号登录

- [ ] 5.1 [iOS] 配置 WeChat Open SDK、URL Scheme、LSApplicationQueriesSchemes、Associated Domains 和 Universal Links 回调。
- [ ] 5.2 [iOS] 实现微信登录服务：检测微信安装、发起 `SendAuthReq`、校验 state、接收 code 并提交后端。
- [ ] 5.3 [iOS] 改造登录页：微信可用时作为主入口，Apple 与手机号为备用；微信不可用时隐藏微信入口。
- [ ] 5.4 [iOS] 实现手机号输入页、验证码页、冷却倒计时、重新发送、错误展示与登录成功会话写入。
- [ ] 5.5 [iOS] 将本地 `UserProfile` 中 Apple 专属字段去通用化，身份列表改由服务端账号安全接口返回。

## 6. iOS 账号安全与合并体验

- [ ] 6.1 [iOS] 在「我的」账号分组新增账号安全入口，展示微信、Apple、手机号绑定状态和脱敏摘要。
- [ ] 6.2 [iOS] 实现 Apple、微信、手机号绑定流程，复用各 provider 凭证获取逻辑。
- [ ] 6.3 [iOS] 实现合并预览确认页，清楚展示 target/source 摘要、合并后果和取消路径。
- [ ] 6.4 [iOS] 合并成功后刷新身份列表与画像，清理 source 相关本地缓存并重置所有同步水位。
- [ ] 6.5 [iOS] 任一鉴权接口返回 401 时保持既有登出兜底，避免 source 旧 token 幽灵态。

## 7. 基础设施与配置

- [ ] 7.1 [基础设施] 增加微信 `AppID/AppSecret`、Universal Link、短信供应商、短信模板、HMAC pepper、手机号加密密钥配置项。
- [ ] 7.2 [基础设施] 增加微信、手机号登录和账号合并 feature flag，支持按环境关闭。
- [ ] 7.3 [基础设施] 准备微信开放平台移动应用注册/审核清单：Bundle ID、Universal Links、隐私合规、微信登录能力申请。
- [ ] 7.4 [基础设施] 准备短信供应商签名与模板审核清单，明确测试环境 mock 与生产限额。

## 8. 验证

- [ ] 8.1 [后端] 添加多 provider 登录、绑定、Apple 撤销、多身份删号和 JWT 活跃性校验单元/集成测试。
- [ ] 8.2 [后端] 添加短信验证码过期、消费、尝试次数、限流、kill switch、日志脱敏测试。
- [ ] 8.3 [后端] 添加账号合并事务测试，覆盖训练/计划/Team/设备 token/幂等键迁移与冲突回滚。
- [ ] 8.4 [iOS] 添加登录页状态、手机号验证码、账号安全、合并确认流程的 UI/逻辑测试。
- [ ] 8.5 [验证] 运行后端 `./gradlew test` 与 `./gradlew build`。
- [ ] 8.6 [验证] 运行 iOS `xcodebuild -project DontLift.xcodeproj -scheme DontLift -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build`。
- [ ] 8.7 [人工] 真机验证微信 SDK 拉起/回调、Universal Links、自检函数、手机号短信发送与 TestFlight 登录回归。
