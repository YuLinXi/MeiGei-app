# 训练勾选卡顿性能诊断（2026-09-17）

## 结论

500+ 次历史训练会明显放大该问题。本次使用 600 条历史复现：每次勾选后的本地保存会触发徽章历史快照失效；徽章读取先从后台开始，但在 `await MainActor.run` 解析动作标识之后，完整历史快照的构建实际运行在主线程，单次占用约 1.19–3.18 秒。

另有独立的首次勾选问题：主线程首次创建 `AVAudioPlayer` 并调用 `prepareToPlay()`，本次对照约 338–364ms，前期采样范围约 234–476ms。

这两项均有运行时调用栈和耗时证据。没有实施产品修复；临时诊断和消融开关已全部撤回。

## 环境与方法

- 基线 commit：`d511af9`；App 1.1 (4)。初始工作区无未提交修改。
- Xcode Debug，arm64 iOS 26.5，专用 iPhone 17 Pro 模拟器 `712DE288-DCE6-4D86-9FD8-DB499FBCCAE1`。
- 历史数据：10 条与 600 条；每条 6 个动作、每动作 4 个完成组，分别为 240 / 14,400 个历史组。
- 进行中训练固定 3 个动作 × 3 组，重量 60kg、10 次，连续勾选第一个动作的三组。
- 使用 `-uitest-live-workout` 隔离登录与网络同步；等待启动历史加载和徽章回溯完成后，再采集勾选流程。未使用真实用户数据。
- 原生 `xctrace` 按 PID 附加未成功，全进程录制也未正常收尾，未将其作为有效证据。实际有效采集为 macOS `sample`（1ms 请求采样间隔，每轮 25 秒）及单调时钟阶段耗时日志。
- 主对照三轮使用同一个诊断二进制：600 条正常路径、600 条仅跳过徽章保存通知联动、10 条正常路径；每轮三次勾选。
- App 栈已解析到 Swift 函数及源码行。诊断二进制 `DontLift.debug.dylib` 和 dSYM UUID 均为 `B4917750-4D8D-357E-9C43-EA149AFAD365`。部分系统 SwiftData 内部符号不可见，不影响 App 层归因。
- 为保持实现不变，只插入打印/计时及测试数据入口；对照开关仅使 `BadgeWallStore.saved` 提前返回。

## 主对照实测

下表均为毫秒，列出三次勾选的原始值；启动加载不包含在表内。

| 阶段 | 10 条历史 | 600 条历史 | 600 条、跳过徽章保存联动 |
| --- | --- | --- | --- |
| 徽章历史快照构建，主线程 | 43.59 / 38.48 / 22.89 | 1878.39 / 3176.13 / 1186.83 | 未触发 |
| 徽章读取总墙钟时间，含后台与等待 | 81.56 / 60.46 / 36.78 | 2498.36 / 3723.66 / 1672.88 | 未触发 |
| SwiftData `save()` | 24.91 / 2.62 / 4.26 | 37.49 / 14.20 / 15.79 | 34.65 / 15.47 / 14.07 |
| 勾选完成处理函数，不含延迟保存 | 373.81 / 31.54 / 24.64 | 372.25 / 22.65 / 4.68 | 353.47 / 19.93 / 20.20 |
| 提示音准备 | 363.64 / 0.018 / 0.004 | 352.53 / 0.004 / 0.007 | 337.56 / 0.004 / 0.008 |
| Live Activity 快照及任务调度 | 0.68 / 0.78 / 0.60 | 1.07 / 0.76 / 0.69 | 0.89 / 0.74 / 0.77 |

`touch()` 的本次训练统计重算在主对照里约 0.03–0.38ms。它只扫描当前训练，不是秒级阻塞的来源。Live Activity 行只测同步快照和任务调度，不表示系统异步更新的完整耗时。

600 条消融对照中，三次勾选仍正常保存、计时并更新 Live Activity，但没有任何新的 `badge.read.start`，调用栈也不再出现 `BadgeHistoryReader.readWorkouts`。首次音频初始化仍存在，说明两个问题相互独立。

## 根因链路

```text
勾选完成
  → touch() 标脏
  → 300ms 后 modelContext.save()
  → DontLiftApp 接收 ModelContext.didSave
  → BadgeWallStore.saved() 发现 Workout / WorkoutSet 更新
  → invalidate() 清掉 cachedWorkouts，并立即 ensureLoaded()
  → Task.detached 创建 BadgeHistoryReader，开始读取已完成历史
  → await MainActor.run 解析动作标识
  → workouts.compactMap + 动作/组排序 + SwiftData 属性读取
     实际仍在主线程，600 条历史占用约 1.19–3.18 秒
```

相关源码：

