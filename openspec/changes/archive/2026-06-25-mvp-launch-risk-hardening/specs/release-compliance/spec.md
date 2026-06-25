## ADDED Requirements

### Requirement: 独立法律文档页面

系统 SHALL 提供可公开访问的独立隐私政策页面与服务条款页面。隐私政策 URL 与服务条款 URL MUST 为不同路径，服务条款入口 MUST NOT 指向隐私政策页面。两者均 SHALL 使用 HTTPS，并可在未登录状态下访问。

#### Scenario: 服务条款不复用隐私政策
- **WHEN** 用户打开 App 内「服务条款」
- **THEN** 系统打开独立服务条款页面
- **AND** 该 URL 不等于隐私政策 URL

#### Scenario: 未登录可访问法律页面
- **WHEN** 未登录用户在登录页点击「隐私政策」或「服务条款」
- **THEN** 系统经 App 内浏览器打开对应 HTTPS 页面

### Requirement: 发布前法律链接门禁

系统 SHALL 将“隐私政策与服务条款均已上线且 App 内可达”列为外部 TestFlight 与 App Store 提交前的硬性门禁。发布清单 MUST 明确检查 App Store Connect 隐私政策 URL、App 内隐私政策入口、App 内服务条款入口，以及服务条款页面不再复用 `/privacy`。

#### Scenario: 服务条款缺失阻止发布
- **WHEN** `termsOfServiceURL` 仍指向隐私政策页面或服务条款页面不可访问
- **THEN** 发布清单状态保持未完成，团队不得提交外部 TestFlight 或 App Store 审核

#### Scenario: 法律链接齐备
- **WHEN** 隐私政策与服务条款均为独立 HTTPS 页面，且登录页与关于页均可打开
- **THEN** 发布清单可将法律链接门禁标记为完成

### Requirement: 隐私政策披露 Team 分享与删除语义

隐私政策 SHALL 披露训练数据在 Team 分享中的用途、用户开启 Team 自动分享或主动分享后的可见范围、撤回方式，以及账号删除时个人数据与多人 Team 历史的处理边界。若 Team 分享默认仅自己可见，隐私政策 MUST 与产品行为保持一致。

#### Scenario: 隐私政策说明 Team 可见性
- **WHEN** 用户查看隐私政策
- **THEN** 页面说明训练数据仅在用户开启对应 Team 自动分享或主动分享后对对应 Team 成员可见

#### Scenario: 隐私政策说明删除边界
- **WHEN** 用户查看账号删除说明
- **THEN** 页面说明删除账号会删除本人数据，但不会默认删除其他成员在多人 Team 中贡献的历史
