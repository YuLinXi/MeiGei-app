## MODIFIED Requirements

### Requirement: 个人中心顶部 Profile Header

`ProfileView` SHALL 在「我的」tab 顶部渲染 ProfileHeader：左侧 64×64pt 圆形头像（首字母 + 主色调朱砂红底），右侧两行—大字 `Theme.Font.display(22, .bold)` 称呼 + `Theme.Font.mono` muted 小字副标。

**称呼纯展示、不在顶部编辑**：顶部称呼只展示，编辑统一进「个人资料」分组（见「用户资料编辑分组」）。

**副标内容**：副标 SHALL 显示「加入于 {createdAt:yyyy.MM} · 已记录 {总训练次数} 次」，不再展示训练龄 / 训练年限（该字段已不采集）。`createdAt` 缺失时退化为「已记录 {n} 次」。

#### Scenario: 渲染头像与副标
- **WHEN** 用户进入「我的」页且本地有 `UserProfile`
- **THEN** 渲染头像 + 称呼 + 副标「加入于 {月份} · 已记录 {n} 次」。

#### Scenario: 顶部称呼不可编辑
- **WHEN** 用户点击顶部 ProfileHeader 的称呼
- **THEN** 不进入编辑（顶部仅展示）；编辑入口在「个人资料」分组内。

## ADDED Requirements

### Requirement: 用户资料编辑分组

ProfileView SHALL 在「我的」页统计网格之下、其它设置分组之上渲染「个人资料」分组（`groupCard` + 行式布局），含称呼与性别两行，二者均为**用户资料**，编辑即乐观本地写并 `PATCH /account/profile`（非纯本地偏好）：

- **称呼**：默认展示当前称呼 + chevron；点击该行 → **行内展开输入框**（聚焦态朱砂红描边）+「保存 / 取消」；约束去空白 1–20 字，非法时保存禁用并提示；保存即乐观本地写 + PATCH。
- **性别**：行内两枚 `male` / `female` 胶囊（朱砂红选中态），点击切换；切换 SHALL 同时驱动肌群高亮图底图并 PATCH 回后端。语义由旧版「纯本地偏好（仅切图）」升级为「资料 + 顺带切图」单一字段，原「偏好」分组移除。

#### Scenario: 称呼行内编辑保存
- **WHEN** 用户点击称呼行、改为合法值并点「保存」
- **THEN** 行内编辑收起、展示新称呼，本地即时更新并 `PATCH /account/profile`；称呼空或超 20 字时「保存」禁用。

#### Scenario: 取消称呼编辑
- **WHEN** 用户在称呼编辑态点「取消」
- **THEN** 收起编辑、丢弃草稿，称呼不变、无网络请求。

#### Scenario: 切换性别即时切图并上行
- **WHEN** 用户在个人资料分组切换性别
- **THEN** 本地 `UserProfile.sex` 即时更新、肌群图随之切换，并异步 `PATCH /account/profile`（失败静默重试）。

### Requirement: 登录后首登补全页路由

`RootView` SHALL 在 `SessionStore.isLoggedIn` 为真后，依据后端画像称呼是否为空决定路由：称呼为空 → 全屏首登补全页（覆盖主 App，不可绕过）；称呼非空 → `MainTabView`；门控信号尚未拉取（nil）时渲染纸白加载态并触发 `GET /me`。补全页提交成功后 SHALL 自动转入 `MainTabView`。该判定以 `GET /me` 结果为准，不以 `AuthResponse.newUser` 为唯一信号。

#### Scenario: 称呼为空展示补全页
- **WHEN** 登录后画像称呼为空
- **THEN** `RootView` 渲染全屏补全页，`MainTabView` 不可见。

#### Scenario: 冷启动拉取画像期间加载态
- **WHEN** 冷启动已登录但门控信号尚未就绪
- **THEN** 渲染纸白加载态并拉 `GET /me`，据结果再路由到补全页或主界面。

#### Scenario: 补全成功进入主界面
- **WHEN** 用户在补全页成功提交
- **THEN** `RootView` 切换为 `MainTabView`，并触发既有的注册推送与 `syncAll`。

#### Scenario: 已补全直接进主界面
- **WHEN** 登录后画像称呼非空
- **THEN** 跳过补全页，直接渲染 `MainTabView`。
