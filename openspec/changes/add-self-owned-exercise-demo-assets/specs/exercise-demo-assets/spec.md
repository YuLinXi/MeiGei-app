## ADDED Requirements

### Requirement: 动作素材只交付静态图片

系统 SHALL 为已覆盖的内置动作维护一张已批准的高分辨率静态母版，并从该母版确定性导出 288×288、JPEG 质量 82、单张不超过 24 KiB（24,576 bytes）的 sRGB JPG。系统 MUST NOT 为本能力生产、保存或运行 GIF、视频、APNG、SVG 动画、帧序列、Blender 模型或骨骼动画。

#### Scenario: 静态母版被批准
- **WHEN** 某动作的高分辨率静态母版通过五项自治或人工审核
- **THEN** 导出流程从同一母版生成符合尺寸、质量和大小上限的 288×288 JPG 与运行时 manifest 条目
- **AND** 不生成任何动态媒体或三维源文件

#### Scenario: 候选尚未批准
- **WHEN** 某动作只有 AI 候选图而没有已批准母版
- **THEN** 该候选不得进入运行时资源或 manifest
- **AND** 候选与失败图不得提交为正式资产

### Requirement: 全部动作使用同一个原创角色

系统 SHALL 建立并版本化唯一 `character-v1` 角色母版，锁定原创虚构成年男性的面部、发型、体型比例、四肢比例、服装、肤色/灰阶和线稿表现。每张动作候选 MUST 使用已批准角色母版和风格母版作为 imagegen reference/edit 输入；仅复用文本 prompt、角色名称或 seed MUST NOT 被视为满足角色一致性。

每张候选 MUST 对照角色母版和已批准动作联系表审核面部、发型、体型、四肢、服装与渲染风格。出现换脸、比例漂移、服装变化、多余/缺失肢体、手指融合或左右错误时 MUST 被拒绝。

#### Scenario: 新动作保持角色身份
- **WHEN** 新动作候选使用 `character-v1` 与 `style-v1` 生成且身份清单全部通过
- **THEN** 身份审核人可将该候选标记为 `identity=approved`
- **AND** 审核记录关联角色版本、证据联系表和候选摘要

#### Scenario: 角色发生漂移
- **WHEN** 候选的脸型、发型、体型、服装或肢体结构与角色母版不一致
- **THEN** 身份审核必须拒绝该候选
- **AND** 该动作继续使用既有列表降级图，不得以较低标准发布

### Requirement: 静态图必须准确表达动作与器械

每个动作 SHALL 使用以 `BuiltinExercise.code` 标识的原创 brief 和验收卡，声明动作变体、代表姿势、相机方向、器械识别特征、握法、身体接触点、关节方向、主动肌、协同肌和排除项。正式图片 MUST 在 288×288 与真实双列卡片下可辨认实际动作及必要器械，主动肌使用统一朱砂红强调，协同肌使用统一浅红，其他人体与器械保持灰阶。

`PEC_DECK_FLY` MUST 使用顶部横梁式常规蝴蝶机，包含中央座椅、垂直靠背、左右顶部转轴、向外向下弯曲摆臂和垂直握把；MUST NOT 退化为胸推机、绳索夹胸或左右独立短直臂变体。

#### Scenario: 蝴蝶机夹胸通过首个闸门
- **WHEN** `PEC_DECK_FLY` 候选呈现批准器械结构、正确坐姿与握法、胸大肌高亮和统一角色
- **THEN** 动作、器械和美术审核可分别记录批准
- **AND** 该图片可进入 288×288 导出与真实双列卡片验收

#### Scenario: 图片漂亮但器械错误
- **WHEN** 候选的人物与构图符合风格但器械类别、结构、握法或身体接触点错误
- **THEN** 动作或器械审核必须拒绝该候选
- **AND** 美术审核通过不得覆盖该拒绝结论

### Requirement: 生成输入和权利必须可追溯

正式母版的输入 MUST 仅包含原创文字 brief、本项目自有角色/风格母版，或明确许可该生成用途的素材。受限第三方媒体 MUST NOT 作为 imagegen reference/edit 输入、转描源、训练输入、贴图或正式派生素材。

系统 SHALL 为每个已批准母版记录动作 code、完整 prompt/brief、工具与模型版本、全部输入及权利状态、生成日期、人工修改、审核主体、审核时间和 SHA-256，并保存实施时适用的 imagegen 商业使用条款证据。AI 输出 MUST NOT 自动被视为独占、无侵权、角色一致或动作正确。

#### Scenario: 使用自有输入生成
- **WHEN** 候选只使用原创 brief 和本项目已批准母版作为输入
- **THEN** 来源台账记录全部输入、工具版本、条款证据和文件摘要
- **AND** 权利审核须由项目所有者人工批准或由其明确授权的 `production-autopilot` 按输入政策签署

