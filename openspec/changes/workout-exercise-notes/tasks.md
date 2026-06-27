## 1. iOS 端：实施前核对

- [x] 1.1 核对 `WorkoutExercise.note` 在 SwiftData 模型、`WorkoutDTO` / `WorkoutExerciseDTO`、`SyncEngine` push/pull 中的现有映射，确认本 change 不需要新增模型字段。
- [x] 1.2 核对训练进行中页 `ActiveWorkoutView`、动作卡 `ExerciseBlock`、动作级菜单和 `WorkoutDetailView` 的当前结构，确定备注入口与展示插入点。
- [x] 1.3 核对完成训练、删除空动作、删除训练和同步标脏路径，确认备注保存应复用哪一个现有 `markDirty + save` 入口。

## 2. iOS 端：训练中备注编辑入口

- [x] 2.1 在训练进行中页增加动作备注编辑状态，包括当前编辑的 `WorkoutExercise`、draft 文本、sheet 展示状态和取消编辑回滚语义。
- [x] 2.2 将动作级 `...` 菜单扩展为动作设置菜单，在组间休息设置与删除动作之间加入“添加备注 / 编辑备注”入口。
- [x] 2.3 打开备注编辑入口时关闭动作菜单、组菜单和自定义休息输入态，避免浮层互相叠加。
- [x] 2.4 实现动作备注编辑 sheet：标题展示动作名，支持取消、完成、清空备注和 200 字限制。
- [x] 2.5 保存备注时 trim 文本，空内容写入 `nil`，非空写入 `WorkoutExercise.note`，并触发既有 workout dirty/save 流程。
- [x] 2.6 确认备注输入过程中不逐字写 SwiftData；只有点击“完成”才落盘，点击“取消”不改变原备注。

## 3. iOS 端：备注展示

- [x] 3.1 在训练中动作卡展开态展示备注摘要，无备注时不展示占位。
- [x] 3.2 训练中备注摘要限制为最多 2 行，点击摘要可再次进入编辑。
- [x] 3.3 在训练中动作卡折叠态保留紧凑布局，存在备注时仅展示轻量提示，避免完整文本撑高卡片。
- [x] 3.4 在已完成训练详情的动作卡中以两行预览展示动作备注，点击备注条弹出只读 sheet 查看完整内容，默认只读态不得直接编辑。
- [x] 3.5 确认备注展示使用现有 Theme 纸感 token，长文本在小屏和大字号下不溢出、不遮挡组列表。
- [x] 3.6 为备注入口、清空备注、备注摘要补充合理的 accessibility label / hint。
- [x] 3.7 统一只读查看型与无需显式确认的浏览型 sheet 交互：备注完整内容、Team 训练详情、历史月份浏览不展示顶部操作按钮，统一使用居中大标题并依赖系统下滑关闭；编辑/排序类 sheet 保留操作区。

## 4. 后端 / 同步 / Team 边界

- [x] 4.1 确认 `WorkoutExercise.note` 已经随 workout 聚合 push/pull，不新增同步实体、水位或幂等写接口。
- [x] 4.2 确认后端无需新增数据库迁移、REST 接口或 DTO 字段。
- [x] 4.3 确认实现不使用 `Workout.note` 或 `WorkoutSet.note` 作为本次动作备注入口。
- [x] 4.4 确认 `CheckinSummary` 不加入备注字段，Team feed 与 Team 历史详情不展示动作备注。
- [x] 4.5 确认完成含备注训练并自动分享 Team 时，Team checkin summary JSON 不包含动作备注。

## 5. iOS 端：边界与回归

- [x] 5.1 验证新建训练中添加备注、编辑备注、清空备注、取消编辑不落盘。
- [x] 5.2 验证从计划开始训练的动作、训练中临时新增动作、自定义动作和内置动作均可添加动作备注。
- [x] 5.3 验证备注为空、全空格、超过 200 字、包含换行时的保存与展示行为。
- [x] 5.4 验证删除含备注动作、结束训练时删除空动作、删除训练记录时不会残留备注展示。
- [x] 5.5 验证含备注训练完成后，个人训练详情以两行预览展示备注，点击可查看完整备注，默认只读态不能直接编辑备注。
- [x] 5.6 验证含备注训练分享到 Team 后，Team 今日动态、Team 历史日历详情均不展示备注。

## 6. 基础设施：验证

- [x] 6.1 运行 OpenSpec 状态校验：`openspec status --change "workout-exercise-notes"`。
- [x] 6.2 运行 iOS 编译验证：`xcodebuild -project DontLift.xcodeproj -scheme DontLift -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build`。
- [x] 6.3 检查 `git diff`，确认应用实现只触及训练备注相关文件，且未改 Team snapshot / 后端 schema。
