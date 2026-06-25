## ADDED Requirements

### Requirement: 同步写入时间偏移防护

服务端 SHALL 在每次同步 push 时校验客户端上传实体的 `updatedAt` 与服务端当前时间的偏移。服务端 MUST NOT 持久化明显超前于服务端时间的 `updatedAt` 作为 LWW 比较基准。对超出容忍窗口的时间戳，服务端 SHALL 使用服务端接收时间作为有效更新时间，或将该项作为冲突返回，并在响应中告知客户端发生时间校正。

#### Scenario: 客户端未来时间被校正
- **WHEN** 客户端上传的 `updatedAt` 明显晚于服务端当前时间
- **THEN** 服务端不保存该未来时间
- **AND** 服务端使用服务端接收时间或返回冲突
- **AND** 响应包含时间校正提示

#### Scenario: 正常时间不受影响
- **WHEN** 客户端上传的 `updatedAt` 位于容忍窗口内
- **THEN** 服务端按现有 LWW 规则比较并处理该实体

#### Scenario: 慢时钟上传不静默覆盖较新服务端值
- **WHEN** 慢时钟设备上传的实体会覆盖服务端已有较新版本
- **THEN** 服务端按冲突返回服务端当前值，而不是静默覆盖

### Requirement: 同步响应暴露服务端时间与校正通知

同步 push/pull 响应 SHALL 继续返回 `serverTime` 作为客户端下次增量水位。若本次 push 中任一实体被服务端校正时间戳，响应 SHALL 包含可由客户端展示或记录的校正通知，至少标识实体 id、同步域和校正后的服务端时间。

#### Scenario: push 返回校正通知
- **WHEN** 服务端校正了某个 workout 的未来 `updatedAt`
- **THEN** push 响应包含该 workout id 与校正后的时间

#### Scenario: 客户端保存服务端水位
- **WHEN** pull 成功返回 `serverTime`
- **THEN** 客户端以该服务端时间作为下次 `since` 水位，而不是使用本机当前时间

### Requirement: 既有未来时间数据修复

系统 SHALL 在迁移或启动修复流程中检测同步实体表中明显晚于服务端当前时间的 `updated_at`。检测到的未来时间 MUST 被校正到不晚于修复执行时刻，并记录日志以便排查设备时钟问题。修复 MUST 保留 `deleted_at` 墓碑语义和实体归属。

#### Scenario: 修复未来 updated_at
- **WHEN** 数据库中存在 `updated_at` 晚于服务端当前时间的同步实体
- **THEN** 修复流程将其校正到不晚于修复执行时刻
- **AND** 实体仍保留原有主键、归属用户、删除墓碑和版本信息

#### Scenario: 无异常数据不改写
- **WHEN** 数据库中同步实体时间均未明显超前
- **THEN** 修复流程不改变这些实体
