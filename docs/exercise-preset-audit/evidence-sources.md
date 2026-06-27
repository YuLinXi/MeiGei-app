# 预置动作审核证据索引

生成日期：2026-06-27

说明：逐动作 CSV 的 `证据ID` 引用下列来源。证据采用“动作模式 + 代表动作”的方式：例如杠铃、哑铃、史密斯、器械卧推共享水平推模式证据；具体变体再按上斜/下斜、窄距/钻石等差异补充来源。

| 证据ID | 来源 | 链接 | 用途 |
|---|---|---|---|
| P0 | 当前 iOS 预置动作 JSON | ios/DontLift/DontLift/Resources/ExerciseLibrary/preset_exercises_v1.json | 当前 App 优先加载的预置动作清单，审计范围以此为准。 |
| P1 | 预置动作库 V1 评估稿 | docs/exercise-library-preset-v1.md | 解释 183 条精选库、别名兼容层和移除清单的产品背景。 |
| E1 | StrengthLog：Bench Press / Dumbbell Chest Press / Push-Up 资料 | https://www.strengthlog.com/bench-press/<br>https://www.strengthlog.com/dumbbell-chest-press/<br>https://www.strengthlog.com/push-ups-vs-bench-press/ | 水平推类以胸大肌为主，三角肌前束和肱三头肌参与推举。 |
| E2 | Trebs 等：Bench angle 对卧推动作肌电的影响 | https://pubmed.ncbi.nlm.nih.gov/20512064/<br>https://pmc.ncbi.nlm.nih.gov/articles/PMC7579505/ | 上斜角度会提高锁骨部胸大肌和/或前三角参与度，支持上胸/前束协同判断。 |
| E3 | StrengthLog：Dumbbell Fly / Chest Fly Machine | https://www.strengthlog.com/dumbbell-chest-fly/<br>https://www.strengthlog.com/chest-fly-machine/ | 飞鸟类是胸部水平内收动作，主要目标是胸大肌；三头不应作为主要协同肌。 |
| E4 | StrengthLog：Dips / Push-Ups / Close-Grip Push-Up | https://www.strengthlog.com/dips/<br>https://www.strengthlog.com/push-ups-vs-bench-press/<br>https://www.strengthlog.com/close-grip-push-up/ | 双杠臂屈伸、俯卧撑同时训练胸、前三角和三头；窄距/钻石变体更偏三头。 |
| E5 | StrengthLog：Lat Pulldown / Pull-Up / Chin-Up | https://www.strengthlog.com/lat-pulldown/<br>https://www.strengthlog.com/pull-up/<br>https://www.strengthlog.com/chin-up/ | 垂直拉类以背阔肌为主，肱二头肌、后三角等参与。 |
| E6 | StrengthLog：Barbell Row / Seated Cable Row / Inverted Row | https://www.strengthlog.com/barbell-row/<br>https://www.strengthlog.com/seated-cable-row/<br>https://www.strengthlog.com/inverted-row/ | 划船类同时覆盖背阔肌、中背/菱形肌、斜方肌、后三角，肱二头肌参与拉动。 |
| E7 | StrengthLog：Deadlift / Rack Pull / Romanian Deadlift / Good Morning | https://www.strengthlog.com/deadlift/<br>https://www.strengthlog.com/rack-pull/<br>https://www.strengthlog.com/romanian-deadlift/<br>https://www.strengthlog.com/good-morning/ | 硬拉和髋铰链类是后链复合动作，涉及竖脊肌、臀大肌、腘绳肌、斜方肌/握力。 |
| E8 | StrengthLog：Dumbbell Pullover | https://www.strengthlog.com/dumbbell-pullover/ | 仰卧上拉主要涉及背阔肌，也会明显牵涉胸大肌和上肢推/拉稳定。 |
| E9 | StrengthLog：Barbell Shrug / Dumbbell Shrug | https://www.strengthlog.com/barbell-shrug/<br>https://www.strengthlog.com/dumbbell-shrug/ | 耸肩主要目标是斜方肌，握力/前臂参与负重保持；不是二头或后三角主导。 |
| E10 | StrengthLog：Overhead Press / Dumbbell Shoulder Press / Arnold Press | https://www.strengthlog.com/overhead-press/<br>https://www.strengthlog.com/dumbbell-shoulder-press/<br>https://www.strengthlog.com/arnold-press/ | 肩推类以前束/中束三角肌和肱三头肌为主要参与肌群。 |
| E11 | StrengthLog：Lateral Raise / Front Raise | https://www.strengthlog.com/dumbbell-lateral-raise/<br>https://www.strengthlog.com/front-raise/ | 侧平举主攻三角肌中束，前平举主攻三角肌前束。 |
| E12 | StrengthLog：Reverse Dumbbell Fly / Face Pull | https://www.strengthlog.com/reverse-dumbbell-fly/<br>https://www.strengthlog.com/face-pull/ | 后束飞鸟和面拉主攻后三角，并牵涉斜方肌/菱形肌等肩胛稳定肌。 |
| E13 | StrengthLog：Upright Row / Barbell High Pull | https://www.strengthlog.com/upright-row/<br>https://www.strengthlog.com/barbell-high-pull/ | 直立划船和高拉会训练三角肌中束、斜方肌，且高拉带有爆发/奥举衍生属性。 |
| E14 | StrengthLog：Barbell Curl / Hammer Curl / Reverse Curl / Preacher Curl | https://www.strengthlog.com/barbell-curl/<br>https://www.strengthlog.com/hammer-curl/<br>https://www.strengthlog.com/reverse-curl/<br>https://www.strengthlog.com/preacher-curl/ | 弯举类主攻肱二头肌；锤式和反握变体更强调肱桡肌/前臂参与。 |
| E15 | StrengthLog：Tricep Pushdown / Close-Grip Bench / Triceps Extension / Bench Dip | https://www.strengthlog.com/tricep-pushdown/<br>https://www.strengthlog.com/close-grip-bench-press/<br>https://www.strengthlog.com/lying-triceps-extension/<br>https://www.strengthlog.com/bench-dip/ | 三头动作主攻肱三头肌；窄距卧推和臂屈伸仍有胸和前三角参与。 |
| E16 | StrengthLog：Wrist Curl / Wrist Extension | https://www.strengthlog.com/wrist-curl/<br>https://www.strengthlog.com/wrist-extension/ | 腕屈伸动作归前臂肌群。 |
| E17 | StrengthLog：Squat / Front Squat / Hack Squat | https://www.strengthlog.com/squat/<br>https://www.strengthlog.com/front-squat/<br>https://www.strengthlog.com/hack-squat/ | 蹲类以股四头肌为主，同时涉及臀大肌、内收肌和腘绳肌。 |
| E18 | StrengthLog：Leg Press / Leg Extension / Leg Curl | https://www.strengthlog.com/leg-press/<br>https://www.strengthlog.com/leg-extension/<br>https://www.strengthlog.com/leg-curl/ | 腿举偏股四头肌并牵涉臀/腘绳/内收；腿屈伸主股四头，腿弯举主腘绳肌。 |
| E19 | StrengthLog：Lunge / Step-Up / Bulgarian Split Squat | https://www.strengthlog.com/dumbbell-lunge/<br>https://www.strengthlog.com/step-up/<br>https://www.strengthlog.com/bulgarian-split-squat/ | 单腿蹲/箭步/登踏类主要覆盖股四头和臀大肌，腘绳肌与内收肌协同。 |
| E20 | StrengthLog：Sumo Deadlift / Hip Adduction | https://www.strengthlog.com/sumo-deadlift/<br>https://www.strengthlog.com/hip-adduction-machine/ | 相扑硬拉和髋内收明确牵涉内收肌，前者还涉及臀、后链与背部稳定。 |
| E21 | StrengthLog：Standing Calf Raise / Seated Calf Raise | https://www.strengthlog.com/standing-calf-raise/<br>https://www.strengthlog.com/seated-calf-raise/ | 提踵动作归小腿；站姿偏腓肠肌，坐姿更偏比目鱼肌。 |
| E22 | StrengthLog：Hip Thrust / Glute Bridge / Cable Glute Kickback | https://www.strengthlog.com/hip-thrust/<br>https://www.strengthlog.com/glute-bridge/<br>https://www.strengthlog.com/cable-kickback/ | 臀推、臀桥、后踢腿主攻臀大肌，腘绳肌/核心可作为协同或稳定。 |
| E23 | StrengthLog / PubMed：Hip Abduction / Lateral Band Walk | https://www.strengthlog.com/hip-abduction-machine/<br>https://pubmed.ncbi.nlm.nih.gov/28045218/ | 髋外展和弹力带侧走主要训练臀中肌/臀小肌，臀大肌参与。 |
| E24 | StrengthLog：Crunch / Hanging Leg Raise / Cable Crunch / Ab Wheel | https://www.strengthlog.com/crunch/<br>https://www.strengthlog.com/hanging-leg-raise/<br>https://www.strengthlog.com/cable-crunch/<br>https://www.strengthlog.com/ab-wheel-rollout/ | 屈曲/举腿/健腹轮类主要覆盖腹直肌，健腹轮也需要腹斜肌和肩背稳定。 |
| E25 | StrengthLog / ACE：Plank / Side Plank / Dead Bug / Bird Dog | https://www.strengthlog.com/plank/<br>https://www.strengthlog.com/side-plank/<br>https://www.acefitness.org/resources/everyone/exercise-library/17/bird-dog/<br>https://www.acefitness.org/resources/everyone/exercise-library/193/dead-bug/ | 抗伸展和抗旋稳定类覆盖腹直肌、腹斜肌，并可牵涉竖脊肌/臀部稳定。 |
| E26 | StrengthLog / ACE：Russian Twist / Cable Wood Chop | https://www.strengthlog.com/russian-twist/<br>https://www.acefitness.org/resources/everyone/exercise-library/188/wood-chop/ | 旋转/抗旋核心动作以腹斜肌为主，腹直肌参与稳定。 |
| E27 | StrengthLog：Kettlebell Swing / Turkish Get-Up / Farmer Carry | https://www.strengthlog.com/kettlebell-swing/<br>https://www.strengthlog.com/turkish-get-up/<br>https://www.strengthlog.com/farmers-walk/ | 壶铃摆荡偏后链爆发；土耳其起立是全身稳定动作；农夫行走重点是握力、斜方肌和核心抗侧屈。 |
| E28 | ACE / NASM：Burpee / Battle Rope | https://www.acefitness.org/resources/everyone/exercise-library/67/burpee/<br>https://blog.nasm.org/battle-ropes-exercises | 波比和战绳是全身功能/体能动作，包含上肢、核心和下肢参与。 |
| E29 | Cleveland Clinic / Hinge Health：Cat-Cow / Downward Dog / Thoracic Rotation | https://health.clevelandclinic.org/cat-cow-stretch<br>https://www.hingehealth.com/resources/articles/downward-facing-dog/<br>https://www.hingehealth.com/resources/articles/thoracic-spine-mobility-exercises/ | 猫牛式、下犬式、胸椎旋转适合归热身拉伸/活动度，不应作为力量动作高亮。 |
| E30 | Wiewelhove 等：Foam rolling meta-analysis | https://www.frontiersin.org/articles/10.3389/fphys.2019.00376/full | 泡沫轴更适合作为放松/恢复工具，归热身拉伸的泡沫轴放松。 |
| E31 | Shoulder mobility / pass-through 参考 | https://www.physio-pedia.com/Shoulder_Mobility_Exercises | 肩部热身、绕肩、臂画圈、弹力带绕肩属于肩关节活动度/动态热身。 |
