## 1. iOS 端实现

- [x] 1.1 将 `PlanDetailView` 的可滚动内容改为原生 plain `List`，保持现有纸感卡片、间距、空状态和底部 CTA
- [x] 1.2 将动作删除改为禁用全滑的 trailing `swipeActions`，并复用 `paperConfirmDialog` 完成二次确认
- [x] 1.3 移除计划详情对 `SwipeRowCoordinator`、卡片锚点和透明 `fullScreenCover` 的依赖，保持动作点击编辑与现有数据保存行为

## 2. 后端与基础设施

- [x] 2.1 确认本 change 不需要后端、数据库迁移、依赖或部署配置改动

## 3. 验证

- [x] 3.1 运行 iOS 测试并通过
- [x] 3.2 运行仓库约定的无签名 Simulator build 并通过
- [x] 3.3 严格校验 `stabilize-plan-detail-gestures` OpenSpec change
- [ ] 3.4 人工回归动作卡区域上下滚动、左边缘右滑返回、动作卡左滑删除/取消/确认和全滑不直接删除
