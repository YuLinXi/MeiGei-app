# 背部下拉/划船动作族候选初检

日期：2026-07-25
审查方式：`production-autopilot` 初检；仅依据 preset code、动作 brief、character-v1/style-v1 和候选 PNG。本文不代表正式母版批准，不写入 production-manifest，也不触碰 iOS 运行时资源。

## 统一门槛

- 人物必须保持 character-v1 的脸型、短发、体型、黑色短裤和灰阶线稿；目标肌群用克制的红橙色高亮。
- 背景为暖白、无文字/水印/Logo；整个人物、关键器械、手部和脚部不裁切。
- 逐项检查动作方向、握法、身体接触点、器械识别特征和目标肌群；生成不符合唯一动作标准的候选进入拒绝/跳过台账。
- 候选统一保留在 `candidates/` 与 `staging/candidates/`，下游必须重新执行正式 master/provenance/manifest 流程。

## 初检结果

| code | brief | 候选 | 状态 | SHA-256 | 初检说明 |
| --- | --- | --- | --- | --- | --- |
| CLOSE_LAT_PULLDOWN | `briefs/CLOSE_LAT_PULLDOWN.json` | `candidates/CLOSE_LAT_PULLDOWN/CLOSE_LAT_PULLDOWN-candidate-01.png` | pass | `a571ad6875ffdb2235c8a4b5ca8451eea097c88fd40c2f8c11f6898af9a7b2f6` | 高位下拉机、窄握短杆、杆至上胸和背阔肌高亮可辨。 |
| NEUTRAL_GRIP_PULLDOWN | `briefs/NEUTRAL_GRIP_PULLDOWN.json` | `candidates/NEUTRAL_GRIP_PULLDOWN/NEUTRAL_GRIP_PULLDOWN-candidate-selected.png` | pass | `aa28f3f4cd318fbf46d48a1c400d7eb21601fff41a689400a4dae4f694e1c8c3` | 按用户确认版本更新：连续宽式弯杆、双手闭合包握、坐姿压腿、独立电缆和背阔肌高亮通过。 |
| REVERSE_LAT_PULLDOWN | `briefs/REVERSE_LAT_PULLDOWN.json` | `candidates/REVERSE_LAT_PULLDOWN/REVERSE_LAT_PULLDOWN-candidate-01.png` | pass-with-grip-risk | `e28b2634e0859c5671c58efd09c390edd68f5193aeafe1f5f452075511459615` | 直杆拉至上胸和器械正确；小缩略图下反握掌心方向不够强，正式发布前需保守复核。 |
| V_BAR_PULLDOWN | `briefs/V_BAR_PULLDOWN.json` | `candidates/V_BAR_PULLDOWN/V_BAR_PULLDOWN-candidate-01.png` | pass | `0aedd67934fee2009d1d13d0709c20ee6e7e268d68e5c99fe67534e837793a66` | 紧凑 V-bar、掌心相对、低位肘路和电缆结构通过。 |
| MACHINE_PULLDOWN | `briefs/MACHINE_PULLDOWN.json` | `candidates/MACHINE_PULLDOWN/MACHINE_PULLDOWN-candidate-01.png` | pass | `75345271d6d07dc5188219482ebd878c159eeffa50ff8f7f285a4e2c7bf5fb7f` | 无电缆的独立杠杆器械下拉、压腿垫和板片可辨。 |
| HAMMER_PULLDOWN | `briefs/HAMMER_PULLDOWN.json` | `candidates/HAMMER_PULLDOWN/HAMMER_PULLDOWN-candidate-01.png` | pass | `c91734c99fd47ce5ca0e97dd13597138432e0aaf5db91b9558e7819d6d680ed4` | 悍马机双侧板载杠杆、中立把手和背阔肌高亮通过。 |
| SINGLE_ARM_HAMMER_PULLDOWN | `briefs/SINGLE_ARM_HAMMER_PULLDOWN.json` | `candidates/SINGLE_ARM_HAMMER_PULLDOWN/SINGLE_ARM_HAMMER_PULLDOWN-candidate-01.png` | pass | `3c258e6c4a1c4ef2b23d2129b4b0ac32f4f90eedb8eff3266a85bdcba9c4a356` | 单侧工作把手、另一手支撑、单侧板片和背阔肌高亮通过。 |
| STRAIGHT_ARM_PULLDOWN | `briefs/STRAIGHT_ARM_PULLDOWN.json` | `candidates/STRAIGHT_ARM_PULLDOWN/STRAIGHT_ARM_PULLDOWN-candidate-01.png` | pass | `9df243c36958d2f7379018dc588b18879bce6010867b6d63a12f8490fca0a293` | 站姿、近乎直臂、直杆压至大腿和高位电缆通过。 |
| PENDLAY_ROW | `briefs/PENDLAY_ROW.json` | `candidates/PENDLAY_ROW/PENDLAY_ROW-candidate-01.png` | pass | `ce9c79acfae168026488c7d22eaec087379a5e464da32bb6de1e19a23d6f1ca9` | 近水平髋铰链、正握杠铃、地面起始和背部高亮通过。 |
| T_BAR_ROW | `briefs/T_BAR_ROW.json` | `candidates/T_BAR_ROW/T_BAR_ROW-candidate-01.png` | pass | `cfc80e96e932419f33c9678f822f6b4202747495fb9bade12d3a9d14a812a6e9` | 固定端 T 杠、近握中立把手、板片和俯身姿势通过。 |
| DB_BENT_OVER_ROW | `briefs/DB_BENT_OVER_ROW.json` | `candidates/DB_BENT_OVER_ROW/DB_BENT_OVER_ROW-candidate-01.png` | pass | `206cbf1bad5639d5e5f32768511e4f853257859b4b23521a9646520f7cbfa499` | 自由站姿双哑铃、髋铰链和双侧拉向髋部通过。 |
| SINGLE_ARM_DB_ROW | `briefs/SINGLE_ARM_DB_ROW.json` | `candidates/SINGLE_ARM_DB_ROW/SINGLE_ARM_DB_ROW-candidate-01.png` | pass | `9adfee117a629d1cf11448b472c97e4b97dd74e2a4c17847a80c859691e178fd` | 单膝单手平凳支撑、单只哑铃和工作侧背阔肌通过。 |
| DB_PRONE_ROW | `briefs/DB_PRONE_ROW.json` | `candidates/DB_PRONE_ROW/DB_PRONE_ROW-candidate-01.png` | pass | `e68eed29996b185c0a6b5705d0e4a1a69609f32d59db7a1055d3331f82df3fd2` | 胸托斜凳、双哑铃和双侧拉向肋部通过。 |
| SEATED_CABLE_ROW | `briefs/SEATED_CABLE_ROW.json` | `candidates/SEATED_CABLE_ROW/SEATED_CABLE_ROW-candidate-01.png` | pass | `5f365ad34547d6ce08f1fff31cf8df16d1632e94e73c3f183318f5c7259da5e4` | 低位电缆、脚踏、直杆正握和坐姿回拉通过。 |
| V_BAR_ROW | `briefs/V_BAR_ROW.json` | `candidates/V_BAR_ROW/V_BAR_ROW-candidate-01.png` | pass | `e608452b115888d37f55a40a4546e870809ab237fe272d064c9287ef5a55aef7` | V-bar 中立握、低位电缆、脚踏和肘贴身通过。 |
| WIDE_SEATED_ROW | `briefs/WIDE_SEATED_ROW.json` | `candidates/WIDE_SEATED_ROW/WIDE_SEATED_ROW-candidate-01.png` | pass | `bd652543427361de22091c6abeb463ea9497630f0cb1333a2c5c7f0bc9f4f239` | 长直杆宽握、低位电缆和宽握肘路通过。 |
| MACHINE_ROW | `briefs/MACHINE_ROW.json` | `candidates/MACHINE_ROW/MACHINE_ROW-candidate-01.png` | pass | `017664a9a52d3042a6a6ce95307f87245dbb1103351fe885f10c53ae0b157b06` | 胸托双臂中立握器械、双侧杠杆和板片通过。 |
| MACHINE_SINGLE_ARM_ROW | `briefs/MACHINE_SINGLE_ARM_ROW.json` | `candidates/MACHINE_SINGLE_ARM_ROW/MACHINE_SINGLE_ARM_ROW-candidate-01.png` | pass | `6d8101490709e122dc543352d4be9d56fed00166baeb6d444ac6c2ff497df896` | 胸托单侧独立杠杆、另一手支撑和单侧高亮通过。 |
| HAMMER_ROW | `briefs/HAMMER_ROW.json` | `candidates/HAMMER_ROW/HAMMER_ROW-candidate-01.png` | pass | `963cab4c06b846c8c7486099d0823d6d34738a7666d339a62d28addd2bd6566f` | 悍马机胸托、双侧中立把手和板片通过。 |
| SINGLE_ARM_HAMMER_ROW | `briefs/SINGLE_ARM_HAMMER_ROW.json` | `candidates/SINGLE_ARM_HAMMER_ROW/SINGLE_ARM_HAMMER_ROW-candidate-01.png` | pass | `20f0b35b10003ffe52fa0dff87cb6d5937256a800125ffa4e6c8a2ff2d6b02d3` | 悍马机单侧工作杠杆、胸托和单侧高亮通过。 |
| SMITH_OVERHAND_ROW | `briefs/SMITH_OVERHAND_ROW.json` | `candidates/SMITH_OVERHAND_ROW/SMITH_OVERHAND_ROW-candidate-01.png` | pass | `85918397e47d6070c12bd888747fc2cc6f1643046eebff2efcec292c0a5a0735` | 史密斯导轨、正握、俯身拉向下肋和安全钩通过。 |
| SMITH_REVERSE_ROW | `briefs/SMITH_REVERSE_ROW.json` | `candidates/SMITH_REVERSE_ROW/SMITH_REVERSE_ROW-candidate-01.png` | skip-ambiguous | `db4585b3f3c40c73e668047b7c414e8d5837649eb16e3cda9aeb5413a1675378` | 候选是史密斯架内身体后倾反向划船；preset 未说明是反握俯身划船还是 inverted row，不能在无唯一标准时发布，保留候选但跳过。 |
| SPLIT_HIGH_ROW | `briefs/SPLIT_HIGH_ROW.json` | `candidates/SPLIT_HIGH_ROW/SPLIT_HIGH_ROW-candidate-01.png` | pass | `139cd8f5ae5157abd33357ae869434b0812f2f484fc8371807d544d2b3bb474c` | 分动式高位杠杆、胸托、双侧中立把手和背部高亮通过。 |

