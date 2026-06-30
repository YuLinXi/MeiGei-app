## Why

当前账号体系只支持 Apple Sign-In，国内用户登录转化、账号恢复和跨设备绑定都受限。需要在保留既有 Apple 用户数据的前提下，新增微信优先登录、手机号短信登录和可验证的一键账号合并，避免用户因换登录方式丢失训练、计划和 Team 数据。

## What Changes

- 登录方式从“仅 Apple”扩展为微信、Apple、手机号三种；iOS 登录页首推微信，微信不可用时回退 Apple 与手机号。
- 微信登录使用 iOS 原生 WeChat Open SDK，客户端只取得临时 `code`，后端用 `AppID/AppSecret` 换取 `openid/unionid`，以 `unionid` 优先作为微信身份唯一标识。
- 手机号登录仅支持中国大陆 `+86` 手机号，使用短信验证码完成登录、绑定和合并验证。
- 手机号不以明文作为身份主键；服务端使用 HMAC 盲索引做唯一查找，并用可逆加密密文满足短信投递与账号展示需求。
- 已登录用户可在账号安全入口绑定微信、Apple 或手机号；未绑定身份可直接挂到当前 `app_user`。
- 支持一键账号合并：当新验证身份已属于另一个账号时，用户确认后将 source 账号的数据和身份迁移到当前 target 账号。
- Apple 授权撤销语义调整为多身份安全：撤销 Apple 授权时优先解绑 Apple 身份；仅在无其它可登录身份时才进入注销/删除兜底。
- 新增短信验证码风控：手机号、IP、设备、账号和组合维度限流，验证码短期有效、尝试次数限制、成功后立即消费。
- 合并后使 source 账号旧 JWT 失效，客户端清理本地同步水位并重新拉取 target 账号数据。

## Non-goals

- 不支持中国大陆以外手机号、邮箱登录、游客登录或密码登录。
- 不实现微信扫码登录、Web 微信登录、小程序登录或 Android 微信接入。
- 不把手机号明文作为 `provider_user_id` 或日志字段；完整手机号不得明文落日志。
- 不做未经双重验证的自动账号合并；不得仅凭手机号、微信昵称、头像或 Apple 邮箱猜测同一人。
- 不做跨账号训练记录字段级去重或智能合并；迁移采用账号级归属转移和唯一约束下的确定性处理。
- 不建设后台客服人工改绑系统；本 change 只覆盖用户自助登录、绑定、合并、删除。

## Capabilities

### New Capabilities
- `sms-verification`: 覆盖中国大陆手机号短信验证码发送、验证、限流、验证码存储和短信供应商降级行为。
- `account-merge`: 覆盖已验证账号的一键合并、数据迁移、旧会话失效和客户端同步重置。

### Modified Capabilities
- `account-sync`: 从仅 Apple 登录扩展为微信、Apple、手机号多 provider 身份模型，并调整 Apple 撤销、多身份绑定和 JWT 有效性要求。
- `profile-ui`: 登录页入口优先级、手机号登录页、账号安全/身份绑定与合并确认交互发生变化。
- `account-deletion`: 账号删除范围扩展到微信、手机号身份、手机号密文、短信相关临时数据与合并残留。
- `sync-reliability`: 账号合并后客户端必须重置本地同步水位并按 target 账号重新收敛。

## Impact

- 后端：`auth`、`account`、`security`、`idempotency` 相关接口与服务；Flyway 迁移新增/调整 `user_identity` provider 约束、手机号密文/索引、短信 challenge、账号合并记录和旧会话失效机制。
- iOS：`LoginView`、`AuthService`、`SessionStore`、`UserProfile`、账号页设置入口、微信 SDK 接入、手机号验证码页面和合并确认流程。
- 外部依赖：微信开放平台移动应用、WeChat Open SDK、微信 `AppID/AppSecret`、短信供应商、手机号加密密钥/HMAC pepper、可选 App Attest / DeviceCheck 风控信号。
- 运维配置：新增微信、短信、手机号加密、短信限流与 kill switch 相关环境变量；生产日志必须脱敏手机号和验证码。
