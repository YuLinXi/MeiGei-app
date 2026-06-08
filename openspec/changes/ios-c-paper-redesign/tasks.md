## 1. 准备与盘点（iOS 端）

- [x] 1.1 全局 grep 视图层硬编码颜色/字号（`Color(red:`、`.cyan`、`.red`、`.shadow(`、裸 `.font(.system(size:`），列出违反 Theme 纪律的清单，作为翻转期需收口的点
- [x] 1.2 截取当前霓虹版各屏模拟器截图存档（便于回滚对比），并把 18 张设计稿数值（颜色/字号/圆角/阴影）整理成对照速查表

## 2. Token 层翻转（iOS 端 · 完成即大面积变纸感）

- [x] 2.1 改写 `Assets.xcassets` 全部 colorset 值至设计稿：`bg=#f4f2ec`、`surface=#ffffff`、`surface2=#efece5`、`border=#e4ddd0`、`fg=#1c1a17`、`fg2=#5e5950`、`muted=#9a9486`、`ok=#3f9a5a`
- [x] 2.2 新增 colorset：`accent=#d9482b`、`accentSoft=rgba(217,72,43,0.08)`、`accentSofter=rgba(217,72,43,0.18)`、`border2=#d8d2c6`、`danger`（朱砂红或更深红）
- [x] 2.3 `accentCyan`/`accentMagenta` colorset 暂改值为同一朱砂红作过渡别名（保编译），并在 `Theme+Color.swift` 暴露 `accent`/`accentSoft`/`accentSofter`/`border2`
- [x] 2.4 `MeiGeiApp.swift`：`.preferredColorScheme(.dark)` → `.light`
- [x] 2.5 `Theme+Font.swift`：补字号语义层（Hero32/L1-23/L2-16/L3-15/L4-13/L5-11/timer58/cap10），保留 JetBrains Mono 回退逻辑
- [x] 2.6 `Theme+Layout.swift`：圆角校准为 `sm=8 / md=13 / lg=18 / pill`，核对 Spacing 与设计稿（卡片 padding 13–15、屏边 14–19）
- [x] 2.7 `Modifiers.swift`：新增 `paperShadow(.sm/.md/.lg)`（sh-sm/md/lg 三级数值）；`cardStyle()` 改为白底 + 1px `border` + `paperShadow(.sm)`；`neonGlow` 改为兼容垫片（暂保签名，内部走 paperShadow 或 no-op）
- [x] 2.8 编译验证（`xcodebuild ... CODE_SIGNING_ALLOWED=NO build`），确认全局已翻为纸感浅色

## 3. 跨屏组件层（iOS 端）

- [x] 3.1 `HorizontalChipPicker`：选中态改 `accent` 实底白字（去 glow），未选态白底 + `border` + `fg2`
- [x] 3.2 `MainTabView`：`UITabBarAppearance`/`UINavigationBarAppearance` 改纸感（纸白背景、`border` 分隔、tint `accent`），5 个 tab 图标/选中色对齐
- [x] 3.3 统一按钮样式：CTA（`accent` 实底白字 + `paperShadow`）、ghost（白底 + `border` 描边）、icon button（38×38 圆形白底）；落到复用的 ButtonStyle/修饰符
- [x] 3.4 统一表单组件：TextInput（白底 + `border` + r-md）、Stepper（± 圆钮 + 中值，`accent` 描边）、Searchbox（虚线 `border2` 边框 + 放大镜）、Picker 行（右箭头）
- [x] 3.5 统一列表/分组组件：分组标签 `eyebrow`（10pt uppercase + tracking + muted）、stat3 三宫格（中缝 1px `border`）、记录行（日期方块 + 标题 + 标签 + 左滑删除）

## 4. 逐屏校准（iOS 端 · 按依赖顺序）

