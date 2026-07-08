## 1. iOS 端实现

- [x] 1.1 撤回动作库 Tab 里基于键盘通知和 offset 的失败补偿逻辑，恢复为外壳级修复入口。
- [x] 1.2 新增动作库专用 keyboard-stable host，局部排除 `UIHostingController` 的 keyboard safe area 对内容布局的影响。
- [x] 1.3 将动作库搜索框与 `query` 状态上提到可复用 shell，让主体内容通过 binding 使用搜索词。
- [x] 1.4 让动作库 Tab 和 `ExercisePickerView` 复用同一套 shell 与键盘稳定策略。
- [x] 1.5 将动作库 Tab 右下悬浮添加按钮改为不参与布局的 overlay，避免底部安全区 inset 抬高主体内容。

## 2. 后端 / 基础设施

- [x] 2.1 确认本 change 不涉及后端 API、数据库迁移、同步实体、幂等键或基础设施变更。

## 3. 验证

- [x] 3.1 运行 iOS simulator build，确认编译通过。
- [x] 3.2 梳理真机回归路径：动作库首次进入、Tab 切换返回、训练中添加动作抽屉、中文输入法候选栏、返回上个 App 状态栏。
