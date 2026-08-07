# 正式资产与 iOS 发布契约

## 目录

- 动作数据：`ios/DontLift/DontLift/Resources/ExerciseLibrary/preset_exercises_v1.json`
- 统一人物：`art/exercise-static/references/approved/character-v1.png`
- 统一风格：`art/exercise-static/references/approved/style-v1.png`
- 动作 brief：`art/exercise-static/briefs/<CODE>.json`
- 本地候选：`art/exercise-static/candidates/<CODE>/`，Git 忽略
- 正式母版：`art/exercise-static/masters/approved/<CODE>-v1.png`
- 单动作审核：`art/exercise-static/reviews/<CODE>-review.json`
- 母版来源：`art/exercise-static/masters/approved/<CODE>-v1.provenance.json`
- 全局来源台账：`art/exercise-static/manifests/provenance-v1.json`
- 生产清单：`art/exercise-static/manifests/production-manifest-v1.json`
- iOS JPG 与 manifest：`ios/DontLift/DontLift/Resources/ExerciseArtwork/`

不要跟踪 `candidates/`、`staging/`、`cache/`、`logs/`，不要把高分辨率母版打入 App。

## 用户确认后的登记

使用项目所有者登记命令：

```bash
node art/exercise-static/scripts/exercise-static-assets.mjs owner-register CODE \
  art/exercise-static/candidates/CODE/CODE-candidate-NN.png
```

该命令允许为新动作创建 `v1` 母版，也允许在用户重新确认后替换同 code 的现有 `v1` 母版。它必须完成：

1. 复制最终候选为唯一批准母版；
2. 记录 `project-owner` 的 identity/art/movement/equipment/rights 五项批准；
3. 写入单动作和全局 provenance；
4. 导出 288×288、sRGB、无 Alpha、默认 Q82、≤24 KiB JPG；
5. 更新生产 manifest 和 iOS manifest；
6. 将条目标记为 `released` 并运行严格校验。

未获得当前候选明确确认时禁止运行该命令。

## 自治批量登记

只有用户明确授权无需逐张确认时才运行：

```bash
node art/exercise-static/scripts/exercise-static-assets.mjs autopilot-register CODE candidate.png
```

自治失败或存在争议时按 `art/exercise-static/reviews/autopilot-skipped-actions-v1.md` 记录，不降低标准发布。

## 校验命令

```bash
node art/exercise-static/scripts/exercise-static-assets.mjs export CODE
node art/exercise-static/scripts/exercise-static-assets.mjs preflight CODE
node art/exercise-static/scripts/exercise-static-assets.mjs validate
node art/exercise-static/scripts/exercise-static-assets.mjs coverage
node art/exercise-static/scripts/exercise-static-assets.mjs review-page
```

正式条目的技术约束以脚本为准。默认运行时图为 288×288、JPEG Q82、sRGB、无 Alpha、≤24 KiB；显式 code 级质量覆盖是例外，不是新默认值。

## Git 边界

- 提交 brief、正式母版、provenance、review、生产 manifest、iOS JPG、iOS manifest，以及本次确有必要的流水线改动。
- 不提交候选、生成缓存、审核临时页、构建产物或网页参考截图。
- 暂存前逐文件核对 `git status --short`，排除工作树里已有的无关修改或删除。
- 在提交说明中概括动作图正式替换与 skill/流水线变化，不把未完成验证写成已完成。
