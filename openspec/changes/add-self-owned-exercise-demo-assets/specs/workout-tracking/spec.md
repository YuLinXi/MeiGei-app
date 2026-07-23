## MODIFIED Requirements

### Requirement: 动作详情页（ExerciseDetail）版式与行为

内置动作详情页 SHALL 为纯浏览页，自上而下展示：① 标题与 meta、② 可选动作演示、③ 你的数据、④ 动作要点、⑤ 目标肌群、⑥ 肌群高亮图。动作演示只有在该 `BuiltinExercise.code` 的运行时条目、五类审核状态和必要本地资源均完整时才显示；缺失时整段隐藏，后续内容自然上移。

动态演示卡 SHALL 使用随包 180×180 GIF 并默认无限循环，用户可点击暂停/继续；其 180×180 JPG 用作静态预览和 Reduce Motion 降级。静态保持动作 SHALL 只显示 JPG。开启 Reduce Motion 时 MUST NOT 解码或播放 GIF。演示卡 MUST 提供动作名称、演示类型和播放状态的 VoiceOver 描述与可操作提示。

动作演示 MUST NOT 替代 `MuscleMapView`、写入训练数据或在动作库列表解码 GIF。自定义动作默认不展示内置演示。该页继续不提供训练数据写入入口。

#### Scenario: 有完整动态素材的内置动作
- **WHEN** 用户打开已发布且 GIF/JPG 完整的「蝴蝶机夹胸」
- **THEN** 标题与 meta 后显示自动循环的 180×180 动作演示
- **AND** 点击可暂停或继续
- **AND** 后续数据、要点、目标肌群与肌群图保持原行为

#### Scenario: Reduce Motion 显示静态缩略图
- **WHEN** 用户开启 Reduce Motion 并打开有动态素材的动作
- **THEN** 演示卡只显示对应 JPG
- **AND** 不解码、不播放 GIF，也不显示虚假的播放状态

#### Scenario: 无素材自然降级
- **WHEN** 用户打开未进入运行时 manifest 的内置动作
- **THEN** 页面不渲染动作演示段
- **AND** 不显示空白、破图、采集中或 AI 生成中的占位

#### Scenario: 动态资源不完整
- **WHEN** 运行时条目声明动态动作但 GIF 或 JPG 缺失
- **THEN** 整个演示段隐藏
- **AND** App 不展示残缺静态或动态资源

#### Scenario: 进入详情页不触发写入
- **WHEN** 用户查看详情并暂停或继续演示
- **THEN** 页面不新建、不修改任何 `Workout`

#### Scenario: 自定义动作不显示内置演示
- **WHEN** 用户查看自定义动作资料
- **THEN** 页面不根据同名动作猜测或复用内置素材

#### Scenario: 动作列表不加载 GIF
- **WHEN** 用户浏览或搜索动作库列表
- **THEN** 动作行继续使用既有肌群缩略图或首字占位
- **AND** 不读取演示 manifest、不解码动作 GIF

#### Scenario: VoiceOver 操作动态演示
- **WHEN** VoiceOver 用户聚焦动态演示
- **THEN** 系统朗读动作名称与播放状态
- **AND** 用户可通过卡片操作暂停或继续

### Requirement: 详情页肌群高亮图

详情页 SHALL 以独立 `MuscleMapView` 渲染动作肌群高亮，主动肌/协同肌取自 `primaryRegions`/`secondaryRegions`，底图按 `UserProfile.sex` 选择并可正背切换。动作演示和肌群图 SHALL 同时存在且职责分离：前者表达动作与器械轨迹并在人物上强调目标肌，后者提供全身部位定位。缺少细分区数据时肌群图隐藏，但不得影响已有演示。

#### Scenario: 内置动作同时显示演示与高亮图
- **WHEN** 查看已有正式演示且具有胸部区域数据的「蝴蝶机夹胸」
- **THEN** 标题后显示动作演示卡
- **AND** 页面后部仍显示独立肌群高亮图

#### Scenario: 性别只影响独立肌群底图
- **WHEN** 用户切换资料中的性别设置
- **THEN** `MuscleMapView` 使用对应轮廓
- **AND** 动作演示不重复制作男女两套

#### Scenario: 缺肌群数据但有动作演示
- **WHEN** 内置动作有正式演示但 `primaryRegions` 为空
- **THEN** 演示正常显示，独立肌群图隐藏

#### Scenario: 缺动作演示但有肌群数据
- **WHEN** 内置动作没有正式演示但具有肌群数据
- **THEN** 演示隐藏，肌群图正常显示
