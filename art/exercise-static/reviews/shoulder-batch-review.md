# 肩部动作批次审核记录

- 审核日期：2026-07-25
- 范围：肩部 preset 动作 20 项；仅生成候选与 brief，本批不发布到 `masters/approved`、`provenance-v1`、`production-manifest` 或 iOS 运行时资源。
- 统一标准：复用 `references/approved/character-v1.png` 与 `style-v1.png`；单人单姿势；暖白背景；石墨灰解剖线稿；仅目标肌群橙红高亮；器械握法和接触点可辨；四周留安全边距；不使用文字、logo、水印或第三方素材。
- 权利来源：角色/风格参考为仓库已批准自有母版；候选由 imagegen 基于自有 brief 生成；本批未输入 `hasaneyldrm/exercises-dataset` 或其他第三方图片作为图像参考。

## 结论

- Accepted：19 项，候选路径与 SHA-256 见下表。
- Rejected：`SEATED_BB_PRESS-candidate-01`、`DB_OVERHEAD_PRESS-candidate-01`、`MACHINE_SHOULDER_PRESS-candidate-01`（胸部错误高亮并出现明显乳头焦点）；`ARNOLD_PRESS-candidate-01`（胸部高亮/乳头焦点）、`ARNOLD_PRESS-candidate-02`（分屏重复人物）、`ARNOLD_PRESS-candidate-03`（乳头细节点仍明显）；`PREACHER_BENCH_REAR_DELT_FLY-candidate-01`、`candidate-02`（均为普通上斜凳，未形成可验收的牧师凳窄高斜垫）。
- Skip：`PREACHER_BENCH_REAR_DELT_FLY` 暂缓发布，等待能明确呈现牧师凳结构的重生成；不把普通上斜凳候选冒充牧师凳。

## Accepted 候选

| code | brief | candidate | SHA-256 | 视觉审核要点 |
| --- | --- | --- | --- | --- |
| `SEATED_BB_PRESS` | `briefs/SEATED_BB_PRESS.json` | `candidates/SEATED_BB_PRESS/SEATED_BB_PRESS-candidate-02.png` | `8623d6228cb91cbd21e28d8f92c1168fadbf612bf822e21b482c61cea366e90b` | 靠背坐姿、自由杠铃过顶、三角肌前束高亮；胸部保持灰阶。 |
| `DB_OVERHEAD_PRESS` | `briefs/DB_OVERHEAD_PRESS.json` | `candidates/DB_OVERHEAD_PRESS/DB_OVERHEAD_PRESS-candidate-02.png` | `b5eb4a0f72ccc917978b27c53b65b46107bf0e141e0cdc3c3074a967990436a7` | 靠背坐姿双哑铃过顶，双手和器械连接自然。 |
| `ARNOLD_PRESS` | `briefs/ARNOLD_PRESS.json` | `candidates/ARNOLD_PRESS/ARNOLD_PRESS-candidate-04.png` | `cbecd2d7cde48681d3512da558c3f508cb650f283681c6112cec7e248706dd8d` | 单人坐姿双哑铃顶端；仅肩部高亮，无分屏。 |
| `MACHINE_SHOULDER_PRESS` | `briefs/MACHINE_SHOULDER_PRESS.json` | `candidates/MACHINE_SHOULDER_PRESS/MACHINE_SHOULDER_PRESS-candidate-02.png` | `61298adb418775fa526ae4e3e8a3c6c39f7550ae5c44044b28483548236d9a98` | 固定轨迹肩推机、座椅/握把/配重结构完整。 |
| `SMITH_SHOULDER_PRESS` | `briefs/SMITH_SHOULDER_PRESS.json` | `candidates/SMITH_SHOULDER_PRESS/SMITH_SHOULDER_PRESS-candidate-01.png` | `05b752957398a340a803ea1154972a9bee9b866c731f8ee8358c45932ef2baf9` | 两根史密斯导轨、固定杠铃与靠背清晰。 |
| `HAMMER_SEATED_PRESS` | `briefs/HAMMER_SEATED_PRESS.json` | `candidates/HAMMER_SEATED_PRESS/HAMMER_SEATED_PRESS-candidate-01.png` | `d8883ca26f6d8d03f5edd1809e7147aef28ab2735b6e83f3d9f334c72f7f8049` | 悍马机独立杠杆、中立握和板片清晰。 |
| `CABLE_LATERAL_RAISE` | `briefs/CABLE_LATERAL_RAISE.json` | `candidates/CABLE_LATERAL_RAISE/CABLE_LATERAL_RAISE-candidate-01.png` | `9475e0089655dd115d7d991dcc00f74ed3115cf0c16ae230eb6d021f59c708dc` | 低位钢索单侧外展，滑轮和钢索连续可见。 |
| `SINGLE_ARM_CABLE_LATERAL_RAISE` | `briefs/SINGLE_ARM_CABLE_LATERAL_RAISE.json` | `candidates/SINGLE_ARM_CABLE_LATERAL_RAISE/SINGLE_ARM_CABLE_LATERAL_RAISE-candidate-01.png` | `e767ad4c9d417fc1a843e8fb0c89d49c2482c6a6afd99942eb6857087d96d7a6` | 侧向单臂绳索侧平举，非工作手置髋部。 |
| `MACHINE_LATERAL_RAISE` | `briefs/MACHINE_LATERAL_RAISE.json` | `candidates/MACHINE_LATERAL_RAISE/MACHINE_LATERAL_RAISE-candidate-01.png` | `45770b3b76e5b6aab4ff9f8fea2128d04cce3f252a7a061b2b0d05e4aac27bb5` | 坐姿双臂固定轨迹侧平举，臂垫/转轴可辨。 |
| `HAMMER_LATERAL_RAISE` | `briefs/HAMMER_LATERAL_RAISE.json` | `candidates/HAMMER_LATERAL_RAISE/HAMMER_LATERAL_RAISE-candidate-01.png` | `eba77b7a215e9fcb78ee8f33f69fa372af0b8c089a2750c2dac2af5e1bee66fd` | 悍马机独立侧平举杠杆与板片完整。 |
| `FRONT_RAISE` | `briefs/FRONT_RAISE.json` | `candidates/FRONT_RAISE/FRONT_RAISE-candidate-01.png` | `118eec05c63a40803713a8d025ccaf038b558e651e94fe87e118d3762c298236` | 双哑铃前举至肩高，前束高亮。 |
| `BB_PLATE_FRONT_RAISE` | `briefs/BB_PLATE_FRONT_RAISE.json` | `candidates/BB_PLATE_FRONT_RAISE/BB_PLATE_FRONT_RAISE-candidate-01.png` | `cbed7c6e7dd03346e848c3cd8736a84f314a59d7096dc258969b576c8eaa97f8` | 单独圆形杠铃片、双手对称握位，无长杆。 |
| `CABLE_FRONT_RAISE` | `briefs/CABLE_FRONT_RAISE.json` | `candidates/CABLE_FRONT_RAISE/CABLE_FRONT_RAISE-candidate-01.png` | `4d38673a0bf43dfce55621619397df34eab7cf26254ec9944b83f0b07df0b25d` | 低位钢索与前平举把手方向可辨。 |
| `REAR_DELT_FLY` | `briefs/REAR_DELT_FLY.json` | `candidates/REAR_DELT_FLY/REAR_DELT_FLY-candidate-01.png` | `ad4a73b2a57f45074127935491e8760059afb2c91a643d83bd2358e51eb705b8` | 髋折叠双哑铃俯身飞鸟，后束高亮。 |
| `MACHINE_REVERSE_FLY` | `briefs/MACHINE_REVERSE_FLY.json` | `candidates/MACHINE_REVERSE_FLY/MACHINE_REVERSE_FLY-candidate-01.png` | `5dbcb6068666212bda0a1f6597834b583a406fd6fc45e99908edcac290fe8752` | 胸托反向蝴蝶机、双侧把手和配重清晰。 |
| `FACE_PULL` | `briefs/FACE_PULL.json` | `candidates/FACE_PULL/FACE_PULL-candidate-01.png` | `0a404d5b307ae8735a5836c7e91621c5aaa52da68c5597c3fe62c4b831138e1f` | 高位绳索拉向面部两侧，肘部抬高。 |
| `CABLE_CROSS_REAR_FLY` | `briefs/CABLE_CROSS_REAR_FLY.json` | `candidates/CABLE_CROSS_REAR_FLY/CABLE_CROSS_REAR_FLY-candidate-01.png` | `2221b8b606f07bfb24741bf5ba965f083c16f6e966e4723c533d9c43fd91bd4a` | 双侧高位塔、X 形交叉钢索、后束飞鸟语义明确。 |
| `DB_UPRIGHT_ROW` | `briefs/DB_UPRIGHT_ROW.json` | `candidates/DB_UPRIGHT_ROW/DB_UPRIGHT_ROW-candidate-01.png` | `24d38f311b03441241008b43e92adc342bf7df75e2550d3187d6d5e0467753b4` | 双哑铃贴身提拉，肘部高于手腕。 |
| `BB_HIGH_PULL` | `briefs/BB_HIGH_PULL.json` | `candidates/BB_HIGH_PULL/BB_HIGH_PULL-candidate-01.png` | `b9646b684dac3db8e3b85b420cb5b0590796bc2cceff7f23951c128b67a883dd` | 杠铃贴身高拉至胸口，板片和宽握清晰。 |

