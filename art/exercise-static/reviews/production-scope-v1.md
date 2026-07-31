# 预置动作生产范围 v1

本文件记录当前用户授权的全量制作范围，避免把明确排除项误报为未完成。

## 纳入制作

`preset_exercises_v1.json` 中除下方排除规则外的全部 `BuiltinExercise.code`。纳入动作必须继续遵守 `character-v1`、`style-v1`、原创 brief、五项自治审核、288×288/JPEG Q82/sRGB/纯白/≤24 KiB 和正式 manifest 规则。

## 排除规则

- `category == 热身拉伸`：排除。
- `category == 功能性`：排除。
- `category == 有氧`：排除；当前预置数据没有独立的“有氧”分类，脚本仍保留该规则以防数据后续增加。
- `category == 核心 && equipmentType == 自重`：排除“自重核心类动作”。核心分类中的器械、绳索等非自重动作不自动排除，仍按动作 brief 判断是否有稳定的静态表达。

## 当前核对结果（2026-07-25）

| 范围 | 数量 |
| --- | ---: |
| 预置动作总数 | 224 |
| 纳入制作 | 179 |
| 热身/拉伸 | 22 |
| 功能性 | 9 |
| 有氧 | 0 |
| 自重核心 | 14 |

权威统计命令：

```bash
node art/exercise-static/scripts/exercise-static-assets.mjs coverage
```

范围外动作保留原有肌群缩略图，不生成静态动作图，也不作为质量失败项计入跳过台账。
