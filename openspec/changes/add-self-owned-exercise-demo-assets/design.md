## Context

内置动作使用稳定 `BuiltinExercise.code`，当前约 226 个动作。目标产品形态是 180×180 GIF 动画与 JPG 缩略图，但第三方参考仓库的媒体不在其 MIT License 范围内，不能作为生成输入或正式素材。

前期探索得到两项结论：

1. imagegen 能较快产出高质量静态解剖插画和器械构图；
2. imagegen 独立生成或编辑多帧时，人物身份、器械结构、转轴、配重、相机和画面位置会漂移，不能直接承担正式动画生产。

本设计因此把“美术方向”与“运动确定性”拆开。被批准的 imagegen 静态母版负责定义视觉目标；Blender 重新建立原创三维资产、骨骼和机械约束，并成为所有动画帧与正式 GIF/JPG 的生产真相源。

本 change 当前仍在规划阶段。本轮不创建实现文件。

## Goals / Non-Goals

**Goals：**

- 建立可跨电脑恢复、可审核、可重复导出的动作演示生产链。
- 让 imagegen 提升静态美术质量，同时不承担逐帧一致性职责。
- 让 Blender 保证人物、器械、相机、目标肌和运动轨迹的确定性。
- 为每个器械动作建立可验证的常规器械与机械联动标准。
- 输出统一 180×180 GIF/JPG，并以稳定 code 关联 App。
- 先通过 `PEC_DECK_FLY` 单动作质量闸门，再扩展到最多 12 个试点。
- 保留 prompt、输入来源、AI 工具、人工修改、Blender 源和审核记录的完整 provenance。

**Non-Goals：**

- 不把 AI 多帧或单张 AI 输出直接作为正式 App 动画。
- 不复制、转描、风格迁移或输入受限第三方媒体。
- 不完成全部 226 个动作，不批量生成占位素材。
- 不增加视频、SVG、APNG、交互式 3D、CDN 或运行时下载。
- 不修改后端、同步协议、动作分类或自定义动作数据模型。

## Decisions

### D1：imagegen 静态母版只负责美术方向

每个动作族先生成一张高分辨率静态母版，内容可约束：

- 人体体型、解剖细节密度和灰阶线稿质感；
- 主要目标肌红橙色、协同肌浅红、其他结构灰阶；
- 常规器械类别、画面构图、相机方向、光影和留白；
- 开放位或最能说明动作与器械关系的代表姿势；
- 缩小到 180×180 后仍需保留的视觉优先级。

静态母版不是正式动作帧，也不是 Blender 贴图。它只能作为建模、材质、相机和审核的视觉基准。imagegen 不独立生成 12 帧，不通过变体图、插帧或光流掩盖几何漂移。

被采用母版必须记录：

```json
{
  "assetId": "PEC_DECK_FLY_ART_MASTER_V1",
  "exerciseCode": "PEC_DECK_FLY",
  "tool": "<provider/model/version>",
  "promptFile": "<repo-relative-path>",
  "inputs": [
    { "kind": "text", "source": "原创器械与动作 brief" },
    { "kind": "owned-or-cleared", "path": "<optional-path>", "license": "<license>" }
  ],
  "humanEdits": "<description>",
  "sha256": "<digest>",
  "reviews": { "art": "pending", "equipment": "pending", "rights": "pending" }
}
```

未采用候选图、实验 sprite sheet 和失败多帧不进入 Git。被采用母版属于不可确定性重建的正式生产输入，需要版本化并使用路径限定的 Git LFS。

### D2：受限参考只能提供通用事实，不能成为媒体输入

`hasaneyldrm/exercises-dataset` 只可帮助确认 180×180 产品形态以及“蝴蝶机通常具有座椅、靠背、左右力臂、握把、转轴与配重”等通用事实。其 JPG/GIF 不得：

- 下载或复制进仓库；
- 作为 imagegen reference image、edit target、ControlNet、图生图或训练输入；
- 被转描、抠图、风格迁移或作为 Blender 贴图/背景；
- 用于逐像素构图或动作帧复刻。

