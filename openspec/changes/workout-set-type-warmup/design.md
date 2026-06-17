# Design — 组类型（正式组/热身组）

## 1. 建模：可扩展枚举 + raw-string 存储

只落两个 case，但用枚举承载，给未来留位。存储沿用项目既有的 `*Raw: String` 模式（同 `SyncStatus`/`syncStatusRaw`），避免 SwiftData 直接持久化枚举的兼容包袱。

```swift
/// 组类型。当前仅 working/warmup；后续可 append dropset/failure 等，
/// 统计判据为 `!= .warmup`，新增「正式类」case 无需改统计代码。
enum WorkoutSetType: String, Codable, CaseIterable {
    case working   // 正式组
    case warmup    // 热身组
    // 预留：case dropset / case failure ...
}

@Model final class WorkoutSet {
    // ...既有字段...
    var setTypeRaw: String   // 默认 "working"

    var setType: WorkoutSetType {
        get { WorkoutSetType(rawValue: setTypeRaw) ?? .working }   // 未知值兜底为正式组
        set { setTypeRaw = newValue.rawValue }
    }
}
```

- **默认值 `"working"`**：新 `@Attribute` 给默认值，旧记录读出来即正式组 → **零迁移脚本**。
- **未知值兜底 `.working`**：将来后端/旧端发来本端未识别的类型（如老客户端收到 `dropset`），按「正式组」处理而非崩溃 —— 与「统计判据 `!= .warmup`」一致，未知类型默认计入统计，安全保守。

**为何不用 `isWarmup: Bool`**：用户明确要枚举形态以便扩展。布尔到三态以上要改类型/补列，枚举只 append case。

## 2. 统计判据：唯一真相 `正式组 = setType != .warmup`

三处统计口径全部改为同一谓词，集中表达「热身组不算数」：

```swift
// 谓词（建议抽一个扩展，避免散落）
extension WorkoutSet { var countsForStats: Bool { setType != .warmup } }
```

| 落点 | 文件 | 改动 |
|---|---|---|
| PR 最大重量（动作库行） | `PRStats.maxWeightByKey` | set 循环加 `where s.countsForStats` |
| PR 摘要 | `PRStats.latestPR` | 同上 |
| 周训练量 volume | `WorkoutWeeklyStats` | `Σ` 只累加正式组 |
| 周总组数 setCount | `WorkoutWeeklyStats` | 只数正式组 |
| 周总次数 repCount | `WorkoutWeeklyStats` | 只累加正式组 reps |
| 历史强度曲线 | 详情页/历史曲线遍历 | 只取正式组点 |

**为何写 `!= .warmup` 而非 `== .working`**：未来加 `dropset`/`failure`（都是真实训练努力，应计入训练量与组数）时，`!= .warmup` 自动把它们归入「正式类」，统计代码一行不改。这是用户选「枚举一步到位」的核心收益落点。

> 注意：递减组的轻重量段、力竭组本就不会破 PR，计入 PR 无副作用；而它们计入 volume/组数符合训练学。故「正式类」统一进统计是正确缺省。

## 3. 录入交互：徽章 + ⋯ 菜单双入口

- **徽章点击切类型**：组行最左的序号徽章可点。当前两态 → 单击 toggle `working ⇄ warmup`。
  - 将来 case ≥ 3 时，把 toggle 换成「点徽章弹类型选择器（popover）」，**入口不变**（仍是点徽章），仅落下来的控件升级。
- **⋯ 菜单入口（可发现性）**：组级「更多操作」⋯ 菜单加一项「标为热身组 / 改回正式组」（复用现成 `setMenuItem`，与「删除组」并列、用 hairline 分隔），与徽章点按等价。纯徽章点按太隐蔽，菜单文字入口让功能可被发现；两入口共用模型方法 `WorkoutExercise.toggleSetType(_:)`。
- **徽章显示规则**：
  - 热身组：显「热」**朱砂红浅底 pill**（`accentSoft` 底 + `accent` 字，frame 略宽容纳中文；不参与数字编号）。
  - 正式组：按动作内**仅正式组**的相对顺序显示 **1, 2, 3…**（重新编号，跳过热身组；纯文本无底）。
