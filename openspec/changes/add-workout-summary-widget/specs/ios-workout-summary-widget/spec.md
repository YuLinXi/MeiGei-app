## ADDED Requirements

### Requirement: 训练摘要 Widget 展示

iOS SHALL 提供常驻训练摘要 Widget，至少支持 small 与 medium 家族。Widget SHALL 使用纸感浅色视觉，展示今日训练状态与本周训练摘要；medium 家族 SHALL 额外展示本周 7 天节奏与最近训练摘要。Widget MUST NOT 展示 Team 数据、队友训练详情或服务端 feed。

#### Scenario: 本周已有训练
- **WHEN** 用户添加 medium 训练摘要 Widget，且本周已有完成训练
- **THEN** Widget 展示本周训练次数、训练量、组数、次数与 7 天节奏
- **AND** Widget 展示最近一条本周训练摘要

#### Scenario: 今日尚未训练
- **WHEN** 用户添加 small 训练摘要 Widget，且今天没有完成训练也没有进行中训练
- **THEN** Widget 展示今日尚未训练状态
- **AND** Widget 提供打开 App 开始训练的入口

#### Scenario: 存在进行中训练
- **WHEN** 本地存在进行中的训练会话
- **THEN** Widget 优先展示「训练进行中」与继续训练入口
- **AND** Widget MUST NOT 替代 Live Activity 承担秒级训练计时或休息倒计时

### Requirement: Widget 数据快照

主 App SHALL 将 Widget 所需的最小训练摘要写入 App Group JSON 快照。Widget extension SHALL 只读取该快照生成 timeline，MUST NOT 直接读取 SwiftData 聚合树、Keychain/JWT 或调用后端 API。快照 SHALL 被视为本机派生展示缓存，MUST NOT 作为云同步真相源或参与 last-write-wins 冲突。

#### Scenario: 主 App 写入快照
- **WHEN** 主 App 刷新训练首页摘要或训练会话状态发生变化
- **THEN** 主 App 写入包含今日状态、本周摘要、7 天节奏、最近训练与进行中训练状态的 App Group 快照
- **AND** 主 App 请求 WidgetKit 重新加载训练摘要 Widget timeline

#### Scenario: 快照缺失
- **WHEN** 用户首次安装后尚未打开 App，或 App Group 快照不可用
- **THEN** Widget 展示默认空状态
- **AND** Widget 不崩溃、不展示伪造训练数据

#### Scenario: 快照不参与同步
- **WHEN** 客户端进行训练记录同步
- **THEN** Widget 快照不上传到后端
- **AND** 同步冲突仍只依据原始同步实体处理

### Requirement: Widget 打开 App 行为

训练摘要 Widget SHALL 通过深链打开主 App 的训练区域。默认状态点击 SHALL 打开训练首页；存在进行中训练时点击 SHALL 打开或引导到当前训练会话。Widget 内 MUST NOT 直接创建、修改、完成或结束训练记录。

#### Scenario: 点击默认摘要
- **WHEN** 用户点击无进行中训练的训练摘要 Widget
- **THEN** 系统打开 DontLift 主 App 的训练区域

#### Scenario: 点击继续训练
- **WHEN** 用户点击展示进行中训练的 Widget
- **THEN** 系统打开 DontLift 主 App 并进入或引导到当前训练会话

#### Scenario: Widget 不执行写操作
- **WHEN** 用户与训练摘要 Widget 交互
- **THEN** Widget extension 不创建训练、不完成组、不结束训练、不写入 SwiftData 训练实体
