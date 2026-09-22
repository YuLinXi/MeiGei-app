# 1.1 build 5 发版检查清单

## 版本、范围与当前状态

- 准备日期：2026-09-22。
- `MARKETING_VERSION=1.1`，`CURRENT_PROJECT_VERSION=5`；8 处构建配置同步递增。
- 发布基线：`v1.1-b4`（`298768d4`），用户已确认 build 4 正在使用；远端既有 tag 已取回本地。
- 候选分支：`feature/v1.1-b4`（沿用现有分支名，候选实际为 build 5）。
- 功能提交：`1a79c50`（训练交互）、`d4345cb`（认证状态码）、`9f98f75`（肩部透明图）、`f0f350a`（动作库与胸托 T 杆划船图）；版本号与三份发布文档另作准备提交。
- 当前为本地准备阶段，尚未推送、部署、Archive 或上传；未合并 `main`、未创建 `v1.1-b5`。
- 上传前仍须在 App Store Connect 确认 build 5 未被占用；已上传的 build 号不得复用。
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
- [ ] 真机交互与长历史数据性能验收：自动化通过不替代真机结论。

验证记录：测试结果 `/tmp/dontlift-release-b5-20260922.xcresult`，测试日志 `/tmp/dontlift-release-b5-20260922-test.log`，资源校验日志 `/tmp/dontlift-release-b5-20260922-assets.log`。本次 Debug 构建有 31 条 warning（主要为并发隔离/未来 Swift 语言模式提示），不声称零 warning；本轮未做与基线相同环境的 warning 差分。测试运行另有 LLDB 版本探测 warning，但 xcresult 最终为 Passed。保留后续治理，不扩大本次提交范围。

## 后端发布判断与顺序

**需要部署后端。** 相对基线，`SecurityConfig` 新增未认证 401 入口；不是仅测试变化。数据库迁移无变化，预期 Flyway 最新版本仍为 22。

- 2026-09-22 只读线上检查：health HTTP 200、`status=UP`；Flyway 最新记录 `22|true`。
- 上述检查不代表本次后端代码已经部署。
- 顺序：候选验证与提交 → 经授权推送 → 确认数据库备份 → 经授权部署后端 → 部署后验证 → iOS Archive/上传 → TestFlight 真机回归 → 经授权合并/tag。
- 旧版 iOS 已具备 401 登录失效处理，后端可以先发；合法登录请求与真实权限不足的 403 行为保持不变。
- 部署只使用 `backend/deploy/release-update.sh`，不得在服务器直接拉取或执行覆盖共享设施的脚本。
- [ ] 部署前记录候选 commit、备份位置和时间。
- [ ] 部署后连续 health=UP、Flyway 22 成功、dev token=404、`/privacy` 与 `/terms`=200、启动日志无持续错误。
- [ ] 未登录/失效 JWT 返回 401；正常登录 Team 功能可用；真实权限不足仍返回 403。

## iOS 上传与回归

- [ ] Xcode 打开 `ios/DontLift/DontLift.xcodeproj`，选择 DontLift / Any iOS Device (arm64)。
- [ ] 确认版本/build、签名、App Group、Push Notifications entitlement。
- [ ] Product → Archive；Organizer → Distribute App → App Store Connect → Upload。
- [ ] 等待对应 build 状态为 VALID 且 TestFlight 可安装，记录上传时间。
- [ ] 冷启动与 Apple 登录、旧 build 4 升级、本地训练记录保留、离线输入及恢复网络同步。
- [ ] 少量/大量历史记录下启动训练、修改重量次数、完成/撤销组、切换动作、结束训练；历史准备不得覆盖当前输入。
- [ ] 键盘展开/收起时的休息入口，前后台切换、锁屏计时、Live Activity、通知和提醒音。
- [ ] Team 页、共享计划启动、打卡；登录失效后能重新登录，已有有效会话不受影响。
- [ ] 搜索新增三个动作、添加到计划并开始训练；透明肩部缩略图与胸托 T 杆划船图显示正常。
- [ ] 历史统计、徽章、HealthKit、widget 受影响路径无回归。

## 收口与回滚

- [ ] 记录实际设备、iOS 版本、测试结论及阻塞问题。
- [ ] 回填三份文档的部署、TestFlight、真机回归状态。
- [ ] 全部门禁通过并经用户授权后，才合并 `main` 和创建 annotated tag `v1.1-b5`。
- 当前不要打新 tag；本次准备不代表发布完成。
- 后端回滚：记录部署前实际生产 commit，恢复该已验证版本；本次无数据库迁移，不执行降库。
- iOS 阻塞：停止分发候选，保留 build 4；修复后使用新的未占用 build 号重新上传，不覆盖 build 5。
