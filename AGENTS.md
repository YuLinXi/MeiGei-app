# AGENTS.md

## 语言与范围

- 交流、文档和新增代码注释使用简体中文；技术术语、API 和代码标识符保留英文。
- 常规开发按本次改动选择验证范围；发版、性能分析、真机验收是独立任务，不自动附加到每次功能开发。

## 项目与规格

别练了（Don't Lift，代号 DontLift）是一款 iOS 原生健身 App，核心是训练记录与 Team 共享。

- `backend/`：Java 21 + Spring Boot + MyBatis-Plus + PostgreSQL + Flyway。
- `ios/DontLift/`：SwiftUI + SwiftData，包含主 App、widget extension 和测试 target。
- 改动业务行为时，读取 `openspec/specs/` 下相关规格；若任务属于 active change，再读取对应 `openspec/changes/<change>/` 的 proposal、design、specs 和 tasks。归档 change 是历史依据，不作为全项目当前规格入口。
- 饮食模块已移除，不按历史文档恢复。

## 常规开发的验证策略

选择能验证本次改动的最小充分检查，而不是固定执行 build、全量测试、启动 App、截图的整套流程。

| 改动 | 默认验证 |
| --- | --- |
| 文档、注释、Agent 规则 | 检查内容、路径和 `git diff --check`，无需启动模拟器 |
| iOS 源码、资源、构建配置 | 一次不启动模拟器的编译；测试配置或测试源码可用 `build-for-testing` 检查编译 |
| 业务逻辑、持久化、同步等行为变化 | 运行覆盖受影响行为的定向测试；修复缺陷优先添加能复现问题的回归用例 |
| 布局、手势、导航等交互 | 编译后，按风险选择相关 UI 用例或实际交互检查；不能用只启动 App、截图代替行为验证 |
| 仅后端改动 | 使用 `./gradlew` 运行相关后端测试，不触发 iOS 验证 |
| 跨模块高风险改动、发布候选或明确要求全面回归 | 扩大到相关测试套件；发布候选按发布流程验证 |

- `xcodebuild test` 已包含编译；决定运行测试时，不必先单独 build。同一候选的有效检查结果可复用；仅在新改动、失败或未解决疑点出现时重跑或扩大范围。
- 测试失败先区分产品问题与环境问题，再针对原因处理；不通过反复重启、创建模拟器或重跑全套测试碰运气。
- 交付时区分编译、单元/集成测试、UI 测试、端到端验证与真机验收，说明实际覆盖和未验证项。编译成功、零用例命中、用例跳过都不等于行为测试通过。

## 模拟器使用约定

- 编译使用 `-destination 'generic/platform=iOS Simulator'`，无需 boot、安装 App 或打开 Simulator 窗口。
- 确需运行测试时，优先复用已启动且兼容的模拟器；没有时选择一个现有设备并启动一次。记录 UDID，后续命令固定 `-destination 'platform=iOS Simulator,id=<UDID>'`，避免同名设备或不同 runtime 混用。
- 测试串行运行，使用 `-parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1`；共享 scheme 的测试并行也保持关闭。保留编译并行，它不等于模拟器测试并行。同一设备已有其他测试任务时先等待，不另开副本抢跑。
- 普通定向测试使用 `DontLiftTests` scheme 和 `-only-testing`；需要 UI 行为验证时才选择 `DontLiftUITests` 中的具体用例。仅需后台测试时不主动打开 Simulator 窗口。
- 一轮验证结束后保留设备供后续复用，不默认 shutdown、erase、delete 或 `killall Simulator`。确诊环境故障需要重启时，仅处理本任务设备并说明原因；清理或重置设备数据需用户明确要求。

当前 `DontLiftTests` 使用 App 作为宿主，执行单元测试也需要运行环境。测试期间 App 的启动/退出不等于端到端测试；只有实际操作目标流程并断言结果，才报告相应流程已验证。具体命令与现有测试边界见 [开发与验证指南](docs/development.md)。

## 架构边界

- SwiftData 仅作本地存储，CloudKit 保持关闭；同步域遵循离线优先、显式同步与 LWW。Team 共享数据由服务端裁决，不混入客户端权威同步域。
- 业务用户与登录提供方身份分离；JWT 存 Keychain。沿用现有 UUID v7、幂等键和 ProblemDetail 错误约定。
- 修改同步实体时核对信封字段、软删墓碑和增量水位；修改 workout 时按聚合处理子树。新增数据库变更追加 Flyway 迁移，不改已发布迁移。
- 主 App 的 Swift 文件由文件系统同步分组自动纳入 target；widget 共享文件需核对两端 target membership。

## 按任务读取

- 配置本地环境、调整后端/iOS 架构、运行测试或排查构建：读取 [开发与验证指南](docs/development.md) 对应章节，具体版本和状态以当前配置为准。
- 准备、执行或收口发版：使用 [release-dontlift](.codex/skills/release-dontlift/SKILL.md)。发布基线、门禁、checklist、功能介绍与用户公告统一在该 skill 维护。
- 制作、替换、审核或发布动作图：使用 [produce-exercise-artwork](.codex/skills/produce-exercise-artwork/SKILL.md)。
- 待办与验收状态从相关 change 的 tasks 和本次发布记录核对，不在本文件维护易过期的数量或完成状态。