#### Scenario: 使用受限第三方图片
- **WHEN** 候选使用 `hasaneyldrm/exercises-dataset` 或其他未获许可图片作为 reference/edit 输入
- **THEN** 权利审核必须拒绝该候选及其派生图
- **AND** 文件不得进入正式母版、运行时资源或版本控制

### Requirement: 审核与 promote 必须分离

生产 manifest SHALL 对每个动作分别记录 `identity`、`art`、`movement`、`equipment`、`rights` 五类审核状态和自动技术状态。只有五类审核状态均为 `approved`、审核记录完整且技术校验通过时，promote 流程才可写入运行时 manifest。未获得项目所有者自治授权时，Codex、imagegen、脚本和 CI MUST NOT 以人工审核人身份把状态改为 `approved`；获得明确授权时，记录必须使用 `production-autopilot`，不得冒充人工审核人。

#### Scenario: 全部审核通过
- **WHEN** 某动作五类审核均已由稳定人工主体或获授权的 `production-autopilot` 记录且技术校验通过
- **THEN** promote 流程生成或更新该 code 的 288×288 JPG 与运行时条目

#### Scenario: 任一审核未通过
- **WHEN** 某动作任一审核状态为 `pending` 或 `rejected`
- **THEN** promote 流程必须失败且不得写入运行时 manifest
- **AND** 已发布的其他动作不受影响

### Requirement: 正式静态资源具有稳定身份与技术约束

正式资源 SHALL 以稳定 `BuiltinExercise.code` 映射，运行时文件命名为 `exercise_<CODE>.jpg`。导出流程 MUST 将母版中与四角背景相近的烘焙暖色像素确定性归一为纯白。导出结果 MUST 为 288×288、JPEG 质量 82、sRGB、不透明纯白背景、无文字、无 Logo、主体未裁切且具有安全边距，文件大小 MUST 不超过 24,576 bytes；manifest 中的尺寸、质量、大小、文件名和 SHA-256 MUST 与实际文件一致。

技术校验 SHALL 拒绝未知 code、重复 code、缺文件、尺寸错误、摘要不符、孤立正式图片和无法解码的 JPG。编码质量 MUST 在首个真机试点后全局锁定，MUST NOT 按动作任意变化。

#### Scenario: 正式文件通过技术校验
- **WHEN** 288×288 JPG 可解码、背景已归一为纯白、JPEG 质量为 82、文件不超过 24,576 bytes、code 存在、摘要一致且没有孤立映射
- **THEN** 技术状态可标记为通过

#### Scenario: manifest 与文件不一致
- **WHEN** manifest 声明的文件缺失、尺寸不是 288×288、质量不是 82、文件超过 24,576 bytes 或 SHA-256 不匹配
- **THEN** 严格校验必须失败
- **AND** 该条目不得随 App 发布

### Requirement: 必要生产资源必须可跨电脑恢复

版本控制 SHALL 保存已批准角色/风格母版、已批准动作母版、prompt/brief、来源台账、审核记录、manifest、导出/校验脚本和正式 288×288 JPG。候选图、失败图、缓存、API key 和账户凭证 MUST NOT 入库。大尺寸母版使用 Git LFS 时 MUST 采用路径限定规则，MUST NOT 迁移无关图片。

fresh clone SHALL 能取得全部已批准输入，重新导出符合尺寸与摘要规则的运行时 JPG，并在不安装 AI 工具时完成 iOS 构建。

#### Scenario: 更换电脑继续工作
- **WHEN** 开发者在 fresh clone 拉取普通 Git 与所需 LFS 对象
- **THEN** 已批准母版、brief、审核、脚本和正式资源均可用
- **AND** 不依赖旧电脑的候选目录、缓存或密钥

#### Scenario: 未安装 AI 工具构建 App
- **WHEN** 开发者只需要构建现有 iOS App
- **THEN** 构建只消费已提交运行时 JPG 和 manifest
- **AND** 不要求调用 imagegen 或安装 Blender

### Requirement: 扩量必须经过分阶段质量闸门

系统 SHALL 先以 `PEC_DECK_FLY` 验证统一角色、常规器械、动作姿势、肌肉高亮和 288×288 双列卡片真机效果。首个动作和代表动作验证通过后，项目所有者可明确授权 `production-autopilot` 连续覆盖全部内置动作；无唯一标准、无法稳定保持角色或无法满足动作/器械规则的动作 MUST 被跳过并写入版本控制的台账，不得阻塞其他动作。

#### Scenario: 首个动作未通过
- **WHEN** `PEC_DECK_FLY` 任一人工或技术审核未通过
- **THEN** 不得开始批量生成其他正式动作

#### Scenario: 自治全量覆盖
- **WHEN** 项目所有者已授权 `production-autopilot`，且某动作通过五项审核、确定性导出和技术校验
- **THEN** 该动作可直接进入正式运行时资源
- **AND** 无法得出唯一动作或器械标准的动作写入跳过台账，仍不得标记为已覆盖
