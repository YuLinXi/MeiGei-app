# 超级组功能迭代测试计划

本文用于验证 `add-superset-training-units` 迭代。测试目标是确认「超级组」作为与单动作平级的一级训练单元，在计划、训练中录入、统计、详情、Team 和分享海报链路中都能保持结构语义，并且不破坏旧训练、旧计划和递减组能力。

## 1. 测试范围

本轮需要覆盖：

- 计划详情中创建、编辑、展示超级组。
- 训练中新增超级组、按轮录入重量/次数、完成本轮、取消完成。
- 超级组固定 2 个普通正式动作、统一组数，不支持热身组、递减组、嵌套或 3 个及以上动作。
- 超级组创建页的自研数字键盘：重量允许小数，次数和统一组数只允许整数。
- 「超级组 / 添加动作」「递减组 / 加一组」按钮层级和视觉：副按钮灰色系，主按钮主题色，均有白色背景。
- 超级组轮后休息、加一轮、删末轮、解除超级组。
- 训练统计、PR、历史详情、Team checkin summary、分享海报对超级组的结构化展示。
- 旧 workout / plan payload 的兼容展示。
- 后端 `workout.units` 字段迁移和 workout 聚合同步透传。

## 2. 环境准备

### 2.1 后端

在 `backend/` 下启动本地后端。模拟器 E2E 建议开启 dev token：

```bash
cd backend
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
APP_DEV_TOKEN=true ./gradlew bootRun
```

启动后确认：

```bash
curl -sS http://localhost:8001/actuator/health
```

期望返回：

```json
{"status":"UP","groups":["liveness","readiness"]}
```

数据库迁移期望：

- `flyway_schema_history` 最新版本为 `17 - workout units`。
- `workout.units` 存在，类型为 `jsonb NOT NULL DEFAULT '[]'::jsonb`。
- `workout_set.segments` 存在，类型为 `jsonb NOT NULL DEFAULT '[]'::jsonb`。

### 2.2 iOS

在 `ios/DontLift/` 下使用 Xcode 26 和 iPhone 17 Pro 模拟器：

```bash
cd ios/DontLift
xcodebuild -project DontLift.xcodeproj -scheme DontLift \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

模拟器登录路径：

1. 首屏点击「⌥ 开发者登录（仅模拟器）」。
2. 如果进入资料补全页，在「称呼」输入任意测试名，例如 `E2E`。
3. 点击「开始训练」进入主界面。

## 3. 常规验证命令

每次提交前至少运行：

```bash
openspec validate --changes
git diff --check
```

后端验证：

```bash
cd backend
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
./gradlew test
```

iOS 编译验证：

```bash
cd ios/DontLift
xcodebuild -project DontLift.xcodeproj -scheme DontLift \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

iOS 单元/UI 测试可选验证：

```bash
cd ios/DontLift
xcodebuild -project DontLift.xcodeproj -scheme DontLift \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO test
```

## 4. 手工回归测试用例

