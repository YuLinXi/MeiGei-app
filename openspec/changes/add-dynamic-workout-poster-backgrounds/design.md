## Context

训练海报由 `WorkoutPosterData` 派生训练文本，再由 `WorkoutPosterCanvas` 同时用于屏幕预览与 `ImageRenderer` 导出。5 张正式背景均为 `941×1672` RGB PNG，比例接近 9:16，且为不同训练语义预留了不同位置的留白。

上一版 change 错误地把需求收窄为 `classic`、`diagonal`、`rings` 三款 SwiftUI 程序化装饰。本次修正以原 explore 结论和用户提供的 5 张图片为准，替换该错误方向。

## Goals / Non-Goals

**Goals:**

- 5 张插画均可被自动推荐和手动选择，并随 App 离线提供。
- 推荐结果能表达 PR、Team 分享、复杂训练和高容量训练；相同训练重复打开结果稳定。
- 训练信息以暖白半透明凭证融合到插画中，不遮挡主体，也不沿用旧黑红卡片视觉。
- 预览、保存和系统分享使用完全相同的 9:16 画布和背景输入。

**Non-Goals:**

- 不做自由编辑器、用户图片上传、动画或远程模板。
- 不修改 `Workout`、SwiftData schema、后端、数据库、同步协议或 Team 流程。
- 不持久化用户手动选择。

## Decisions

### 1. 使用 5 张正式图片资源和类型化目录

`WorkoutPosterBackground` 固定包含：

- `celebration`：完成庆典台，PR/突破语义，`topCompact`。
- `energyTrail`：能量环游轨迹，高投入/长训练/高容量语义，`upperCenter`。
- `miniGym`：迷你综合训练场，多动作/复杂结构语义，`topCompact`。
- `highFive`：伙伴击掌，Team/协作语义，`topCompact`。
- `equipmentWreath`：训练装备花环，普通/专注训练语义与兼容回退，`centerReceipt`。

枚举提供稳定标识、中文名、asset name 和 layout kind。未知 raw value 回退 `equipmentWreath`，不再回退旧黑红海报。

### 2. 推荐由训练语义决定，UUID 只处理平局

新增不持久化的 `WorkoutPosterContext`，从现有训练数据派生：`hasPersonalRecord`、`isFromTeamShare`、`durationMinutes`、`totalVolumeKg`、`setCount`、`exerciseCount`、`structuredUnitCount`。

按以下优先级选择：

1. 产生 PR → `celebration`。
2. 来自 Team 分享计划 → `highFive`。
3. 动作数不少于 5 且同时满足高投入条件 → 用 UUID 字节在 `energyTrail` / `miniGym` 间稳定二选一。
4. 动作数不少于 5，或包含超级组/递减组 → `miniGym`。
5. 时长不少于 60 分钟、有效组数不少于 20，或训练量不少于 `10000 kg·rep` → `energyTrail`。
6. 其余训练 → `equipmentWreath`。

不得使用 Swift `hashValue`。手动选择只更新 `WorkoutPosterPreviewSheet` 的局部 `@State`，下次打开重新计算推荐结果。

### 3. 采用全画幅插画 + 半透明训练凭证

画布固定为 `360×640 pt`，`ImageRenderer.scale = 3`，导出 `1080×1920`。背景图按 `.scaledToFill()` 全画幅展示并裁切到 bounds。

训练凭证使用暖白色 86%～92% 不透明度、细描边和轻阴影；文字使用深暖棕，数字与 PR 使用珊瑚橙。禁止大面积毛玻璃、厚重渐变遮罩和旧黑红卡片结构。

布局按背景安全区变化：

- `topCompact`：凭证位于顶部留白，适配 01、03、04。
- `upperCenter`：使用较窄的上半区居中凭证，避开 02 四周器械和下方人物。
- `centerReceipt`：凭证位于 05 中央留白，让装备自然形成花环。

凭证保持统一信息顺序：品牌/日期、状态标签、训练标题、核心指标、动作摘要、PR。动作过多时以固定上限展示并给出“另有 N 个动作”，避免挤出安全区。底部只保留 `别练了 · DON'T LIFT` 品牌签名。

### 4. 预览、保存与分享共享同一背景参数

调用链保持为：

`WorkoutPosterPreviewSheet.selectedBackground`
→ `WorkoutPosterCanvas(data:background:)`
→ `WorkoutPosterVisualCardView`

`WorkoutPosterImageRenderer.render` 接收同一 `background`。选择器直接使用 5 个真实资源缩略图，采用横向滚动、明确选中态和中文 VoiceOver label/value；选择器不进入导出图片。

### 5. 资源与回退全部离线

5 张图片放入 `Assets.xcassets`，不做网络加载。未知背景回退 `equipmentWreath`；若图片资源异常，画布仍使用暖白底完成渲染，不阻断保存和分享。

## Risks / Trade-offs

- [PNG 增加包体] → 只加入用户确认的 5 张正式资源，不生成重复尺寸资源。
- [图片解码影响预览] → 使用 Asset Catalog 和固定 5 项非 lazy 选择器；不在 `body` 中做文件读取或图片处理。
- [训练内容过长] → 凭证显示关键动作摘要并明确剩余数量，完整数据仍保留在训练详情中。
- [背景主体被遮挡] → 通过 `layoutKind` 使用三种稳定 safe zone，而不是对所有图片套同一位置。
- [推荐和用户意图冲突] → 自动推荐只决定初始值，5 张缩略图始终允许用户覆盖。

## Migration Plan

无需数据迁移。升级后已有训练按当前派生数据获得推荐背景；回滚时移除 5 张资源和新画布即可，不影响训练记录或已导出图片。

## Open Questions

无。