- **「加一组」默认 `working`**：`WorkoutKeypad` 的加一组键追加正式组（预填上一**正式**组重量，热身组重量不作为预填源）。

```
卧推                          ⋯ 菜单：
┌─────────────────────────────┐   ┌──────────────┐
│ 热  40 × 10  ← 点「热」切回正式│   │ 🔥 标为热身组  │
│ 热  60 × 5                   │   │ ───────────  │
│ 1   80 × 8   ← 点「1」切热身  │   │ 🗑  删除组     │
│ 2   80 × 8                   │   └──────────────┘
│ 3   80 × 7                   │
└─────────────────────────────┘
（热身徽章浅红底 pill；正式组纯文本数字）
```

## 4. 排序：仅热身吸顶

- 同一 `WorkoutExercise` 下，**热身组强制排在所有正式组之前**；正式组之间保持用户手动顺序。
- 实现取向：渲染/落盘时按「热身优先」稳定排序（warmup 段在前、working 段在后，段内保持原相对次序），再据此派生徽章编号。`setIndex` 仍作底层稳定序，类型分段是其上的展示与编号规则。
- 当某组从正式切为热身（或反向）时：重排到对应段尾、并重算正式组编号。
- **为何只热身吸顶**：递减/力竭组在训练学里接在正式组之后/之中，将来引入时不应被吸顶——所以排序规则今天就只对 `warmup` 生效，不写成「非正式全部置底」。

## 5. 同步契约

- `WorkoutSet` 是聚合孙节点，**随 workout 整树全量替换**上传，无独立信封、**无 LWW 逐字段合并** → 新增 `setType` 无冲突解决复杂度。
- iOS：`WorkoutSetDTO` 加 `var setType: String?`（编码时写 `setTypeRaw`；解码缺失时兜底 `working`，兼容旧后端/旧数据）。
- 后端：`WorkoutTree` 直接内嵌 `WorkoutSet` 实体 → 实体加 `setType` 字段即随 Jackson 序列化进出；DB 加列 `NOT NULL DEFAULT 'working'`。
- **向后兼容**：旧客户端 push 不带 `setType` → 后端列默认 `working`；新客户端 pull 到旧记录无该值 → 解码兜底 `working`。两向都安全。
- **不涉及软删墓碑坑**：set 无独立软删信封（随聚合整树替换），CLAUDE.md 记的「墓碑 softDelete」约定在此不适用。

## 6. 迁移

- **后端**：`V4__workout_set_type.sql`（V2/V3 已占用，顺延 V4）—— `ALTER TABLE workout_set ADD COLUMN set_type text NOT NULL DEFAULT 'working';`（Flyway 自动跑）。旧行回填 `working`。
- **iOS SwiftData**：新增带默认值的 `@Attribute`，SwiftData 轻量迁移自动补列，旧本地记录读出即 `working`。无需手写 migration plan。
- **历史数据语义**：全部既有组 = 正式组（用户决策），与默认值天然一致。

## 7. 决策摘要

| 决策点 | 选择 | 理由 |
|---|---|---|
| 建模形态 | 可扩展枚举 + rawString | 用户要一步到位的扩展性；复刻 SyncStatus 存储风格 |
| 当前 case | 仅 working / warmup | 用户：现在只做两种，留口子 |
| 统计判据 | `setType != .warmup` | 未来「正式类」新 case 自动计入，统计零改动 |
| 未知值兜底 | `.working`（计入统计） | 跨版本安全，保守缺省 |
| 切换入口 | 序号徽章点击 toggle + ⋯ 菜单项 | 徽章点按作快捷；⋯ 菜单文字入口提升可发现性 |
| 编号 | 仅正式组 1..n，热身显「热」pill | 业界一致的视觉区分；中文「热」比 W 直观 |
| 排序 | 仅热身吸顶 | 递减/力竭将来接正式组后，不应吸顶 |
| 迁移 | DB DEFAULT + SwiftData 默认值 | 旧数据天然=正式组，无脚本 |
