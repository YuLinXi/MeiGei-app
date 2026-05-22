## Context

MeiGei 是全新的 iOS 原生健身 App + Java 后端，无既有代码。MVP 由 1-2 人开发，需在有限工期内交付训练记录、饮食记录、Team 共享三大模块。本设计经过一次外部第二意见（Codex）评审，核心结论是「收窄技术面、明确数据真相来源、离线优先」。技术栈已锁定（见 `openspec/config.yaml`），本文档聚焦数据模型、同步、关键架构决策的取舍。字段级 ER 图与 DDL 草案见同目录 `data-model.md`（Flyway 基线迁移设计稿）。

## Goals / Non-Goals

**Goals:**
- 确立离线优先的数据流与单一真相来源，避免本地/服务端双算导致的不一致。
- 给出一套从 day1 就可扩展登录方式、可软删除、可幂等重试的数据模型。
- 明确训练计划（jsonb 文档）与训练记录（规范化表）的存储分界。
- 用最低复杂度实现「轻实时」（打卡/表情回应）：APNs + 进页面拉取。
- iOS 端在 SwiftData 之上自建同步，规避其早期成熟度与 CloudKit 自动同步风险。

**Non-Goals:**
- 不设计 WebSocket、不设计独立 WatchKit App、不设计 LLM/图像识别。
- 不设计字段级冲突合并；不设计公开计划广场。
- 不在 MVP 持久化大量派生统计（PR/曲线/营养汇总以重算为主）。

## Decisions

### D1. 身份三层模型，而非 Apple sub 直作主键
`user`（业务主体，雪花/UUID 主键）—`user_identity`（provider=apple, provider_user_id=sub, email）。所有业务表外键指向 `user.id`。
- 理由：未来加手机号/微信只需新增 `user_identity` 行，零业务数据迁移。
- 备选：直接用 Apple sub 作主键——被否，扩展登录方式时全库重构。

### D2. 离线优先 + 客户端为编辑真相
训练/饮食/自定义食材的编辑真相在客户端本地（SwiftData），写操作先落本地、异步同步；服务端存最终快照 + 软删除。Team 可见数据以服务端为准（队友数据本就来自服务端）。
- 同步对象统一携带 `serverId / localId / updatedAt / deletedAt / version`，本地另有 `syncStatus` 与重试队列。
- 理由：健身房弱网高频，记录绝不能因网络丢失。

### D3. 冲突 last-write-wins + 人工提示
按 `updatedAt` 取较新者覆盖，并提示用户旧修改被覆盖；不做字段级 merge。
- 理由：单用户多设备场景冲突极少，复杂 merge 投入产出比低。

### D4. 写接口幂等
所有写接口接受 `Idempotency-Key`（客户端用 `localId` 派生），服务端记录键→结果映射，重复请求返回首次结果。
- 理由：离线重试 + 弱网超时必然产生重复提交。

### D5. 训练计划用 jsonb，训练记录用规范化表
- 计划模板：`workout_plan` 表的 `items jsonb` 存有序动作列表，每项含稳定 `itemId`、动作引用、建议组数/次数/重量。Fork = 复制该 jsonb（+ 记 `forked_from` 软指针）。
- 训练记录：`workout` / `workout_set` 规范化多表，便于历史曲线、PR、容量统计的聚合查询。
- 理由：模板是可变结构文档、整体读写；记录需跨维度统计。备选「全规范化计划」被否（Fork 要操作多表、复杂）。

### D6. 轻实时 = APNs + 进页面拉取
打卡、表情回应通过 APNs（Pushy，.p8 token 认证）推送；客户端进入 Team 页时拉取最新打卡列表。不建长连接。
- 理由：Team ≤10 人、事件稀疏，长连接的断线重连/鉴权续期不划算。

### D7. SwiftData 仅本地，禁用 CloudKit 自动同步；最低 iOS 17.4+
云同步完全走自建后端 API；不开 `NSPersistentCloudKitContainer`。发版最低 iOS 17.4 以规避 SwiftData 早期版本问题。
- 理由：自建后端 + SwiftData 自动同步两套平面会复杂度翻倍且难调试。

### D8. Live Activity 承载 Watch 体验，海报客户端生成
休息计时用 ActivityKit Live Activity，配对 Watch 经 Smart Stack 呈现 + App Intent 按钮，不写独立 Watch App。海报由客户端用训练数据本地渲染，服务端只给结构化数据。
- 理由：以最小工作量覆盖 Watch 与分享两个诉求。

### D9. 食物库分层存储与合规自建
内置 ~1500 条标准食材随包发布（只读，离线 sqlite/SwiftData seed）；用户自定义食材入主数据库并云同步，标记来源 `standard|personal`，个人项不进标准库首屏、不跨用户共享。
- **数据来源（合规决策）**：MVP 采用「自建基础库」路径——从公开来源逐条采集单条营养事实（客观事实不受著作权保护），由本项目自行完成食材的选择与编排，形成自有汇编。MUST NOT 整表照搬《中国食物成分表》的选择+编排+成套实测值，MUST NOT 使用未授权的第三方转录（如无 LICENSE 的 GitHub OCR 数据集）。
- **标识措辞**：内置库标为「标准库」而非「官方/权威」；可注明「参考《中国食物成分表》及公开来源整理」，但不得宣称为官方成分表。
- **升级路径**：PMF 后再向版权方（北京达邦数据技术有限公司 / 北大医学出版社）购买正式授权，届时可坐实「权威」表述。

## Risks / Trade-offs

- [SwiftData 早期成熟度 / 迁移坑] → 最低 17.4+；SwiftData 只承载本地数据，复杂查询/统计在内存或服务端重算，避免重度依赖其迁移与关系删除规则。
- [自建同步比 BaaS 工作量大] → 用统一的同步字段与 last-write-wins 把复杂度压到最低；MVP 单用户多设备冲突罕见。
- [仅 Apple Sign-In 的扩展与账号恢复弱] → 身份三层模型预留扩展；持久化首登邮箱；实现撤销回调满足审核。
- [《中国食物成分表》商用授权不清晰] → 上线前确认数据来源授权，必要时仅取公开营养成分字段并注明来源。
- [Java/Spring 冷启动慢、内存重] → 选不休眠的低配实例；MVP 流量小无性能压力。
- [jsonb 计划项无稳定 id 会导致编辑/Fork/diff 困难] → 强制每个动作项带 `itemId`（spec 已约束）。

## Migration Plan

全新项目，无数据迁移。部署顺序：
1. 后端：建库 + Flyway 基线迁移 + Docker 镜像 + 部署到目标平台，配置 Apple 私钥（登录校验、APNs .p8）。
2. iOS：配置 Sign in with Apple、HealthKit、Live Activity capability；内置食物库 seed 打包。
3. 回滚：后端按 Flyway 版本回退；客户端经 TestFlight 灰度，问题版本下架。

## Resolved Questions

- **食物库数据来源（已定）**：采用自建基础库路径，从公开来源采集单条营养事实并自行编排，规避《中国食物成分表》整表照搬的著作权风险（详见 D9）。不打「官方/权威」招牌，改用「标准库」表述。授权采购作为 PMF 后的升级项。
- **业务主键（已定）**：采用 UUID v7。客户端可离线预生成，使 `localId` 与 `serverId` 一致，省去本地/服务端 id 映射对账，契合离线优先与幂等设计（D2/D4）。

## Open Questions

- 海报模板的视觉风格（Nike/Keep/极简）待界面设计阶段定稿（非阻塞）。
