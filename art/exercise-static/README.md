# 静态动作图生产目录

本目录保存《别练了》自有静态动作图的必要生产资源。正式交付物只有静态图片，不包含 Blender、GIF、视频、帧序列或运行时生成逻辑。

## 目录约定

- `references/approved/`：项目所有者已批准的统一角色与风格母版，以及对应 prompt/brief。
- `masters/approved/`：逐动作批准的高分辨率母版。
- `briefs/`：以 `BuiltinExercise.code` 命名的动作与器械验收卡。
- `manifests/`：生产 manifest、来源台账和 JSON Schema。
- `reviews/`：自治/人工审核记录、输入政策和条款核对证据。
- `scripts/`：确定性导出、校验、promote 和联系表脚本。
- `staging/`、`candidates/`、`cache/`、`logs/`：仅限本机，已由 `.gitignore` 排除。

## 发布边界

1. 新候选必须以已批准 `character-v1`、`style-v1` 和原创动作 brief 作为输入。
2. `identity`、`art`、`movement`、`equipment`、`rights` 五类审核均为 `approved`，且技术校验通过后，才允许 promote。
3. 默认审核主体为 `production-autopilot`，适用范围和跳过规则见 `reviews/autopilot-production-policy-v1.md`；只有明确由项目所有者人工决定的历史记录才能使用 `project-owner` 身份。
4. App 只消费 `ios/DontLift/DontLift/Resources/ExerciseArtwork/` 中的纯白底 288×288、JPEG 质量 82、≤24 KiB JPG 与运行时 manifest；高分辨率母版不会打入 App。

## 本地命令

```bash
# 将旧肌群 PNG 的烘焙背景转为透明；只处理 muscleThumb_male_*.png
swift art/exercise-static/scripts/normalize-muscle-thumbnail-background.swift \
  ios/DontLift/DontLift/Assets.xcassets

# 导出到 Git 忽略的 staging，供人工检查
node art/exercise-static/scripts/exercise-static-assets.mjs export PEC_DECK_FLY

# 生成角色联系表与 288×288 / 双列卡片离线审核页
node art/exercise-static/scripts/exercise-static-assets.mjs review-page

# 校验正式 manifest、摘要、尺寸、颜色、大小、孤立文件和禁入文件
node art/exercise-static/scripts/exercise-static-assets.mjs validate

# 输出 224 个预置动作的 released / draft / skipped / uncovered 覆盖统计
node art/exercise-static/scripts/exercise-static-assets.mjs coverage

# 只运行 promote 人工与技术门禁，不写入运行时目录
node art/exercise-static/scripts/exercise-static-assets.mjs preflight PEC_DECK_FLY

# 仅在五项自治或人工审核均通过后写入运行时资源；`production-autopilot` 条目直接发布，历史人工条目先保持 draft
node art/exercise-static/scripts/exercise-static-assets.mjs promote PEC_DECK_FLY

# 候选已完成视觉初检后，自动生成五项自治审核、来源台账、母版并发布
node art/exercise-static/scripts/exercise-static-assets.mjs autopilot-register BB_ROW \
  art/exercise-static/candidates/BB_ROW/BB_ROW-candidate-01.png

# 项目所有者明确确认候选后，以人工审核身份登记、更新母版并正式发布
node art/exercise-static/scripts/exercise-static-assets.mjs owner-register BB_ROW \
  art/exercise-static/candidates/BB_ROW/BB_ROW-candidate-02.png

# 为历史人工审核条目完成真实列表验收后，单独将 draft 切为 released
node art/exercise-static/scripts/exercise-static-assets.mjs release BB_SQUAT
```

## 当前阶段

`character-v1`、`style-v1`、`PEC_DECK_FLY-v1` 与 `BB_BENCH_PRESS-v1` 高分辨率母版已由项目所有者批准。后续全部预置动作按 `autopilot-production-policy-v1.md` 自治推进；存在无唯一标准或无法稳定满足质量规则的动作必须写入跳过台账，而不是降低质量发布。
