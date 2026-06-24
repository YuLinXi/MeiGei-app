## Why

近期评审暴露出若干上线级风险：训练数据默认进入 Team、服务条款链接占位、跨版本计划动作不可解析、团主删号影响成员历史、Watch Smart Stack 被写成无条件承诺、同步冲突过度依赖设备时钟，以及 MVP 范围文档与已落地计划模式不一致。它们不会阻塞继续写功能，但会影响 App Store 审核、用户信任和多设备数据正确性，必须在灰度前形成明确产品与技术基线。

## What Changes

- Team 打卡从“训练完成自动 fan-out 到所有 Team”改为“默认仅自己可见；用户在某个 Team 首次明确开启自动分享后，后续训练才自动分享到该 Team”；用户可关闭偏好并撤回某次训练的 Team 可见性。
- App 内法律入口必须分别打开独立的隐私政策与服务条款页面；独立 `/terms` 页面成为 TestFlight 外部测试与 App Store 提交前的硬性门禁。
- Team 共享计划项必须携带动作快照字段，旧客户端遇到未知 builtin code 时仍能展示、Fork 与开始训练。
- 团主删除账号不再默认解散团队并清除其他成员历史；团队保留并进入“待接管”或转移状态，只有独立“解散 Team”流程才可删除多人共享历史。
- Watch Smart Stack 需求改为“平台支持时呈现”：iOS 18 + watchOS 11 及系统支持场景下自动呈现；不支持或连接受限时以 iPhone 锁屏 Live Activity、本地通知和 App 内提示降级。
- 同步冲突裁决加入服务端时间防护：对明显偏移的客户端时间做校正/拒绝/冲突提示，避免错误设备时钟长期赢得 last-write-wins。
- 更新 MVP 范围说明：strict/adaptive 计划模式、历史预填与自适应回写已由后续 change 纳入 1.0 能力，不再按原 `meigei-mvp` Non-goal 解读。

## Capabilities

### New Capabilities

- `team-data-governance`: Team 训练数据自动分享偏好、首次授权、撤回、多人历史保留、共享计划动作快照与跨版本兼容。
- `release-compliance`: App 内法律链接、独立服务条款页面、发布前合规门禁。
- `sync-reliability`: 多设备同步中的时间偏移防护、服务端单调水位与冲突提示。

### Modified Capabilities

- `workout-tracking`: 结束训练后的 Team 分享不再作为无确认副作用；Live Activity 的 Watch Smart Stack 行为改为平台支持时呈现并定义降级；训练计划模式范围与现有 1.0 能力对齐。
- `account-deletion`: 团主删号不再默认删除其他成员 Team 历史；影响面预览与删除流程语义调整为只删除本人数据和成员关系。
- `profile-ui`: 登录页与「关于」页的服务条款入口必须指向独立服务条款 URL，不得复用隐私政策 URL。

## Impact

- iOS：训练完成流程、Team 自动分享偏好与撤回入口、法律链接配置、计划项解码 fallback、Live Activity/Watch 验收文案、同步冲突提示。
- 后端：checkin 创建/更新/撤回 API、Team owner 删除账号处理、团队待接管或 owner 转移逻辑、计划 items JSON 兼容字段、同步接口时间偏移校验。
- 数据库：可能新增 Team 待接管/owner 转移字段或状态、checkin 可见性记录、计划项 JSON schema 字段；如实现服务端单调水位，需在同步实体或响应信封中增加服务端时间字段。
- 文档与发布：`docs/testflight-checklist.md` 需把独立 `/terms` 页面列为硬卡点；`meigei-mvp` 范围说明需标注已被后续计划模式 change 覆盖。

## Non-goals

- 不引入公开动态广场、评论、群聊或私信。
- 不做字段级 CRDT/merge；同步仍以聚合级冲突裁决为主，只增加时间偏移防护和明确冲突提示。
- 不引入独立 WatchKit App；Watch 仍只承接系统支持的 iPhone Live Activity 呈现。
- 不实现完整 Team 权限体系或训练字段级隐藏；本 change 只控制“是否分享到哪些 Team/是否撤回”。
- 不新增 Android/Web 发布范围。
