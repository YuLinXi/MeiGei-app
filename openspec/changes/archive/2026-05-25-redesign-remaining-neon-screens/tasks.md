## 1. 设计系统补强

- [x] 1.1 [iOS] 在 `Assets.xcassets` 新增 `macroFat.colorset`（sRGB 由 `scripts/oklch_to_srgb.*` 从 `oklch(72% 0.18 35)` 生成），并在 `Theme+Color.swift` 暴露 `Theme.Color.macroFat`
- [x] 1.2 [iOS] 在 `DesignSystem/` 新增 `HorizontalChipPicker.swift`：泛型 `<Item: Identifiable & Hashable>`，参数 `items`、`selection: Binding<Item.ID>`、`label: (Item) -> String`
- [x] 1.3 [iOS] 单元测试 `HorizontalChipPickerTests`：覆盖切换选中、空 items、单 item 三 case（snapshot 比较或行为断言均可）
- [x] 1.4 [iOS] 在 `DesignSystemPreviewView` 追加 `HorizontalChipPicker` 与 `macroFat` 预览块

## 2. 动作库（Screen 04）

- [x] 2.1 [iOS] 抽出 `Workout/PRStats.swift`：`func latestPR(for exerciseKey: String, in workouts: [Workout]) -> PRSummary?`；`WorkoutListView` / `HistoryView` / `ExerciseLibraryView` 共用
- [x] 2.2 [iOS] 新建 `Workout/ExerciseLibraryView.swift`：顶部 navbar「动作」+ 右上 +，搜索框（noop）+ `HorizontalChipPicker` 部位筛选
- [x] 2.3 [iOS] 列表按「复合 · 推 / 拉 / 腿 / 单关节」分组，行结构 = thumb + 双语名 + PR 副标
- [x] 2.4 [iOS] 数据库空占位卡「动作库尚未采集，点右上 + 添加自定义动作」+ CTA
- [x] 2.5 [iOS] `MainTabView` 在「动作」tab 挂载 `ExerciseLibraryView`（若 tab 未独立则按设计稿挂入对应位置）

## 3. 计划列表 + 详情（Screen 05/06）

- [x] 3.1 [iOS] 改造 `Workout/PlanViews.swift` 中的 `PlanListView`：三段「进行中 / 我的计划 / 推荐模板」+ featured 卡 cyan gradient + glow
- [x] 3.2 [iOS] featured 卡渲染 `WEEK n/N` pill + 大标题 + 简介 + 3 列 meta
- [x] 3.3 [iOS] 改造 `PlanDetailView`：navbar 返回 + 三点，eyebrow + 大标题（多行）+ 3 列 meta
- [x] 3.4 [iOS] 动作列表 row card（序号 cyan / 中间名+方案 / 右拖拽 handle），末尾 dashed 「＋ 添加动作」占位
- [x] 3.5 [iOS] 底部固定 CTA：ghost 复制按钮 + primary 「开始这次训练 →」 + glow
- [x] 3.6 [iOS] jsonb 解码错误兜底「计划数据损坏」红卡 + OSLog payload

## 4. 饮食日记（Screen 07）

- [x] 4.1 [iOS] 新建 `Nutrition/MacroRingView.swift`：圆环 + 4 条进度条（蛋白/碳水/脂肪/水），颜色 = `accentCyan / accentCyan / macroFat / 240° 蓝色`
- [x] 4.2 [iOS] 改造 `Nutrition/FoodDiaryView.swift`：用 `ScrollView { LazyVStack }` 重写，顶部 navbar「饮食」+ 日历/+ 双按钮，下方日期 eyebrow + `MacroRingView`
- [x] 4.3 [iOS] 餐次分块 `MealBlockView`：按早/午/晚/加餐/训练后过滤，header 粗体餐次名 + mono 副标 `{kcal} kcal · {HH:mm}`；行间 1pt border 分隔
- [x] 4.4 [iOS] 餐次内 > 4 条折叠成「+ N 项 / 合计」灰色行；0 条餐次不渲染
- [x] 4.5 [iOS] 右下 56pt 圆形 FAB（cyan + medium glow）+ 时段→默认餐次映射，点击 push `FoodPickerView`

## 5. 食材选择器（Screen 08）

- [x] 5.1 [iOS] 改造 `Nutrition/FoodPickerViews.swift`：顶部 navbar「添加 · {餐次}」+ 右上「取消」文字按钮
- [x] 5.2 [iOS] 搜索框（noop，placeholder「搜索 1500 项标准食材」）+ `HorizontalChipPicker`（最近 / 收藏 / 蛋白质 / 主食 / 蔬菜 / 水果 / 自定义）
- [x] 5.3 [iOS] 食材行：42pt 圆角缩略图（emoji 占位）+ 名称 + mono 宏量副标 + 右 28pt 圆按钮
- [x] 5.4 [iOS] 添加状态切换：未添加 = `surface + border + +`；已添加 = `accentCyan 填充 + ✓`
- [x] 5.5 [iOS] chip「最近」按 `FoodEntry.createdAt` desc 取前 20；「收藏」走自定义食材表 `isFavorite`；「自定义」按 `CustomFood`（备注：CustomFood 暂无 isFavorite 字段，proposal Non-goals 禁止改 schema，「收藏」当前以全部自定义占位）

## 6. Team 动态（Screen 09）