| ID | 场景 | 步骤 | 预期 |
| --- | --- | --- | --- |
| SUP-PLAN-001 | 计划中新建超级组 | 进入「计划」Tab，点击右上添加菜单，选择「新建计划」，输入计划名称并保存；进入计划详情，点击「超级组」。 | 打开「创建超级组」sheet。 |
| SUP-PLAN-002 | 创建页动作选择 | 在「动作 1」「动作 2」分别选择两个不同动作。 | 两个动作展示名称、部位和器械信息；选择同一动作时「完成」不可用。 |
| SUP-PLAN-003 | 创建页输入顺序 | 在创建页依次点击动作 1 重量、动作 1 次数、动作 2 重量、动作 2 次数、统一组数。 | 自研数字键盘出现；右侧「上一项 / 下一项 / 完成」按视觉顺序切换，统一组数位于页面最后。 |
| SUP-PLAN-004 | 数字键盘输入规则 | 重量输入 `60.5`，次数输入 `12`，统一组数输入 `4`；在次数和组数态点击小数点。 | 重量允许小数；次数和组数的小数点不可用；输入格高度紧凑，不出现系统键盘。 |
| SUP-PLAN-005 | 计划详情展示 | 创建完成后回到计划详情。 | 出现一个与单动作平级的「超级组」计划单元，摘要包含 `4 轮`、`8 组` 和两个成员动作的重量/次数。 |
| SUP-PLAN-006 | 编辑超级组 | 点击计划详情中的超级组卡片，修改其中一个动作重量/次数和统一组数后完成。 | 原超级组被更新；成员顺序不变；总组数按 `轮数 * 2` 更新。 |
| SUP-PLAN-007 | 添加入口视觉 | 查看计划详情底部「超级组 / 添加动作」按钮。 | 「超级组」在左侧、紧凑宽度、灰色系、白色背景；「添加动作」在右侧、宽按钮、主题色、白色背景。 |
| SUP-WORKOUT-001 | 从计划开始训练 | 对包含超级组的计划点击「开始这次训练」。 | 训练页出现超级组卡片，卡片与普通动作平级。 |
| SUP-WORKOUT-002 | 训练中新增超级组 | 在进行中训练页底部点击「超级组」，完成创建。 | 当前训练新增超级组训练单元；不自动写回来源计划结构。 |
| SUP-WORKOUT-003 | 超级组按轮录入 | 在超级组第 1 轮两个成员动作分别填写重量/次数。 | 两个成员各自显示输入值；重量/次数仍使用统一训练键盘。 |
| SUP-WORKOUT-004 | 完成本轮 | 点击第 1 轮「完成本轮」。 | 两个成员对应 set 同时变为 completed；按钮文案变为「已完成」；已完成组数增加 2。 |
| SUP-WORKOUT-005 | 取消完成 | 再次点击已完成轮。 | 两个成员 set 同时取消完成；统计减少 2 组。 |
| SUP-WORKOUT-006 | 加一轮 / 删末轮 | 点击「加一轮」，再点击「删末轮」。 | 加一轮时两个成员各新增一组并继承上一轮值；删末轮只删除最后一轮，轮数不能小于 1。 |
| SUP-WORKOUT-007 | 轮后休息 | 打开超级组右上更多操作，选择「轮后休息 90s」，完成一轮。 | 只在完成整轮后启动休息；轮内第一个动作完成不启动休息；下一组提示指向下一轮第一个成员动作。 |
| SUP-WORKOUT-008 | 解除超级组 | 打开超级组右上更多操作，选择「解除超级组」。 | 超级组拆成两个单动作训练单元；已有重量、次数、完成状态保留。 |
| SUP-WORKOUT-009 | 添加入口视觉 | 查看训练页底部「超级组 / 添加动作」按钮，以及单动作卡内「递减组 / 加一组」。 | 「超级组」「递减组」为灰色系副按钮；「添加动作」「加一组」为主题色主按钮；所有按钮有白色背景。 |
| SUP-STATS-001 | 统计口径 | 完成一个 4 轮超级组并结束训练。 | 总组数按 8 个普通正式组计算；训练量按两个成员动作完成组的 `重量 * 次数` 汇总。 |
| SUP-DETAIL-001 | 完成详情展示 | 结束训练后打开训练详情。 | 详情页保留「超级组」结构，展示两个成员动作、轮数和每轮重量/次数；不展平成两个无关联动作。 |
| SUP-POSTER-001 | 分享海报 | 在训练详情右上更多操作中选择「分享训练海报」。 | 海报摘要展示类似「超级组 · A + B · N 轮」；统计仍按完成组数计算。 |
| SUP-TEAM-001 | Team checkin 详情 | 完成训练并分享到 Team，进入 Team 动态详情。 | Team 详情保留超级组结构，展示成员、轮数和重量/次数。 |
| SUP-SYNC-001 | 同步 payload | 完成含超级组训练后触发同步，重启 App 或换设备拉取。 | `workout.units` 结构可被 push/pull，重新打开后超级组仍保留。 |
| SUP-COMPAT-001 | 旧数据兼容 | 打开旧训练记录和旧计划。 | 旧数据缺少 units 时按单动作列表正常展示，不崩溃、不空白。 |
| SUP-NEG-001 | 非目标能力约束 | 尝试在超级组内创建热身组、递减组、三个动作或嵌套超级组。 | UI 不提供入口；模型中超级组成员 set 始终为普通正式组。 |

