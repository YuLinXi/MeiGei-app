# 手臂动作批次审核记录

- 审核日期：2026-07-25
- 当前阶段：二头肌 14 项、三头肌 9 项已完成，共 23 项；后续若发现遗漏动作继续追加到本文件。
- 范围：preset 中未发布的直接手臂训练动作；跳过已发布的 `BB_CURL`、`DB_CURL`、`DB_ALTERNATING_CURL`、`HAMMER_CURL`、`ROPE_PUSHDOWN`、`CABLE_V_BAR_PUSHDOWN`、`SKULL_CRUSHER` 与 manifest 中已存在的 `TRICEP_PUSHDOWN`。
- 统一标准：复用 `references/approved/character-v1.png` 与 `style-v1.png`；单人单姿势；暖白背景；石墨灰解剖线稿；仅肱二头肌/肱三头肌橙红高亮；器械与接触点可辨；四周留安全边距；无文字、logo、水印或第三方图像输入。
- 权利来源：角色/风格参考为仓库已批准自有母版；候选由 imagegen 基于各自 brief 生成；未使用第三方图片作为图像参考。

## 当前 Accepted 候选

| code | brief | candidate | SHA-256 | 视觉审核要点 |
| --- | --- | --- | --- | --- |
| `EZ_BAR_CURL` | `briefs/EZ_BAR_CURL.json` | `candidates/EZ_BAR_CURL/EZ_BAR_CURL-candidate-01.png` | `3846d507e3c9efeafaaba7814eadd8ee0f9a51aba0d66d755ebba670707fc898` | 站姿 EZ 曲杆、半旋前握、肘部固定，肱二头肌高亮。 |
| `DB_CROSS_HAMMER_CURL` | `briefs/DB_CROSS_HAMMER_CURL.json` | `candidates/DB_CROSS_HAMMER_CURL/DB_CROSS_HAMMER_CURL-candidate-01.png` | `577fef97795a52fe48917aa77c95226c184cb06d8f9e1897d7ebf2cccc071273` | 工作臂跨向对侧肩前，双哑铃和中立握清晰。 |
| `INCLINE_DB_CURL` | `briefs/INCLINE_DB_CURL.json` | `candidates/INCLINE_DB_CURL/INCLINE_DB_CURL-candidate-01.png` | `24d692a388e260ca7b12dc1f1de0500e0ca28ac64ad317e9a21beadde7ba69fa` | 上斜靠背、上臂后置、双哑铃弯举语义明确。 |
| `CONCENTRATION_CURL` | `briefs/CONCENTRATION_CURL.json` | `candidates/CONCENTRATION_CURL/CONCENTRATION_CURL-candidate-01.png` | `c310e65e5a3815513b02d839e57bd0faf3ac143eba86fa25992f6ec3b402ba52` | 单侧肘抵大腿内侧，单只哑铃和支点清楚。 |
| `SPIDER_CURL` | `briefs/SPIDER_CURL.json` | `candidates/SPIDER_CURL/SPIDER_CURL-candidate-01.png` | `f746e7d74b9e55142843a5781d3eb96362c92ffb95340d9a92937ff4b6362b77` | 胸部贴高斜凳、双臂垂下、双哑铃，区别于上斜坐姿。 |
| `EZ_BAR_PREACHER_CURL` | `briefs/EZ_BAR_PREACHER_CURL.json` | `candidates/EZ_BAR_PREACHER_CURL/EZ_BAR_PREACHER_CURL-candidate-01.png` | `9bc0cd6f84545dfd6b15922cabcce23b83e5fe611f2810c159ffa29a542419ef` | 窄高牧师凳斜垫与 EZ 曲杆清晰。 |
| `BB_PREACHER_CURL` | `briefs/BB_PREACHER_CURL.json` | `candidates/BB_PREACHER_CURL/BB_PREACHER_CURL-candidate-01.png` | `e4a81ba97a35e3fd84e247d944a23cf03d1245df880e6a7bce568a9eec9afa6d` | 牧师凳与直杠铃区分明确，杠杆保持笔直。 |
| `DB_PREACHER_CURL` | `briefs/DB_PREACHER_CURL.json` | `candidates/DB_PREACHER_CURL/DB_PREACHER_CURL-candidate-01.png` | `4eff40085b4077dacb57bb6b864ef8828a49584bf20ea0d61ddef6bec96f4164` | 单侧前臂贴牧师凳、单只哑铃，另一手支撑。 |
| `CABLE_CURL` | `briefs/CABLE_CURL.json` | `candidates/CABLE_CURL/CABLE_CURL-candidate-01.png` | `8ccc5f2c541dd3327dab6055278809e9333e91920afcb7bbc51be95c5896aff2` | 低位滑轮、连续钢索与短直杆弯举可辨。 |

### 第二批 Accepted

