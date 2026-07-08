# v1.0-b19 首页 Hero 和动作库稳定版功能介绍

> 适用版本：`1.0 (build 19)`
> 生成时间：2026-07-09 00:10 CST。
> 后端状态：本次无后端运行时代码和数据库迁移变更，无需重新部署；生产 health 已确认为 `UP`，Flyway 最新仍为 `V18 workout set is warmup success=true`。
> iOS 状态：已完成本地 build/test 验证；TestFlight `1.0 (19)` 已上传并完成真机回归，2026-07-09 00:13 CST 由用户确认。
> 合并与 tag 状态：2026-07-09 00:16 CST 完成 `main` 合并，并创建 `v1.0-b19` tag。

## 一句话摘要

本次 build 19 优化训练首页顶部状态展示，并继续收紧动作库搜索框在真机键盘弹起时的稳定性。

## 面向测试用户的更新说明

- 训练首页顶部换成动态图片 Hero，会根据今天是否完成训练、是否连续训练 3 天以上切换状态图和左侧文案。
- 首页 Hero 文案更克制，不再混入进行中训练的下一组、计时或继续训练提示，进行中训练仍由全局浮层承载。
- 动作库 Tab 和训练/计划里的「添加动作」抽屉继续优化搜索框键盘表现，目标是真机弹出键盘后顶部搜索框仍保持可见。
- 训练中自定义组间休息秒数的按钮展示更清晰，编辑态、已设置态和未设置态更容易区分。

## 内部技术变更

- iOS 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 19`，App、widget、测试 target 已同步。
- 发版前已将 DEBUG 本地后端从真机局域网调试地址切回 `http://localhost:8001`；Release 仍强制使用 `https://dontlift.peipadada.com`。
- `Assets.xcassets` 新增 `homeHeroStreak`、`homeHeroPending`、`homeHeroDone` 三张首页 Hero 背景图。
- `HomeWorkoutSnapshot` 新增今日完成训练次数和连续训练天数两个轻量派生字段，由 `WorkoutHistoryStore` 构建快照时一次性计算。
- `WorkoutListView.heroSection` 改为图片 Banner，并由 SwiftUI 文案提供 VoiceOver 语义；Hero 不作为额外开始训练入口。
- `ExerciseLibraryView` / `ExercisePickerView` 引入局部 keyboard-stable host 和 `ExerciseLibraryShell`，将搜索框、搜索状态和列表主体拆开。
- 本次无后端 API、同步协议、数据库 migration 或生产部署变更。

## 兼容性说明

- build 19 的变化均为 iOS 客户端 UI / 本地派生状态，不改变后端接口或本地/云端数据结构。
- 未升级用户仍保持 build 18 行为，不会受到后端兼容性影响。
- 首页 Hero 的连续训练天数只由本地已完成训练记录派生；不会写入同步字段，也不会影响历史训练数据。
- 动作库搜索框稳定性仍需 TestFlight 真机重点回归，尤其是中文输入法候选栏、Dynamic Island、返回上个 App 状态栏场景。
- TestFlight `1.0 (19)` 已完成真机回归，用户未反馈首页 Hero 或动作库搜索框异常；具体设备和 iOS 版本未提供。
- TestFlight `1.0 (19)` 已可用并完成回归，本次发布合并到 `main` 后创建 `v1.0-b19` tag。

## 已完成验证

- OpenSpec 校验通过：`add-dynamic-home-hero`、`stabilize-exercise-library-search-keyboard` 均通过 strict validate。
- `git diff --check` 通过。
- 后端构建通过：`JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ./gradlew build`。
- iOS simulator build/run 通过：XcodeBuildMCP `build_run_sim`，`CODE_SIGNING_ALLOWED=NO`，无编译错误。
- iOS simulator test 通过：XcodeBuildMCP `test_sim`，`160` 个测试通过，`0` failure。
- 生产 health 已确认：`https://dontlift.peipadada.com/actuator/health` 返回 `UP`。
- 生产 dev token 已确认关闭：`POST /auth/dev/token` 返回 `404`。
- 生产 Flyway 已确认最新记录为 `18  workout set is warmup  success=true`。
- TestFlight `1.0 (19)` 已上传并完成真机回归，2026-07-09 00:13 CST 由用户确认。
- `feature/v1.0-b19` 已合并回 `main`，并创建 `v1.0-b19` tag。

## TestFlight 回归重点

- 真机安装 TestFlight `1.0 (19)` 后，确认 Apple 登录、冷启动、同步和 Team 页加载正常。
- 训练首页今日未完成、今日已完成、连续训练 3 天以上三种状态下，Hero 图片和左侧文案符合预期。
- 有进行中训练时，Hero 不显示下一组、计时或继续训练文案；继续训练仍通过全局浮层或已有冲突流程进入。
- 动作库 Tab 聚焦搜索框后，键盘弹起时搜索框保持可见，不与状态栏、Dynamic Island 或返回上个 App 文案重叠。
- 训练中和计划编辑中打开「添加动作」抽屉，重复验证中文/英文搜索、收起键盘、选择动作后关闭抽屉。
- 训练中打开组间休息设置，验证自定义秒数按钮的编辑、清空、保存和 VoiceOver 读法。
