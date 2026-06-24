## Context

当前 MVP 已完成训练记录、Team 打卡、账号删除、Live Activity 与发布准备的大部分实现，但评审指出几个上线前必须收紧的风险点：

- Team 打卡现在由训练完成自动 fan-out 到用户所有 Team，等同默认公开训练摘要和每组重量次数。
- App 内服务条款 URL 暂复用 `/privacy`，对外部测试和 App Store 审核不够诚实。
- Team 计划 `items` 只保存 `exerciseRef`，旧客户端遇到新 builtin code 会无法展示。
- 团主删除账号会解散其拥有的 Team，并删除其他成员共享历史。
- Watch Smart Stack 呈现依赖 iOS/watchOS 版本、连接状态和系统预算，不能写成无条件验收。
- 同步 LWW 直接信任客户端 `updatedAt`，未来时间或严重偏移会污染冲突裁决。
- `meigei-mvp` 的旧 Non-goal 未反映后续已落地的 strict/adaptive 计划模式。

这些问题横跨 iOS、后端、数据库、发布文档和 OpenSpec 规格。目标是在不引入大规模社交权限系统、不重写同步架构的前提下，建立可上线的产品边界。

## Goals / Non-Goals

**Goals:**
- 训练数据默认私有，只有用户在 Team 内首次确认开启自动分享或主动分享后才共享。
- 已共享的训练支持按 Team 撤回，撤回后 Team feed 和反应一起移除。
- Team 计划在跨客户端版本时可读、可 Fork、可开始训练。
- 账号删除只删除删号用户自身数据；多人 Team 的其他成员历史不被团主删号连带删除。
- 发布前法律链接真实、独立、可达，服务条款不再冒充隐私政策。
- Watch Smart Stack 规格与 Apple 平台支持条件一致，并保留 iPhone 侧降级体验。
- 同步服务端防止严重设备时钟偏移破坏 LWW。

**Non-Goals:**
- 不做字段级可见性（例如隐藏某个动作或某组重量）；本次只控制整次训练是否分享到哪些 Team。
- 不新增文字评论、群聊、私信、公开广场或教练分配计划。
- 不实现 CRDT 或字段级 merge；仍保留聚合级 LWW + 人工提示。
- 不新增独立 WatchKit App。
- 不在本 change 内重做完整法律文本审稿，只要求独立 `/terms` 页面存在、App 内 URL 正确、发布清单硬门禁。

## Decisions

### D1. Team 打卡改为 Team 级自动分享偏好

训练完成时先完成本地归档、HealthKit 写入、PR 检测和自适应计划回写；Team 分享不再作为无条件副作用，也不再要求每次完成训练后弹出大确认 sheet。每个 Team 的成员关系上保存 `autoShareWorkouts` 偏好，默认关闭。用户在 Team 详情中首次开启时，客户端必须弹出一次确认，说明后续训练会自动分享到该 Team，Team 成员可看到训练摘要和每组记录，且可随时关闭和按次撤回。

训练结束后客户端读取当前用户已开启自动分享的 Team 列表，只为这些 Team 创建或更新 checkin。未开启任何 Team 时保持仅自己可见，不创建 Team checkin。新加入的 Team 不继承其他 Team 的偏好，仍默认关闭。

备选“Team 默认开启分享”被否：它仍会在用户未明确授权时公开健康/训练数据。备选“每次训练结束都确认”合规上更保守，但会增加高频训练流程负担；本版采用首次授权作为默认方案。

### D2. Team 分享意图可离线排队，但只针对已授权 Team

如果用户完成训练时离线，训练本地归档不受影响。若用户未对任何 Team 开启自动分享，不产生任何 Team 分享副作用。若用户已对 Team A 开启自动分享但分享请求失败，客户端保存 Team A 的 pending share intent，待 workout 同步成功后重放。pending intent 的幂等键使用 `share-checkin:{workoutId}:{teamIds}:{updatedAt}`，保证弱网重试不会重复创建。

这保持离线优先，同时避免“网络恢复后突然分享到未授权 Team”。用户关闭某 Team 自动分享后，只影响后续训练；历史已分享记录需按次撤回。

### D3. Checkin 从 fan-out API 改为按 Team 目标 upsert

后端新增或调整接口语义：

- `POST /checkins` 接受 `workoutId`、`checkinDate`、`summary`、`teamIds`，只对请求中的 Team upsert。
- `DELETE /teams/{teamId}/checkins/workouts/{workoutId}` 撤回某次训练在某个 Team 的可见性。
- `PATCH /teams/{teamId}/members/me/share-preferences` 更新当前用户在该 Team 的 `autoShareWorkouts` 偏好。
- `GET /teams/members/me/share-preferences` 返回当前用户在各 Team 的分享偏好，供训练结束后自动分享读取。
- 服务端校验调用者必须是目标 Team 成员，且 `workoutId` 属于调用者。
- 撤回 checkin 时，`checkin_reaction` 经外键或显式删除同步移除。

仍保留幂等键铁律。旧客户端如果继续调用旧 fan-out 语义，服务端应在兼容期内要求显式 `teamIds`；缺失时返回 400 而不是自动分享到所有 Team。

### D4. Team 计划项保存动作快照

`PlanItem` JSON schema 增加可选但写入时必填的快照字段：

- `exerciseName`
- `primaryMuscle`
- `equipmentType`（如本地有）

`exerciseRef` 仍是稳定引用，用于新客户端解析 builtin/custom。快照是展示和跨版本 fallback，不作为动作身份主键。发布 Team 计划、Fork 队友计划、复制为新计划和开始训练时都必须保留这些快照字段；旧 payload 缺失时，客户端按现有 builtin/custom 解析，解析失败显示“未知动作”并阻止开始训练，直到用户修复或更新 App。

