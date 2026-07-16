## ADDED Requirements

### Requirement: Team 成员可发送拍一拍

系统 SHALL 允许当前 Team 成员向同一 Team 内、当日尚无 Team checkin 的其他成员发送一次“拍一拍”。系统 MUST NOT 允许用户拍自己、拍非当前成员或拍当日已有 Team checkin 的成员。

#### Scenario: 向无今日 Team 动态的队友发送
- **WHEN** 发送者和接收者均为 Team A 当前成员，接收者当日尚无 Team A checkin，且双方未触发其他限制
- **THEN** 系统记录一条 Team A 的当日 nudge 并返回成功

#### Scenario: 不能拍自己
- **WHEN** 当前用户把自己作为接收者发送 nudge
- **THEN** 系统拒绝请求且不写入 nudge、不发送 APNs

#### Scenario: 接收者已有今日 Team 动态
- **WHEN** 接收者当日已在该 Team 产生 checkin
- **THEN** 系统拒绝请求且不写入 nudge、不发送 APNs

#### Scenario: 成员关系已失效
- **WHEN** 发送者或接收者已经退出 Team，或 Team 已解散
- **THEN** 系统拒绝请求，历史 nudge 不赋予任何访问或发送权限

### Requirement: 拍一拍写入幂等且当日去重

拍一拍写接口 SHALL 要求 `Idempotency-Key`。系统 SHALL 对同一 Team、发送者、接收者和服务端自然日最多记录一条 nudge；同一业务请求被重复提交时 MUST NOT 重复推送。

#### Scenario: 弱网重复提交同一请求
- **WHEN** 客户端使用相同 `Idempotency-Key` 重试已成功的拍一拍请求
- **THEN** 系统回放首次成功结果且不新增记录、不重复发送 APNs

#### Scenario: 使用不同幂等键重复拍同一人
- **WHEN** 发送者在同一服务端自然日、同一 Team 再次拍同一接收者但使用不同幂等键
- **THEN** 系统返回已有的当日成功状态，且不新增记录、不重复发送 APNs

### Requirement: 拍一拍限频

系统 SHALL 在所有 Team 范围内限制发送者每日最多触达 5 位不同成员，并限制接收者每日最多收到 3 条拍一拍 APNs。接收者达到 APNs 上限后，系统 SHALL 继续记录符合其他规则的 nudge，但 MUST 静默抑制 APNs，响应 MUST NOT 暴露接收者限额状态。

#### Scenario: 发送者达到每日人数上限
- **WHEN** 发送者当日已经拍过 5 位不同成员，又尝试拍第 6 位成员
- **THEN** 系统拒绝请求，并可向发送者说明自己的当日次数已用完

#### Scenario: 同一接收者跨 Team 不重复占用发送人数
- **WHEN** 发送者当日已经在一个 Team 拍过接收者，又在双方共同加入的另一个 Team 拍该接收者
- **THEN** 系统仍按一位不同成员计算发送人数，但分别执行每个 Team 的当日去重

#### Scenario: 接收者达到每日 APNs 上限
- **WHEN** 接收者当日已经有 3 条拍一拍 nudge，又收到一条符合其他规则的 nudge
- **THEN** 系统记录新 nudge 并向发送者返回成功
- **AND** 系统不向接收者发送第 4 条 APNs，也不在响应中说明抑制原因

#### Scenario: 并发请求检查配额
- **WHEN** 多个拍一拍请求并发命中同一发送者或接收者的当日边界
- **THEN** 系统串行化相关配额检查，最终记录和 APNs 数量不得突破上限

### Requirement: 接收偏好按 Team 隔离

每个 Team 成员 SHALL 可独立设置是否接收该 Team 的拍一拍，默认值 SHALL 为开启。偏好写接口 MUST 要求 `Idempotency-Key`。关闭后，系统 MUST 拒绝来自该 Team 的新 nudge，且 MUST NOT 向发送者暴露“关闭偏好”这一具体原因。

#### Scenario: 新成员默认接收拍一拍
- **WHEN** 用户创建或加入一个 Team
- **THEN** 该 Team 的接收拍一拍偏好默认为开启

#### Scenario: 关闭某个 Team 的拍一拍
- **WHEN** 用户在 Team A 关闭接收拍一拍，但在 Team B 保持开启
- **THEN** Team A 的成员暂时无法拍该用户，Team B 的成员仍可按规则发送

#### Scenario: 发送者尝试拍已关闭接收的成员
- **WHEN** 接收者已关闭当前 Team 的拍一拍
- **THEN** 系统返回通用的暂不可用错误，不写入 nudge、不发送 APNs
- **AND** 响应不说明接收者的偏好值

### Requirement: 当日状态可拉取

系统 SHALL 向当前 Team 成员提供当日 nudge 状态，包含服务端日期、当前用户今日在该 Team 已拍过的接收者 ID、当前 Team 中允许接收拍一拍的其他成员 ID，以及当前用户自己的接收偏好。响应 MUST NOT 包含其他成员的具体偏好值、被拍次数、发送者名单或历史记录。

#### Scenario: 拉取自己的当日拍一拍状态
- **WHEN** 当前成员进入 Team 详情并请求当日 nudge 状态
- **THEN** 系统返回该用户在当前 Team 今日已拍过的接收者 ID、允许接收拍一拍的其他成员 ID 和本人的接收偏好
- **AND** 系统不返回其他成员的具体偏好值或被拍统计

### Requirement: 拍一拍 APNs 内容与路由

当新 nudge 符合推送条件时，系统 SHALL 向接收者发送标题“队友拍了拍你”的 APNs，正文 SHALL 包含发送者在 Team 中的展示名和 Team 名称，payload SHALL 包含 `type=team_nudge` 与 `teamId`。通知 MUST NOT 包含“偷懒”“还没练”等对用户实际训练状态的判断。

#### Scenario: 成功发送 APNs
- **WHEN** nudge 写入成功且接收者未达到每日 APNs 上限
- **THEN** APNs 标题为“队友拍了拍你”
- **AND** 正文采用“{发送者} 在「{Team}」喊你一起练练”语义
- **AND** payload 包含 `type=team_nudge` 和对应 `teamId`

#### Scenario: APNs 凭据未配置
- **WHEN** 本地或测试环境未配置 APNs 凭据
- **THEN** nudge 业务写入仍成功，推送按既有 `PushService` 规则降级为 no-op

### Requirement: 服务端自然日口径

MVP 的 nudge 去重与限频 SHALL 使用 `Asia/Shanghai` 服务端自然日，客户端 MUST NOT 通过提交自定义日期改变配额窗口。

#### Scenario: 客户端重复修改本地日期
- **WHEN** 客户端设备日期被修改后发送拍一拍
- **THEN** 系统仍以 `Asia/Shanghai` 的服务端当前日期执行去重和限频
