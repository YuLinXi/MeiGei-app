## 1. 开源数据（iOS 端）

- [x] 1.1 抽取 4 面开源 path 生成 `Models/MuscleBodyArt.swift`（各面 viewBox + [(slug,[d])]）

## 2. SVG 解析器（iOS 端）

- [x] 2.1 完整解析器：`M/m L/l H/h C/c Q/q A/a Z/z`，绝对/相对 + 隐式重复指令
- [x] 2.2 椭圆弧 `A/a` → 三次贝塞尔近似（endpoint→center 参数化 + ≤90° 分段）
- [x] 2.3 容错：未知指令跳过不崩

## 3. MuscleMapView 升级（iOS 端）

- [x] 3.1 改 Canvas 渲染：viewBox→size 等比居中变换，逐 slug 绘制
- [x] 3.2 slug → `MuscleRegion` 映射（deltoids 按正/背分前/后束；无映射作 idle）
- [x] 3.3 三态着色：先 idle 底，再叠 primary(accent)/secondary(accentSofter)；保留 `sex`/`side`/缺数据隐藏与对外 API
- [x] 3.4 移除手绘简化 `BodyArt` 及其数据

## 4. 许可（基础设施）

- [x] 4.1 随包加 `react-native-body-highlighter` 的 MIT LICENSE + 版权声明文件

## 5. 验收

- [x] 5.1 `xcodebuild` 编译通过；`ExerciseDetailView`/`MuscleRegionTests` 不回归
- [ ] 5.2 模拟器渲染目检：男女正背四面轮廓平滑无破面、卧推三态染色正确
