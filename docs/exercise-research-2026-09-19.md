# 新增动作调研与定义（2026-09-19）

本轮按项目动作库的统一 code、器械、肌群和动作图 brief 约定核对 4 个名称。最终决定：Y字侧平举、单侧器械侧平举、低位坐姿划船机加入 iOS 预置动作库，不配置动作示意图，已删除 8 张候选 PNG，保留肌群图降级展示。三份绘图 brief 仅作为历史调研记录，不代表已确认姿势或后续制图任务。`CHEST_SUPPORTED_T_BAR_ROW` 使用用户已确认的 candidate-02 替换现有动作图，并补齐“胸托T杆划船”别名。

## 数据模型决定

| 用户名称 | code | 标准名称 | 器械 | 归类 | 处理 |
| --- | --- | --- | --- | --- | --- |
| Y字侧平举 | `CABLE_Y_LATERAL_RAISE` | Y字侧平举 | 绳索 | 肩 / 中束 | 沿用导入层已有 code，进入正式 preset；兼容“Y字绳索侧平举” |
| 单侧器械侧平举 | `MACHINE_HANDLE_LATERAL_RAISE` | 单侧器械侧平举 | 器械 | 肩 / 中束 | 沿用导入层已有 code，进入正式 preset；兼容“器械把手侧平举” |
| 低位坐姿划船机 | `MACHINE_LOW_ROW` | 低位坐姿划船机 | 器械 | 背 / 中背 | 新建 code，与普通坐姿器械划船、胸托 T 杠划船区分 |
| 胸托T杆划船 | `CHEST_SUPPORTED_T_BAR_ROW` | 胸托 T 杠划船 | T杠 | 背 / 中背 | 已在 preset、批准母版和运行时 JPG 中；补充无空格名称别名 |

### 动作事实

- `CABLE_Y_LATERAL_RAISE` 改为参考谭成义公开示范的单侧绳索版本，并把 Y 字与普通单臂绳索侧平举的视觉差异写成硬约束：器械侧绳索出绳点/滑轮与人物腰线大致同高，绳索从人物躯干后方绕行，工作手直接握绳头或绳结，不使用 D 把手；工作臂在肩胛平面内较纯侧向向身体前方偏约 30–45°，沿斜线经过肩高并继续到耳朵或头顶外侧，拇指向上、肘部低于手部，肩胛自然上旋而不耸肩。普通单臂绳索侧平举则是纯侧向抬臂、与地面平行并在肩高处停止。谭成义相关视频将该动作称为“Y 字绳索侧平举”；Cable Y-Raise 动作资料进一步确认“斜向轨迹 + 过肩进入头顶 Y 位”是区别普通侧平举的核心。原“双塔双手、仅略高于肩、低位滑轮、握单把手”的定义已判定为不够可辨识。
- `MACHINE_HANDLE_LATERAL_RAISE` 选择坐姿片式侧平举机的单侧独立把手变体。工作臂抬至肩高，非工作臂保持低位作为单侧识别依据；背垫、独立转轴和工作把手必须可见。Hammer Strength 官方资料明确将该设备描述为单侧独立功能、坐姿、独立工作臂，并以三角肌中束为主要目标。
- `MACHINE_LOW_ROW` 选择低位片式独立划船机，而不是通用坐姿绳索划船。画面保留胸垫、座椅、脚踏、双侧独立中立把手和板片；双肘向下肋后方移动，胸部保持贴垫。Matrix Magnum Low Row 官方结构说明包含低位支撑姿势、独立垂直握把和脚踏/板片布局。
- `CHEST_SUPPORTED_T_BAR_ROW` 按本轮调研收紧为 `Lever Reverse T Bar Row` 胸托片式 T 杠杠杆划船机：上胸贴黑色上斜胸垫，双手中立握胸垫下方两侧独立把手，肘部向后并略向下拉向下肋，双膝微屈、双脚踩固定脚踏，杠片真实挂在杠杆远端；不能画成自由杠铃 landmine、无胸托站姿 T 杠或普通坐姿绳索划船。该动作保留项目统一人物和医学线稿规范，重新进入候选图流程。

## 项目文件

- `art/exercise-static/briefs/CABLE_Y_LATERAL_RAISE.json`
- `art/exercise-static/briefs/MACHINE_HANDLE_LATERAL_RAISE.json`
- `art/exercise-static/briefs/MACHINE_LOW_ROW.json`
- `art/exercise-static/briefs/CHEST_SUPPORTED_T_BAR_ROW.json`
- `ios/DontLift/DontLift/Resources/ExerciseLibrary/preset_exercises_v1.json`
- `ios/DontLift/DontLift/Resources/ExerciseLibrary/exercise_aliases_v1.json`

## 调研来源

1. 凯圣王 / 谭成义，`谭成义三分化训练效果`（“Y 字绳索侧平举”、低位绳索起点）：<https://www.douyin.com/shipin/7635480017257941002>
2. 凯圣王，`Y字侧平举详解`（动作名称和肩部活动方向）：<https://www.bilibili.com/video/BV17hNXz6Exv/>
3. Sohu，`练肩部中束只会侧平举？试试这个动作`（Y 字绳索侧平举与传统水平侧平举的区分、绳索与手臂受力线）：<https://www.sohu.com/a/414829500_402200>
4. World Gym Taiwan，`Cable机（滑轮机）全方位训练指南`（单臂低位侧平举、远侧手握把、钢索经身体后方、肘部微屈）：<https://blog.worldgymtaiwan.com/twelve-cable-exercises>
5. MuscleWiki，`绳索单臂低位侧平举`（单把手、低位滑轮、肩外展至肩高、掌心中立）：<https://musclewiki.com/zh-cn/exercise/cable-rope-single-arm-low-lateral-raise>
6. Pocket Fit，`Cable Y-Raise`（斜向肩胛平面、拇指向上、越过肩高完成头顶 Y 位、与 Cable Lateral Raise 的区别）：<https://www.pocket-fit.app/exercises/cable-y-raise>
7. Exercise Dataset / RepDB，`Cable Lateral Raise`（普通单臂绳索侧平举：侧对低位滑轮、外侧手握把、手臂平行地面）：<https://exercise-dataset.com/exercise/cable-lateral-raise/>
8. Hammer Strength / Life Fitness，`Plate Loaded Lateral Raise`：<https://www.lifefitness.com/en-us/catalog/strength-training/plate-loaded/plate-loaded-lateral-raise>
9. Matrix Fitness，`Magnum Low Row MG-PL38`：<https://world.matrixfitness.com/eng/strength/plate-loaded/mg-pl38-low-row>
10. Experience Life / Life Time，`How to Use 4 Popular Strength-Training Machines`（坐姿划船的座椅、双手把手、下肋拉回和受控回放）：<https://experiencelife.lifetime.life/article/how-to-use-4-popular-strength-training-machines/>
11. Movviva，`Chest-Supported T-Bar Row`（胸托、下肋轨迹和动作区分）：<https://movviva.com/exercises/chest-supported-t-bar-row>
12. ExerciseGymGifsDB，`Lever Reverse T Bar Row`（胸托杠杆 T 杆机器动作结构参考）：<https://cdn.jsdelivr.net/gh/JahelCuadrado/ExerciseGymGifsDB@v1.1.0/api/en/exercises/upper-back/lever-reverse-t-bar-row.json>

外部页面只用于动作事实、器械结构和肌群归类核对；候选图未使用第三方图片，使用项目自有视觉风格与上一版项目候选作为人物/线稿连续性参考，并以本轮原创文字 brief 重做动作和器械关系。
