# v1.0-b14 发版功能介绍

> 适用版本：`1.0 (build 14)`
> 后端状态：无需新部署。本次无后端代码和数据库迁移变更，生产后端沿用 `V15 checkin reaction push receipts success=true`。
> iOS 状态：准备上传 TestFlight。

## 一句话摘要

本次 build 14 聚焦动作库浏览性能和目标肌肉缩略图质量，同时优化计划列表、分享图展示和训练中悬浮窗的可读性。

## 面向测试用户的更新说明

- 动作库列表新增目标肌肉缩略图，可以更直观看到每个动作主要训练的位置。
- 手臂、前臂、臀部、大腿、小腿等缩略图位置和比例已重新调整，目标肌肉区域更接近真实展示位置。
- 动作库默认进入“全部”时改为分批加载，减少 200 多个动作和缩略图一次性渲染导致的卡顿。
- 动作库左侧筛选区展开新分组时，上一个分组会自动收起，并修复选中背景从下往上滑动的异常动画。
- 计划页分组改为类风琴效果，展开一个分组时会自动收起其它分组。
- 计划列表和训练分享图展示做了版式优化，信息更稳、更容易读。
- 训练中悬浮窗文字颜色更清晰，内容到边缘的间距更宽，计时和当前动作不再显得拥挤。

## 内部技术变更

- iOS 版本号：`MARKETING_VERSION = 1.0`，`CURRENT_PROJECT_VERSION = 14`，App、widget、测试 target 已同步。
- 新增 25 组男性肌肉缩略图资源：`muscleThumb_male_*`，动作库缩略图固定使用男性肌肉图，不随用户性别切换。
- 动作库缩略图改为静态 asset 渲染，不再在动作列表中实时生成肌肉高亮图，降低列表滚动和初次加载成本。
- 移除历史生成的女性缩略图资源，避免无引用资源继续留在 bundle 中。
- 新增 `MuscleMapThumbnail` 轻量组件，用于展示静态肌肉缩略图资源。
- 动作库“全部”视图加入增量加载：初始 60 条，每次追加 50 条。
- 计划页分组展开状态从多分组折叠集合收敛为单一 `expandedSectionId`。
- 训练中悬浮胶囊 `LiveSessionCapsule` 提升计时、动作名、箭头颜色对比，并增加水平和垂直 padding。
- `feature/v1.0-b14` 不包含已延期功能。

## 兼容性说明

- 本次无后端接口、数据库 schema、同步协议变更，生产后端无需随 build 14 重新部署。
- 后端生产健康检查已通过，生产 Flyway 最新仍为 `V15 checkin reaction push receipts success=true`。
- 未升级 iOS 用户不受影响；升级到 build 14 后才会看到新的动作缩略图、动作库懒加载和悬浮窗视觉优化。
- 动作缩略图是客户端内置静态资源，不影响服务端动作数据和历史训练记录。
- 已延期功能未进入 build 14；测试 build 14 时不应看到相关入口。

## 已完成验证

- 生产后端健康检查通过：`curl https://dontlift.peipadada.com/actuator/health` 返回 `{"status":"UP","groups":["liveness","readiness"]}`。
- 生产 Flyway 当前最新为 `V15 checkin reaction push receipts success=true`。
- 后端构建通过：`export JAVA_HOME=/Users/yumengyuan/Library/Java/JavaVirtualMachines/ms-21.0.11/Contents/Home && ./gradlew build --rerun-tasks`。
- iOS simulator build 通过：`xcodebuild -project DontLift.xcodeproj -scheme DontLift -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build`。
- iOS simulator test 通过：同 destination 下 `xcodebuild ... -resultBundlePath /tmp/DontLift-b14-tests.xcresult test`。
- xcresult summary：`result = Passed`，`totalTestCount = 100`，`failedTests = 0`，`skippedTests = 0`。
- `git diff --check` 通过。

## TestFlight 回归重点

- 首次进入动作库默认“全部”列表时，页面不应明显卡顿，滚动到底部应能继续加载更多动作。
- 动作库每行动作缩略图应显示男性肌肉图，目标肌肉位置准确，不出现女性资源或空白占位。
- 重点检查肱二头肌、肱三头肌、前臂、臀大肌、臀中肌、内收肌、小腿肌群缩略图的位置和比例。
- 动作库左侧筛选区切换不同分组时，上一个展开项应自动收起，选中背景不应出现异常滑入动画。
- 计划页分组展开一个后，其它分组应自动收起；新增、重命名、删除、排序计划后展开状态仍合理。
- 训练分享图展示应保持信息完整，动作、组数、时长和训练量文字不应挤压或错位。
- 开始训练后最小化到悬浮窗，检查计时颜色、动作名称、箭头和边距是否清晰舒适。
- 点击训练中悬浮窗应能回到进行中训练页，拖拽和左右吸附仍正常。
- 训练、计划、Team 分享计划开始训练、完成页保存为计划模板等主流程需要回归，确认未受动作库改动影响。
- build 14 中不应出现已延期功能入口或展示。
