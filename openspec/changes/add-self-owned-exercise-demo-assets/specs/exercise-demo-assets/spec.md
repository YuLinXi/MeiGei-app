## ADDED Requirements

### Requirement: imagegen 静态母版与正式动画职责分离

系统 SHALL 使用经过人工批准的 imagegen 静态母版定义动作演示的解剖表现、肌肉强调、器械类别、构图、相机方向和视觉风格。静态母版 MUST NOT 直接作为 App 动画帧、Blender 贴图或独立生成正式多帧；正式 GIF/JPG MUST 由 Blender 中可编辑的人体、器械、骨骼、约束、相机、材质和灯光确定性渲染。

被采用的静态母版 SHALL 记录动作 code、完整 prompt、工具/模型版本、全部输入及 License、生成日期、人工修改、文件摘要和审核状态。未采用候选与失败多帧 MUST NOT 进入版本控制。

#### Scenario: 静态母版通过后进入 Blender
- **GIVEN** `PEC_DECK_FLY` 有一张通过美术、器械和权利初审的静态母版
- **WHEN** 开始制作动画
- **THEN** Blender 根据母版重新建立可编辑人体、器械、骨骼、约束和固定相机
- **AND** 正式帧不直接使用该母版的像素

#### Scenario: AI 多帧存在漂移
- **WHEN** imagegen 候选多帧出现人物、器械、相机或运动轴漂移
- **THEN** 这些帧不得编码或 promote 为正式 GIF
- **AND** 系统不得通过插帧、光流或淡化掩盖几何错误

### Requirement: 生成输入与参考来源必须商业可追溯

正式母版的输入 MUST 仅包含文字 brief、自有素材或明确允许该生成用途的素材。受限第三方媒体 MUST NOT 作为 imagegen reference/edit 输入、转描源、训练输入、Blender 贴图、背景或正式派生素材。系统 SHALL 记录实施时的 imagegen 服务条款、模型版本、输入来源、License、人工修改和 SHA-256；AI 输出 MUST NOT 被自动视为独占、动作正确或权利审核通过。

`hasaneyldrm/exercises-dataset` 的媒体只能用于理解产品形态及常规器械事实，MUST NOT 下载入库或用于图生图。

#### Scenario: 输入包含受限媒体
- **WHEN** 候选母版使用了受限第三方 JPG/GIF 作为生成输入
- **THEN** 权利审核必须拒绝该候选
- **AND** 该候选及其派生 Blender/媒体不得进入正式生产链

#### Scenario: 采用自有文字 brief
- **WHEN** 母版只使用原创文字 brief 和许可清晰的自有输入
- **THEN** 来源台账记录 prompt、输入、工具条款、模型版本和摘要
- **AND** 仍需人工权利审核后才可采用

### Requirement: 每个器械动作必须声明并验证常规器械结构

生产 manifest SHALL 为器械动作关联器械验收卡，至少声明器械类别、180×180 识别特征、静止组件、活动组件、转轴与轨迹、身体接触点和拒绝案例。Blender 器械 MUST 是本项目原创可编辑网格或来源许可清晰的可编辑资产，并 MUST 具备物理可解释的运动与配重联动。

`PEC_DECK_FLY` MUST 表现中央座椅、垂直靠背、刚性支架、左右对称转轴、两侧力臂与握把，以及可解释的配重/滑轮联动。人物 MUST 保持坐姿、背贴靠垫、双脚着地、双臂在肩高附近对称开合；MUST NOT 表现为胸推、绳索夹胸或泛化器械。

#### Scenario: 常规蝴蝶机验收通过
- **WHEN** 审核 `PEC_DECK_FLY` 的 180×180 起点、终点和循环 GIF
- **THEN** 用户能辨认常规蝴蝶机的座椅、靠背、支架、力臂、握把和配重结构
- **AND** 左右力臂绕固定转轴对称运动并与人物双手保持接触

#### Scenario: 器械只是外形近似
- **WHEN** 器械缺少真实转轴/配重联动或表现为其他胸部器械
- **THEN** 器械审核必须拒绝该动作
- **AND** 该动作不得进入运行时 manifest

### Requirement: Blender 源必须确定性生成十二帧动画

动态动作 SHALL 由同一 Blender 人体、器械、骨骼、约束、相机、材质和灯光生成 12 个有序帧。animation contract MUST 明确允许变化的人体骨骼、器械活动组件和配重联动；人物身份、头部、躯干接触、座椅、静止机架、相机、背景、画布和目标肌区域 MUST 逐帧保持一致。

系统 MUST NOT 使用 AI 独立生成正式中间帧。Blender 源引用 MUST Pack Resources 或使用仓库相对路径，并能在 fresh clone 中无需个人 Add-on 或外部 AI 服务重渲染。

#### Scenario: 重渲染同一动作
- **GIVEN** fresh clone 已取得指定 commit 和全部 LFS 对象
- **WHEN** 使用规定 Blender 版本渲染 `PEC_DECK_FLY`
- **THEN** 输出同一 12 个 scene、相机、尺寸、运动轨迹和器械联动
- **AND** 导出报告记录 Blender 版本、commit、manifest 版本和时间

#### Scenario: 静止组件发生漂移
- **WHEN** 任一帧的机架、座椅、靠背、相机或人物固定接触点偏离 animation contract
- **THEN** 技术或器械审核必须失败
- **AND** 编码器不得 promote 该动画

### Requirement: GIF 与 JPG 遵守统一交付标准

