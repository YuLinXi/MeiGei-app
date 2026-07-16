# Review 与自动化验收标准

所有阻断门禁必须产生机器可读退出码和可下载证据。自动重试不得掩盖 flaky test；偶发失败需要先分类和修复。

## 阻断门禁

| ID | 阶段 | 自动化检查 | 通过标准 |
|---|---|---|---|
| G0 | Release PR | 分支/工程/文档/Tag 版本一致，工作区干净 | 所有版本唯一且匹配；目标 Tag 不存在 |
| G1 | Review | PR review、conversation、敏感文件与 secret 检查 | 至少 1 个有效 approval；`P0/P1=0`；无凭据入库 |
| G2 | Spec | `openspec validate --all --strict --no-interactive`；检查本次 change 的 tasks | strict 通过；本次已实现任务无未解释的 `[ ]/[~]` |
| G3 | Backend | `./gradlew build`、Docker build、Flyway immutability/risk scan | test 0 failure；镜像可构建；旧 migration 未修改/删除；无未批准破坏性 SQL |
| G4 | iOS | simulator build/test、Release archive、IPA 元数据检查 | test 0 failure；skip 必须有说明；archive/IPA version、build、bundle ID 正确 |
| G5 | Compatibility | API/DTO/同步 JSON/migration review | 上一 TestFlight 客户端可继续登录、同步和读取；不兼容变更退出自动通道 |
| G6 | Backend deploy | DB 备份、远程构建、Flyway、连续 health | 备份成功；最新 migration `success=true`；health 连续 3 次 `UP` |
| G7 | Production security | dev token、HTTPS、隐私政策、服务条款 | dev token `404`；三个 HTTPS URL 均 `200`；法务 URL 不相同 |
| G8 | TestFlight | 签名、上传、Apple processing、内部组分发 | processing=`VALID`；version/build/bundle 精确匹配；内部组自动分发已启用 |
| G9 | Finalize | Tag、GitHub Release、证据链接 | Tag 指向发布 SHA；两份文档和 workflow 证据可访问 |

## 发布 Review 清单

Review 必须针对“上一 Tag 到候选提交”的完整 diff，至少覆盖：

1. **正确性**：边界值、状态恢复、幂等、离线重试、日期/时区、并发与 actor 隔离。
2. **数据安全**：SwiftData/同步实体的 `localId/serverId/updatedAt/deletedAt/version` 语义，软删墓碑，聚合子树替换，历史数据兼容。
3. **API 兼容**：旧字段仍可读、旧 endpoint 保留、枚举新增有未知值策略、JSON 字符串二次编解码不变。
4. **数据库**：既有 Flyway 文件不可修改；`DROP/TRUNCATE/RENAME/ALTER TYPE/SET NOT NULL` 等进入人工审批通道；大表回填需评估锁和回滚。
5. **安全与隐私**：生产 dev token 默认关闭；JWT/APNs/Apple Key 不落日志；账号删除、法律链接、HealthKit 隐私声明不回归。
6. **iOS 发布**：App/Widget entitlement、App Group、Release 线上 URL、出口合规声明、主 target 与 extension build 一致。
7. **运维**：新后端必须兼容旧 TestFlight；失败时旧容器/镜像仍可恢复；migration 失败有前向修复路径。

Finding 分级：

- `P0`：会造成数据丢失、凭据泄露、生产不可用、错误账号数据串用。必须阻断。
- `P1`：核心训练/同步/登录/Team/发布路径高概率错误。必须阻断。
- `P2`：非核心缺陷或可观察性不足。默认修复；明确接受时写入 checklist。

## 自动化测试标准

- Backend 必须使用仓库 `./gradlew` 和 Java 21，运行完整 `build`，不能以 `build -x test` 代替。
- iOS 必须使用 Xcode 26 正式版，运行 `DontLift` scheme 的 unit + UI tests，并保留 `.xcresult`；签名 archive 是独立门禁，不能用 simulator build 代替。
- 改动行为必须有对应回归测试。当前仓库尚未建立稳定 coverage baseline，因此不虚构百分比阈值；建立 baseline 后采用“总覆盖率不下降 + 改动代码覆盖”策略。
- 测试失败不得自动重跑后按成功处理。若确认平台性偶发问题，先保留第一次失败证据，再通过专门的 quarantine 规则处理。
- OpenSpec strict validation 与代码测试都要通过；两者不能互相替代。

## 后端部署验收

现行生产路径为 `backend/deploy/release-update.sh`，不是 `backend/fly.toml`。自动化必须保留其安全顺序：

1. migration 前备份 `dontlift` 数据库；
2. 保护 `.env.prod`、`secrets/`、`backups/`；
3. 重建并启动 `dontlift-app`，不重启共享 PostgreSQL/Caddy；
4. 公网 HTTPS health 为 `UP`；
5. 本地最新 Flyway migration 在线上为 `success=true`；
6. 再执行 dev token 和法务页探针。

若新应用 health 失败，优先恢复上一应用镜像。数据库已经执行的 migration 不自动回滚；只有 schema 向前/向后兼容证据充分时才恢复旧应用，否则停止并报告事故。

## TestFlight 验收

TestFlight 自动化不是“调用上传命令后返回 0”即可。必须验证：

- signed archive 和导出的 IPA 均来自发布 SHA；
- `CFBundleIdentifier=com.yulinxi.app.DontLift`；
- `CFBundleShortVersionString`/`CFBundleVersion` 与 Release PR 一致；
- `manageAppVersionAndBuildNumber=false`；
- Apple processing 最终为 `VALID`，不是 `PROCESSING`；
- App Store Connect 内部测试组启用 automatic distribution；
- `ITSAppUsesNonExemptEncryption=false` 与当前系统标准加密事实一致。

外部 TestFlight 可能触发 Beta App Review，不纳入“确定时长的全自动成功”定义。默认通道只发布内部测试组。

## 真机覆盖边界

以下能力无法仅凭 GitHub Hosted macOS runner 和 Simulator 证明，必须在功能介绍中列为 TestFlight 真机回归重点：

- 真 Sign in with Apple 登录/续期/删号授权撤销；
- APNs 生产真实投递、双账号 Team reaction；
- HealthKit 授权与读写；
- Live Activity、锁屏、灵动岛、本地通知、声音和触觉；
- Widget 主屏刷新、深链和系统生命周期行为；
- Apple Watch Smart Stack 条件验证。

这些项目不阻断把候选 build 发布到内部 TestFlight，因为 TestFlight 正是其验收载体；它们必须阻断 App Store 正式提交，除非已有真实设备自动化平台输出可审计证据。
