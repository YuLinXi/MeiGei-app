# v1.0-b21 Team 互动、训练计划与分享海报功能介绍

> 适用版本：`1.0 (build 21)`
> 对比基线：已发布版本 `v1.0-b20` 与当前 `feature/v1.0-b21` 候选版本的最终状态。
> 生成时间：2026-07-16 22:12 CST。
> 后端状态：已于 2026-07-16 22:21 CST 部署生产，Flyway `V19/V20` 已应用，production smoke 通过。
> iOS 状态：Simulator build/test 已通过；TestFlight `1.0 (21)` 已为 `VALID` 并完成真机回归，2026-07-16 22:28 CST 由用户确认。
> 发布状态：`feature/v1.0-b21` 已合并到 `main`，发布记录已完成，tag 为 `v1.0-b21`。

## 一句话摘要

本次 build 21 增加 Team 队友拍一拍、训练计划备选动作和 5 款插画分享海报，并提升计划详情、训练数据与跨日提醒的可靠性。

## 面向测试用户的更新说明

- Team 详情页新增“拍一拍队友”：可以查看队友今天是否已分享 Team 动态，并向尚无动态的队友发送一次轻量提醒。
- Team 设置简化为“分享动态”和“Team消息”。“Team消息”统一控制当前 Team 的拍一拍、队友打卡和表情回应提醒，两项设置对新成员默认开启。
- 普通计划动作现在可以添加有序备选动作；从计划开始训练后，在该动作尚未完成任何一组前，可以临时切换备选，且不会改掉计划中的默认动作。
- 计划详情动作卡改为紧凑摘要，点击后展开完整组次、热身、递减组、超级组、备选动作和下次训练重量；编辑与删除统一放在右侧 `…` 菜单，长列表滚动和侧滑返回更稳定。
- 训练分享海报新增 5 款随 App 提供的插画背景，会根据 PR、Team 来源和训练内容推荐初始背景；可直接在海报左右滑动、点击左右按钮或小预览切换，当前页就是保存和分享的版式。
- 海报采用更通透的训练信息卡，至少可展示 6 个动作摘要，并保持预览、保存图片和系统分享的内容一致，导出尺寸为 `1080×1920`。
- 切换热身标记时会保留训练组原有顺序；结束训练时若最后一段休息仍在进行，会按本段目标时长保留休息记录。
- 历史训练跨日补同步到 Team 时不再发送“今天完成训练”的误导提醒；训练摘要小组件在跨日、跨周后会按当前日期刷新，设置页编辑弹窗的高度也更稳定。

## 内部技术变更

- iOS 版本统一为 `MARKETING_VERSION = 1.0`、`CURRENT_PROJECT_VERSION = 21`，主 App、widget extension 与测试 target 保持一致。
- 新增 Flyway `V19__team_workout_nudges.sql`，创建 `team_nudge`、当日去重与限频索引，并增加 Team 成员消息偏好；`V20__team_member_preferences_default_enabled.sql` 将新成员的分享和消息默认值统一为开启，已有成员保存值不被覆盖。
- 新增 Team nudge 当日状态、发送和消息偏好 API；写接口继续要求 `Idempotency-Key`，服务端执行成员关系校验、同人同 Team 当日去重、发送者每日最多触达 5 人和接收者每日最多 3 条拍一拍推送。
- Team 消息偏好统一作用于拍一拍、队友打卡和表情回应推送；旧偏好接口与 `receive_workout_nudges` 物理列保留兼容映射，不维护第二份状态。
- `POST /checkins` 增加向后兼容的可选静默通知字段；checkin 仍按原日期写入，仅跨日补录抑制通知。
- 计划 items 与训练 unit JSON 增加可选备选动作快照；旧数据继续解码，后端继续透传结构并递归执行 Team 分享重量脱敏。
- 5 张海报背景全部随 App 打包，本地完成语义推荐、切换和渲染；不新增 SwiftData 字段、同步协议、后端 API 或网络资源依赖。
- 返回 `TeamMember` 的自定义 MyBatis 查询显式映射兼容物理列，保证 Team 消息状态在普通读取、事务锁行和批量读取中一致。
- 本次没有新增第三方依赖。

## 兼容性说明

