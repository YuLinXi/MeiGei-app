## 1. OpenSpec

- [x] 1.1 校验 `ios-paper-action-menu` OpenSpec artifacts。

## 2. iOS 端：DesignSystem 组件

- [x] 2.1 新增纸感动作菜单数据结构，支持标题、SF Symbol 图标、普通/危险角色、禁用态与 action。
- [x] 2.2 实现 `PaperActionMenu` 浮层：记录触发按钮 anchor、点外关闭、选择后关闭并执行 action。
- [x] 2.3 实现菜单卡片与菜单行样式：surface 白底、border 描边、r-lg 圆角、paperShadow、统一行高与图标/文字 token。
- [x] 2.4 实现边缘避让与安全区域 clamp，覆盖右上角触发按钮场景。
- [x] 2.5 接入 Reduce Motion：关闭缩放/位移动效，仅保留淡入淡出。
- [x] 2.6 提供圆形 `+` 与圆形 `...` 的动作菜单便捷入口，并让展开态驱动 active/rotated 视觉。
- [x] 2.7 移除或重定向 `CircleIconMenu` 对 SwiftUI `Menu` 的包装，避免新增调用继续走系统菜单。

## 3. iOS 端：页面替换

- [x] 3.1 替换 `PlanListView` 顶部 `+` 系统 `Menu` 为纸感动作菜单。
- [x] 3.2 替换 `PlanListView` 分组 header `...` 系统 `Menu` 为纸感动作菜单。
- [x] 3.3 替换 `PlanDetailView` 工具栏 `...` 菜单为纸感动作菜单。
- [x] 3.4 替换 `TeamListView` 顶部 `+` 系统 `Menu` 为纸感动作菜单。
- [x] 3.5 保持 `paperConfirmDialog`、错误 `.alert` 与 Team 详情底部 action sheet 不变，确认未误改确认/错误提示链路。

## 4. 后端

- [x] 4.1 确认本 change 不涉及后端 API、数据库 migration、同步域或幂等写接口改动。

## 5. 基础设施

- [x] 5.1 确认本 change 不涉及部署配置、环境变量、证书或 CI/CD 基础设施改动。

## 6. 验证

- [x] 6.1 运行 iOS 编译验证：`xcodebuild -project DontLift.xcodeproj -scheme DontLift -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build`。
- [x] 6.2 手动验证计划页顶部 `+`：新建计划、新建分组、调整分组顺序入口可用，菜单视觉为纸感浮层。
- [x] 6.3 手动验证计划分组 `...`：各操作可用，危险操作视觉正确，点外关闭有效。
- [x] 6.4 手动验证计划详情 `...`：重命名、移动分组、删除计划入口可用，删除仍进入原二次确认。
- [ ] 6.5 手动验证 Team 顶部 `+`：创建 Team 与邀请码加入入口可用。（当前账号无 Team，且 `/teams` 返回 403，顶部 `+` 按既有设计不渲染，暂无法触达）
- [x] 6.6 在右上角、长文案、禁用项和 Reduce Motion 开启场景下检查菜单不溢出、不残留、不遮挡关键内容。（已复测计划页顶部 `+`、分组 `...`、计划详情 `...`；禁用项/Reduce Motion 走统一组件代码路径）
- [x] 6.7 重新校验 OpenSpec change。
