---
name: produce-exercise-artwork
description: 为《别练了》制作、回修、审核并正式发布统一人物风格的健身动作图。用于新增或替换内置动作插画、核对标准动作与主流器械、根据用户参考图修正握法/接触点/绳索路径/运动阶段、逐张确认候选图，以及将已确认母版导出为 iOS 运行时 JPG 并同步 manifest；也用于检查动作图覆盖率和 App 资源是否完整。
---

# 制作健身动作图

在仓库根目录工作。复用 `art/exercise-static/` 的人物母版、动作 brief、审核记录和发布脚本，不另建平行资产流水线。

## 开始前

1. 阅读 [visual-standard.md](references/visual-standard.md)。
2. 阅读 [research-and-review.md](references/research-and-review.md)。
3. 需要写入正式资源时，再阅读 [asset-workflow.md](references/asset-workflow.md)。
4. 检查工作树，保留用户已有改动，只修改当前动作和必要的 manifest。
5. 从 `ios/DontLift/DontLift/Resources/ExerciseLibrary/preset_exercises_v1.json` 取得准确的 `code`、中文名、器械和类别。不要根据图片臆造名称。

如果 `code` 尚未进入预置动作库，先说明正式发布门禁尚未满足；只有用户同时授权新增动作数据时才修改预置库。

## 默认工作流

### 1. 调研并写动作 brief

- 先确认动作变体、主流器械、起始或中间阶段、运动方向、握法、手脚与器械接触点。
- 新器械动作、名称有歧义或用户指出错误时必须查阅资料；按 [research-and-review.md](references/research-and-review.md) 选源。
- 创建或更新 `art/exercise-static/briefs/<CODE>.json`，遵循 `exercise-brief-v1.schema.json`。
- 用 `rejectionCases` 明确最容易混淆的相邻动作、错误器械和错误姿势。
- 在生成前用简短中文向用户说明本次会锁定的动作特征；不要先生成再猜动作。

### 2. 生成候选图

- 先查看：
  - `art/exercise-static/references/approved/character-v1.png`
  - `art/exercise-static/references/approved/style-v1.png`
  - 当前动作 brief
  - 同器械或同动作族已发布母版
- 使用 image generation，并把 `character-v1.png` 与 `style-v1.png` 作为项目自有 reference。
- 第三方网页或用户截图只用于提取动作事实，不直接作为生成输入，除非来源台账已有可用于 AI reference/edit 和商业分发的明确许可。
- 将候选保存为 `art/exercise-static/candidates/<CODE>/<CODE>-candidate-<NN>.png`。候选目录保持 Git 忽略。
- 每次只展示一个动作的一个明确候选，并同时标注中文名和 `code`。

### 3. 逐张确认与定点回修

- 默认等待用户明确回复“确认”“正确”或等价表达后再正式发布。
- 用户指出局部问题时，以最新候选为基础，只修改指定区域；保留已确认的人物、器械、视角、背景和肌肉高亮。
- 每次回修增加候选编号，不覆盖旧候选，便于确认最终定稿。
- 对手、把手、钢索、滚筒、挡板、杠铃片、脚掌和身体朝向执行局部放大检查。
- 无法稳定画对时继续调研或记录待确认项，不把有争议的候选放入正式目录。

### 4. 正式发布已确认候选

仅在用户明确确认后运行：

```bash
node art/exercise-static/scripts/exercise-static-assets.mjs owner-register <CODE> \
  art/exercise-static/candidates/<CODE>/<CODE>-candidate-<NN>.png
```

该命令应以 `project-owner` 写入五项审核和来源台账，更新或创建批准母版，确定性导出 288×288 iOS JPG，并将条目标记为 `released`。

只有用户明确授权整批自治时，才使用：

```bash
node art/exercise-static/scripts/exercise-static-assets.mjs autopilot-register <CODE> <candidate.png>
```

不得把自治审核伪装成 `project-owner` 确认，也不得把未确认候选直接复制到 `masters/approved/`。

### 5. 验证并交付

至少运行：

```bash
node art/exercise-static/scripts/exercise-static-assets.mjs preflight <CODE>
node art/exercise-static/scripts/exercise-static-assets.mjs validate
node art/exercise-static/scripts/exercise-static-assets.mjs coverage
git diff --check
```

本轮包含正式 iOS 资源替换时，再运行仓库 `AGENTS.md` 规定的 iOS 构建命令。核对：

- 正式生产 manifest、iOS manifest 和运行时 JPG 的 code 集合一致；
- SHA-256、尺寸、JPEG 质量和文件大小一致；
- 没有候选图、动态媒体、第三方参考图或孤立 JPG 进入 Git；
- 真实卡片尺寸下仍能辨认动作、器械、握法和运动方向；
- 未暂存或提交无关工作树改动。

最终汇报已确认并发布的动作、校验结果、未验证项和剩余待确认项。只有用户要求提交时才执行 Git 提交。

## 失败保护

- 动作或器械存在争议：停止发布，继续调研或记录待确认项。
- 人物一致但动作错误：优先修动作和接触关系，不更换人物外观。
- 动作正确但人物漂移：以 `character-v1` 重做，不把错误人物当作新标准。
- 运行时 JPG 超过 24 KiB：保持 288×288 与构图不变，先检查画面复杂度；只有确有必要时才为该 code 设置显式质量覆盖，并记录原因。
- 用户要求两个 code 共用一张图：确认动作语义确实相同后复用同一批准画面，但仍保留各自的 code、brief、运行时文件和 manifest 条目。