## 追加批次：单臂/胸托/地雷/海豹划船（2026-07-25）

| code | brief | 候选 | 状态 | SHA-256 | 初检说明 |
| --- | --- | --- | --- | --- | --- |
| CABLE_SINGLE_ARM_PULLDOWN | `briefs/CABLE_SINGLE_ARM_PULLDOWN.json` | `candidates/CABLE_SINGLE_ARM_PULLDOWN/CABLE_SINGLE_ARM_PULLDOWN-candidate-01.png` | pass | `a8fb33a3c4a948ca4da717f5e10c5fb8927b2805ce166de1c195c15917963897` | 站姿高位单把手、单根钢索、非工作手置髋和单侧背阔肌高亮可辨。 |
| SINGLE_ARM_CABLE_ROW | `briefs/SINGLE_ARM_CABLE_ROW.json` | `candidates/SINGLE_ARM_CABLE_ROW/SINGLE_ARM_CABLE_ROW-candidate-01.png` | pass | `7395f303d4b5e6c41c6f83f8ffa0885ade6351aa894b363f020081040a2295f7` | 半跪支撑、低位单把手和单侧回拉轨迹明确，背阔肌/菱形肌高亮通过。 |
| CHEST_SUPPORTED_T_BAR_ROW | `briefs/CHEST_SUPPORTED_T_BAR_ROW.json` | `candidates/CHEST_SUPPORTED_T_BAR_ROW/CHEST_SUPPORTED_T_BAR_ROW-candidate-01.png` | pass | `0a9d71bb055c0fd421cae3a8e3876e2ea87af0ec0c1e6c44b99dc92974b7d52a` | 胸托上斜凳、地雷/T 杠固定端、中立双把手和板片结构可辨。 |
| CHEST_SUPPORTED_MACHINE_ROW | `briefs/CHEST_SUPPORTED_MACHINE_ROW.json` | `candidates/CHEST_SUPPORTED_MACHINE_ROW/CHEST_SUPPORTED_MACHINE_ROW-candidate-01.png` | pass | `dff8433584ebb65d6bbbccedd7b4ac0f625f476c52f425b01ad8754d29b3d022` | 胸托固定轨迹器械、双侧杠杆把手和配重结构可辨，背部高亮通过。 |
| MEADOWS_ROW | `briefs/MEADOWS_ROW.json` | `candidates/MEADOWS_ROW/MEADOWS_ROW-candidate-01.png` | pass | `d5e0963ee12cbdcc687952cb731f34b090b72f5759706624815a599892558585` | 地雷底座、斜置杠铃、错步前倾和单臂粗端回拉结构可辨。 |
| SEAL_ROW | `briefs/SEAL_ROW.json` | `candidates/SEAL_ROW/SEAL_ROW-candidate-01.png` | pass | `8bd50b988f5ebfcad97cb803f4113d40c1dba9bedc3ae3d851546e0864fa3191` | 高架海豹凳、胸腹贴凳、双脚离地及凳下直杠铃结构可辨。 |

