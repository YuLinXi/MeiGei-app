# `DEADLIFT` 候选 08 人工审核

## 候选

- 本地候选：`art/exercise-static/staging/candidates/DEADLIFT/DEADLIFT-candidate-08.png`
- 动作 brief：`art/exercise-static/briefs/DEADLIFT.json`
- 尺寸：1254×1254 PNG，无 alpha
- 文件大小：1,489,968 bytes
- SHA-256：`cffe2f559e68e2759db40db88ea6257d9c6a2de4e7373fc96a241a1ab8df3a87`
- 当前状态：`approved-master`（运行时卡片验收待完成）
- 来源 commit：`7ef36ad60aac753dc95ff4e6b3f0feb33c3202b0`
- Codex 预检时间：`2026-07-24T10:00:32Z`
- 说明：候选位于 Git 忽略的 `staging/`，未进入 `masters/approved/`、production manifest 或 iOS 运行时资源。

## 生成输入与 prompt 链

使用 Codex built-in imagegen；built-in tool 未暴露底层模型版本。

唯一图片输入：

1. `art/exercise-static/references/approved/character-v1.png`：人物 identity reference，身份优先级最高；
2. `art/exercise-static/references/approved/style-v1.png`：灰阶 graphite/ink、色板、暖白背景与器械表现的 style reference；
3. 后续精修只使用同一轮 imagegen 自有候选作为 edit target，并继续附带上述两个已批准 reference。

原创文字输入为 `art/exercise-static/briefs/DEADLIFT.json`。没有下载、传入、转描或风格迁移任何第三方动作图片。

最终采用的 prompt 链：

1. 重新生成传统站距杠铃硬拉的离地前起始姿势；明确从画面左到右必须依次为“左杠铃片、左手、左膝/小腿/脚、躯干、右膝/小腿/脚、右手、右杠铃片”，从生成阶段保证双手位于双腿外侧。
2. 只统一缩小并居中完整人物与杠铃，使所有外缘获得至少 8% 安全边距。
3. 只移除胸部乳头圆点、乳晕环和凸起，保持其他身份、动作、器械、肌肉高亮与构图不变。

最终精修 prompt：

```text
Remove only the two visible male nipple dots, areola rings, and any nipple protrusions from the chest in Image 1. Blend those tiny areas into understated grayscale pectoral muscle linework and soft shading so there are no circular marks or dark focal points.

Change only the nipple/areola features. Preserve Image 1's exact person identity, face, haircut, expression, body proportions, pose, correct double-overhand hands-outside-legs grip geometry, straight arms, narrow stance, neutral spine, full barbell, equal floor-touching plates, at-least-8% margins, camera, every muscle highlight location/color, warm off-white background, graphite-and-ink style and shadows. Do not shift, resize, redraw or add anything else.

Avoid any visible nipple dot, areola ring or nipple bump; changed identity; changed grip; hand between legs; changed equipment; extra/missing limbs; text; logo; arrows; watermark.
```

## 失败迭代

- 候选 01：完整动作基本成立，但杠铃两端距离画布边缘不足 8%。
- 候选 02：安全边距改善，但男性乳头圆点仍较明显。
- 候选 03–04：完成乳头弱化，但 45° 透视下观察者左手与近侧膝的前后关系仍不够明确。
- 候选 05：针对握距的 edit 生成了多余脚部，明确拒绝。
- 候选 06：重新生成后双手明确位于双腿外侧，但横向安全边距不足。
- 候选 07：安全边距达到要求，仍需移除乳头圆点。
- 候选 08：保留候选 07 的动作与器械，仅完成乳头特征弱化，进入人工审核。

失败候选未进入正式目录、manifest 或运行时资源。

## Codex 预检（不等同人工批准）

- `identity`：略长椭圆脸、短深色低渐变发型、自然健壮比例、黑色无 Logo 短裤和赤脚造型与 `character-v1` 基本一致；弯髋姿势下脸部仍可辨认。
- `art`：灰阶医学健身线稿、暖白背景、朱砂红主动肌和浅红协同肌符合 `style-v1`；胸部乳头/乳晕特征已移除；无文字、Logo、箭头或水印。主体在 288×288 预览中仍可清楚辨认。
- `movement`：传统硬拉离地前起始位明确；杠铃贴近小腿并位于中足上方，髋高于膝且低于肩，脊柱与头颈保持中立，双臂伸直；两只正握手均清楚位于对应腿外侧。
- `equipment`：完整直奥杆、左右对称大直径圆片、套筒与卡扣可辨认，双片触地；未出现六角杠、史密斯导轨、架上拉、垫高或额外器械，四周安全边距超过 8%。
- `rights`：图片输入仅为本项目自有 `character-v1`、`style-v1` 与本轮自有候选；文字输入仅为原创 `DEADLIFT` brief 和精修指令。未使用第三方媒体。

## 人工审核关注点

- 30° 前侧弱透视使左右杠铃片存在合理的近大远小；请确认该透视仍满足“对称安装同规格圆片”的器械表达。
- 代表姿势为杠铃离地前起始位，不是锁定站立位；请确认该姿势在动作库卡片中符合对“硬拉”的识别预期。

## 待项目所有者审核

以下状态必须由 `project-owner` 明确逐项批准或拒绝，Codex 不得代签：

```yaml
identity:
  status: approved
art:
  status: approved
movement:
  status: approved
equipment:
  status: approved
rights:
  status: approved
```

项目所有者已于 `2026-07-24T11:10:21Z` 明确批准五项，包括弱透视下的对称圆片表达与离地前起始位。候选已提升为批准母版；运行时 JPG、manifest 技术校验与真实 104pt 卡片验收仍为后续独立步骤，发布状态在完成该验收前必须保持 `draft`。
