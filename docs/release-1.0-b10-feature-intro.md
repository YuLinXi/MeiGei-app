# v1.0-b10 发版功能介绍

> 适用版本：`1.0 (build 10)`
> 后端状态：本次不需要部署 backend，线上沿用 2026-06-24 23:34 CST 已发布版本，Flyway 最新为 `V10 team auto share preference success=true`。
> iOS 状态：准备上传 TestFlight。

## 一句话摘要

本次 build 10 聚焦动作库质量和训练记录体验：收敛预置动作、兼容旧动作历史归并，并优化训练进行中的操作反馈与休息计时稳定性。

## 面向测试用户的更新说明

- 动作库更干净：预置动作经过收敛和分类审核，减少重复、歧义和不适合作为新建入口的动作。
- 旧记录更连续：旧动作名、旧动作 code 会尽量归并到标准动作，历史记录、PR 和计划自适应回填不容易断成两份。
- 动作搜索更稳：搜索支持标准动作名、别名和旧名称，用户按熟悉叫法也更容易找到目标动作。
- 热身拉伸分类更清楚：热身拉伸动作补齐动态热身、静态拉伸、泡沫轴放松等可浏览子类。
- 训练进行中更直观：首页悬浮胶囊显示已训练时长，点击可回到进行中训练。
- 训练操作更完整：进行中训练增加“放弃此次训练”入口，放弃后不会进入训练记录。
- 加一组反馈更明确：加组按钮增加轻触感和点击声，完成组的重量/次数格视觉状态更醒目。
- 休息计时更稳定：休息完成写回、通知和前后台状态处理继续收敛，降低计时状态丢失或重复处理风险。

## 内部技术变更

- iOS 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 10`。
- 新增动作库 manifest 读取与解析：`preset_exercises_v1.json`、`exercise_aliases_v1.json`、`removed_exercises_v1.json`。
- 新增 `ExerciseLibrary.canonicalHistoryKey(...)`，`WorkoutExercise` 和 `PlanItem` 统一使用 canonical history key。
- 动作库搜索纳入 alias 文本，旧动作 code/name 可解析到标准动作展示名。
- 新增动作分类审核文档、CSV、审核工作簿和生成脚本。
- 训练记录页新增放弃训练确认、加一组反馈、完成组视觉调整。
- Live Session capsule 从名称展示改为训练时长展示，并保留无障碍朗读训练名。
- 本机开发脚本支持 backend 绑定 `0.0.0.0`，方便同一局域网真机访问本机后端。

## 兼容性说明

- 本次不需要 backend 部署；没有生产后端代码、API、数据库 schema 或 Flyway 迁移变更。
- 未升级到 build 10 的 iOS 用户仍可继续使用线上后端，基础登录、训练同步和 Team 功能不受影响。
- 升级到 build 10 后，旧动作历史不会被破坏性改写；客户端在展示、PR、计划回填和搜索时通过 alias 解析到标准动作。
- 动作库入口会更收敛：部分旧名称不再作为新选择入口出现，但历史记录仍保留原始快照并可继续展示。
- 新的训练交互、动作库收敛和 canonical history key 逻辑需要安装 build 10 后生效。

## 已完成验证

- 分支已修正为 `feature/v1.0-b10` 并推送远端。
- `git diff --check` 通过。
- 后端部署影响面已核对：`backend/.gitignore` 和 `backend/scripts/dev-start.sh` 仅影响本机开发。
- iOS build 号已递增到 `10`。
- iOS simulator build 通过：`DontLift` scheme，`CODE_SIGNING_ALLOWED=NO`。
- iOS 测试通过：`DontLiftTests` scheme，78 passed / 0 failed。
- 构建仍有现存 Swift 6 迁移类 warnings，未阻塞本次 build 10 上传。

## TestFlight 回归重点

- 从 build 9 升级到 build 10 后，历史训练记录、PR、训练详情和动作展示正常。
- 用旧动作名或旧 code 产生的历史记录能归并到标准动作，例如 `CABLE_FLY` / `CABLE_CROSSOVER`。
- 动作搜索、动作筛选、热身拉伸子类、壶铃摆荡器械类型显示正确。
- 新建训练、加一组、完成组、删除动作、放弃训练、结束训练均正常。
- 首页训练中悬浮胶囊计时准确，点击可回到进行中训练。
- 休息计时、Live Activity、Dynamic Island、本地通知、提前结束休息可用。
- Apple 登录、Team 分享、账号删除等 build 9 核心路径未回归。
