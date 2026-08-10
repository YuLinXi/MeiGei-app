## Context

参见 `proposal.md`。现有休息数据分为两层：`WorkoutSet.plannedRestSeconds` / `actualRestSeconds` 保存每组目标与事实，`WorkoutUnit.restAfterSetSeconds` 和 `WorkoutSupersetUnit.restAfterRoundSeconds` 保存本次训练的单元默认值。普通/递减计划项缺少对应字段，导致 `PlanWorkoutBuilder`、`PlanWriteback` 与计划转换路径无法跨训练传递默认休息；超级组计划已经有轮后休息字段。

`WorkoutPlan.items` 以 JSON 文档随现有同步实体传输，计划本身已具备 `localId/serverId/updatedAt/deletedAt/version/syncStatus` 信封、软删除、幂等 push 与 LWW 冲突规则。Team 分享快照同样保存 items JSON，并通过既有幂等写接口创建版本或 Fork。

## Goals / Non-Goals

**Goals:**

- 用最小模型增量让普通动作、递减组和超级组的默认休息在计划、训练和计划转换之间无损传递。
- 保持用户显式默认值与每组预计/实际休息事实的边界，避免偶然等待时间改变计划。
- 让休息单独变化也复用既有自适应回写回执、撤销和同步链路。

**Non-Goals:**

- 不建立逐组休息处方、休息历史索引或推荐算法。
- 不统一普通动作与超级组的字段结构，不重构现有计划项类型。
- 不改变身份、权限、幂等、软删除、冲突或同步协议。

## Decisions

### D1. 在 `PlanItem` 增加 optional `restAfterSetSeconds`

普通动作和递减组复用训练单元已有三态：`nil` 跟随全局、`0` 关闭自动休息、正整数为显式秒数。超级组继续使用 `supersetRestAfterRoundSeconds`。

选择增补与 `WorkoutUnit` 同名字段，而不是抽象为统一的 `restAfterUnitSeconds`，可以避免迁移超级组旧 JSON、扩大初始化器调用面或引入只服务三个枚举分支的新协议。`PlanItem` 已是 Codable JSON 文档，optional 字段使旧数据自然解码为 `nil`，后端 jsonb 与同步 DTO 无需改动。

### D2. 计划构建只做计划字段到训练单元字段的直接映射

`PlanWorkoutBuilder` 在创建普通动作或递减组 `WorkoutUnit` 时直接传入 `PlanItem.restAfterSetSeconds`；超级组保持现有映射。严格与自适应模式使用同一休息落值规则，模式差异继续只约束组值来源和完成回写。

开始训练后仍由 `WorkoutRestPolicy` 解析“上一段已完成目标 > 训练单元默认 > 全局默认 > 90 秒”。不把计划字段复制到每个 `WorkoutSet`，避免把一个默认值误建模为逐组处方。

### D3. 自适应休息回写按一级训练单元合并

重量和次数仍沿用现有按 `WorkoutExercise` 合并；休息属于 `WorkoutUnit`，在 `PlanWriteback` 中按一级训练单元处理：

- 普通动作/递减组通过来源 `planItemId` 优先匹配计划项，沿用既有唯一 `historyKey` fallback；
- 超级组通过两个成员的稳定 `memberId` 定位来源超级组计划项；
- 训练中新增且完成正式组的普通动作/递减组，在现有 append 分支写入训练单元默认休息；临时超级组仍不自动加入来源计划结构；
- 跳过或无法安全匹配的计划项保持原值。

回写值只读取训练单元当前配置，包括用户明确恢复的 `nil` 与关闭的 `0`。不从 `plannedRestSeconds` 或 `actualRestSeconds` 推导计划值。`PlanWriteback` 的摘要/差异判定加入休息，使 rest-only 变化产生 `.updated`；现有整份 `plan.items` 快照可直接撤销新字段。

备选方案是取最后一次已完成休息的最终目标。放弃原因是活动倒计时 `+/-` 属于单次操作，且实际训练可能因器械占用、接电话或提前结束出现偶然值；动作菜单“默认休息”才是明确的跨训练意图。

### D4. UI 复用现有休息选项并显式区分 `nil` 与 `0`

普通动作和递减组计划编辑增加“默认休息”，复用训练页已有的关闭、60/90/120 秒与自定义数字输入；额外提供“跟随全局”以写入 `nil`。计划详情在现有训练安排内显示一行，不在折叠卡或计划列表增加信息。

训练中动作菜单也应提供恢复“跟随全局”的入口，否则从计划带入显式值后用户无法表达清除覆盖。显示时区分“跟随全局 · 当前 N 秒”“关闭自动休息”和“N 秒”，但实际解析仍复用全局默认，不把解析结果写回计划。

### D5. 所有显式重建 `PlanItem` 的路径必须传递休息

计划 JSON 的常规同步会自动编码新字段，但以下路径会显式重新构造 `PlanItem`，必须逐一传递：

- 无计划训练保存为模板；
- 个人计划复制与重量清理；
- Team 分享前的客户端无重量快照；
- Team 分享版本的 Fork 与直接开始训练。

Team 分享保留休息，因为它属于训练结构且现有超级组轮后休息已采用相同规则。`nil` 保持缺失，确保接收者使用自己的全局默认。服务端现有重量递归剥离只删除重量键，未知休息键可透明保存；不新增接口，既有成员鉴权、幂等键和不可变分享版本规则不变。

### D6. 继续使用计划聚合的同步与软删除边界

休息字段随 `WorkoutPlan.items` 本地编辑后调用既有 `markDirty()`，由计划同步域整体 push；撤销同样恢复 items 快照并重新标脏。新增字段没有独立身份、时间戳、删除或冲突策略，避免与计划聚合 LWW 产生第二套裁决。

身份三层、所有写接口幂等键、同步信封、软删除墓碑与 Team 权限均不受影响。该字段不是可重算统计结果，而是用户计划配置，因此保存在计划 JSON 中符合现有数据边界。

## Risks / Trade-offs

- [Risk] 旧版本客户端解码并重新保存计划时会丢弃未知休息字段，随后可能凭 LWW 覆盖新版值。→ Mitigation：按现有新增 PlanItem 字段的版本兼容边界发布；回归跨设备同步，并在仍有旧 TestFlight 活跃版本时避免宣称跨版本无损编辑。
- [Risk] rest-only 更新若仍只比较重量/次数摘要，会被误判为无变化。→ Mitigation：把休息纳入纯逻辑合并结果和回执测试，覆盖修改、恢复跟随全局、关闭与撤销。
- [Risk] 显式重建 `PlanItem` 的复制/分享路径容易漏传字段。→ Mitigation：为模板、复制、Team 分享/Fork 建立定向 round-trip 测试，而不是依赖 Codable 单测推断所有路径。
- [Trade-off] 单元级默认休息不能表达热身 45 秒、正式组 120 秒等逐组安排。→ 这是本 change 的明确上限；只有出现真实需求时再扩展逐组处方。

## Migration Plan

1. iOS 先加入 optional 计划字段、旧 JSON 解码测试与所有映射逻辑。
2. 接入计划编辑/详情、自适应回写回执及计划转换路径。
3. 验证计划同步、Team 分享无重量快照和从分享版本直接开始训练；后端无需部署或迁移。
4. 随 iOS 版本发布。回滚时旧客户端忽略新字段，现有训练历史与休息计时继续工作；再次编辑计划可能清除字段，属于上述跨版本兼容上限。
