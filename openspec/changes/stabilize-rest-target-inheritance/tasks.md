## 1. iOS 端 - 先锁定休息目标契约

- [x] 1.1 扩充 `WorkoutRestPolicyTests`，先用失败测试覆盖调时后自然完成、调时后提前结束、继续休息累计，以及“最终目标参与继承、实际时间不参与继承”。
- [x] 1.2 增加同一动作优先级测试，覆盖热身转正式、上一组未完成休息、动作默认配置、用户全局配置、90 秒兜底和关闭后重新启用。
- [x] 1.3 增加超级组轮级测试，覆盖上一轮最终目标继承、第一轮轮后配置回退及轮内不启动休息。

## 2. iOS 端 - 模型与运行时实现

- [x] 2.1 为 `WorkoutUnit` 增加向后兼容的 optional `restAfterSetSeconds`，补充旧 JSON 解码和新字段 round-trip 测试。
- [x] 2.2 从既有休息完成事件派生最终目标秒数，消费事件时分别回写 `plannedRestSeconds` 与 `actualRestSeconds`，并复用继续休息基底分别累计两类值。
- [x] 2.3 调整普通组完成顺序：无条件先收束并消费旧休息，再按“上一组已完成目标 > 动作默认 > 用户全局 > 90 秒”解析、落值和启动新休息。
- [x] 2.4 调整超级组完成顺序与轮级继承，确保轮后休息绑定轮末锚点组且不从单个成员动作错误推导。
- [x] 2.5 将普通动作/递减组休息菜单改为读写所属 `WorkoutUnit`，删除 `restByExercise` 会话字典，并把界面文案收敛为“默认休息”。

## 3. 后端 - 聚合同步兼容确认

- [x] 3.1 核对 workout `units` JSON 在现有 push/pull 中保持透明透传，确认无需新增后端实体字段、Flyway 迁移或 API 契约。
- [x] 3.2 用既有同步测试或最小补充测试验证旧客户端缺失 `restAfterSetSeconds`、新客户端携带该字段时均可 round-trip，且 workout 聚合仍沿用既有幂等、LWW 与软删除路径。

## 4. 基础设施 / 验证

- [x] 4.1 运行 `WorkoutRestPolicyTests` 及受影响的训练组、超级组、热身排序测试，确认新契约与既有下一组导航无回归。
- [x] 4.2 运行 iPhone 17 Pro Simulator 无签名 Debug build，确认 App 与 Widget extension 编译通过。
- [x] 4.3 在 Simulator 人工回归：90 秒 `+10s` 自然结束、`+10s` 后提前结束、继续休息、活动休息中直接完成下一组、关闭后重新启用、最小化恢复和超级组下一轮。
- [x] 4.4 运行 `openspec validate stabilize-rest-target-inheritance --strict`，并在归档前与 `finalize-active-rest-with-target-duration`、`add-superset-training-units` 的最终规格做完整 requirement 对比。
