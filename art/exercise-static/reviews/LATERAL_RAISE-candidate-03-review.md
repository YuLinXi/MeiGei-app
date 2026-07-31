# `LATERAL_RAISE` 候选 03 待人工审核

## 生成范围

- 动作：`LATERAL_RAISE`（哑铃侧平举）
- 原创动作 brief：`art/exercise-static/briefs/LATERAL_RAISE.json`
- 人物身份输入：`art/exercise-static/references/approved/character-v1.png`
- 视觉风格输入：`art/exercise-static/references/approved/style-v1.png`
- 生成方式：Codex 内置 imagegen；候选 01 为原创生成，候选 02 只修正双肘屈曲和肘腕高度关系，候选 03 只移除双侧乳头/乳晕特征
- 第三方图片输入：无
- 当前结论：`approved-master`（运行时卡片验收待完成）

## 候选迭代

### 候选 01

- 本地文件：`art/exercise-static/staging/candidates/LATERAL_RAISE/LATERAL_RAISE-candidate-01.png`
- 尺寸：1254×1254 PNG，无 alpha
- 文件大小：1,561,870 bytes
- SHA-256：`b93a79008187c10ba456c44a60220c4d1490da9a7aa8b034f2ccb550add8354f`
- Codex 结论：不提交人工审批。人物、构图、哑铃和三角肌中束高亮基本可用，但双肘接近锁死，没有充分表达 brief 要求的轻微屈曲。

### 候选 02

- 本地文件：`art/exercise-static/staging/candidates/LATERAL_RAISE/LATERAL_RAISE-candidate-02.png`
- 尺寸：1254×1254 PNG，无 alpha
- 文件大小：1,622,548 bytes
- SHA-256：`8cccc26a38b1c8ae29a71bbc261f9b15b2b6616c997fddbd2fdae3abdfcc3339`
- Codex 结论：不提交人工审批。动作、器械和身份基本可用，但双侧乳头/乳晕形成清晰深色圆点与轮廓，违反 `style-v1` 锁定项及已确立的用户标准。

### 候选 03

- 本地文件：`art/exercise-static/staging/candidates/LATERAL_RAISE/LATERAL_RAISE-candidate-03.png`
- 尺寸：1254×1254 PNG，无 alpha
- 文件大小：1,663,186 bytes
- SHA-256：`2d46e20ff1d5aa3b314d411b824f32c4604d2931e1b3a4321c2b919d91f1bbc9`
- Git 边界：文件位于被 `.gitignore` 排除的 `art/exercise-static/staging/`，尚未进入正式母版或运行时资源。

## Codex 预检（不等同人工批准）

| 维度 | 自动预检 | 证据与风险 |
| --- | --- | --- |
| `identity` | 建议进入人工审核 | 略长椭圆脸、短深色低渐变发型、无胡须、自然健壮体型、黑色无 Logo 短裤和赤脚外观与 `character-v1` 基本一致；仍需项目所有者确认面部身份没有漂移。 |
| `art` | 建议进入人工审核 | 暖白背景、灰阶 graphite/ink、克制阴影和朱砂红层级一致，无文字、Logo、箭头或边框；候选 02 的双侧乳头圆点、乳晕环和凸起已移除，胸部改为连续低对比灰阶线稿。红色集中于双侧肩峰外侧，但正面可见区域仍需人工确认没有过多覆盖三角肌前束。 |
| `movement` | 建议进入人工审核 | 双脚约髋宽、躯干直立；双肩对称外展接近肩高，双肘轻微屈曲且高于手腕，腕部中立，没有耸肩、后仰或倒水式内旋。画面整体更接近正面弱透视而非严格 45°，但动作轮廓清晰，需人工决定是否接受此构图偏差。 |
| `equipment` | 建议进入人工审核 | 仅有两只尺寸与结构一致的短柄六角哑铃，握柄和两端对称配重头完整，双手闭合握持；右侧近端配重头被透视部分遮挡但结构仍可辨。 |
| `rights` | 建议进入人工审核 | 仅使用项目自有 `character-v1.png`、`style-v1.png`、原创 `LATERAL_RAISE.json` 及本次 imagegen 候选 01→02→03 的自有迭代链；没有下载、输入、转描或派生第三方图片。 |

## 人工审核闸门

以下状态只能由 `project-owner` 明确决定，Codex 预检不能自动改为 `approved`：

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

项目所有者已于 `2026-07-24T11:10:21Z` 明确批准五项。候选已提升为批准母版；运行时 JPG、manifest 技术校验与真实 104pt 卡片验收仍为后续独立步骤，发布状态在完成该验收前必须保持 `draft`。

## 最终生成提示词

候选 01 使用 `character-v1`（身份优先）与 `style-v1`（仅风格）生成站姿双臂哑铃侧平举顶部代表姿势，要求双肩外展接近 90°、两只匹配短柄哑铃、三角肌中束朱砂红高亮、其余人体和器械灰阶、暖白背景、全身与器械完整入画。候选 02 在候选 01 上仅定向调整双肘为约 10–15° 屈曲并使肘略高于腕，明确保持人物身份、哑铃、构图、色彩、背景和其余姿势不变。候选 03 在候选 02 上只移除双侧乳头圆点、乳晕环、圆形轮廓和凸起，以连续的低对比灰阶胸肌线稿填补，同时锁定人物身份、动作角度、哑铃、肩部高亮、构图和背景不变。
