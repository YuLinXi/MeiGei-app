## Why

动作库 Tab 和训练中「添加动作」抽屉的顶部自定义搜索框在真机弹出系统键盘后会被整体页面上推，导致搜索内容与状态栏 / Dynamic Island / 返回上个 App 文案重叠，用户无法稳定看到输入内容。此前在子视图上叠加 `padding`、`safeAreaPadding`、`safeAreaInset`、`ignoresSafeArea(.keyboard)` 和键盘 offset 补偿均被真机路径证明不稳定，需要从动作库外壳层解决键盘避让边界。

## What Changes

- 为动作库引入 keyboard-stable 外壳，使顶部自定义搜索框在键盘弹出 / 收起、Tab 切换返回、训练中添加动作抽屉内保持视觉位置稳定。
- 将动作库搜索框与主体列表的布局责任拆清：搜索框由外壳固定在顶部 safe area 下方，动作列表和左侧分类作为主体内容渲染。
- 让动作库 Tab 和 `ExercisePickerView` 复用同一套搜索外壳策略，避免两个入口行为分叉。
- 移除此前不稳定的键盘通知 offset 补偿实现。

## Non-goals

- 不切换为系统 `.searchable`，保留当前自定义顶部搜索框视觉。
- 不重做动作库分类、器械索引、内置动作数据、搜索匹配算法或列表分页策略。
- 不改变训练记录、计划、Team、登录等其它页面的系统键盘避让行为。
- 不引入新的后端 API、同步实体、数据库迁移或数据模型变更。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `exercise-library`: 动作库和动作选择器的自定义顶部搜索框 MUST 在系统键盘弹出时保持顶部位置稳定，不得因键盘避让与状态栏区域重叠。

## Impact

- iOS：`ExerciseViews.swift` 中动作库 / 动作选择器布局外壳与搜索状态 ownership。
- iOS：可能新增一个局部 SwiftUI/UIKit bridge，用于限定动作库 host 的 keyboard safe area 行为。
- 验证：需要真机验证 Dynamic Island、普通刘海机型、Tab 切换返回、训练中添加动作 sheet、中文输入法候选栏和返回上个 App 状态栏场景。
