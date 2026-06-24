## ADDED Requirements

### Requirement: 法律入口使用独立 URL

登录页与「我的 → 关于」分组中的「隐私政策」和「服务条款」入口 SHALL 使用独立配置项，并 MUST 指向不同 HTTPS URL。服务条款入口 MUST NOT 复用隐私政策 URL。若任一 URL 缺失或不可构造，DEBUG 构建 SHALL 明确暴露配置错误，Release 构建 MUST 使用已配置的线上 URL。

#### Scenario: 登录页服务条款打开独立页面
- **WHEN** 未登录用户点击登录页「服务条款」
- **THEN** App 打开 `termsOfServiceURL`
- **AND** 该 URL 不等于 `privacyPolicyURL`

#### Scenario: 关于页隐私政策打开隐私页面
- **WHEN** 已登录用户点击「我的 → 关于 → 隐私政策」
- **THEN** App 打开 `privacyPolicyURL`

#### Scenario: 关于页服务条款打开条款页面
- **WHEN** 已登录用户点击「我的 → 关于 → 服务条款」
- **THEN** App 打开 `termsOfServiceURL`
- **AND** 该 URL 不等于 `privacyPolicyURL`