### D5. 团主删号优先转移 owner，而不是解散多人 Team

账号删除仍必须物理硬删删号用户自身数据：identity、device token、idempotency、custom exercise、workout plan、workout、自身 checkin/reaction、自身 team_member。若删号用户拥有 Team：

- Team 仍有其他成员时，将 owner 转移给 joined_at 最早的剩余成员，并保留 Team、其他成员 checkin/reaction、共享计划。
- Team 已无其他成员时，删除该空 Team。
- 被删用户发布到 Team 的计划应从 Team 计划列表移除或匿名化归属；已被 Fork 的副本保持不受影响。

独立“解散 Team”仍存在，但它是 owner 主动管理行为，必须有强确认，不能被“删除个人账号”隐式触发。

### D6. 服务条款作为发布硬门禁

新增静态 `/terms` 页面并将 `AppConfig.termsOfServiceURL` 指向 `https://dontlift.peipadada.com/terms`。登录页和「我的 → 关于」均使用同一配置。`docs/testflight-checklist.md` 将“独立服务条款页面已上线且 App 内可达”列为外部 TestFlight / App Store 提交前硬门禁。

Apple 指南要求隐私政策在 App Store Connect 和 App 内易访问，并说明数据收集、用途、共享与删除策略；即使服务条款不是所有免费 App 的同等硬性条款，也不能用隐私政策冒充条款页面。

### D7. Live Activity Watch 支持条件写入规格与验收

iOS 18 + watchOS 11 起，iPhone Live Activity 可自动出现在 Apple Watch Smart Stack；系统也会受连接状态、更新预算和 Always On Display 影响。因此规格改为“平台支持时呈现”。最低 iOS 17.4 的手机仍必须提供锁屏 Live Activity、本地通知、前台声音/震动；Watch 不支持时不得视为功能失败。

验收拆成两档：

- 必测：iPhone 锁屏/灵动岛/本地通知。
- 条件测试：iOS 18+ 配对 watchOS 11+ Apple Watch 的 Smart Stack 呈现与交互。

### D8. 同步时间偏移防护采用服务端校正，不引入 CRDT

保留现有同步信封和 LWW，但服务端在 push 时计算 `skew = client.updatedAt - serverNow`：

- 若客户端时间在容忍窗口内，沿用客户端 `updatedAt` 作为 LWW 比较基准。
- 若 `updatedAt` 明显超过未来阈值，服务端不得持久化该未来时间；改用 `serverNow` 作为有效更新时间，并在响应中返回 timestamp adjustment notice。
- 若 `updatedAt` 明显落后但本次上传是新建或本地 pending 写，服务端可用 `serverNow` 作为有效更新时间并提示已校正；若会覆盖服务端已有较新版本，则按冲突处理。
- 若库内已有 legacy 未来时间，迁移或启动修复任务将其 clamp 到不晚于迁移执行时刻，并写日志。

备选 HLC/服务端单调版本列更严谨，但改动面更大。当前方案优先解决“未来时间长期赢”的上线风险，并保留后续演进空间。

### D9. MVP 范围用 supersede 注记消除歧义

不重写 `meigei-mvp` 整体 proposal，只在范围相关文档标注：strict/adaptive、历史预填、训练后回写已由后续 workout specs 纳入 1.0；旧 Non-goal 只代表初稿，不再作为当前验收依据。最终验收以 `openspec/specs/workout-tracking/spec.md` 和本 change 归档后的主规格为准。

## Risks / Trade-offs

- [自动分享降低心智负担但有隐私风险] → 默认关闭；只有用户在 Team 内首次确认开启后才自动分享，并保留关闭与撤回入口。
- [离线分享意图增加本地队列复杂度] → 队列只保存 workoutId/teamIds/summaryHash/updatedAt，不存额外训练副本；失败可在完成页或 Team 页提示重试。
- [owner 转移可能让用户意外成为团主] → 新 owner 首次进入 Team 时展示“已自动接管”提示，并允许其解散或转移。
- [计划项快照与 builtin 目录可能不一致] → `exerciseRef` 仍为身份源，快照仅 fallback；新客户端优先用本地目录展示标准名称。
- [timestamp 校正可能改变严格客户端编辑时间语义] → 只对明显 skew 生效，并通过 conflict/notice 告知用户；正常设备不受影响。
- [服务条款文本仍需人工确认] → 本 change 只建立工程门禁，最终法律文案需上线前人工审阅。

## Migration Plan

1. 新增 `/terms` 静态页面，更新 `AppConfig.termsOfServiceURL` 和发布清单。
2. 数据库迁移：如选择记录 pending owner/transfer，可为 `team` 增加必要状态字段；为 existing 未来 `updated_at` 执行一次 clamp 修复；Team checkin 可继续用现表，通过接口语义控制可见性。
3. 后端先兼容新 `teamIds` checkin API、撤回 API、owner 转移删号逻辑、计划项快照 passthrough、timestamp 校正响应。
4. iOS 再接入 Team 自动分享偏好、首次开启确认、训练结束自动分享、撤回入口、pending share intent、计划项快照编码/解码 fallback、Watch 条件文案与同步 notice。
5. 回滚：如新分享 API 有问题，可暂时隐藏自动分享偏好入口；不得恢复自动 fan-out。timestamp 校正可通过配置阈值放宽，但不得允许未来时间无限持久化。

## Open Questions

- owner 转移时选择 joined_at 最早成员还是最近活跃成员；本设计默认 joined_at 最早，便于可解释。
- timestamp skew 容忍窗口取值：建议先用未来 5 分钟、过去 24 小时作为初始阈值，实测后调整。
