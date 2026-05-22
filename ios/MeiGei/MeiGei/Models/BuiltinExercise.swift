import Foundation

/// 主要肌群分类。rawValue 直接作为动作的 primaryMuscle 存储值（中文，前后端一致）。
enum MuscleGroup: String, CaseIterable, Identifiable, Codable {
    case chest = "胸"
    case back = "背"
    case shoulders = "肩"
    case arms = "手臂"
    case legs = "腿"
    case glutes = "臀"
    case core = "核心"
    case fullBody = "全身"

    var id: String { rawValue }
}

/// 器械类型。
enum EquipmentType: String, CaseIterable, Identifiable, Codable {
    case barbell = "杠铃"
    case dumbbell = "哑铃"
    case machine = "器械"
    case cable = "绳索"
    case bodyweight = "自重"
    case kettlebell = "壶铃"

    var id: String { rawValue }
}

/// 内置动作（只读，随包发布）。
/// 注意：当前为起步用的代表性子集；任务 3.1 将补齐 150-200 个 + 部位高亮图资源。
struct BuiltinExercise: Identifiable, Hashable, Codable {
    let code: String
    let name: String
    let primaryMuscle: String
    let equipmentType: String

    var id: String { code }
}

extension BuiltinExercise {
    /// 起步内置动作集（占位，待 3.1 数据任务补齐）。
    static let starter: [BuiltinExercise] = [
        .init(code: "BB_BENCH_PRESS", name: "杠铃卧推", primaryMuscle: "胸", equipmentType: "杠铃"),
        .init(code: "DB_BENCH_PRESS", name: "哑铃卧推", primaryMuscle: "胸", equipmentType: "哑铃"),
        .init(code: "INCLINE_BB_PRESS", name: "上斜杠铃卧推", primaryMuscle: "胸", equipmentType: "杠铃"),
        .init(code: "CABLE_FLY", name: "绳索夹胸", primaryMuscle: "胸", equipmentType: "绳索"),
        .init(code: "PUSH_UP", name: "俯卧撑", primaryMuscle: "胸", equipmentType: "自重"),
        .init(code: "PULL_UP", name: "引体向上", primaryMuscle: "背", equipmentType: "自重"),
        .init(code: "BB_ROW", name: "杠铃划船", primaryMuscle: "背", equipmentType: "杠铃"),
        .init(code: "LAT_PULLDOWN", name: "高位下拉", primaryMuscle: "背", equipmentType: "绳索"),
        .init(code: "DEADLIFT", name: "硬拉", primaryMuscle: "背", equipmentType: "杠铃"),
        .init(code: "SEATED_CABLE_ROW", name: "坐姿绳索划船", primaryMuscle: "背", equipmentType: "绳索"),
        .init(code: "OHP", name: "站姿推举", primaryMuscle: "肩", equipmentType: "杠铃"),
        .init(code: "DB_SHOULDER_PRESS", name: "哑铃肩推", primaryMuscle: "肩", equipmentType: "哑铃"),
        .init(code: "LATERAL_RAISE", name: "侧平举", primaryMuscle: "肩", equipmentType: "哑铃"),
        .init(code: "FACE_PULL", name: "面拉", primaryMuscle: "肩", equipmentType: "绳索"),
        .init(code: "BB_CURL", name: "杠铃弯举", primaryMuscle: "手臂", equipmentType: "杠铃"),
        .init(code: "DB_CURL", name: "哑铃弯举", primaryMuscle: "手臂", equipmentType: "哑铃"),
        .init(code: "TRICEP_PUSHDOWN", name: "绳索下压", primaryMuscle: "手臂", equipmentType: "绳索"),
        .init(code: "SKULL_CRUSHER", name: "仰卧臂屈伸", primaryMuscle: "手臂", equipmentType: "杠铃"),
        .init(code: "BB_SQUAT", name: "杠铃深蹲", primaryMuscle: "腿", equipmentType: "杠铃"),
        .init(code: "LEG_PRESS", name: "腿举", primaryMuscle: "腿", equipmentType: "器械"),
        .init(code: "LEG_EXTENSION", name: "腿屈伸", primaryMuscle: "腿", equipmentType: "器械"),
        .init(code: "LEG_CURL", name: "腿弯举", primaryMuscle: "腿", equipmentType: "器械"),
        .init(code: "ROMANIAN_DL", name: "罗马尼亚硬拉", primaryMuscle: "腿", equipmentType: "杠铃"),
        .init(code: "HIP_THRUST", name: "臀冲", primaryMuscle: "臀", equipmentType: "杠铃"),
        .init(code: "PLANK", name: "平板支撑", primaryMuscle: "核心", equipmentType: "自重"),
        .init(code: "HANGING_LEG_RAISE", name: "悬垂举腿", primaryMuscle: "核心", equipmentType: "自重"),
    ]
}
