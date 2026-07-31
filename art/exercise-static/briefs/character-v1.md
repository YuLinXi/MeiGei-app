# `character-v1` 统一角色 brief

## 目标

创建一个完全原创、非真人、非名人的成年男性健身角色，作为《别练了》全部静态动作图的唯一人物身份参考。角色表必须同时展示同一人的正面、45° 前侧面和标准侧面，便于后续 imagegen reference/edit 保持脸型与体型。

## 身份锁定

- 年龄观感：28–35 岁成年男性。
- 脸型：略长的椭圆脸，下颌清晰但不过度方正，颧骨适中。
- 发型：短深色头发，低渐变侧边，顶部短而自然，无胡须。
- 体型：自然健壮、肌肉清晰但非健美赛夸张比例；肩宽、腰窄，四肢长度真实。
- 服装：纯黑色、无 Logo、不过膝的训练短裤；赤脚；无首饰、护具、纹身。
- 表情：中性、专注，三视图保持同一面部特征。

## 视觉锁定

- 高质量灰阶医学健身插画，细腻铅笔与墨线结合，轻微纸张纹理。
- 皮肤和肌肉结构用灰阶塑造，不暴露内脏、不剥离皮肤、不做血腥解剖。
- 暖白色 `#F6F3EC` 纯净背景，柔和落地阴影。
- 三个全身人物等比例、等高度、彼此分离，全部完整显示手脚，保留安全边距。
- 不使用红色肌肉高亮；角色表只锁定身份，目标肌颜色由 `style-v1` 定义。

## 禁止项

- 不使用真人、名人、现有游戏/影视/漫画角色或品牌人物的 likeness。
- 不出现器械、道具、文字、标签、编号、Logo、水印或装饰边框。
- 不允许三视图换脸、发型变化、体型变化、服装变化、肢体缺失/增加、手指融合或左右结构错误。

## imagegen prompt

```text
Use case: scientific-educational
Asset type: original canonical character identity sheet for a fitness exercise illustration library
Primary request: Create one polished wide horizontal character sheet showing the exact same original fictional adult male athlete in three full-body views: front view, three-quarter front view at 45 degrees, and strict side view. This is a new fictional person, not based on any real person, celebrity, public figure, existing character, or brand mascot.
Scene/backdrop: perfectly clean warm off-white #F6F3EC studio background with only a very soft grounding shadow
Subject: one consistent 28–35-year-old male athlete, slightly long oval face, defined but not square jaw, medium cheekbones, short dark hair with low faded sides and short natural top, clean-shaven, neutral focused expression, naturally athletic muscular build rather than bodybuilding-stage mass, realistic shoulder-to-waist ratio and limb proportions, plain black logo-free training shorts above the knee, barefoot, no jewelry, no tattoos, no equipment
Style/medium: premium grayscale medical fitness illustration, refined pencil-and-ink linework with subtle paper texture, anatomically plausible surface muscle definition beneath intact skin, elegant controlled shading, non-photorealistic but highly polished
Composition/framing: wide horizontal three-view model sheet, three figures equal scale and equal height, evenly spaced and clearly separated, every head, hand, finger, leg, and foot fully visible, generous outer padding, consistent eye level and lighting
Color palette: grayscale figure and shorts, warm off-white background only; no colored muscle highlights in this identity sheet
Constraints: all three views must unmistakably depict the same face, haircut, body proportions, muscle mass, skin tone, shorts, and age; correct human anatomy; exactly two arms and two legs per figure; hands and feet anatomically coherent
Avoid: text, labels, numbers, logos, watermark, border, panels, props, gym equipment, red highlights, exposed internal organs, flayed skin, gore, superhero proportions, bodybuilder competition physique, facial hair, different people, duplicate limbs, cropped extremities, fused fingers, distorted hands or feet
```