正式输入只能是文字 brief、自有素材、明确允许该用途的开放素材或本项目创建的 Blender 截图。实施时需重新核对 imagegen 服务条款并归档证据；模型输出不自动视为独占或无需审核。

### D3：Blender 原创重建是生产真相源

Blender 根据获批静态母版重新建立：

- 许可清晰、可编辑的人体基础网格与 Rigify 骨骼；
- 本项目自制表层肌肉 mask；
- 原创器械网格、转轴、力臂、握把、配重和联动关系；
- 固定正交相机、暖白背景、材质、描边和灯光；
- 12 帧骨骼姿势、器械约束与渲染 scene。

母版中的形态只作为视觉目标，Blender 不把母版直接投影成人体或器械纹理，也不通过二维切片伪造机械运动。最终帧必须由可编辑三维资产渲染。

Blender 文件须 Pack Resources，或只使用 `//` 仓库相对路径。fresh clone 在不安装个人 Add-on、未采用 AI 服务和没有旧电脑缓存的情况下仍应可以编辑和重渲染。

### D4：每个器械动作先通过常规器械验收卡

器械验收卡至少声明：

- `equipmentFamily`：动作使用的常规器械类别；
- `recognitionFeatures`：用户在 180×180 下仍应辨认的特征；
- `stationaryParts`：整个动画中逐帧固定的机架、座椅、靠背等；
- `movingParts`：力臂、握把、滑轮、配重等活动组件；
- `pivotAndPath`：每个活动组件的转轴与运动轨迹；
- `bodyContacts`：背、臀、脚、手等接触点；
- `rejectionCases`：容易误生成的近似器械或错误动作。

`PEC_DECK_FLY` 的最低标准：中央座椅与垂直靠背、刚性支架、顶部或肩部左右对称转轴、两侧力臂与握把、可解释的配重/滑轮联动；人物坐姿稳定、背贴靠垫、双脚着地、双臂在肩高附近对称开合。不得变成胸推、绳索夹胸或只有装饰性框架的泛化器械。

### D5：人体骨骼与器械约束共同驱动 12 帧

动态动作固定 12 个渲染帧，由同一 Blender scene/collection、同一相机、同一人体和同一器械生成。允许变化的内容必须显式列入 animation contract：

- 肩、肘、腕等相关骨骼姿势；
- 器械左右力臂绕既定转轴的角度；
- 配重或滑轮的机械联动；
- 必要的肌肉形变，但目标肌高亮区域身份不变。

人物身份、头部、躯干、座椅、静止机架、背景、相机、画布和光照不得逐帧漂移。起点到终点使用 6 帧，回程使用 6 帧或镜像时序，循环接缝由同一确定性姿势保证，不使用 AI 补帧。

### D6：统一高分辨率渲染与 180×180 交付

Blender 先输出至少 720×720、sRGB、8-bit RGBA PNG。编码器再：

1. 合成到固定 `#F6F3EC` 暖白背景；
2. 使用高质量 Lanczos 缩小到 180×180；
3. 生成 12 帧、无限循环 GIF；
4. 以 manifest 指定代表帧生成 180×180 JPG；
5. 校验尺寸、帧数、时长、循环、颜色、摘要、非空图和孤立资源。

默认节奏仍为起点和最大收缩位各停留 1000 ms，其余帧 100 ms，总周期 3000 ms。真机审核若决定修改，必须提升 asset version 并整批重新导出。

### D7：五类审核独立，首个动作是扩量闸门

- `art`：解剖比例、线稿、肌肉辨识、构图和颜色；
- `movement`：动作变体、关节方向、接触点和运动轨迹；
- `equipment`：器械类别、静止/活动组件、转轴和配重联动；
- `rights`：prompt、输入、工具条款、License、人工修改和文件摘要；
- `technical`：manifest、帧、GIF/JPG、LFS、恢复和 App 成本。

`PEC_DECK_FLY` 必须首先通过全部五类审核。通过后才制作 `BB_BENCH_PRESS`、`BB_SQUAT`、`LATERAL_RAISE`，第二道闸门通过后再补齐 12 个试点。单个动作失败只阻止自身，不生成占位，也不降低其他动作标准。

