# 训练进行页性能优化与验证（2026-09-18）

## 交付状态

已实现后台历史快照、进行中保存的徽章失效分类、串行音频执行、局部历史等待与重试、浮层观察隔离、完成操作统计合并和 Live Activity 相同快照去重。REST、同步 DTO、SwiftData 持久化字段、正常用户配置与 300ms 保存防抖不变。

模拟器已验证主要根因消除和数据一致性。**处理函数耗时与 `onAppear` 时间不是端到端可见反馈延迟；本报告不把它们视为全部性能目标已验收。** 尚需补齐逐帧触摸到显示测量、所有交互的完整采样矩阵，以及真机 Release／TestFlight 验收。

## 实现

1. `BadgeWallStore.saved` 只按保存通知中的变更标识判断所属训练。明确归属到进行中训练的更新和插入不会清除历史缓存。结束、已完成历史修改、软删除、计划修改继续失效；物理删除、未知归属保守失效。徽章授予变化只重算进度，不重读历史。
2. `BadgeHistoryReader` 在无挂起点的方法内完成关系读取和值提取；别名批量解析只携带值标识，之后明确在后台重组快照。`WorkoutHistoryReader` 使用独立 `ModelContext`，PR、日历、计划预填、肌群负荷由 `WorkoutHistoryProjection` 在后台按原规则聚合。两处 reader 和聚合入口均有后台线程断言。
3. `WorkoutHistoryStore` 提供未就绪、刷新中、可用、失败状态，共用在途任务；刷新期间发生变化时丢弃旧代数并补跑，失败保留旧快照，退出登录隔离旧任务。主线程只批量解析不同动作标识并一次性发布结果。
4. 当前训练立即展示。预填流程在打开可编辑内容前等待有效历史，避免建立空值后异步覆盖用户输入；首页和动作详情有旧历史时继续展示旧内容，首次失败可重试。计划开始同样等待预填依赖。后台只读取已保存数据，训练结束仍先执行原立即保存步骤。
5. `RestAudioExecutor` 用串行队列管理播放器与 audio session，取消代数使关闭声音、结束训练和退出登录后的待播放请求失效。准备不激活会话；实际播放保留 playback、duck/mix 与延迟恢复语义。后台本地通知及防双响路径保留。
6. 勾选中的计时启动、上段休息结算和本组更新合并到一次最终 `touch`。浮层拖动和倒计时由子视图持有，输入中间态与区块观察分离；相同几何值不重复回写。保留稳定身份、聚焦行测量及原有列表结构。
7. 结束训练后的 PR 使用完成后的有效历史快照；徽章增量计算使用后台值快照。完成时先固定当前组、计划判定和原授予集合，提交前去重，避免后台回溯先授予后吞掉本次庆祝；跨账号代数结果直接丢弃。

## 环境、范围与原始证据

- 专用 iPhone 17 Pro 模拟器：`712DE288-DCE6-4D86-9FD8-DB499FBCCAE1`，iOS 26.5，Xcode Debug、arm64、关闭签名。
- 基线使用已有 [2026-09-17 诊断](workout-set-completion-performance-2026-09-17.md)，commit `d511af9`。基线只有三次勾选，不足以计算同采样数量的前后 P95；下面同时标明采样数，不能当作严格配对实验。
- 新性能入口必须同时传入 `-uitest-live-workout -profile-workout`，使用独立的 `WorkoutPerformance.store`，不修改日常训练库。`-profile-history-count N` 构造 N × 6 动作 × 4 组；`-profile-long-workout` 构造当前 20 动作 × 5 组；`-profile-resume-workout` 保留已保存的当前训练用于真实冷恢复。通常当前训练为 3 × 3。
- XCTest 点击总耗时含自动化 IPC、无障碍查询和等待，不计入下述 App 函数耗时。P95 使用 nearest-rank。
- [证据目录](performance/workout-2026-09-18/) 保留基线日志、符号化调用栈压缩文件、优化后日志和统计 JSON。日志仅保留性能事件与合成数据规模，不收录测试环境的其它控制台内容。

## 测量结果

| 测量项 | 优化前 | 优化后 | 解释 |
| --- | --- | --- | --- |
| 600 条历史、首次勾选处理 | 372.25ms | 9.61ms | 处理函数，不含 300ms 延迟保存或最终渲染 |
| 600 条历史、连续勾选处理 | 3 次：372.25 / 22.65 / 4.68ms | 30 次：P95 30.17ms，最大 38.52ms | 同时执行了 30 次取消，按钮状态断言通过 |
| 勾选后徽章完整历史重读 | 每次保存触发 | 30 轮中新增 0 次 | 单元测试直接断言计数；UI 日志只有启动时一次读取 |
| 徽章快照提取，600 条 | 主线程 1186.83–3176.13ms | 后台 2273.96ms（启动时一次） | 收窄失效 + 移出主线程，不宣称全量读取本身达到毫秒级 |
| 首次音频准备 | 主线程 352.53ms | 后台 236.80ms | 长列表另一轮后台 228.17ms；不再占用点击路径 |
| 600 条历史、冷恢复请求展示至 `onAppear` | 未采集同口径基线 | 10 次：P95 268.22ms | 不含登录、查找当前训练、测试数据播种；不等同于第一帧实际可操作时刻 |
| 1000 条历史、20 × 5 长列表数字输入 | 未采集同口径基线 | 31 次数字键：P95 0.75ms，最大 1.09ms | 30 轮输入／删除及最后落值 7kg 断言通过 |
| 1000 条完整历史读取／聚合 | 原主线程同步投影 | 后台读取约 4088ms、聚合约 267ms | 页出现约 385ms，不等待历史完成 |