- `ios/DontLift/DontLift/Workout/WorkoutViews.swift:3040`：防抖只推迟保存，没有消除保存后的观察者开销。
- `ios/DontLift/DontLift/DontLiftApp.swift`：根层接收 `ModelContext.didSave` 并调用 `badgeWallStore.saved`。
- `ios/DontLift/DontLift/Workout/BadgeWallStore.swift:131`：按实体名称判断失效；进行中的训练组变化也会让完整徽章历史失效。
- `ios/DontLift/DontLift/Workout/BadgeWallStore.swift:57`：清空历史缓存并启动重读。
- `ios/DontLift/DontLift/Workout/BadgeHistoryReader.swift:14`：实际只查询已完成训练。因此进行中勾选通常不改变该历史集合，却仍触发全量重建。
- `ios/DontLift/DontLift/Workout/BadgeHistoryReader.swift:22`：显式进入 `MainActor.run`。
- `ios/DontLift/DontLift/Workout/BadgeHistoryReader.swift:37`：后续快照构建。
- `ios/DontLift/DontLift/Workout/RestTimer.swift:307`：首次音频准备位于勾选调用链的主线程。

线程探针在相同一次读取中打印：

```text
PROFILE badge.read.start main=false
PROFILE badge.map.start main=true count=600
PROFILE badge.map.end main=true ms=3176.1335416231304
```

调用栈交叉验证：`large-timed-sample.txt` 的主线程分支中，`BadgeHistoryReader.readWorkouts` 快照构建占 3070 个采样权重，内部热点包括 `Sequence.sorted`、`WorkoutSet.setIndex.getter` 和 SwiftData 属性访问。10 条对照中同一主线程快照分支只有 49 个权重。权重不是精确毫秒，也不等同于 CPU 百分比；以日志的单调时钟数值描述阻塞时长。

当前证据确定了实际执行位置及触发源；没有进一步把“为何 await 后没有切回预期执行器”归结为特定 Swift 编译器或 SwiftData 缺陷。修复时需显式验证执行器边界，不能只依据 `Task.detached` 或代码注释判断已在后台。

## 建议修复顺序

1. 收窄徽章历史失效条件：进行中训练的组勾选不应重建全部已完成历史；完成训练、修改/删除已完成记录、导入/同步历史等场景仍必须正确失效。
2. 修正历史快照构建的执行器边界，保证 SwiftData 关系读取和排序在 reader 所属执行器完成；动作库主线程解析仅处理必要的值标识。用相同线程探针和调用栈重新验证。
3. 将首次提示音准备移出点击关键路径，避免把音频服务初始化留给第一次勾选。
4. 前三项之后再评估保存和页面布局的剩余开销。现有证据不支持把秒级卡顿主要归因于统计重算、Live Activity 或后端网络。

本次未关闭正式徽章功能，也未提交永久修复。

## 证据文件

采集目录：`/tmp/dontlift-profile.3xhfcN`。临时目录可能被系统清理，需长期保留时应一并归档。

- [600 条主对照日志](/tmp/dontlift-profile.3xhfcN/large-timed.log)
- [600 条主对照调用栈](/tmp/dontlift-profile.3xhfcN/large-timed-sample.txt)
- [600 条关闭联动日志](/tmp/dontlift-profile.3xhfcN/large-ablation.log)
- [600 条关闭联动调用栈](/tmp/dontlift-profile.3xhfcN/large-ablation-sample.txt)
- [10 条对照日志](/tmp/dontlift-profile.3xhfcN/small-timed.log)
- [10 条对照调用栈](/tmp/dontlift-profile.3xhfcN/small-timed-sample.txt)
- [全部临时诊断补丁，已从工作区撤回](/tmp/dontlift-profile.3xhfcN/instrumentation.patch)

复现时将诊断补丁应用到基线，构建 Debug，使用隔离模拟器。`-uitest-live-workout -profile-history-count 600 -dismiss-career-review` 播种大库；小库将数量改为 10；后续重新启动不传数量可复用库。消融增加 `-profile-skip-badge-invalidation`。待启动加载完成后采样进程并勾选三组。测试种子入口会修改目标 App 容器的数据，不应用于真实数据容器。

## 限制与收尾

- 这是模拟器 Debug 的实测，不是用户真机 TestFlight 的帧率或绝对耗时保证；没有测量 500 条的准确阈值。
- UI 自动化本身会产生无障碍查询开销；三轮方法保持一致，根因另由函数计时和消融交叉确认。
- 数据规模影响同时取决于动作/组数量，不只取决于训练次数。
- 六个源码文件的临时修改已按原始 diff 撤回，工作区仅新增本报告；没有改动业务行为。
- 专用模拟器已关闭，保留测试容器和诊断构建，便于复核。
- 排查备用采集方案时安装了 `ettrace 1.1.0` 并下载其源码，最终未链接进 App，也未用于上述取证。Homebrew 安装后自动执行 cleanup，清理部分旧版本包、缓存及日志；未删除项目数据。已清理的包可按需重新安装，缓存可重新下载。
