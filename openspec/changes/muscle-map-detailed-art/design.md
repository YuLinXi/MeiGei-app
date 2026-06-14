## Context

`exercise-muscle-data` 落地了 `MuscleMapView`（纯 SwiftUI Path，手绘简化 ~12 区）。真机验收发现观感偏「积木」，不如开源 `react-native-body-highlighter`（MIT）详细解剖图。已抽取该开源 4 面数据为 `MuscleBodyArt.swift`（maleFront 19 slug / maleBack 16 / femaleFront 19 / femaleBack 14，各带 viewBox）。开源 path 用到 `M/m L/l H/h C/c Q/q A/a Z/z`，含相对坐标与椭圆弧。

## Goals / Non-Goals

**Goals:**
- 高亮图升级为详细解剖底图，三态染色/性别/正背/缺数据隐藏行为不变。
- `MuscleMapView` 对外 API 不变，详情页零改动。

**Non-Goals:**
- 不二次美术精修开源图；不引第三方 SVG 库；不改 API；不做 PDF 路线。

## Decisions

### D1：直接使用开源 MIT path（衍生作品 + 附 LICENSE）
比起「自绘重画」，直接渲染开源 path 保真度高得多、且省绘制。代价：成为衍生作品，须随包附 `react-native-body-highlighter` MIT 许可证与版权声明。
- 与 `exercise-muscle-data` D3「自绘、零资产」是**不同技术路线**，故独立立案，不污染原 change 的 design 自洽性。

### D2：自写完整 SVG 解析器（不引库）
支持 `M/m L/l H/h C/c Q/q A/a Z/z`：
- 维护「当前点」`cur` 与「子路径起点」`start`；相对指令累加 `cur`。
- 隐式重复：一个指令字母后可跟多组坐标，按该指令参数个数循环消费。
- 椭圆弧 `A`：按 SVG 规范 endpoint→center 参数化，再以 ≤90° 分段、每段用三次贝塞尔近似（标准 kappa 公式）。
- 不支持 `S/s T/t V/v`（开源数据未用到），遇到则跳过该指令参数，避免崩。
- 备选：引 SVGKit/PocketSVG（被否：零重依赖偏好）。

### D3：Canvas 渲染（按 slug 着色）
用 `Canvas` 一次性绘制几十段 path（优于几十个 `Shape` 视图）。
- viewBox→size 变换：等比缩放 `s = min(W/vb.w, H/vb.h)`，居中；path 解析为原始 viewBox 坐标，绘制前 `path.applying(transform)`。
- 渲染顺序：先全部 idle 底，再按 region 着色的 slug 叠加（保证高亮压在底图之上）。

### D4：slug → MuscleRegion 映射
- chest→chest，biceps→biceps，triceps→triceps，abs→abs，obliques→obliques，forearm→forearms，quadriceps→quads，adductors→adductors，calves→calves，trapezius→traps。
- deltoids：**按面**——正面→deltFront，背面→deltRear。
- upper-back→lats，lower-back→lowerBack，hamstring→hams，gluteal→glutes。
- 无映射（idle 底）：neck/knees/tibialis/hands/ankles/feet/head/hair/abductors。

## Risks / Trade-offs

- [自写弧线解析有误 → 破面] → 真机/模拟器渲染一张目检；弧段分割 ≤90° + 标准近似，误差极小。
- [Canvas 几十段 path 性能] → 单视图静态绘制，开销可忽略；如卡顿可缓存 `Path`。
- [许可合规] → 随包附 MIT LICENSE + 版权声明，proposal/design 注明，发版前核对。
- [女版 viewBox 偏移(-50,-40)] → 解析后按各面 vb 变换，已按面分别存 vb。

## Migration Plan

1. 生成 `MuscleBodyArt.swift`（已完成）。
2. 升级 `MuscleMapView`：完整 SVG 解析器 + Canvas 渲染 + slug 映射；移除手绘 `BodyArt`。
3. 加 `react-native-body-highlighter` LICENSE 文件随包。
4. 编译 + 模拟器渲染一张目检（卧推四面）。
- 回滚：保留 git 历史的手绘版即可还原（API 不变）。
