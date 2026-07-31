# `PEC_DECK_FLY` 候选 02 人工审核

## 修改目标

候选 01 的 `art` 被 `project-owner` 驳回，原因是男性乳头特征过强。候选 02 只针对该问题精修：移除明显乳头圆点、乳晕环和凸起，保留朱砂红胸大肌肌纤维、统一角色、开放位姿势和完整蝴蝶机。

## 候选

- 高分辨率：`art/exercise-static/candidates/PEC_DECK_FLY/PEC_DECK_FLY-candidate-02.png`
- 正式压缩样例：`ios/DontLift/DontLift/Resources/ExerciseArtwork/exercise_PEC_DECK_FLY.jpg`
- 高分辨率 SHA-256：`a4c0f07e6046f73717505222ea3deee1e029381cb7734553e230e1295ce9f82f`
- 批准母版：`art/exercise-static/masters/approved/PEC_DECK_FLY-v1.png`
- 当前状态：`approved`

## Codex 预检（不等同人工批准）

- `identity`：脸型、发型、体型、服装与候选 01 和 `character-v1` 保持一致。
- `art`：胸大肌高亮中已无明显乳头圆点或乳晕环；灰阶线稿、色板和背景保持一致。
- `movement`：坐姿开放位、背贴靠垫、双脚着地、肘部轻微屈曲保持不变。
- `equipment`：顶部横梁、双转轴、弯曲摆臂、垂直握把和侧置配重保持完整。
- `rights`：只使用本项目自有候选、角色母版、风格母版与原创修改指令。

## 项目所有者逐项批准

以下五项均由 `project-owner` 在 2026-07-24 明确点名批准；每项独立记录，不以 Codex 预检代替人工结论。`sourceCommit` 是审批发生时的基线提交，相关资产与记录尚处于同一未提交工作区。

```yaml
identity:
  status: approved
  reviewerId: project-owner
  reviewedAt: 2026-07-24T06:05:27Z
  sourceCommit: 7ef36ad60aac753dc95ff4e6b3f0feb33c3202b0
  evidence:
    - art/exercise-static/references/approved/character-v1.png
    - art/exercise-static/masters/approved/PEC_DECK_FLY-v1.png
  notes: 批准候选 02 的人物身份一致性。
art:
  status: approved
  reviewerId: project-owner
  reviewedAt: 2026-07-24T06:05:27Z
  sourceCommit: 7ef36ad60aac753dc95ff4e6b3f0feb33c3202b0
  evidence:
    - art/exercise-static/references/approved/style-v1.png
    - art/exercise-static/masters/approved/PEC_DECK_FLY-v1.png
  notes: 批准候选 02 的美术表现，包括弱化男性乳头特征后的胸肌高亮。
movement:
  status: approved
  reviewerId: project-owner
  reviewedAt: 2026-07-24T06:05:27Z
  sourceCommit: 7ef36ad60aac753dc95ff4e6b3f0feb33c3202b0
  evidence:
    - art/exercise-static/briefs/PEC_DECK_FLY.json
    - art/exercise-static/masters/approved/PEC_DECK_FLY-v1.png
  notes: 批准候选 02 的坐姿开放位、握法、身体接触点与胸大肌表达。
equipment:
  status: approved
  reviewerId: project-owner
  reviewedAt: 2026-07-24T06:05:27Z
  sourceCommit: 7ef36ad60aac753dc95ff4e6b3f0feb33c3202b0
  evidence:
    - art/exercise-static/briefs/PEC_DECK_FLY.json
    - art/exercise-static/masters/approved/PEC_DECK_FLY-v1.png
  notes: 批准候选 02 的顶部横梁式常规蝴蝶机器械结构。
rights:
  status: approved
  reviewerId: project-owner
  reviewedAt: 2026-07-24T06:05:27Z
  sourceCommit: 7ef36ad60aac753dc95ff4e6b3f0feb33c3202b0
  evidence:
    - art/exercise-static/reviews/input-policy-v1.md
    - art/exercise-static/reviews/openai-imagegen-terms-2026-07-24.md
    - art/exercise-static/masters/approved/PEC_DECK_FLY-v1.provenance.json
  notes: 批准候选 02 的输入来源与当前记录的商业使用边界。
```

本记录批准高分辨率静态母版。288×288 JPG 已通过技术校验；真实双列卡片的 3x 清晰度和构图已在 `PEC_DECK_FLY-runtime-card-review.md` 中由项目所有者验收，生产状态更新为 `released`。12 动作快速滚动与性能仍须在后续统一验收。
