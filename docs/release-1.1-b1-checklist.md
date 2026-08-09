# v1.1-b1 发版 Checklist

> 发布基线：`v1.0-b21`
> 目标版本：`1.1 (build 1)`
> 候选分支：`feature/v1.1-b01`
> iOS 候选源码 SHA：`1b66e16cc2e4476a8998b910e6ebaee24de99326`
> 当前结论：**暂不可发布**
> 功能介绍：[release-1.1-b1-feature-intro.md](release-1.1-b1-feature-intro.md)

## 0. 当前发布摘要

| 项目 | 状态 | 说明 |
| --- | --- | --- |
| 发布范围 | ✅ 已冻结并推送 | iOS 候选源码为 `1b66e16`；后续仅提交发版记录，不改变 App 代码或资源 |
| 版本号 | ✅ 已更新 | App、Widget 与测试 target 均为 `1.1 (build 1)` |
| 后端部署 | ✅ 不需要 | 没有后端运行时代码、配置、API 或 Flyway 迁移 |
| 后端验证 | ✅ 通过 | 80 项测试通过；生产 health 与 Flyway 只读检查正常 |
| iOS 构建与测试 | ✅ 通过 | `1.1 (build 1)` 下 216 项测试通过，Release Simulator 构建成功 |
| 动作图门禁 | ✅ 通过 | 远端 fresh clone 已完成 LFS、193 张 JPG 确定性重导出、manifest 对照及 Release 构建 |
| 人工回归 | ⚠️ 部分通过 | 休息继承 Simulator 全场景通过；动作历史、计划详情、海报、日历和兼容性待真机验证 |
| TestFlight | ⚠️ 签名阻断 | Archive 成功，但 App Store export 因 Xcode 凭据失效且缺少 `iOS Distribution` 证书失败；未上传 |
| 发布 tag | ⏳ 禁止创建 | 仅在 TestFlight `VALID` 且真机回归完成后创建 `v1.1-b1` |

## 1. 发布范围与冻结

- [x] 已确认最近一个完成 TestFlight/生产发布并打 tag 的基线为 `v1.0-b21`。
- [x] 已按 `v1.0-b21...当前工作区` 盘点最终用户行为，不使用分支起点或单个中间 commit 作为发布基线。
- [x] 已确认目标版本为 `1.1 (build 1)`，目标 tag 为 `v1.1-b1`。
- [x] 已生成本 Checklist 与[发版功能介绍](release-1.1-b1-feature-intro.md)。
- [x] 已将 `REVERSE_LAT_PULLDOWN`、`CLOSE_LAT_PULLDOWN` 别名目标更新为当前标准名，并保留旧名称解析。
- [x] 已恢复 `v1.0-b21` 发布过的「器械上拉」预置动作；当前使用肌群图降级，不伪造未审核动作图。
- [x] 已将所有 App、Widget 与测试 target 的 `MARKETING_VERSION` 改为 `1.1`，`CURRENT_PROJECT_VERSION` 改为 `1`。
- [x] 已重新检查候选 diff，确认没有密钥、临时文件、个人绝对路径或无关改动进入 iOS 候选源码。
- [x] 已提交并推送全部确认范围，冻结 TestFlight iOS 候选 SHA `1b66e16cc2e4476a8998b910e6ebaee24de99326`。
- [x] 已在候选 SHA 验证后更新本次两份发版文档；后续仅记录验证与发布状态，不改变 App 代码或资源。

## 2. 本次功能范围

### 动作库与动作数据

- [x] 动作库双列图片卡片及本地图片优先展示已实现。
- [x] 当前运行时 manifest 含 193 张正式动作图。
- [x] 225 个预置动作中 182 个纳入专属图范围：181 个已发布正式图，1 个「器械上拉」已记录跳过并使用肌群图降级；43 个按功能性、热身拉伸或自重核心规则排除。
- [x] 已加入「绳索直立划船」「掌心向上哑铃侧平举」。
- [x] 已调整核心动作命名，并为「卷腹」保留既有历史兼容记录。
- [x] 别名目标名与当前标准名一致，动作库数据校验通过。
- [x] 相对 `v1.0-b21` 仅「卷腹」停止新选，并保留历史原名；「器械上拉」已恢复。

### 训练计划与训练中交互

- [x] 计划详情统一展示下一次真实训练安排。
- [x] 训练中新增普通组、递减组和超级组时按同动作、同结构已完成历史预填。
- [x] 一级训练单元达到 2 个即可排序，超级组整体移动。
- [x] 海报完整展示全部动作，超过 6 个动作时使用紧凑双列布局。
- [x] 日历相邻月份选日时禁用错误的选中状态跨网格动画。

