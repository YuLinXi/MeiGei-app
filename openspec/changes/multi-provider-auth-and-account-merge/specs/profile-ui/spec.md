## MODIFIED Requirements

### Requirement: 登录页视觉规范

`LoginView` SHALL 全屏纸白底（`Theme.Color.bg`），以大面积留白 + 极简排版呈现，MUST NOT 使用赛博网格、radial gradient 或 scanline 背景。顶部区域 SHALL 渲染品牌标识：方形「M」标记 + `Theme.Font.mono` 小字品牌识别。中部/下部 SHALL 渲染既有品牌大标题与说明副标。底部登录区 SHALL 首推微信登录；当设备未安装微信或微信 SDK 不可用时，微信入口 MUST 隐藏或降级，Apple 登录成为主入口。Apple 登录与手机号登录 SHALL 作为备用入口展示。法律提示中的「服务条款」与「隐私政策」SHALL 为可点击控件，点击经 `SFSafariViewController` 打开与「我的 / 关于」组相同的后端页面 URL。DevConfig 启用时 SHALL 渲染开发者快捷登录入口。

#### Scenario: 已安装微信的首次启动
- **WHEN** App 启动且 `SessionStore.isSignedIn == false`，并且检测到微信可用
- **THEN** 登录页渲染微信主按钮
- **AND** 渲染 Apple 与手机号备用入口

#### Scenario: 未安装微信的首次启动
- **WHEN** App 启动且未检测到微信客户端或微信 SDK 不可用
- **THEN** 登录页不展示不可用的微信登录按钮
- **AND** Apple 登录与手机号登录仍可用

#### Scenario: 登录中
- **WHEN** 任一登录请求正在进行
- **THEN** 对应入口显示加载态并禁止重复点击

#### Scenario: 登录失败
- **WHEN** 微信、Apple 或手机号登录返回错误（用户取消除外）
- **THEN** 登录区下方显示 1 行红色错误文字 `Theme.Color.danger`，文本来自服务端错误或本地兜底「登录失败，请重试」

#### Scenario: 点击法律链接打开页面
- **WHEN** 用户点击登录页法律提示中的「服务条款」或「隐私政策」
- **THEN** 经 `SFSafariViewController` 打开对应页面，且不中断登录流程

## ADDED Requirements

### Requirement: 手机号验证码登录页

客户端 SHALL 提供手机号验证码登录流程。手机号输入页 MUST 明确仅支持中国大陆手机号，提交后进入验证码输入页。验证码页 SHALL 展示脱敏手机号、倒计时、重新发送入口、错误提示和返回修改手机号入口。验证码登录成功后复用既有 `SessionStore.handleLogin` 会话写入与首登补全路由。

#### Scenario: 请求手机号验证码
- **WHEN** 未登录用户输入合法大陆手机号并点击获取验证码
- **THEN** 客户端调用短信验证码发送接口
- **AND** 进入验证码输入页并展示倒计时

#### Scenario: 验证码登录成功
- **WHEN** 用户输入正确验证码
- **THEN** 客户端调用手机号登录接口
- **AND** 成功后写入 JWT 与当前 userId
- **AND** 继续执行首登补全判断

#### Scenario: 重新发送冷却中
- **WHEN** 验证码仍在冷却期
- **THEN** 重新发送入口禁用并显示剩余秒数

### Requirement: 账号安全身份绑定

`ProfileView` SHALL 在「账号」分组或独立「账号安全」页面中展示当前账号已绑定的登录方式摘要：微信、Apple、手机号。每个身份只展示脱敏摘要和绑定状态，不展示完整手机号、Apple sub、微信 unionid。用户 SHALL 能从该入口发起绑定未绑定的 provider。

#### Scenario: 展示已绑定手机号
- **WHEN** 当前账号已绑定手机号
- **THEN** UI 展示脱敏手机号，例如 `138****5678`
- **AND** 不展示完整手机号

#### Scenario: 发起微信绑定
- **WHEN** 用户在账号安全页点击绑定微信
- **THEN** 客户端发起微信授权
- **AND** 将返回 code 提交到身份绑定接口

#### Scenario: 发起手机号绑定
- **WHEN** 用户在账号安全页点击绑定手机号
- **THEN** 客户端进入手机号验证码绑定流程

### Requirement: 账号合并确认交互

当身份绑定接口返回账号合并预览时，客户端 SHALL 展示强确认界面。确认界面 MUST 明确说明：当前账号将作为合并目标，另一个账号的训练、计划、Team 数据和登录方式将迁入当前账号，合并后另一个账号将无法再单独登录。用户确认后才调用合并接口。

#### Scenario: 展示合并预览
- **WHEN** 用户绑定的身份属于另一个账号，服务端返回 merge preview
- **THEN** 客户端展示 source 与 target 的摘要信息
- **AND** 展示合并后果说明和「确认合并 / 取消」操作

#### Scenario: 确认合并
- **WHEN** 用户在合并确认页点击确认合并
- **THEN** 客户端携带 mergeToken 和 Idempotency-Key 调用合并接口
- **AND** 成功后刷新当前账号资料与身份列表
- **AND** 重置同步水位并触发全量收敛

#### Scenario: 取消合并
- **WHEN** 用户在合并确认页点击取消
- **THEN** 客户端不调用合并接口
- **AND** 当前账号数据保持不变