0、10、600、1000 条（每条 24 组）的独立内存库投影墙钟约为 0.71ms、31.92ms、1852.73ms、3031.95ms。该组用于规模与正确性验证，不与 UI 磁盘库速度横比；原有 5000 条大库测试也保留并通过。

`after-large-restore-input.log` 的 12 条展示日志依次对应 1 次 600 条播种启动、10 次保留当前训练的冷恢复、1 次 1000 条长列表启动；冷恢复 P95 仅取中间 10 条。该轮输入通过后，浮层定位曾因同名无障碍节点失败；后续修正定位并单独复核，未把失败步骤算作通过。

## 线程与调用栈核验

- 优化后所有 `badge.read.values`、`history.read.values`、`history.project.values`、`audio.prepare` 探针均为 `main=false`。没有仅凭 `Task.detached` 判断执行位置。
- 连续勾选期间采集 25 秒、1ms 请求间隔的 `sample`。符号化结果保存在 `after-completion-sample.txt.gz`。此窗口未出现 `BadgeHistoryReader`、`WorkoutHistoryReader`、`WorkoutHistoryProjection` 或 `prepareToPlay` 历史／初始化栈；音频停止仅出现在后台执行分支。
- 采样证明原先的重复历史构建与同步音频初始化未再出现在这条交互路径，**不能单独证明整个 App 在所有交互中绝无持续 100ms 阻塞**，也不能代替帧时间数据。

## 自动验证

- iOS Debug 构建通过。
- 全量单元测试：274 项、37 个套件通过。涵盖既有徽章、历史统计、辅助重量、递减组、超级组、预填、休息、计划回写、同步和 widget 测试。
- 新增：进行中连续 30 次保存不增徽章读取；并发等待合并；读取期间再次失效；失败保留旧快照并重试；退出登录隔离；0/10/600/1000 规模；原始值快照与模型的特殊组／辅助重量／别名一致性；软删除排除。
- 已有 UI：辅助重量提示、徽章馆重复进入与滚动、排序 sheet 封锁／恢复、默认启动与启动测试均通过。模拟器合成排序拖拽不当作真机重排验收。
- 新 UI：600 条历史连续 30 轮完成／取消、600 条历史冷恢复 10 次、1000 条历史长列表 30 轮输入／删除与落值保留。休息浮层展开单独断言复核通过；最终收口重跑 23 项徽章／历史测试通过。详见[验证摘录](performance/workout-2026-09-18/verification.md)。
- `openspec validate workout-tracking --type spec --strict --no-interactive` 通过；`git diff --check` 通过。

测试中发现并修正了值快照迁移时双层 Optional 的非解剖分类偏差；最终非解剖动作继续完全排除。UI 首轮横屏残留与一次模拟器无参数启动导致的无效样本未用于成功结论，测试已固定竖屏并沿用现有套件的重启兜底。

## 复现命令

在仓库根执行（使用专用模拟器，不连接真实数据容器）：

```sh
xcodebuild -project ios/DontLift/DontLift.xcodeproj -scheme DontLift \
  -destination 'platform=iOS Simulator,id=712DE288-DCE6-4D86-9FD8-DB499FBCCAE1' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO \
  test -only-testing:DontLiftTests \
  -only-testing:DontLiftUITests/WorkoutInteractionPerformanceTests \
  -resultBundlePath /tmp/dontlift-workout-performance.xcresult

xcrun xcresulttool export diagnostics \
  --path /tmp/dontlift-workout-performance.xcresult \
  --output-path /tmp/dontlift-workout-performance-diagnostics
```

测试脚本是 `WorkoutInteractionPerformanceTests.swift`；性能事件位于导出目录的 `StandardOutputAndStandardError-com.yulinxi.app.DontLift.txt`。对运行中的模拟器 App PID 执行 `sample <PID> 25 1 -file <输出路径>`，同时执行相同交互。结果目录须使用尚不存在的路径。

## 尚未完成的验收

- 端到端「触摸／击键 → 显示」P95 ≤100ms、第一帧真正可操作 P95 ≤500ms，需要帧级测量；现有处理函数／`onAppear` 指标只提供支持证据。
- 对每种数据规模完整执行每项交互各 30 次的矩阵尚未全部采齐。尤其快速焦点跳转、滚动、动作展开收起、浮层拖动与收起重开、后台恢复，尚需更完整的连续采样。
- 真机 Release／TestFlight：静音键、背景音乐压低与恢复、关闭声音后无迟到播放、锁屏本地通知、防双响、Live Activity、交互流畅度。模拟器结果不能替代这些结论。
- 未进行 TestFlight 上传或发布。
