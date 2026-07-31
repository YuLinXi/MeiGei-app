# 11 个代表动作 brief 核对记录

## 边界

本轮为 `BB_BENCH_PRESS`、`BB_SQUAT`、`DEADLIFT`、`OHP`、`BB_ROW`、`LAT_PULLDOWN`、`LATERAL_RAISE`、`DB_CURL`、`TRICEP_PUSHDOWN`、`LUNGE`、`PLANK` 编写原创 JSON brief。

- code、中文名、器械分类和肌群字段以仓库内 `preset_exercises_v1.json` 为准。
- 动作姿势只核对公开的文字动作要点，不复制原文，不下载或保存第三方图片。
- 任何第三方网页、截图或图片都不得作为 imagegen reference/edit 输入；正式生成仍只允许 `character-v1`、`style-v1` 与对应原创 brief。
- brief 是后续生成与人工审核的约束，不代表动作图片已经制作或批准。

## 文字事实核对

核对时使用 American Council on Exercise 的公开文字动作说明：

- [Chest Press](https://www.acefitness.org/resources/everyone/exercise-library/5/chest-press/)
- [Back Squat](https://www.acefitness.org/resources/everyone/exercise-library/11/back-squat/)
- [Bent-over Row](https://www.acefitness.org/resources/everyone/exercise-library/12/bent-over-row/)
- [Standing Shoulder Press](https://www.acefitness.org/resources/everyone/exercise-library/71/standing-shoulder-press/)
- [Seated Lat Pulldown](https://www.acefitness.org/resources/everyone/exercise-library/158/seated-lat-pulldown/)
- [Lateral Raise](https://www.acefitness.org/resources/everyone/exercise-library/26/lateral-raise/)
- [Seated Biceps Curl](https://www.acefitness.org/resources/everyone/exercise-library/44/seated-biceps-curl/)
- [Triceps Pressdown](https://www.acefitness.org/resources/everyone/exercise-library/3/triceps-pressdown/)
- [Dumbbell Lunge](https://www.acefitness.org/resources/everyone/exercise-library/363/lunge/)
- [Front Plank](https://www.acefitness.org/resources/everyone/exercise-library/32/front-plank/)

`DEADLIFT` 的变体、动作名称、主要与协同肌边界沿用仓库既有 preset；brief 采用常规站距、双手位于双腿外侧、杠铃从地面中足位置起始的传统硬拉，明确排除相扑、罗马尼亚和六角杠变体。

## 统一约束

- 使用同一个 `character-v1` 和 `style-v1`。
- 主动肌使用朱砂红，协同肌使用浅红，其余人体和器械保持灰阶。
- 使用弱透视 45° 构图；背部动作允许 45° 后侧视角，以保证目标肌可读。
- 完整保留头、手、脚和动作识别所必需的器械结构。
- 禁止品牌、文字、Logo、箭头、健身房背景、随机器械和不相关肌肉高亮。
