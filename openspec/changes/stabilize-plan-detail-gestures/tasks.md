## 1. iOS 端实现

- [x] 1.1 将 `PlanDetailView` 的可滚动内容改为原生 plain `List`，保持现有纸感卡片、间距、空状态和底部 CTA
- [x] 1.2 按后续主规格由动作 `…` 菜单触发删除，并复用 `paperConfirmDialog` 完成二次确认；卡片不提供左滑删除
- [x] 1.3 移除计划详情对 `SwipeRowCoordinator`、卡片锚点和透明 `fullScreenCover` 的依赖，保持动作点击编辑与现有数据保存行为

## 2. 后端与基础设施

- [x] 2.1 确认本 change 不需要后端、数据库迁移、依赖或部署配置改动

## 3. 验证

- [x] 3.1 运行 iOS 测试并通过
- [x] 3.2 运行仓库约定的无签名 Simulator build 并通过
- [x] 3.3 严格校验 `stabilize-plan-detail-gestures` OpenSpec change
- [ ] 3.4 人工回归动作卡与展开详情区域上下滚动、左边缘右滑返回、菜单删除取消/确认，以及左滑不显示删除或直接删除

2026-11-09：删除入口验收已按当前主规格对齐，未恢复初始 `swipeActions`。隔离库的上下滚动、全左滑无删除、菜单取消/确认及停止 App 后落库复核已完成。小屏 XCTest 的首次返回与展开/收起后慢速返回 2/2 通过，但 CLI 直接拖动仍有未解释差异，可见 Simulator 窗口的人工核对又受原生工具访问阻断，因此 3.4 保持未完成。证据见[计划手势待验说明](../../../docs/ui-ux-release-readiness-plan-2026-11-07.md#待验事项)。
