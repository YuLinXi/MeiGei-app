## MODIFIED Requirements

### Requirement: 三宫格统计

ProfileHeader 下方 SHALL 渲染 1×2 网格：「总训练 / 最长连续」，每格背景 `Theme.Color.surface`，外层 1px `Theme.Color.border` 网格内 1px 分隔，两格数字均使用 `Theme.Color.fg`。原「本月 PR」格 MUST 移除（其依赖的 `PRStats.newPRs()` 随历史模块一并删除）。

#### Scenario: 用户从未训练
- **WHEN** `Workout` 表 0 行
- **THEN** 两格分别显示 `0` / `0d`，不报错不空白。

#### Scenario: 不再展示本月 PR
- **WHEN** 用户进入「我的」页
- **THEN** 顶部统计仅含「总训练」与「最长连续」两格，不渲染「本月 PR」格，布局不留空位。

### Requirement: 设置分组列表

ProfileView SHALL 渲染设置项分组：**数据 · 同步**（立即同步 / HealthKit / 导出数据）。每组顶部为 `sec-h`（uppercase `eyebrow` 样式），每项为 `SetItemRow`：左 24×24pt outlined icon + label + 可选 right value（muted）+ 右 chevron。「个人信息」「单位」「通知」三项及其二级页 MUST 移除（三者各自留待后续单独立项），其占位目标页 `PlaceholderDetailView` 一并删除。

#### Scenario: 不再展示三个二级入口
- **WHEN** 用户进入「我的」页查看设置分组
- **THEN** 列表不出现「个人信息」「单位」「通知」任一行，亦无指向 `PlaceholderDetailView` 的入口。

#### Scenario: HealthKit 已授权
- **WHEN** HealthKit 已授权
- **THEN** HealthKit 行右侧 value 显示「已连接」并用 `Theme.Color.ok` 文字。

#### Scenario: 立即同步进行中
- **WHEN** 用户点击「立即同步」且 `SyncEngine.syncAll` 正在运行
- **THEN** value 切换为「同步中…」灰色文字，完成后切到「已同步 {N} 分钟前」绿色文字。