## 5. XcodeBuildMCP E2E 自动化测试

本节用于在另一台机器上交给 Codex + XcodeBuildMCP 执行。执行前确保：

- 后端已按 `APP_DEV_TOKEN=true ./gradlew bootRun` 启动。
- PostgreSQL 已启动，数据库能通过 Flyway 迁移到 v17。
- XcodeBuildMCP 已连接到当前 Codex 会话。
- 当前分支已包含本次提交。

### 5.1 XcodeBuildMCP 基础流程

使用 XcodeBuildMCP 的工具顺序：

1. `list_sims`：列出模拟器。
2. 如无 Booted 设备，使用 XcodeBuildMCP 的 boot simulator 工具启动 `iPhone 17 Pro`；若当前 MCP 版本没有 boot 工具，则用 `xcrun simctl boot` 启动后重新 `list_sims`。
3. `session-set-defaults`：
   - `projectPath`: `<repo>/ios/DontLift/DontLift.xcodeproj`
   - `scheme`: `DontLift`
   - `configuration`: `Debug`
   - `simulatorId`: 上一步选中的 booted simulator id
   - `useLatestOS`: `true`
4. `build_run_sim`：构建并启动 App。
5. `describe_ui`：确认 App 首屏已渲染。
6. 后续通过 `tap`、`type_text`、`gesture`、`screenshot` 执行和留存证据。
7. 失败时用 `screenshot` 和 `describe_ui` 保存当前状态，输出失败步骤、实际 UI 文案和预期差异。

### 5.2 可直接执行的 E2E Agent Prompt

将下面整段交给具备 XcodeBuildMCP 的 Codex 代理执行：