- 本次后端已先于 TestFlight build 21 部署，Flyway 已从 `V18` 升级到 `V20`；新版 iOS 所需的拍一拍和 Team 消息接口已经就绪。
- `V19/V20` 为新增表、索引和默认值调整；旧 build 20 不会调用新 nudge API，登录、训练、同步和既有 Team 功能可继续使用。
- 已有 Team 成员的分享和消息偏好保持原值；默认开启只作用于新建或新加入的成员关系。
- 计划备选字段为 optional，旧计划和旧训练记录可以继续解码；海报和计划详情改动主要在新版 iOS 客户端生效。
- 真实拍一拍、队友打卡和表情回应通知仍依赖生产 APNs 配置、系统通知权限及至少两个真实账号。
- TestFlight `1.0 (21)` 已为 `VALID` 并完成真机回归，满足合并 `main` 和创建 `v1.0-b21` tag 的客户端门禁。

## 已完成验证

- 后端 `./gradlew clean build` 通过；随后使用 `--rerun-tasks` 实际执行完整测试，`80` 个测试通过，`0` failure、`0` error、`0` skipped。
- iOS Simulator Debug build 通过，目标为 iPhone 17 / iOS 26.4.1，`CODE_SIGNING_ALLOWED=NO`。
- iOS Simulator test 通过，xcresult 为 `Passed`，`192` 个测试、`0` failed、`0` skipped；参数化展开后的设备执行记录为 `195` 个 passed case。
- 8 个本次相关 OpenSpec change 均通过 strict validate：动态海报背景、计划备选动作、Team 拍一拍、结束训练休息回填、计划详情、计划手势、热身顺序和跨日 Team 通知。
- Team 拍一拍本地端到端验证通过：Simulator 请求返回 `HTTP 200`，页面保持“已拍”，重新进入后可恢复服务端状态并确认落库。
- `git diff --check` 通过；发布来源为 `feature/v1.0-b21`，基线为 `v1.0-b20`，已无冲突合并到 `main`。
- 生产发布前备份已生成：`/opt/DontLift-app/backend/backups/dontlift_2026-07-16_222004.sql.gz`，大小 `449K`。
- 生产后端容器重建成功；Flyway 已成功应用 `V19 team workout nudges` 与 `V20 team member preferences default enabled`，当前 schema 为 `V20`。
- 独立 production smoke 通过：health 连续 3 次返回 `UP`，`POST /auth/dev/token`=`404`，`/privacy`=`200`，`/terms`=`200`，启动后日志扫描 `recent_errors=0`。
- TestFlight `1.0 (21)` 已处理为 `VALID` 并完成真机回归，2026-07-16 22:28 CST 由用户确认，未报告阻塞问题。
- `main` 合并后门禁再次通过：后端 `80` tests、iOS build、iOS `192` tests、8 个 OpenSpec strict validate、生产 health 和 Flyway `V20` 均正常。
- iOS 测试编译存在 Swift 6 actor-isolation 兼容性 warning，但当前 Swift 模式下不阻塞 build/test；本次没有测试失败。

## TestFlight 回归重点

> 以下回归重点已完成，2026-07-16 22:28 CST 由用户确认通过；具体设备与 iOS 版本未提供。

- 后端 health 与 Flyway `V19/V20` 已通过；开始 build 21 回归前，再用旧 build 20 快速确认 Apple 登录、训练同步和既有 Team 功能兼容。
- 使用两个真实账号验证拍一拍：队友分组、发送成功、重复发送、已有 Team 动态不可拍、系统通知展示及点击后进入对应 Team。
- 分别关闭“分享动态”和“Team消息”，确认前者只影响训练分享，后者统一停止当前 Team 的拍一拍、队友打卡和表情回应提醒，其他 Team 不受影响。
- 为普通计划动作添加多个备选，验证个人计划、Team 分享、Fork 和离线重启后仍保留；训练未完成组时可切换，完成任意热身或正式组后不可切换。
- 验证严格与自适应计划的备选重量规则，并确认备选实绩不会覆盖默认动作的计划安排。
- 在包含普通动作、递减组、超级组和备选动作的长计划中，验证详情展开互斥、组次内容、`…` 编辑/删除、连续滚动和左边缘侧滑返回。
- 对普通训练、PR 训练、复杂训练和 Team 来源训练分别打开海报，检查 5 款背景推荐与切换；确认至少 6 个动作可读，保存图片和分享图片与当前预览一致。
- 回归热身标记来回切换后的组顺序，以及最后一组休息未结束时直接结束训练后的休息记录。
- 制造跨日离线 checkin 重放，确认历史动态仍落在原日期且不会向队友发送“今天完成训练”通知。
- 回归训练摘要小组件跨日/跨周展示、Apple 登录、冷启动、同步、Live Activity、休息通知和 Team 既有动态/表情路径。
