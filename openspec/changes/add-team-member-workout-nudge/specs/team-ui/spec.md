## ADDED Requirements

### Requirement: 拍一拍队友入口

`TeamDetailView` SHALL 允许用户点击 cover 卡中的“今日已练”进度 pill 或整个成员头像栈打开成员拍一拍 sheet。两个入口的可点击区域 SHALL 至少为 44pt；重叠的小头像 MUST NOT 各自承担独立点击操作。sheet SHALL 使用系统 drag indicator 与下滑手势关闭，MUST NOT 展示额外标题、Team 名小文案或右上角关闭按钮。

#### Scenario: 点击今日进度
- **WHEN** 用户点击“3 / 6 今日已练”进度 pill
- **THEN** 页面打开当前 Team 的“拍一拍队友” sheet

#### Scenario: 点击头像栈空隙或头像
- **WHEN** 用户点击成员头像栈的整体区域
- **THEN** 页面打开同一个“拍一拍队友” sheet
- **AND** 系统不要求用户准确命中某个重叠小头像

#### Scenario: 下滑关闭 sheet
- **WHEN** 用户查看“拍一拍队友” sheet
- **THEN** 顶部展示系统 drag indicator，用户可通过下滑手势关闭
- **AND** 页面不展示标题、Team 名小文案或额外的右上角关闭按钮

### Requirement: 队友今日状态分组

“拍一拍队友” sheet SHALL 只展示当前 Team 中允许接收拍一拍的其他成员，并分开展示今天尚无 Team 动态的队友和今天已有 Team 动态的队友。当前用户本人和已关闭当前 Team 拍一拍接收偏好的成员 MUST NOT 出现在列表中。页面只能描述 Team 可见状态，MUST NOT 将没有 Team checkin 表达为“没训练”“还没练”或“偷懒”。

#### Scenario: 队友没有 Team checkin
- **WHEN** 某队友今天尚未向当前 Team 分享 checkin
- **THEN** 该成员出现在“今天还没有 Team 动态”分组并显示“拍一拍”操作

#### Scenario: 队友已有 Team checkin
- **WHEN** 某队友今天已有当前 Team checkin
- **THEN** 该成员出现在“今日已分享”分组并显示完成状态，不显示“拍一拍”

#### Scenario: 列表排除本人
- **WHEN** 当前用户打开“拍一拍队友” sheet
- **THEN** 列表只展示其他 Team 成员
- **AND** 当前用户本人不出现在任何分组中

#### Scenario: 列表排除关闭接收的成员
- **WHEN** 某队友已关闭当前 Team 的拍一拍接收偏好
- **THEN** 该成员不出现在“拍一拍队友” sheet 的任何分组中

### Requirement: 拍一拍即时反馈

拍一拍按钮 SHALL 使用 SF Symbol `hand.tap` 并提供至少 44pt 的点击区域。点击后 SHALL 无确认弹窗，触发轻触觉反馈并乐观显示“已拍”；请求失败时 SHALL 回滚状态并显示可理解的错误。

#### Scenario: 拍一拍成功
- **WHEN** 用户点击符合资格队友的“拍一拍”且服务端返回成功
- **THEN** 按钮立即切换为“已拍”并保持不可重复点击
- **AND** 页面产生轻触觉反馈，不弹出确认对话框

#### Scenario: 拍一拍失败
- **WHEN** 用户点击“拍一拍”后服务端拒绝或网络失败
- **THEN** 页面从乐观的“已拍”回滚为“拍一拍”
- **AND** 页面展示错误信息，用户可在条件允许时重试

### Requirement: Team 拍一拍接收偏好

`TeamDetailView` SHALL 在 sheet 外提供“接收这个 Team 的拍一拍”开关，并与“训练完成后自动分享”作为同级设置相邻展示。开关 SHALL 乐观更新；保存失败时 SHALL 恢复旧值并显示错误。该开关只影响当前 Team。

#### Scenario: 关闭当前 Team 提醒
- **WHEN** 用户关闭“接收这个 Team 的拍一拍”且服务端保存成功
- **THEN** 当前 Team 的开关保持关闭，其他 Team 的设置不变

#### Scenario: 两项 Team 设置并列展示
- **WHEN** 用户进入 Team 详情页
- **THEN** “训练完成后自动分享”和“接收这个 Team 的拍一拍”在主页面相邻展示
- **AND** 成员拍一拍 sheet 中不再展示接收偏好开关

#### Scenario: 保存偏好失败
- **WHEN** 用户切换接收偏好但请求失败
- **THEN** 开关恢复到切换前状态并展示错误

### Requirement: 拍一拍推送刷新与打开 Team

iOS SHALL 识别 `type=team_nudge` 的 APNs。前台收到时 SHALL 刷新相关 Team 的当日成员状态；用户点击通知时 SHALL 切换到 Team tab 并打开 payload 中 `teamId` 对应的 Team 详情。目标 Team 不可用时 SHALL 安全停留在 Team 列表。

#### Scenario: 前台收到拍一拍
- **WHEN** App 在前台收到包含 `type=team_nudge` 和 `teamId` 的通知
- **THEN** 对应 Team 详情重新拉取成员、checkin 与当日 nudge 状态

#### Scenario: 点击拍一拍通知
- **WHEN** 用户点击包含有效 `teamId` 的拍一拍通知
- **THEN** App 切换到 Team tab 并打开对应 Team 详情

#### Scenario: 点击已失效 Team 的通知
- **WHEN** 通知中的 Team 已解散或用户已退出
- **THEN** App 切换到 Team 列表但不打开无权访问的详情，也不崩溃