```text
你是 DontLift iOS E2E 测试执行器。请使用 XcodeBuildMCP 在模拟器上自动验证超级组功能。

仓库路径：
/Users/yumengyuan/Desktop/yumengyuan/projects/MeiGei-app

前置检查：
1. 确认后端 http://localhost:8001/actuator/health 返回 UP。若未启动，进入 backend，执行：
   export JAVA_HOME=$(/usr/libexec/java_home -v 21)
   APP_DEV_TOKEN=true ./gradlew bootRun
2. 使用 XcodeBuildMCP list_sims。若没有 Booted 模拟器，启动 iPhone 17 Pro。
3. 设置 XcodeBuildMCP session defaults：
   projectPath = <repo>/ios/DontLift/DontLift.xcodeproj
   scheme = DontLift
   configuration = Debug
   simulatorId = booted iPhone 17 Pro
   useLatestOS = true
4. 执行 build_run_sim。
5. 使用 describe_ui 和 screenshot 确认 App 已启动。

登录与基础数据：
1. 如果看到登录页，点击「⌥ 开发者登录（仅模拟器）」。
2. 如果看到资料补全页，在「称呼」输入 E2E，点击「开始训练」。
3. 如果出现通知权限、网络权限、HealthKit 权限弹窗，选择允许或继续；不得因此中断测试。

E2E-01：计划侧创建超级组
1. 进入「计划」Tab。
2. 点击「添加计划或分组」浮动按钮，选择「新建计划」。
3. 在「计划名称」输入「E2E 超级组计划」，保存或返回计划详情。
4. 在计划详情底部确认按钮顺序：左侧「超级组」，右侧「添加动作」。
5. 截图并断言：「超级组」为左侧紧凑副按钮，「添加动作」为右侧宽主按钮，二者均有白色背景。
6. 点击「超级组」。
7. 在「创建超级组」页选择两个不同动作。优先选择动作库中可见的前两个动作。
8. 点击动作 1 重量，输入 60.5；点击下一项，输入 12；继续下一项，输入 40；继续下一项，输入 15；继续下一项到「统一组数」，输入 4。
9. 断言：统一组数位于两个动作之后；次数/组数状态小数点不可用；页面没有系统键盘。
10. 点击「完成」。
11. 断言计划详情出现「超级组」，摘要包含「4 轮」和成员动作名称。

E2E-02：从计划开始训练并完成一轮
1. 在计划详情点击「开始这次训练」。
2. 断言训练页出现超级组卡片，卡片标记为「超级组」，摘要显示轮数。
3. 在第 1 轮两个成员输入框中确认默认重量/次数来自计划。
4. 点击「完成本轮」。
5. 断言按钮变为「已完成」，顶部已完成组数增加 2。
6. 再次点击该轮，断言完成状态被取消，已完成组数减少 2。
7. 再次完成第 1 轮，保留完成状态。

E2E-03：超级组轮操作
1. 点击「加一轮」。
2. 断言超级组轮数增加 1，新轮两个成员继承上一轮重量/次数。
3. 点击「删末轮」。
4. 断言轮数恢复，且不能删到 0 轮。

E2E-04：轮后休息
1. 打开超级组右上更多操作。
2. 点击「轮后休息 90s」。
3. 完成下一轮。
4. 断言休息计时出现，下一组提示指向该超级组下一轮第一个成员动作。
5. 结束休息或收起休息弹窗后继续。

E2E-05：训练中新增超级组入口视觉
1. 滚动到训练页底部。
2. 断言底部按钮顺序为左「超级组」、右「添加动作」。
3. 断言「超级组」为灰色系副按钮，「添加动作」为主题色主按钮，均有白色背景。

E2E-06：结束训练与详情/海报
1. 点击顶部结束训练按钮。
2. 如出现未完成组确认，确认结束。
3. 打开刚完成训练详情。
4. 断言详情中保留「超级组」结构，展示成员动作和轮数，不展平成两个无关联动作。
5. 打开右上更多操作，点击「分享训练海报」。
6. 断言海报预览包含「超级组 · A + B · N 轮」或等价超级组摘要。
7. 截图保存。

E2E-07：旧路径回归
1. 回到训练或计划页。
2. 新建一个普通单动作训练或计划项。
3. 断言普通「添加动作」「加一组」「递减组」仍可用。
4. 断言「递减组」为灰色系副按钮，「加一组」为主题色主按钮。

输出报告：
- 列出每个 E2E 用例的 PASS/FAIL。
- 对每个 FAIL 给出：失败步骤、当前 UI 文案、截图路径、可能原因。
- 输出至少 5 张截图：登录后首页、计划详情按钮、创建超级组页、训练中超级组卡、完成详情或海报。
```

### 5.3 自动化通过标准

自动化测试必须满足：

- 所有 E2E 用例均 PASS。
- 没有 SwiftUI runtime crash、空白页或无法点击的核心按钮。
- 关键截图中能看到超级组结构，而不是两个普通动作被扁平展示。
- 训练结束后重新进入详情，超级组结构仍存在。
- 后端日志没有 500；iOS 控制台没有与 `Workout.units`、`PlanUnit`、`Superset` 编解码相关的错误。

## 6. 失败排查

- 登录失败：确认后端以 `APP_DEV_TOKEN=true` 启动，且模拟器使用本机 `localhost:8001`。
- Flyway 校验失败：确认本地库没有旧 V16 checksum 冲突；干净库可直接迁移到 v17。
- 找不到按钮：先 `describe_ui`，优先按可见文案查找，例如「超级组」「添加动作」「完成本轮」。
- 动作库选择失败：优先选择当前列表可见的两个不同动作，不强依赖具体动作名称。
- 分享海报权限弹窗：选择允许或继续，测试目标是预览结构而不是系统分享完成。
- 休息计时遮挡：可先点击「完成休息」或收起休息弹窗，再继续下一步。

## 7. 提交前最终检查清单

- [ ] `openspec validate --changes` 通过。
- [ ] `git diff --check` 通过。
- [ ] `backend ./gradlew test` 通过。
- [ ] iOS Debug simulator build 通过。
- [ ] 至少手工验证一次创建超级组、开始训练、完成一轮、结束详情。
- [ ] XcodeBuildMCP E2E 在目标机器完整跑通并产出截图报告。