- [x] 6.1 [iOS] 改造 `Team/TeamViews.swift` 中的 `TeamDetailView`：顶部 cover 卡（gradient `surface2→bg` + 圆角 lg）+ 右上 pill「{N}/{M} 今日已练」
- [x] 6.2 [iOS] 成员头像横向列表：4 档配色 hash、超 4 折叠 +N、尾部 mono「{N} 成员」
- [x] 6.3 [iOS] eyebrow「今日动态」+ `FeedItemCard` 列表（head 头像/名/时间，body 文字 PR 部分 magenta + glow）
- [x] 6.4 [iOS] 反应行：固定 4 emoji 🔥/💪/😱/👏 + + 按钮，未点亮 vs 点亮两套样式（备注：现有 enum 含 fire/muscle/clap/heart，以 ❤️ 替代 😱 暂位，扩 enum 时再换）
- [x] 6.5 [iOS] 反应点击调用 `TeamService.react(activityId:, emoji:)`；本地乐观更新计数，失败回滚
- [x] 6.6 [iOS] 空 feed 占位卡 + CTA「开始训练」跳训练 tab

## 7. 历史（Screen 10）

- [x] 7.1 [iOS] 改造 `Workout/HistoryViews.swift`：顶部 `HorizontalChipPicker` 时间窗（7/30/90/全部，默认 30）
- [x] 7.2 [iOS] chart-card：标题 + 大数字「{N} 吨」+ MoM/WoW delta（用 `Theme.Color.ok` 或 `danger`）+ Swift Charts BarMark 柱状图，最末柱 magenta + glow
- [x] 7.3 [iOS] eyebrow「本月 PR」+ PR 列表：首张 magenta 边光「★ NEW PR」卡，其余 card + `+{delta}` ok pill；窗口内 0 PR 时整段折叠
- [x] 7.4 [iOS] 时间窗切换驱动训练量/PR 联动重算（PRStats 复用任务 2.1 抽出的函数）

## 8. 个人中心（Screen 11）

- [x] 8.1 [iOS] 新建 `Profile/ProfileView.swift`，挂到 `MainTabView` 「我的」tab
- [x] 8.2 [iOS] ProfileHeader：64pt 圆形头像（首字母 + hash 色）+ 用户名（display 22）+ mono 副标「{w}kg · {h}cm · 训练龄 {y} 年」
- [x] 8.3 [iOS] 三宫格统计：总训练 / 本月 PR (cyan) / 最长连续，1px 内分隔 + border
- [x] 8.4 [iOS] 设置分组「账户 / 数据·同步 / 偏好」+ `SetItemRow` 子组件（icon + label + 可选 value + chevron）
- [x] 8.5 [iOS] HealthKit 行显示「已连接」/「未授权」+ `Theme.Color.ok / danger`；「立即同步」绑定 `SyncEngine.syncAll` 状态文字
- [x] 8.6 [iOS] 底部居中「退出登录」`Theme.Color.danger` 文字 + confirm alert → `SessionStore.signOut()`
- [x] 8.7 [iOS] 二级页面（个人信息 / 体重 / 训练目标 / 单位 / 通知）建空架壳 NavigationLink + 「即将上线」占位

## 9. 登录（Screen 12）

- [x] 9.1 [iOS] 改造 `Auth/LoginView.swift`：全屏黑底 + cyber 网格 Canvas（水平/垂直 1px 40pt 网格 + cyan 右上 / magenta 左下 RadialGradient + 横向 2pt scanline）
- [x] 9.2 [iOS] 左下文案区：3 段彩色色条 + mono「MEIGEI · NO.0001」+ 大标题「认真训练。/ 严肃记录。/ 仅此而已。」最后一行 cyan + 副标 ≤ 260pt 宽
- [x] 9.3 [iOS] 底部原生 `SignInWithAppleButton`（高 50 / 圆角 13）+ mono 法务小字「服务条款」「隐私政策」underline 占位
- [x] 9.4 [iOS] 登录中按钮 → `ProgressView()` 禁用；失败 → 按钮下方红字错误（取消错误不显示）

## 10. 全局适配 & 验证

- [x] 10.1 [iOS] 全工程 grep `List {`、`Form {` 顶层用法；非必要全部替换为 `ScrollView { LazyVStack }`；必要的 List 加 `.scrollContentBackground(.hidden).background(Theme.Color.bg)` + 文件头注释
- [x] 10.2 [iOS] grep `Color(red:`、`Color.cyan`、`Color.gray` 等字面量；全部迁到 `Theme.Color.*`（备注：`SharePoster` 与 `RestTimer` 中保留的字面量为隔离海报/计时主题视觉，受 Modifier 控制；`ContentView.swift` 是 Xcode 模板未挂载，未处理）
- [x] 10.3 [iOS] `xcodebuild -project MeiGei.xcodeproj -scheme MeiGei -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build` 通过
- [ ] 10.4 [iOS] iPhone 17 Pro 模拟器逐屏截图（9 张），与 `ios/design-system/MeiGeiApp/index.html` 设计稿肉眼对位，容差 ±2pt（待用户在本地模拟器跑一遍并人工对位）
- [x] 10.5 [iOS] `DesignSystemPreviewView` 内 11 + 1 个色板（含新增 macroFat）+ `HorizontalChipPicker` 预览正常
- [x] 10.6 [iOS] 跑全套单元测试 `xcodebuild test`；现有测试不回归（同步修复 `MeiGeiTests.swift:40` 类型推断超时）

## 11. 归档

- [x] 11.1 `/opsx:archive redesign-remaining-neon-screens` 把本 change 归档到 `openspec/changes/archive/`，新增/修改的 spec 同步到 `openspec/specs/`