| code | brief | candidate | SHA-256 | 视觉审核要点 |
| --- | --- | --- | --- | --- |
| `BB_STRAIGHT_BAR_CURL` | `briefs/BB_STRAIGHT_BAR_CURL.json` | `candidates/BB_STRAIGHT_BAR_CURL/BB_STRAIGHT_BAR_CURL-candidate-01.png` | `f46822d0096a34b0800ea302beaa66da4405ab326b9a10f4f1e9e1d0c27103cb` | 低位滑轮与直杆连接清晰，非自由杠铃。 |
| `CABLE_SEATED_BAR_CURL` | `briefs/CABLE_SEATED_BAR_CURL.json` | `candidates/CABLE_SEATED_BAR_CURL/CABLE_SEATED_BAR_CURL-candidate-01.png` | `94e07db8a097c6f96d6e19dd9b36b1a4b66d32568e7cf13c89c9673a4f13a842` | 坐姿、双腿前伸、低位钢索拉杆弯举。 |
| `MACHINE_CURL` | `briefs/MACHINE_CURL.json` | `candidates/MACHINE_CURL/MACHINE_CURL-candidate-01.png` | `162325223c801a5ce57596815855183593cd8f5cccc6932b8add828160d3d029` | 固定臂垫和机械转轴/配重结构可辨。 |
| `REVERSE_CURL` | `briefs/REVERSE_CURL.json` | `candidates/REVERSE_CURL/REVERSE_CURL-candidate-01.png` | `90ec42feeb991ce0e5b2c5379e971792e2273038fa0632dd554c7fa7a4c37cdb` | 直杠、掌心向下反握、肘部贴身。 |
| `SINGLE_ARM_CABLE_CURL` | `briefs/SINGLE_ARM_CABLE_CURL.json` | `candidates/SINGLE_ARM_CABLE_CURL/SINGLE_ARM_CABLE_CURL-candidate-01.png` | `16682d63801fc526b7ad07f41c7f341ff953868188a41867a6f8b365f62ce0f1` | 单臂低位钢索、非工作手置髋部。 |

### 三头 Accepted

| code | brief | candidate | SHA-256 | 视觉审核要点 |
| --- | --- | --- | --- | --- |
| `BB_STRAIGHT_BAR_PUSHDOWN` | `briefs/BB_STRAIGHT_BAR_PUSHDOWN.json` | `candidates/BB_STRAIGHT_BAR_PUSHDOWN/BB_STRAIGHT_BAR_PUSHDOWN-candidate-01.png` | `54984892adadce3d292fef46ceec5a7a0bf26369a37e51c5f17fcb5fc0e2def2` | 高位滑轮直杆下压，肘部贴身。 |
| `SINGLE_ARM_CABLE_PUSHDOWN` | `briefs/SINGLE_ARM_CABLE_PUSHDOWN.json` | `candidates/SINGLE_ARM_CABLE_PUSHDOWN/SINGLE_ARM_CABLE_PUSHDOWN-candidate-01.png` | `7491c5ecfdd81cb6a9c5530ce7cd3963ae5c37cc35fd8d8843762391ea1be4b1` | 单臂高位钢索下压，非工作手置髋。 |
| `CABLE_TRICEP_EXT` | `briefs/CABLE_TRICEP_EXT.json` | `candidates/CABLE_TRICEP_EXT/CABLE_TRICEP_EXT-candidate-01.png` | `7aa878440dce1778a4a0cba245c2b8cd0f0be18fcf6ac32f35f958d36140653c` | 背对高位滑轮、绳索置头后、双肘伸展。 |
| `OVERHEAD_TRICEP_EXT` | `briefs/OVERHEAD_TRICEP_EXT.json` | `candidates/OVERHEAD_TRICEP_EXT/OVERHEAD_TRICEP_EXT-candidate-01.png` | `3eddc19fb5997d491881d79fff717f18ae36f5bb04c47dd71c3810b926b6e30b` | 双手单哑铃过顶伸展，肱三头肌高亮。 |
| `TRICEP_KICKBACK` | `briefs/TRICEP_KICKBACK.json` | `candidates/TRICEP_KICKBACK/TRICEP_KICKBACK-candidate-01.png` | `8013a5a26c3333f225276af8b905aaa83793de9d5f00728f62ad8ca40a872229` | 髋折叠俯身、双哑铃后伸，动作方向清楚。 |
| `SINGLE_ARM_DB_TRICEP_EXT` | `briefs/SINGLE_ARM_DB_TRICEP_EXT.json` | `candidates/SINGLE_ARM_DB_TRICEP_EXT/SINGLE_ARM_DB_TRICEP_EXT-candidate-01.png` | `4c8951f003a137e45ad159201eb5d9d477269d836c3c9f6f9c9cc4e39308e222` | 单臂哑铃过顶伸展，非工作手置髋。 |
| `TRICEP_DIP` | `briefs/TRICEP_DIP.json` | `candidates/TRICEP_DIP/TRICEP_DIP-candidate-01.png` | `e0f2c76e6fa75504715f71d91ecbffe3b577988c34d9fd558514c21f7797abd8` | 平行双杠、直立躯干、自重三头臂屈伸。 |
| `MACHINE_TRICEP_EXT` | `briefs/MACHINE_TRICEP_EXT.json` | `candidates/MACHINE_TRICEP_EXT/MACHINE_TRICEP_EXT-candidate-01.png` | `8c4a0bcf974f23e299ac0d68ec18caf310368ceade870e372a60a133e48f22e0` | 坐姿固定轨迹器械、握把和配重清晰。 |
| `CABLE_OVERHEAD_EXT` | `briefs/CABLE_OVERHEAD_EXT.json` | `candidates/CABLE_OVERHEAD_EXT/CABLE_OVERHEAD_EXT-candidate-01.png` | `279609dea9b8ddee103706c9b9c7c9e3cd4577e3b13c11ffbdd67e28bd82a69a` | 背对高位滑轮、双绳置头后，区分于直杆下压。 |

## 当前 Rejected / Skip

当前 23 项未发现需要拒绝的候选；均为 single-person、单姿势，目标肌群与器械语义通过初检。若后续人工审核发现胸部高亮、乳头焦点或器械语义漂移，应将具体候选追加到此表，不覆盖历史文件。

## 发布边界

本批只提供 `briefs/`、`candidates/` 与本 review；不写入 `masters/approved`、`provenance-v1`、`production-manifest` 或 iOS 运行时资源。发布前仍需按 144×144、JPEG quality 82、目标不超过 10 KiB 的流水线生成缩略图，并重新记录压缩后 SHA。