### 休息目标

- [x] 最终休息目标与实际休息时长分别保存。
- [x] 相同动作下一组和超级组下一轮可继承最近完成项的最终目标。
- [x] “继续休息”分别累计目标时长与实际时长。
- [x] 普通动作默认休息随 `WorkoutUnit` JSON 保存并保持后端透传兼容。
- [x] OpenSpec `stabilize-rest-target-inheritance` 的 Simulator 人工回归任务 4.3 完成。

## 3. 自动化验证

### OpenSpec

- [x] `openspec validate add-self-owned-exercise-demo-assets --strict`
- [x] `openspec validate add-dynamic-workout-poster-backgrounds --strict`
- [x] `openspec validate restore-workout-unit-history-prefill --strict`
- [x] `openspec validate stabilize-rest-target-inheritance --strict`

### 动作数据与动作图

- [x] 动作图严格校验通过：193 个正式运行时条目。
- [x] 覆盖率校验通过：225 个预置动作，182 个纳入专属图范围，181 个已发布，1 个已记录跳过，0 个草稿或未覆盖。
- [x] `node scripts/exercise-library-v1.mjs validate` 通过。
- [x] 动作库真路径加载、连续 80 次滚动与峰值内存检查完成；宿主 RSS 峰值约 460.3 MiB，memgraph 物理占用峰值 168.6 MiB，未发现 App 自有类型泄漏。
- [x] 已从 GitHub 远端 `feature/v1.1-b01` 全新 clone；`git lfs fsck` 通过，193 张正式 JPG 可由批准母版确定性重导出并与 manifest 一致，干净目录 Release Simulator 构建通过。
- [x] 运行时正式 JPG 193 张、入包 2.82 MiB；Release Simulator App 为 42.54 MiB。相对 `v1.0-b21` 的完整候选 Debug App 增量约 28.48 MiB，其中动作 JPG 仅占 2.82 MiB。
- [x] 新增高分辨率 PNG 均命中路径限定 Git LFS；远端 fresh clone 的 `git lfs fsck` 通过并完成可用性验证。
- [x] 动作库生成器增加防缩减门禁：来源文档当前只能生成 188 条时会拒绝覆盖现有 225 条 manifest；该工具债不影响已校验的运行时数据。

### 后端

- [x] 使用 JDK 21 执行 `./gradlew clean build`，通过。
- [x] 执行 `./gradlew test --rerun-tasks`，80 项测试通过，0 失败、0 错误、0 跳过。
- [x] JSON 透传测试覆盖新增的可选默认休息字段。
- [x] 已确认候选工作区没有后端运行时代码、配置或数据库迁移变更。
- [x] Gradle 现有 deprecation warning 已记录，本次不阻塞发布。

### iOS

- [x] 在 Xcode 26.4、iPhone 17 Pro Simulator（iOS 26.4.1）上执行签名关闭的 Debug build，`BUILD SUCCEEDED`。
- [x] `1.1 (build 1)` 下执行 iOS 测试，216 项测试通过，0 失败、0 跳过；UI tests 6 项通过。
- [x] 已记录 Simulator 调试器版本与重复 accessibility class 警告，未造成测试失败。
- [x] App 与 Widget 构建产物均读取为 `1.1 (build 1)`；工程内 8 组 build configuration 均已更新。
- [x] 使用 Release 配置完成签名关闭的 Archive 前 Simulator 构建检查；31 条现有 Swift 6 迁移 warning 不阻塞本次构建。

### 通用检查

- [x] 修改发版文档前执行 `git diff --check`，通过。
- [x] 冻结候选后已执行 `git diff --check`，通过。
- [x] 已检查签名：`1.1 (1)` 的设备版 Archive 成功，App 使用 Apple Development 身份；App Store export 预检因 Xcode Keychain 凭据失效且没有 `iOS Distribution` 证书失败，未执行上传。

## 4. 后端生产状态

本次是 iOS-only 发布，不执行后端部署。

- [x] 生产 `/actuator/health` 连续 3 次返回 `UP`。
- [x] 生产 `/privacy`、`/terms` 返回 200。
- [x] 生产 `POST /auth/dev/token` 返回 404，开发 token 未开启。
- [x] 生产 Flyway 最新记录读取正常，`V16` 至 `V20` 均为成功状态，最新为 `V20__team_member_preferences_default_enabled.sql`。
- [x] 已确认旧版 `v1.0-b21` 不需要等待新后端即可继续使用现有 API。
- [ ] 发版当天再次执行一次只读 health 检查并将时间、响应写入发版记录。

## 5. TestFlight 前人工回归