## Rejected / skip 台账

| code | 候选 | 结论 | 原因 |
| --- | --- | --- | --- |
| `SEATED_BB_PRESS` | `candidate-01` | rejected | 胸大肌被错误染红，并有明显乳头焦点；已用 candidate-02 替换。 |
| `DB_OVERHEAD_PRESS` | `candidate-01` | rejected | 胸部高亮和乳头焦点漂移；已用 candidate-02 替换。 |
| `MACHINE_SHOULDER_PRESS` | `candidate-01` | rejected | 胸部高亮/乳头焦点；已用 candidate-02 替换。 |
| `ARNOLD_PRESS` | `candidate-01` | rejected | 胸部高亮和乳头焦点。 |
| `ARNOLD_PRESS` | `candidate-02` | rejected | 分屏并出现两个不同姿势/重复人物。 |
| `ARNOLD_PRESS` | `candidate-03` | rejected | 单人结构已正确，但乳头细节点仍明显；已用 candidate-04 替换。 |
| `PREACHER_BENCH_REAR_DELT_FLY` | `candidate-01` | rejected | 视觉上是普通上斜凳，不是可验收的牧师凳。 |
| `PREACHER_BENCH_REAR_DELT_FLY` | `candidate-02` | rejected | 重生成仍是普通上斜凳；暂不发布，避免设备语义误导。 |

## 后续动作

1. 主线可将 Accepted 候选作为待人工确认的候选，不直接写入生产 manifest。
2. `PREACHER_BENCH_REAR_DELT_FLY` 需要下一轮专门的牧师凳结构生成或改为明确的普通上斜凳动作 code；在语义澄清前保持 skip。
3. 发布前仍需按统一 144×144、JPEG quality 82、目标不超过 10 KiB 的缩略图流水线生成产物，并重新记录压缩后 SHA。