## 追加批次：引体/反式划船/下背（2026-07-25）

| code | brief | 候选 | 状态 | SHA-256 | 初检说明 |
| --- | --- | --- | --- | --- | --- |
| PULL_UP | `briefs/PULL_UP.json` | `candidates/PULL_UP/PULL_UP-candidate-01.png` | pass | `8f3557a4b566224024aba2f9db1585629096aed5f30af5f5503bed501c077192` | 单杠肩宽正握、双脚悬空、背阔肌高亮与完整支架通过。 |
| CHIN_UP | `briefs/CHIN_UP.json` | `candidates/CHIN_UP/CHIN_UP-candidate-01.png` | pass | `e6656351215100063db2b2c61df41a35fe115d316afea7116351765b188ea8fa` | 单杠肩宽反握、后侧握法可辨、双脚悬空和背阔肌高亮通过。 |
| WIDE_PULL_UP | `briefs/WIDE_PULL_UP.json` | `candidates/WIDE_PULL_UP/WIDE_PULL_UP-candidate-01.png` | pass | `83f8a6dc62bb2827f8e503d01531f359a04ebe8bd9fdde2a28e7123ff7f519ef` | 单杠宽握正握、握距明显、背侧双肘外展与背阔肌高亮通过。 |
| ASSISTED_PULL_UP | `briefs/ASSISTED_PULL_UP.json` | `candidates/ASSISTED_PULL_UP/ASSISTED_PULL_UP-candidate-01.png` | pass | `0a23611df75015ece358aeb33d630d8e80419b6401e01cbe86cf386c13574140` | 辅助引体机高位把手、膝垫、配重塔和背阔肌高亮可辨。 |
| INVERTED_ROW | `briefs/INVERTED_ROW.json` | `candidates/INVERTED_ROW/INVERTED_ROW-candidate-01.png` | pass | `fd02b11673f11aaf093ccc540f0bd6c11ce56bb381538144b9f8405a8812c63e` | 低位横杠仰卧水平划船、脚跟着地、身体直线和目标肌群通过。 |
| BACK_EXTENSION | `briefs/BACK_EXTENSION.json` | `candidates/BACK_EXTENSION/BACK_EXTENSION-candidate-01.png` | pass | `002908781155f6444e858670dc389875c48c1abb9b158082e46f6592a9e763d5` | 单一45度背部伸展凳、髋垫/脚踝固定、躯干回到直线和后链高亮通过。 |
| REVERSE_HYPEREXTENSION | `briefs/REVERSE_HYPEREXTENSION.json` | `candidates/REVERSE_HYPEREXTENSION/REVERSE_HYPEREXTENSION-candidate-01.png` | pass | `8ce313bdb7f6d7411d5b5286237498f65b6e48c69e895b4a954c05f46c9b4a4f` | 反向挺身机腹部支撑、前把手、双腿后抬和臀/竖脊肌高亮通过。 |
| NEUTRAL_GRIP_PULL_UP | `briefs/NEUTRAL_GRIP_PULL_UP.json` | `candidates/NEUTRAL_GRIP_PULL_UP/NEUTRAL_GRIP_PULL_UP-candidate-01.png` | pass | `57df427a3ee50225ac9b2f02f795e1d0348614611e5c1eafe62d76d111236d92` | 双杠架平行把手、中立握悬垂引体、双脚离地和背阔肌高亮通过。 |