### D8：生产 manifest 与运行时 manifest 分离

生产 manifest 保存母版、器械验收卡、Blender scene、目标肌、帧时序、审核和发布状态。运行时 manifest 是可重建产物，只包含稳定 code、演示类型和 GIF/JPG 文件名。

只有 `releaseStatus == released` 且五类审核均为 `approved` 的条目可以 promote。动态动作必须同时存在 GIF/JPG；静态动作只需 JPG。首批运行时 manifest 最多包含本 change 声明的 12 个 code。

### D9：iOS 只消费已提交的正式媒体

未来实现时，GIF/JPG 作为 Bundle Resources 随 App 提交。`ExerciseDemoLibrary` 按 code 安全解析；必要文件缺失时整卡隐藏。动态 GIF 默认循环，点击暂停/继续；Reduce Motion 只加载 JPG，不能先解码 GIF。VoiceOver 朗读动作名称、演示类型和播放状态。

动作演示位于详情页标题与 meta 之后，不替代 `MuscleMapView`，不在动作列表解码 GIF，不写训练数据，也不为自定义动作猜测映射。iOS 使用 ImageIO/UIKit，不引入第三方运行时依赖。

### D10：同仓版本化与 fresh-clone 验证

未来目录规划：

```text
art/exercise-demo/
├── references/approved/      # 被采用 imagegen 静态母版与 prompt，Git LFS + 普通 Git
├── manifests/                # 生产 manifest、器械验收卡、schema
├── blender/                  # 可编辑 .blend，Git LFS
├── textures/                 # 实际使用贴图
├── scripts/                  # 渲染、编码、校验、promote
├── reviews/                  # 五类审核与来源台账
└── staging/                  # 可重建帧和候选，忽略

docs/exercise-demo-previews/  # Contact Sheet 与压缩审核预览

ios/DontLift/DontLift/Resources/ExerciseDemos/
├── exercise_demo_manifest_v1.json
├── exerciseDemo_<CODE>.gif
└── exerciseDemo_<CODE>.jpg
```

Git LFS 规则必须路径限定，不能迁移海报、hero、肌群图等无关图片。最终验收需在独立 fresh clone 中完成 `git lfs pull`、Blender 重渲染、媒体摘要比对以及无需 Blender 的 iOS 构建。

## Risks / Trade-offs

- **AI 母版漂亮但不可执行**：器械卡、动作卡和 Blender 约束优先于视觉照搬。
- **从静态母版重建成本较高**：先用一个动作闸门验证，不提前扩量。
- **AI 输出来源或权利不清**：只允许自有/许可清晰输入，保留条款证据与完整 provenance，不承诺独占。
- **器械外形正确但机械错误**：拆分静止/活动组件并验证转轴、握把、配重联动。
- **GIF 颜色和边缘受限**：使用固定背景、受控调色板和真机审核，不静默改格式。
- **Blender 二进制难以 diff**：manifest、prompt、摘要、审核和 Contact Sheet 使用普通 Git。
- **LFS 历史增长**：只保留被采用母版、正式 Blender 版本与正式媒体，扩量前复核预算。

## Migration Plan

本 change 尚未实施，无既有生产资源需要迁移。未来按以下顺序执行：

1. 先建立来源、母版和器械验收 schema；
2. 生成并批准 `PEC_DECK_FLY` 静态母版；
3. 在 Blender 原创重建并输出确定性 12 帧；
4. 编码、审核并在真实详情页验证首个 GIF/JPG；
5. 通过首道闸门后扩展三个代表动作，再扩展至 12 个；
6. 最后完成 LFS、fresh clone、包体、内存和 iOS 验收。

回滚时删除运行时 manifest 条目、正式 GIF/JPG 和演示卡即可，不涉及数据迁移；生产源与审核历史保留。

## Open Questions

- 谁负责动作、器械和权利审核的最终签字？
- imagegen 实施时选用的具体服务、模型和账户条款是什么？
- GitHub LFS 预算是否允许保存 12 个动作的母版、Blender 历史和正式媒体？
- `PEC_DECK_FLY` 真机审核后，3000 ms 循环节奏是否需要调整？
