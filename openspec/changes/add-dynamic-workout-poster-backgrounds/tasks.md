## 1. iOS 资源与背景模型

- [x] 1.1 将 `/Users/yu/Desktop/app海报/无文字版` 的 5 张 PNG 作为独立 image set 加入 `Assets.xcassets`，保持原图比例且不生成重复素材
- [x] 1.2 将 `WorkoutPosterBackground` 改为 5 个正式背景，提供稳定标识、中文名称、asset name、layout kind 和 `equipmentWreath` 回退

## 2. 语义推荐

- [x] 2.1 从训练和 PR 数据派生 `WorkoutPosterContext`，覆盖 PR、Team 来源、时长、训练量、组数、动作数与复杂训练结构
- [x] 2.2 按 PR → Team → 动作丰富且高投入 → 复杂/多动作 → 高投入 → 普通训练的优先级实现推荐，UUID 仅用于 02/03 稳定二选一

## 3. 视觉融合与交互

- [x] 3.1 将海报改为固定 9:16 全画幅图片背景，移除旧黑红侧栏、假 QR 和固定口号
- [x] 3.2 实现 `topCompact`、`upperCenter`、`centerReceipt` 三种 safe zone，以及暖白半透明训练凭证、深暖棕文字和珊瑚橙强调
- [x] 3.3 处理长动作列表：展示限定数量的动作摘要和剩余数量，保证凭证不离开 safe zone
- [x] 3.4 将选择器改为 5 张真实图片缩略图，默认使用语义推荐结果，保留明确选中态、中文 VoiceOver 和预览会话内手动覆盖
- [x] 3.5 保持预览、保存与分享共用 `WorkoutPosterCanvas(data:background:)`，导出固定为 `1080×1920`

## 4. 测试与验收

- [x] 4.1 更新单元测试，覆盖 5 个背景资源、推荐优先级、UUID 稳定二选一、普通训练/未知值回退和训练内容不变
- [x] 4.2 验证预览画布与导出图片一致，并运行 DontLift iOS 测试与无签名 Simulator 构建
- [x] 4.3 在 Simulator 检查 5 张背景、三种 safe zone、短训练、长动作列表、PR 和 Team 场景，并验证保存/分享与离线行为