## 追加批次：传统硬拉/哑铃上拉（2026-07-25）

| code | brief | 候选 | 状态 | SHA-256 | 初检说明 |
| --- | --- | --- | --- | --- | --- |
| DEADLIFT | `briefs/DEADLIFT.json` | `candidates/DEADLIFT/DEADLIFT-candidate-01.png` | pass | `9e4152e88d04614cc8c1a751abd56cbf0e664a797ed96e79d8fc112690495e9d` | 传统杠铃离地前起始、杠铃贴近小腿、髋膝关系和后链高亮通过。 |
| DB_PULLOVER | `briefs/DB_PULLOVER.json` | `candidates/DB_PULLOVER/DB_PULLOVER-candidate-01.png` | pass | `4deca094b1fd7b8cfb754005bef04d7e00cd563908d4bce44010f64e102574ef` | 平凳仰卧、双手共同托握单只哑铃、过头轨迹和背阔肌高亮通过。 |

## 跳过与风险台账

1. `SMITH_REVERSE_ROW` 暂不进入正式素材：常见资料同时把 “reverse row” 用作史密斯架反向身体划船和反握俯身杠铃划船；当前 preset 只有“与正手区分”而无体位/器械动作定义。候选图和 brief 已保存，待动作域补充唯一语义后再重生成。
2. `REVERSE_LAT_PULLDOWN` 的候选大图能够表达直杆下拉，但缩小至 144 px 后掌心朝向不够醒目；属于握法可读性风险，建议正式导出前由自动缩略图检查复核，不直接视为跳过。

## 权利与来源

所有候选只使用本仓库 `references/approved/character-v1.png`、`style-v1.png` 和本次原创动作 brief 作为输入，生成工具条款记录沿用 `reviews/input-policy-v1.md` 与 `reviews/openai-imagegen-terms-2026-07-24.md`。本批次没有使用第三方动作图片或外部训练素材。