动态动作 SHALL 提供 180×180、sRGB、无限循环 GIF 和 180×180 JPG；静态保持动作 SHALL 只提供 JPG。Blender MUST 先渲染至少 720×720 的高分辨率帧，再以高质量缩小并合成到统一 `#F6F3EC` 暖白背景。成品 MUST NOT 包含文字、动作阶段、品牌 Logo 或水印。

动态试点默认 12 帧，起点与最大收缩位各停留 1000 ms，其余帧各 100 ms，总周期 3000 ms。JPG MUST 取 production manifest 指定代表帧。

#### Scenario: 动态媒体技术校验通过
- **WHEN** 一个动态动作准备发布
- **THEN** GIF 的画布、颜色空间、帧数、顺序、时长和循环与 manifest 一致
- **AND** JPG 的画布、颜色空间和代表帧声明一致

#### Scenario: 时序或尺寸错误
- **WHEN** GIF/JPG 尺寸错误、GIF 帧数不符、循环缺失或时长错误
- **THEN** 技术校验失败
- **AND** 对应动作不得 promote

### Requirement: 动作演示资产以稳定 code 建立独立清单

系统 SHALL 以 `BuiltinExercise.code` 作为唯一关联键，并维护独立于动作分类数据的 production manifest。动态动作 MUST 声明 GIF/JPG、母版、器械验收卡、Blender scene、肌肉强调、帧时长、审核和发布状态；静态保持动作 MUST 声明 JPG、代表 scene、审核和发布状态。

运行时 manifest SHALL 是 production manifest 的可重建精简产物，只包含已发布 code、演示类型和必要文件名。资源 MUST NOT 以本地化动作名建立身份关系，也 MUST NOT 把制作状态写入权威动作分类清单。

#### Scenario: 动作名称改变
- **WHEN** `PEC_DECK_FLY` 的中文显示名发生变化
- **THEN** 其母版、Blender scene、GIF/JPG 和运行时映射保持不变

#### Scenario: 未发布动作不伪造映射
- **WHEN** 动作尚未通过全部审核
- **THEN** 运行时 manifest 不声明该动作
- **AND** App 不生成占位图或同名猜测映射

### Requirement: 正式素材须通过五类审核门槛

动作只有在 `art`、`movement`、`equipment`、`rights` 和 `technical` 全部通过时才可发布。审核 SHALL 覆盖解剖与构图、动作变体和关节轨迹、器械识别和机械联动、输入/工具/License/人工修改、帧/媒体/LFS/恢复完整性。每批 SHALL 生成 Contact Sheet；单个动作失败只阻止自身。

#### Scenario: 器械审核仍为待定
- **WHEN** 动作的 GIF/JPG 已生成但 `equipment` 仍为 `pending`
- **THEN** 该动作不得进入运行时 manifest

#### Scenario: 单个动作被驳回
- **WHEN** 12 个试点中一个动作因轨迹或器械错误被拒绝
- **THEN** 其余已通过动作仍可发布
- **AND** 被拒绝动作不生成占位资源

### Requirement: 首次变更使用两道扩量闸门并限定十二个试点

本 change SHALL 先只制作并审核 `PEC_DECK_FLY`，用于锁定静态母版、常规器械、Blender 重建、45° 相机、解剖风格、目标肌、机械联动、循环和 180×180 可读性。其五类审核全部通过后，才可制作 `BB_BENCH_PRESS`、`BB_SQUAT`、`LATERAL_RAISE`；三类代表动作通过后，才可扩展至最多 12 个试点。

十二项范围 SHALL 限定为：`PEC_DECK_FLY`、`BB_BENCH_PRESS`、`BB_SQUAT`、`DEADLIFT`、`OHP`、`BB_ROW`、`LAT_PULLDOWN`、`LATERAL_RAISE`、`DB_CURL`、`TRICEP_PUSHDOWN`、`LUNGE`、`PLANK`。

#### Scenario: 首个质量闸门未通过
- **WHEN** `PEC_DECK_FLY` 任一审核未通过
- **THEN** 不制作其他正式试点
- **AND** 先修正母版、器械或 Blender 生产链

#### Scenario: 试点范围完成
- **WHEN** change 准备完成验收
- **THEN** 运行时 manifest 最多声明上述 12 个动作
- **AND** 每个声明动作均已通过五类审核

### Requirement: 制作源与正式媒体必须可恢复和测量

所有无法确定性重建的被采用母版、正式 Blender 源、实际使用贴图和正式 GIF/JPG SHALL 进入当前仓库，并由路径限定的 Git LFS 跟踪；manifest、prompt、器械验收卡、脚本、来源台账、审核和压缩预览 SHALL 使用普通 Git。规则 MUST NOT 接管无关图片。

流程 SHALL 自动校验 code、来源、审核、帧完整性、媒体属性、孤立资源、LFS pointer 和运行时 manifest，并输出媒体总大小。iOS 验收 SHALL 测量 App 增量、首次 GIF 解码、连续切换详情的峰值内存和小屏清晰度。

#### Scenario: 新电脑恢复完整生产链
- **GIVEN** 新电脑安装 Git、Git LFS 和规定 Blender 版本
- **WHEN** clone、`git lfs pull` 并运行预检
- **THEN** 被采用母版、prompt、人体、器械、骨骼、动作、贴图、manifest 和审核资料均可取得
- **AND** Blender 不报告仓库外资源缺失

#### Scenario: App 构建不依赖 Blender
- **WHEN** fresh clone 不运行 Blender而直接构建 iOS App
- **THEN** 构建只消费已提交的正式 GIF/JPG 和运行时 manifest
- **AND** 不访问 AI 服务或生产源文件
