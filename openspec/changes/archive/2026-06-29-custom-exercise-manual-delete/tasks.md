## 1. OpenSpec

- [x] 1.1 补充 proposal/design/spec delta，明确自定义动作删除范围与同步语义
- [x] 1.2 同步产品调整：删除入口改为动作库 browse 模式长按确认，新建自定义动作弹窗改为分类标签网格

## 2. iOS 端

- [x] 2.1 在动作库 browse 模式的自定义动作行加入删除入口，pick 模式保持只选择不删除
- [x] 2.2 删除前展示纸感二次确认，并在确认后执行 `markDeleted()`、保存 SwiftData、触发 `syncAll()`
- [x] 2.3 确认已删除自定义动作继续被动作库和动作选择器过滤，既有训练/计划引用不被改写
- [x] 2.4 将自定义动作删除入口从左滑改为 browse 模式长按直接二次确认，pick 模式长按不删除
- [x] 2.5 将新建自定义动作弹窗改为紧凑标签网格，移除左上取消按钮与二级滚轮弹层

## 3. 后端

- [x] 3.1 补充 `CustomExerciseSyncService` 墓碑上传测试，锁定显式 `softDelete` 路径

## 4. 验证

- [x] 4.1 运行 OpenSpec 校验
- [x] 4.2 运行后端测试
- [x] 4.3 运行 iOS 编译验证
- [x] 4.4 重新运行 OpenSpec 校验
- [x] 4.5 重新运行 iOS 编译验证
- [x] 4.6 重新运行 iOS 测试

> 4.6 已尝试运行；当前测试 target 因既有 `WorkoutHistoryProjectionTests` 仍访问已改名的 `HomeWorkoutSnapshot.recent` 编译失败，未进入本变更新增删除测试执行阶段。
