# `BB_BENCH_PRESS` 候选 02 人工审核

## 修改目标

候选 01 的动作、器械和构图基本可用，但胸部出现了与 `character-v1` 不一致的明显乳头圆点。候选 02 仅通过 imagegen edit 移除乳头圆点和乳晕特征，保留同一人物、平板卧推底部代表姿势、完整卧推架和胸大肌高亮。

## 候选

- 本地候选：`art/exercise-static/staging/candidates/BB_BENCH_PRESS/BB_BENCH_PRESS-candidate-02.png`
- 批准母版：`art/exercise-static/masters/approved/BB_BENCH_PRESS-v1.png`
- 尺寸：1254×1254 PNG，无 alpha
- 文件大小：1,969,412 bytes
- SHA-256：`41f1e8c153ea38454d5ef36b014b488e9605973e2e7591fed77f7d2b832f1400`
- 当前状态：`approved`
- 说明：原候选仍位于 Git 忽略的 `staging/`；批准后复制出的唯一正式母版进入 `masters/approved/`。

## Codex 预检（不等同人工批准）

- `identity`：短黑发、脸型、灰阶解剖线稿、黑色短裤和体型与 `character-v1` 基本一致；仰卧视角会使脸部识别度低于站姿母版。
- `art`：主动肌仅以朱砂红高亮胸大肌，三角肌前束和肱三头肌以浅红表示；候选 01 的乳头圆点已经移除，画面无文字、Logo 和箭头。
- `movement`：人物仰卧平板凳，头、上背和臀部贴凳，双脚踩地；杠铃接近胸骨中下段，肘部屈曲并在躯干两侧展开。
- `equipment`：平板凳、两根对称立柱、挂钩、直奥杆、两侧对称杠铃片和卡扣均可辨认；杠铃因 45° 弱透视呈轻微斜线，但结构连续。
- `rights`：只使用本项目自有 `character-v1`、`style-v1`、原创 `BB_BENCH_PRESS` brief 和 imagegen 生成的候选 01；未使用第三方图片作为 reference 或 edit 输入。

## 项目所有者逐项批准

项目所有者在 2026-07-24 明确批准以下五项。每项独立记录，不以 Codex 预检代替人工结论；`sourceCommit` 是审批发生时的基线提交，相关资产与记录尚处于同一未提交工作区。

```yaml
identity:
  status: approved
  reviewerId: project-owner
  reviewedAt: 2026-07-24T09:12:03Z
  sourceCommit: 7ef36ad60aac753dc95ff4e6b3f0feb33c3202b0
  evidence:
    - art/exercise-static/references/approved/character-v1.png
    - art/exercise-static/masters/approved/BB_BENCH_PRESS-v1.png
  notes: 批准候选 02 的人物身份一致性。
art:
  status: approved
  reviewerId: project-owner
  reviewedAt: 2026-07-24T09:12:03Z
  sourceCommit: 7ef36ad60aac753dc95ff4e6b3f0feb33c3202b0
  evidence:
    - art/exercise-static/references/approved/style-v1.png
    - art/exercise-static/masters/approved/BB_BENCH_PRESS-v1.png
  notes: 批准候选 02 的灰阶线稿、肌群高亮、构图和弱化乳头特征后的美术表现。
movement:
  status: approved
  reviewerId: project-owner
  reviewedAt: 2026-07-24T09:12:03Z
  sourceCommit: 7ef36ad60aac753dc95ff4e6b3f0feb33c3202b0
  evidence:
    - art/exercise-static/briefs/BB_BENCH_PRESS.json
    - art/exercise-static/masters/approved/BB_BENCH_PRESS-v1.png
  notes: 批准候选 02 的平板卧推底部姿势、握法、身体接触点与胸大肌表达。
equipment:
  status: approved
  reviewerId: project-owner
  reviewedAt: 2026-07-24T09:12:03Z
  sourceCommit: 7ef36ad60aac753dc95ff4e6b3f0feb33c3202b0
  evidence:
    - art/exercise-static/briefs/BB_BENCH_PRESS.json
    - art/exercise-static/masters/approved/BB_BENCH_PRESS-v1.png
  notes: 批准候选 02 的平板凳、卧推架、直奥杆、对称杠铃片与卡扣结构。
rights:
  status: approved
  reviewerId: project-owner
  reviewedAt: 2026-07-24T09:12:03Z
  sourceCommit: 7ef36ad60aac753dc95ff4e6b3f0feb33c3202b0
  evidence:
    - art/exercise-static/reviews/input-policy-v1.md
    - art/exercise-static/reviews/openai-imagegen-terms-2026-07-24.md
    - art/exercise-static/masters/approved/BB_BENCH_PRESS-v1.provenance.json
  notes: 批准候选 02 的自有输入来源与当前记录的商业使用边界。
```

本记录批准高分辨率静态母版。288×288 JPG 已通过自动技术校验；真实双列卡片效果已在 `BB_BENCH_PRESS-runtime-card-review.md` 中由项目所有者验收，生产状态更新为 `released`。全部 12 个试点的快速滚动、包体和内存仍须后续统一验收。
