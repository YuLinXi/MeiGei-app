# 1.1 build 5 发版检查清单

## 版本、范围与当前状态

- 准备日期：2026-09-22。
- `MARKETING_VERSION=1.1`，`CURRENT_PROJECT_VERSION=5`；8 处构建配置同步递增。
- 发布基线：`v1.1-b4`（`298768d4`），用户已确认 build 4 正在使用；远端既有 tag 已取回本地。
- 候选分支：`feature/v1.1-b4`（沿用现有分支名，候选实际为 build 5）。
- 功能提交：`1a79c50`（训练交互）、`d4345cb`（认证状态码）、`9f98f75`（肩部透明图）、`f0f350a`（动作库与胸托 T 杆划船图）；版本号与三份发布文档另作准备提交。
- 用户已确认 1.1 build 5「已发 TestFlight 并验证通过」；按用户反馈记录为 TestFlight 可安装、验证通过，未独立查询 App Store Connect。
- 后端已于 2026-09-22 22:35（上海时区）部署成功，用户随后确认「Team 正常，完成收尾」。验收记录提交 `6302808` 已推送候选分支；`main` 已合并为 `ea6d1c0`，annotated tag `v1.1-b5` 指向该合并提交，二者已原子推送到 origin。
- build 5 已使用，后续修复须使用新的未占用 build 号。
- [功能介绍](release-1.1-b5-feature-intro.md) · [可直接发送的用户公告](release-1.1-b5-user-announcement.md)

## 本次范围

- 训练页历史数据异步准备，降低历史记录较多时的交互开销，保护当前训练输入。
- 休息计时与键盘交互优化。
- Team 等受保护接口的未认证响应改为 401，沿用客户端已有的登录失效处理。
- 动作库增加 Y字侧平举、单侧器械侧平举、低位坐姿划船机；按用户决定不添加动作示意图。
- 更新胸托 T 杆划船示意图；肩部肌群缩略图透明背景。

## 本地门禁

- [x] 后端：JDK 21，`./gradlew clean build test --rerun-tasks` 成功；92 项测试，0 失败、0 错误、0 跳过。
- [x] OpenSpec：`add-self-owned-exercise-demo-assets --strict` 通过；主规格 14/14 通过。
- [x] iOS Debug Simulator 构建通过；iPhone 17 Pro / iOS 26.5 全量测试 283 项通过，0 失败、0 跳过（参数化共 289 次执行）。
- [x] Git LFS 历史母版已补齐；胸托 T 杆划船完成仓库内资源发布，全局 `validate` 193 个正式运行时条目通过。此“资源发布”不代表 TestFlight 或生产部署。
- [x] `coverage`：预设 228 个，制作范围 185 个；已发布图 181 个、明确无图/跳过 4 个、草稿 0、未覆盖 0。三个新增无图动作无正式动作图，也无候选 PNG 残留。
- [x] `git diff --check` 通过。
- [x] iPhone 17 / iOS 26.4 真实动作库路径检查：以动作 code 搜索三个动作，均显示肌群图而非动作示意图；两个肩部图无灰色矩形背景；胸托 T 杆划船显示已确认新图并可进入详情。
- 用户已确认 TestFlight 总体验收通过；长历史数据的真机帧级性能数值仍未提供，作为后续专项记录，不将自动化结果冒充真机测量。

验证记录：测试结果 `/tmp/dontlift-release-b5-20260922.xcresult`，测试日志 `/tmp/dontlift-release-b5-20260922-test.log`，资源校验日志 `/tmp/dontlift-release-b5-20260922-assets.log`。本次 Debug 构建有 31 条 warning（主要为并发隔离/未来 Swift 语言模式提示），不声称零 warning；本轮未做与基线相同环境的 warning 差分。测试运行另有 LLDB 版本探测 warning，但 xcresult 最终为 Passed。保留后续治理，不扩大本次提交范围。

## 后端发布判断与顺序

**后端已部署。** 相对基线，`SecurityConfig` 新增未认证 401 入口；不是仅测试变化。数据库迁移无变化，线上 Flyway 最新版本仍为 22。