- [x] 4.1 登录页 `LoginView`：移除赛博网格/radial/scanline，改纸白底 + 品牌 M 标 + 大标题 + 黑色 Apple 按钮 + 法律小字（对齐 `meigei-c-login`）
- [x] 4.2 训练首页 `WorkoutViews`：本周 hero（含 Swift Charts sparkline）+ 三宫格 + LIVE/继续横幅 + 最近训练列表（对齐 `meigei-c-home`）
- [x] 4.3 训练进行中：记录条（脉动 REC + 计时 + 停止）+ 三宫格 + 可展开动作卡（组行 / 当前行 `accentSoft` 高亮 / checkbox / 加组 / 组间休息快选菜单）（对齐 `meigei-c-workout-active`）
- [x] 4.4 休息计时 `RestTimerSheet`：环形进度色 cyan→`accent`、去 glow，中心 58pt mono 计时，−15s/完成/+15s 三键 + 下一组提示（对齐 `meigei-c-rest-timer`）
- [x] 4.5 计划列表 `PlanViews`：featured 卡改纸感（白底 + `accent` 竖条 + 周进度条，去青色渐变/glow）+ 我的/推荐两段（对齐 `meigei-c-plans`）
- [x] 4.6 计划详情：eyebrow + 大标题 + 三宫格 + 编号动作列表（`accent` 序号）+ 底部 复制/开始 双按钮（对齐 `meigei-c-plan-detail`）
- [x] 4.7 计划编辑 Sheet：建议组数/次数 Stepper + 重量输入（对齐 `meigei-c-plan-edit`）
- [x] 4.8 动作库 `ExerciseViews`：虚线搜索框 + 部位 Chip + 分组列表（自定义「个人」标 / PR 副标）（对齐 `meigei-c-exercise-library`）
- [x] 4.9 动作选择器 Sheet：搜索 + 分组列表 + 右侧快速索引栏（部分置灰）（对齐 `meigei-c-exercise-picker`）
- [x] 4.10 自定义动作 Sheet：名称（必填*）+ 主要肌群 Picker + 器械 Picker（对齐 `meigei-c-custom-exercise`）
- [x] 4.11 Team 列表 `TeamViews`：Team 卡（头字方块 + 名称 + 邀请码 + chevron）+ 空态（对齐 `meigei-c-team-list`）
- [x] 4.12 创建/加入 Team Sheet：队名/邀请码输入（对齐 `meigei-c-team-create`）
- [x] 4.13 Team 详情：Cover 卡（白底 + 今日已练 pill + 邀请码 + 成员头像列表）+ 动态 Feed 卡（PR `accent` 着色）+ 4 emoji 反应行（对齐 `meigei-c-team-detail`）
- [x] 4.14 我的 `ProfileView`：Header + 1×2 统计 + 数据·同步分组（HealthKit 状态 / 立即同步）+ 版本 + 退出登录（对齐 `meigei-c-profile`）

## 5. 新增缺失屏幕（iOS 端）

- [x] 5.1 新增 PR 庆祝 Sheet：圆形徽章 + 「{N} 项新纪录!」+ 记录列表（旧→新 + 向上箭头）+「太棒了」CTA，接 `PRStats` 结果，训练结束命中 PR 时弹出（对齐 `meigei-c-pr-celebrate`）
- [x] 5.2 新增动作详情页 `ExerciseDetailView`：`Canvas` 条纹「采集中」占位图 + 名称/肌群副标 + 要点卡 + 主动肌/协同肌 2 列卡 + 有 PR 时 PR 卡（对齐 `meigei-c-exercise-detail`）
- [x] 5.3 新增 Team 计划 Fork 列表：纸感计划卡（名称 + 作者 + Fork 按钮），接既有 Fork 流程 + 空态占位（对齐 `meigei-c-team-plans`）

## 6. 收尾与验收（iOS 端）

- [x] 6.1 视图层全量迁移到 `Theme.Color.accent`，删除 `accentCyan`/`accentMagenta` colorset 与符号别名、删除 `neonGlow` 垫片，grep 确认无残留青/品红/辉光
- [x] 6.2 无障碍核对：纸白底下 `fg`/`fg2`/`muted` 文字对比度达标；`reduceMotion` 下脉动/过渡降级；Dynamic Type 放大不破版
- [x] 6.3 逐屏模拟器截图与 18 张设计稿人工对照，核对 token 数值与版式；记录无法 1:1 的折中项（设备外壳/部位高亮图占位）
- [x] 6.4 全量 `xcodebuild` 编译通过；更新记忆 [[meigei_c_design_spec]] 与实现进度
