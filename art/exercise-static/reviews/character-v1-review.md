# `character-v1` 人工审核

## 候选

- 文件：`art/exercise-static/candidates/character-v1-candidate-01.png`
- Prompt：`art/exercise-static/briefs/character-v1.md`
- 尺寸：1536×1024 PNG
- 大小：2,004,340 bytes
- SHA-256：`78005e64d8d35fe19fd15076367ae21865d0b5eeb2208bd5e276c05bd840d590`
- 当前状态：`approved`

## 身份清单

- [x] 三个视图可识别为同一张脸：略长椭圆脸、清晰但不过方的下颌、适中颧骨
- [x] 三个视图保持同一短深色发型、低渐变侧边和无胡须状态
- [x] 肩宽、胸腰比、四肢长度、肌肉量、手脚大小一致且自然
- [x] 三个视图均为同一款纯黑无 Logo 训练短裤、赤脚、无首饰和纹身
- [x] 没有换人、多余/缺失肢体、左右错误、手指融合或明显关节畸形
- [x] 灰阶医学健身插画、暖白背景、线稿和阴影符合长期角色方向
- [x] 该角色不对应真人、名人、现有角色或品牌人物

## 人工决定

项目所有者已在当前任务中明确回复“批准 character-v1 候选 01”：

```json
{
  "status": "approved",
  "reviewerId": "project-owner",
  "reviewedAt": "2026-07-24T03:24:25Z",
  "sourceCommit": "7ef36ad60aac753dc95ff4e6b3f0feb33c3202b0",
  "evidence": [
    "art/exercise-static/candidates/character-v1-candidate-01.png",
    "art/exercise-static/reviews/character-v1-review.md"
  ],
  "notes": "批准 character-v1 候选 01 作为统一角色母版；审核时工作区尚未提交，sourceCommit 记录当时 HEAD。"
}
```

候选已复制为 `references/approved/character-v1.png`，后续动作必须把它作为 identity reference。
