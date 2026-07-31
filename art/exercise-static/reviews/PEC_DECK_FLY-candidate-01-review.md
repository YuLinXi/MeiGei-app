# `PEC_DECK_FLY` 候选 01 人工审核

## 候选

- 高分辨率：`art/exercise-static/candidates/PEC_DECK_FLY/PEC_DECK_FLY-candidate-01.png`
- 180×180 预览：`art/exercise-static/candidates/PEC_DECK_FLY/PEC_DECK_FLY-candidate-01-180.jpg`
- 高分辨率 SHA-256：`2235c2165af4694ecc84f3c2577a5ec3612ae3d46464122506c74111d2ee1669`
- 当前状态：`rejected`

## Codex 预检证据（不等同人工批准）

### identity

- 候选保留了 `character-v1` 的短深色发型、略长椭圆脸、无胡须、自然健壮体型和黑色短裤。
- 高分辨率下未发现明显换脸、多余肢体、缺失肢体或严重手脚畸形。
- 最终是否“足够像同一角色”必须由 `project-owner` 决定。

### art

- 灰阶 graphite/ink、暖白背景、朱砂红胸大肌、浅红三角肌前束与 `style-v1` 一致。
- 180×180 下胸部、动作姿势和主要器械仍可辨认；无文字、Logo、水印和环境杂物。

### movement

- 人物为坐姿开放位，背部贴垫、双脚着地、上臂接近肩高、双肘轻微屈曲、双手中立握住垂直把手。
- 未表现为胸推、站姿绳索夹胸或前臂垫变体。

### equipment

- 存在中央座椅与垂直靠背、左右立柱、顶部横梁、两端固定转轴/凸轮、向外向下弯曲摆臂、垂直握把、侧置配重塔与导杆。
- 180×180 下仍能识别为顶部横梁式常规选择片蝴蝶机。

### rights

- 输入只有项目自有 `character-v1`、`style-v1` 和原创 `PEC_DECK_FLY` brief。
- 未使用 `hasaneyldrm/exercises-dataset` 或其他第三方媒体。
- 输出可能不唯一，仍需 `project-owner` 明确签署最终 rights 结论。

## 待人工决定

`project-owner` 必须逐项确认：

```yaml
identity: pending
art: rejected
movement: pending
equipment: pending
rights: pending
```

### `art` 人工驳回记录

```yaml
status: rejected
reviewerId: project-owner
reviewedAt: 2026-07-24T05:52:35Z
sourceCommit: 7ef36ad60aac753dc95ff4e6b3f0feb33c3202b0
evidence:
  - art/exercise-static/candidates/PEC_DECK_FLY/PEC_DECK_FLY-candidate-01.png
  - art/exercise-static/candidates/PEC_DECK_FLY/PEC_DECK_FLY-candidate-01-180.jpg
notes: 弱化男性乳头特征；保留胸大肌朱砂红高亮，但乳头和乳晕不得成为视觉焦点。
```

候选 01 不得 promote。只有后续候选五项全部批准后，才允许复制到 `masters/approved/PEC_DECK_FLY-v1.png` 并写入生产 manifest。
