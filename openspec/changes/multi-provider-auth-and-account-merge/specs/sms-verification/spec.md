## ADDED Requirements

### Requirement: 中国大陆手机号验证码发送

系统 SHALL 支持向中国大陆手机号发送短信验证码。服务端 MUST 将用户输入规范化为 `+86` E.164 格式，仅接受合法的 11 位大陆手机号；非法手机号 MUST 返回 400 且不调用短信供应商。发送接口 MUST 返回泛化结果，不暴露该手机号是否已注册或已绑定。

#### Scenario: 发送登录验证码
- **WHEN** 未登录用户提交合法中国大陆手机号请求登录验证码
- **THEN** 服务端创建短信 challenge，调用短信供应商向该手机号发送验证码，并返回 challengeId、过期时间与冷却信息

#### Scenario: 拒绝非大陆手机号
- **WHEN** 用户提交非 `+86` 手机号或格式非法手机号
- **THEN** 服务端返回 400
- **AND** 不创建 challenge
- **AND** 不调用短信供应商

#### Scenario: 不暴露注册状态
- **WHEN** 用户分别对已注册手机号和未注册手机号请求验证码
- **THEN** 服务端返回相同结构的泛化响应
- **AND** 响应不包含“已注册/未注册/已绑定其它账号”等枚举信息

### Requirement: 验证码安全存储与校验

系统 SHALL 只保存验证码 hash，不得保存验证码明文。验证码 challenge MUST 带 purpose（login/link/merge）、过期时间、消费时间和尝试次数。验证码过期、已消费或尝试次数超限时 MUST 拒绝验证。验证成功后 MUST 立即标记 consumed，防止重复使用。

#### Scenario: 验证成功后消费
- **WHEN** 用户在有效期内提交正确验证码
- **THEN** 服务端验证通过并标记该 challenge consumed
- **AND** 同一验证码再次提交时被拒绝

#### Scenario: 验证码过期
- **WHEN** 用户提交已超过有效期的验证码
- **THEN** 服务端拒绝验证
- **AND** 不登录、不绑定、不合并账号

#### Scenario: 尝试次数超限
- **WHEN** 同一 challenge 的错误验证码尝试次数达到上限
- **THEN** 服务端拒绝后续验证
- **AND** 用户必须重新请求验证码

### Requirement: 短信发送防刷与成本控制

系统 SHALL 在短信发送前执行多维限流，至少包含手机号、IP、设备、账号、手机号+IP 组合维度。系统 MUST 支持全局短信 kill switch 和每日预算上限；触发限流、预算或 kill switch 时 MUST 不调用短信供应商。

#### Scenario: 手机号冷却期内重复请求
- **WHEN** 同一手机号在冷却期内重复请求验证码
- **THEN** 服务端不重复发送短信
- **AND** 返回剩余冷却时间

#### Scenario: IP 维度超限
- **WHEN** 同一 IP 在短时间内请求过多不同手机号验证码
- **THEN** 服务端拒绝或延迟发送
- **AND** 不调用短信供应商

#### Scenario: 全局 kill switch 生效
- **WHEN** 运维关闭短信发送开关
- **THEN** 所有短信发送请求返回可重试错误
- **AND** 不调用短信供应商

### Requirement: 手机号盲索引与加密密文

系统 SHALL 使用 HMAC 盲索引查找手机号身份和执行唯一约束，并使用可逆加密密文保存完整手机号以支持必要的短信投递。完整手机号 MUST NOT 作为 `provider_user_id`、日志字段、错误响应或普通 API 响应明文返回。

#### Scenario: 创建手机号身份
- **WHEN** 手机号验证码验证成功且需要创建 phone identity
- **THEN** `user_identity.provider_user_id` 使用 `phone:<phone_lookup_hash>`
- **AND** 完整手机号以密文保存
- **AND** UI 展示仅使用脱敏手机号

#### Scenario: 日志脱敏
- **WHEN** 手机号验证码发送、验证、绑定或合并流程写日志
- **THEN** 日志只包含脱敏手机号或 phone_lookup_hash
- **AND** 不包含完整手机号或验证码明文