### 动作库与历史兼容

- [ ] 冷启动进入动作库，确认 193 张正式图片可随包读取，断网后仍正常展示。
- [ ] 连续滚动全部分类并观察内存、掉帧、图片错位和复用闪烁。
- [ ] 搜索、筛选并打开两个新增肩部动作。
- [ ] 检查四个调整后的核心动作名称和动作详情。
- [ ] 打开包含「卷腹」和其他改名/下架动作的旧训练记录，确认名称、统计和详情可正常解析。
- [ ] 按最终产品决定验证「器械上拉」仍可选择，或旧历史能通过兼容记录展示。

### 计划详情

- [ ] 展开自适应计划动作，核对历史、预设、默认和保留值来源文案。
- [ ] 展开严格计划动作，核对普通组、热身组、递减段和自重动作语义。
- [ ] 从计划实际开始训练，逐项对比展示安排与生成的训练单元一致。
- [ ] 验证默认收起、单卡展开和更多菜单操作。

### 训练历史预填与排序

- [ ] 新增普通组，只读取同一动作最近已完成的普通组历史。
- [ ] 新增递减组，只读取同一动作最近已完成的递减结构历史。
- [ ] 未完成记录、不同动作或不同结构不会错误预填。
- [ ] 新建相同和反向顺序的超级组，确认优先复用相同动作组合的轮数与成员参数。
- [ ] 两个一级单元即可排序；超级组移动后内部成员顺序和数据保持不变。

### 休息目标

- [x] Simulator：调整 `+10/-10` 后自然结束，下一组相同动作继承最终目标。
- [x] Simulator：调整后提前结束，下一组仍继承最终目标，实际休息时长独立记录。
- [x] Simulator：“继续休息”按最终目标恢复，目标时长和实际时长分别记录。
- [ ] 新动作没有相邻完成组时，按动作默认值、全局默认值、90 秒顺序回退。
- [x] Simulator：超级组第一轮从 90 秒调整到 100 秒后提前结束，第二轮以 100 秒启动。
- [ ] 最小化 App、重建训练页面和同步恢复后，普通动作默认休息仍存在。

### 海报、日历与核心路径

- [ ] 生成超过 6 个动作的训练海报，预览、保存和系统分享结果均完整且一致。
- [ ] 在日历中选择相邻月份日期，确认月份切换后选中状态稳定。
- [ ] 完成登录、动作库、创建计划、开始训练、完成训练、历史详情和 Team 读取冒烟。
- [ ] 使用 `v1.0-b21` 客户端连接当前生产后端完成登录、拉取和同步兼容检查。

## 6. TestFlight 上传

- [x] 候选 SHA 已冻结，工作区干净，版本号为 `1.1 (build 1)`。
- [x] Xcode Archive 成功，Archive 中 App 与 extension 的版本号均为 `1.1 (1)`；当前 Archive 为 Apple Development 签名，尚不能导出 TestFlight 包。
- [ ] 上传 App Store Connect/TestFlight 成功。
- [ ] 构建处理完成，状态为 `VALID`，无 ITMS 阻塞警告。
- [ ] 在 TestFlight 安装该构建，确认版本页显示 `1.1 (1)`。
- [ ] 完成本清单第 5 节真机回归，并记录设备型号与 iOS 版本。
- [ ] 更新[发版功能介绍](release-1.1-b1-feature-intro.md)中的 iOS 上传状态和已完成验证。

## 7. 合并、tag 与发布记录

- [ ] TestFlight 构建已确认可安装，真机冒烟与重点回归完成。
- [ ] 候选分支合并 `main`，合并后再次确认目标 SHA。
- [ ] 在最终发布 SHA 创建 tag `v1.1-b1`。
- [ ] 推送 tag，并确认 GitHub 上 tag 指向正确提交。
- [ ] 将 TestFlight 构建、提交 SHA、tag、验证设备、已知限制和发布时间写入发版记录。
- [ ] 若发版后发现阻塞问题，优先停止测试分发并递增 build 修复，不复用或移动已发布 tag。

## 8. 发布负责人结论

候选 iOS 源码 `1b66e16` 已推送并完成干净环境验证，已具备进入 TestFlight 上传的条件，但仍不得创建 `v1.1-b1` tag。最短收口顺序：

1. 在 Xcode 恢复 Apple Developer 登录态，取得 App Store 分发所需身份后重新导出并上传 TestFlight，等待构建状态为 `VALID`。
2. 完成真机重点回归和上一版客户端兼容冒烟。
3. TestFlight `VALID` 且真机回归通过后，再合并 `main` 并创建 `v1.1-b1` tag。
