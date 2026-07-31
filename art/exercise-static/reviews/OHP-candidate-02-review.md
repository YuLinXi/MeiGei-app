# `OHP` 候选 02 人工审核

## 修改目标

首轮候选的动作、杠铃结构和构图基本可用，但胸部出现明显深色乳头圆点，不符合 `style-v1`。候选 02 只通过 imagegen edit 弱化并移除该特征，要求保持人物身份、严格站姿推举姿势、杠铃结构、肌肉高亮和构图不变。首轮失败图未复制进项目目录。

## 候选

- 本地候选：`art/exercise-static/staging/candidates/OHP/OHP-candidate-02.png`
- 尺寸：1254×1254 PNG，无 alpha
- 文件大小：1,575,856 bytes
- SHA-256：`959a5d101c02c00537a781ea7eeb30ae693d52ed12c1d3e40052b10b29045d5c`
- 当前状态：`approved-master`（运行时卡片验收待完成）
- 版本控制边界：文件位于 Git 忽略的 `staging/`，人工五项批准前不得复制到 `masters/approved/` 或运行时资源。

## 生成输入

只使用以下项目自有输入：

1. `art/exercise-static/references/approved/character-v1.png`：人物身份最高优先级；
2. `art/exercise-static/references/approved/style-v1.png`：灰阶 graphite/ink、红色层级、暖白背景和阴影语言；
3. `art/exercise-static/briefs/OHP.json`：原创动作、器械、握法、接触点、关节方向和排除项；
4. 首轮 imagegen 输出：仅作为候选 02 的 edit target，未使用第三方媒体。

未下载、输入、转描或风格迁移任何第三方动作图片。

## Codex 预检（不等同人工批准）

### identity

- 短深色低渐变发型、无胡须、略长椭圆脸、自然健壮体型、纯黑训练短裤和赤脚造型与 `character-v1` 基本一致。
- 全身结构完整，未发现多余或缺失肢体、明显手指融合、左右颠倒或关节畸形。
- 面部角度和举臂状态会改变轮廓观感，最终是否足够像同一角色必须由 `project-owner` 决定。

### art

- 灰阶 graphite/ink、暖白背景、克制阴影和留白与 `style-v1` 基本一致；无文字、Logo、水印、箭头或环境杂物。
- 候选 01 的深色乳头圆点已移除，胸部只保留低对比肌肉轮廓。
- 三角肌前束使用朱砂红，肱三头肌和三角肌中束使用浅红，其余人体和杠铃保持灰阶；在 288×288 临时缩览下仍可读。

### movement

- 人物双脚约髋宽、全掌着地，膝髋伸展，躯干基本垂直，未表现明显腿部借力、挺举或腰椎过伸。
- 杠铃位于头顶，双肘接近伸直但未见明显反张，头部位于双臂之间；双手闭合正握，握距略宽于肩。
- 构图为弱透视前侧视角，但接近正面；项目所有者需确认该角度是否足够满足 45° 前侧识别要求。

### equipment

- 一根连续直奥杆、两侧对称小型圆形杠铃片和卡扣完整可辨，杠铃基本水平并位于身体中线正上方。
- 未出现史密斯导轨、座椅、靠背、机架、哑铃或其他多余器械。

### rights

- 输入仅包含项目自有角色母版、风格母版、原创 `OHP` brief 和本轮 imagegen 输出。
- 未使用 `hasaneyldrm/exercises-dataset` 或其他第三方媒体作为 reference、edit、转描、贴图或训练输入。
- AI 输出不自动等于独占或无侵权，最终 rights 结论仍须 `project-owner` 明确签署。

## 待项目所有者逐项决定

```yaml
identity: approved
art: approved
movement: approved
equipment: approved
rights: approved
```

项目所有者已于 `2026-07-24T11:10:21Z` 明确批准五项。候选已提升为批准母版；运行时 JPG、manifest 技术校验与真实 104pt 卡片验收仍为后续独立步骤，发布状态在完成该验收前必须保持 `draft`。