- 2026-09-22 只读线上检查：health HTTP 200、`status=UP`；Flyway 最新记录 `22|true`。
- 实际顺序：用户先完成 TestFlight 上传和验证 → 授权推送候选 → 部署前备份 → 后端部署 → 线上验证。原计划后端先发，实际 iOS 先发期间认证修复尚未生效。
- 旧版 iOS 已具备 401 登录失效处理，后端可以先发；合法登录请求与真实权限不足的 403 行为保持不变。
- 部署只使用 `backend/deploy/release-update.sh`，不得在服务器直接拉取或执行覆盖共享设施的脚本。
- [x] 部署提交：`43a2cc377122a6c61b0f3fb6e0ab149831cf456f`，包含认证修复 `d4345cb`；后端工作区无未提交改动。部署前以 checksum 对比服务器，仅认证配置及新增测试存在内容差异。
- [x] 备份：`/opt/DontLift-app/backend/backups/dontlift_2026-09-22_223327.sql.gz`，657656 字节，`gzip -t` 通过。既有 14 天保留策略清理了 `dontlift_2026-09-07_033001.sql.gz`；旧文件已删除，不能直接撤销，本次新备份已保留。
- [x] 使用 `backend/deploy/release-update.sh` 成功部署；App 于 22:35:19 创建新容器、22:35:30 完成启动。共享 PostgreSQL 和 Caddy 未重启。
- [x] 部署后连续三次 health HTTP 200 / UP，间隔 5 秒；Flyway 22 成功、22 个迁移校验通过且无需新迁移；GET/POST dev token=404、`/privacy` 与 `/terms`=200。
- [x] 未登录 `/teams` 由部署前 403 改为部署后 401；无效 JWT `/teams`=401。
- [x] 启动观察窗口无 ERROR，容器重启次数 0；有默认 UserDetailsService 配置提示和 dev token 关闭验证引发的预期 404 warning，不声称零 warning。
- [x] 部署后的真实已登录用户 Team 路径：用户确认「Team 正常」。本轮未代用用户凭据；权限不足 403 的专项覆盖未提供，不扩大该确认范围。

部署日志：`/tmp/dontlift-release-b5-backend-deploy-20260922.log`。当前镜像：`sha256:e1e36b4d6bbf756de49dd8ce3ed19672e080c14fdbd67d1a2f7dfa53580d76f7`。服务器认证配置摘要与本地一致：`f2e760fd8e5cb893b6cccc7a0a4a34f1d45020f21773629daccd47717fa0bbca`。

## iOS 上传与回归

- [x] 用户确认 build 5 已上传 TestFlight 并验证通过；上传与可用性按用户反馈记账，未独立读取 VALID 状态字段。
- [x] 用户验收总体结论：通过；后端上线后追加确认 Team 正常，并授权完成发布收尾。
- 上传准确时间、设备与 iOS 版本、逐项验证范围未提供，不推断或补造。以下是后续回归参考范围，不表示逐项已有独立证据，也不否定用户总体验收结论。
- 冷启动与 Apple 登录、旧 build 4 升级、本地训练记录保留、离线输入及恢复网络同步。
- 少量/大量历史记录下启动训练、修改重量次数、完成/撤销组、切换动作、结束训练；历史准备不得覆盖当前输入。
- 键盘展开/收起时的休息入口，前后台切换、锁屏计时、Live Activity、通知和提醒音。
- Team 页、共享计划启动、打卡；登录失效后能重新登录，已有有效会话不受影响。
- 搜索新增三个动作、添加到计划并开始训练；透明肩部缩略图与胸托 T 杆划船图显示正常。
- 历史统计、徽章、HealthKit、widget 受影响路径无回归。

## 合并后复核

- 合并提交：`ea6d1c0fc05e70c3227a76202d7223e1062919c1`。与已部署/验收候选 `43a2cc3` 比较，`backend`、`ios`、`art`、`openspec`、`tools` 均无差异；合并保留了 `main` 上 build 4 的最终发布文档。
- 后端重新执行 clean build 和测试，92 项通过，0 失败、0 错误；日志 `/tmp/dontlift-b5-merge-backend.log`。
- iOS 重新执行 Debug build 和单元测试，274 项通过（参数化共 277 次执行），0 失败、0 跳过；结果 `/tmp/dontlift-b5-merge-unit-20260922.xcresult`，日志 `/tmp/dontlift-b5-merge-ios.log`。
- OpenSpec 主规格 14/14、相关动作图 change 严格校验通过，`git diff --check` 通过；线上 health=UP、未登录 `/teams`=401。
- 本轮未重复 UI 全量测试及图片全局导出；沿用相同业务代码/资源在发版准备阶段已通过的 283 项全量测试、193 个资源校验和模拟器人工检查结果，不宣称这些项目本轮重新执行。

## 收口与回滚

- [x] 记录用户总体验收及 Team 正常结论；设备/iOS 版本未提供，保留上述证据边界。
- [x] 三份文档已回填 TestFlight、用户总体验证结果、后端部署证据和 Team 确认。
- [x] 用户授权后完成 `main` 合并、合并后复核、annotated tag `v1.1-b5` 创建及远端推送；发布收尾日期为 2026-09-22（上海时区）。
- tag 固定指向已验证合并提交 `ea6d1c0`；后续收尾记录仅修改文档，追加到 `main`，不移动 tag、不重复部署。
- 后端回滚：部署前镜像 ID 为 `sha256:29c09507cda7c70ff620583303fb202f1bf4e831c837f94e493e80bf5ac2e848`，部署后已无法通过此 ID inspect，不能承诺直接切回旧镜像。可从 `v1.1-b4` 的后端源码重建；其认证配置摘要与部署前生产一致，且本次无其他生产源码内容差异。回滚需隔离工作目录并走发布脚本，本次无数据库迁移，不执行降库。
- iOS 阻塞：停止分发候选，保留 build 4；修复后使用新的未占用 build 号重新上传，不覆盖 build 5。
