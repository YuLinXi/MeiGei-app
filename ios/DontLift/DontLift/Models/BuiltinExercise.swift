import Foundation

/// 器械类型。训记式细粒度（悍马机/史密斯/T杠 独立成类）。
enum EquipmentType: String, CaseIterable, Identifiable, Codable {
    case barbell    = "杠铃"
    case dumbbell   = "哑铃"
    case kettlebell = "壶铃"
    case machine    = "器械"
    case smith      = "史密斯"
    case hammer     = "悍马机"
    case tbar       = "T杠"
    case cable      = "绳索"
    case band       = "弹力带"
    case suspension = "悬挂"
    case bodyweight = "自重"
    case other      = "其他"

    var id: String { rawValue }
}

/// 内置动作（只读，随包发布）。
/// 分类两级：`category`（`ExerciseCategory` 父级，浏览/筛选/historyKey 归并）+ 可选 `subcategory`（父级内三层）。
/// 高亮细分肌群在 `primaryRegions`/`secondaryRegions`（由 regionData 回填，空则隐藏高亮）。
struct BuiltinExercise: Identifiable, Hashable, Codable {
    let code: String
    let name: String
    /// 浏览父级分类，取自 `ExerciseCategory.rawValue`（中文）。
    let category: String
    /// 父级内子分类（中文，可空=该父级未细分/「全部」）。非空时必属 `category` 的允许子分类清单。
    var subcategory: String? = nil
    let equipmentType: String
    /// 主动肌细分区（高亮图染朱砂红）。默认空 → 高亮图隐藏（由 regionData 回填）。
    var primaryRegions: [MuscleRegion] = []
    /// 协同肌细分区（高亮图染浅红）。
    var secondaryRegions: [MuscleRegion] = []
    /// 动作要点（原创短句 3-5 条；详情页展示）。
    var formCues: [String] = []

    var id: String { code }
}

extension BuiltinExercise {
    /// 内置动作集（对外）：在 `starterBase` 基础上按 `regionData` 回填细分肌群与要点。
    static let starter: [BuiltinExercise] = starterBase.map { ex in
        guard let d = regionData[ex.code] else { return ex }
        var e = ex
        e.primaryRegions = d.primary
        e.secondaryRegions = d.secondary
        e.formCues = d.cues
        return e
    }

    /// 内置动作基础清单（code/name/category/subcategory/equipmentType）。
    /// `category` 取自 `ExerciseCategory.rawValue`，`equipmentType` 取自 `EquipmentType.rawValue`。
    /// 注：训记导入动作见 `BuiltinExercise+Imported.swift`，与本清单合并入 `starterBase`。
    private static let starterBase: [BuiltinExercise] = curated + imported

    /// 原 MVP 精选 153 条（code 永久冻结，保证 historyKey 不断裂）。
    private static let curated: [BuiltinExercise] = [
        // MARK: 胸
        .init(code: "BB_BENCH_PRESS", name: "杠铃卧推", category: "胸", subcategory: "中下胸", equipmentType: "杠铃"),
        .init(code: "DB_BENCH_PRESS", name: "哑铃卧推", category: "胸", subcategory: "中下胸", equipmentType: "哑铃"),
        .init(code: "INCLINE_BB_PRESS", name: "上斜杠铃卧推", category: "胸", subcategory: "上胸", equipmentType: "杠铃"),
        .init(code: "INCLINE_DB_PRESS", name: "上斜哑铃卧推", category: "胸", subcategory: "上胸", equipmentType: "哑铃"),
        .init(code: "DECLINE_BB_PRESS", name: "下斜杠铃卧推", category: "胸", subcategory: "中下胸", equipmentType: "杠铃"),
        .init(code: "DECLINE_DB_PRESS", name: "下斜哑铃卧推", category: "胸", subcategory: "中下胸", equipmentType: "哑铃"),
        .init(code: "SMITH_BENCH_PRESS", name: "史密斯卧推", category: "胸", subcategory: "中下胸", equipmentType: "史密斯"),
        .init(code: "MACHINE_CHEST_PRESS", name: "坐姿器械推胸", category: "胸", subcategory: "中下胸", equipmentType: "器械"),
        .init(code: "CABLE_FLY", name: "绳索夹胸", category: "胸", subcategory: "中下胸", equipmentType: "绳索"),
        .init(code: "HIGH_CABLE_FLY", name: "高位绳索夹胸", category: "胸", subcategory: "中下胸", equipmentType: "绳索"),
        .init(code: "LOW_CABLE_FLY", name: "低位绳索夹胸", category: "胸", subcategory: "中下胸", equipmentType: "绳索"),
        .init(code: "DB_FLY", name: "哑铃飞鸟", category: "胸", subcategory: "中下胸", equipmentType: "哑铃"),
        .init(code: "INCLINE_DB_FLY", name: "上斜哑铃飞鸟", category: "胸", subcategory: "上胸", equipmentType: "哑铃"),
        .init(code: "PEC_DECK", name: "蝴蝶机夹胸", category: "胸", subcategory: "中下胸", equipmentType: "器械"),
        .init(code: "CHEST_DIP", name: "双杠臂屈伸(胸)", category: "胸", subcategory: "中下胸", equipmentType: "自重"),
        .init(code: "PUSH_UP", name: "俯卧撑", category: "胸", subcategory: "中下胸", equipmentType: "自重"),
        .init(code: "INCLINE_PUSH_UP", name: "上斜俯卧撑", category: "胸", subcategory: "中下胸", equipmentType: "自重"),
        .init(code: "DECLINE_PUSH_UP", name: "下斜俯卧撑", category: "胸", subcategory: "中下胸", equipmentType: "自重"),
        .init(code: "DIAMOND_PUSH_UP", name: "钻石俯卧撑", category: "胸", subcategory: "中下胸", equipmentType: "自重"),
        .init(code: "MACHINE_INCLINE_PRESS", name: "上斜器械推胸", category: "胸", subcategory: "上胸", equipmentType: "器械"),
        .init(code: "SVEND_PRESS", name: "斯文德推", category: "胸", subcategory: "中下胸", equipmentType: "哑铃"),

        // MARK: 背
        .init(code: "PULL_UP", name: "引体向上", category: "背", subcategory: "背阔", equipmentType: "自重"),
        .init(code: "CHIN_UP", name: "反握引体", category: "背", subcategory: "背阔", equipmentType: "自重"),
        .init(code: "WIDE_PULL_UP", name: "宽距引体", category: "背", subcategory: "背阔", equipmentType: "自重"),
        .init(code: "LAT_PULLDOWN", name: "高位下拉", category: "背", subcategory: "背阔", equipmentType: "绳索"),
        .init(code: "CLOSE_LAT_PULLDOWN", name: "窄握高位下拉", category: "背", subcategory: "背阔", equipmentType: "绳索"),
        .init(code: "STRAIGHT_ARM_PULLDOWN", name: "直臂下压", category: "背", subcategory: "背阔", equipmentType: "绳索"),
        .init(code: "BB_ROW", name: "杠铃划船", category: "背", subcategory: "中背", equipmentType: "杠铃"),
        .init(code: "PENDLAY_ROW", name: "潘德利划船", category: "背", subcategory: "中背", equipmentType: "杠铃"),
        .init(code: "T_BAR_ROW", name: "T杠划船", category: "背", subcategory: "中背", equipmentType: "T杠"),
        .init(code: "DB_ROW", name: "单臂哑铃划船", category: "背", subcategory: "中背", equipmentType: "哑铃"),
        .init(code: "CHEST_SUPPORTED_ROW", name: "俯卧支撑划船", category: "背", subcategory: "中背", equipmentType: "哑铃"),
        .init(code: "SEATED_CABLE_ROW", name: "坐姿绳索划船", category: "背", subcategory: "中背", equipmentType: "绳索"),
        .init(code: "MACHINE_ROW", name: "坐姿器械划船", category: "背", subcategory: "中背", equipmentType: "器械"),
        .init(code: "INVERTED_ROW", name: "反式划船", category: "背", subcategory: "中背", equipmentType: "自重"),
        .init(code: "DEADLIFT", name: "硬拉", category: "背", subcategory: "下背", equipmentType: "杠铃"),
        .init(code: "RACK_PULL", name: "架上拉", category: "背", subcategory: "下背", equipmentType: "杠铃"),
        .init(code: "DB_PULLOVER", name: "哑铃仰卧上拉", category: "背", subcategory: "背阔", equipmentType: "哑铃"),
        .init(code: "BACK_EXTENSION", name: "山羊挺身", category: "背", subcategory: "下背", equipmentType: "自重"),
        .init(code: "GOOD_MORNING", name: "早安式", category: "背", subcategory: "下背", equipmentType: "杠铃"),
        .init(code: "MEADOWS_ROW", name: "梅多斯划船", category: "背", subcategory: "中背", equipmentType: "杠铃"),
        .init(code: "KROC_ROW", name: "单臂高次哑铃划船", category: "背", subcategory: "中背", equipmentType: "哑铃"),
        .init(code: "ASSISTED_PULL_UP", name: "辅助引体向上", category: "背", subcategory: "背阔", equipmentType: "器械"),

        // MARK: 肩
        .init(code: "OHP", name: "站姿杠铃推举", category: "肩", subcategory: "前束", equipmentType: "杠铃"),
        .init(code: "SEATED_BB_PRESS", name: "坐姿杠铃推举", category: "肩", subcategory: "前束", equipmentType: "杠铃"),
        .init(code: "DB_SHOULDER_PRESS", name: "哑铃肩推", category: "肩", subcategory: "前束", equipmentType: "哑铃"),
        .init(code: "ARNOLD_PRESS", name: "阿诺德推举", category: "肩", subcategory: "前束", equipmentType: "哑铃"),
        .init(code: "MACHINE_SHOULDER_PRESS", name: "器械肩推", category: "肩", subcategory: "前束", equipmentType: "器械"),
        .init(code: "LANDMINE_PRESS", name: "杠铃单臂推", category: "肩", subcategory: "前束", equipmentType: "杠铃"),
        .init(code: "PIKE_PUSH_UP", name: "派克俯卧撑", category: "肩", subcategory: "前束", equipmentType: "自重"),
        .init(code: "LATERAL_RAISE", name: "哑铃侧平举", category: "肩", subcategory: "中束", equipmentType: "哑铃"),
        .init(code: "CABLE_LATERAL_RAISE", name: "绳索侧平举", category: "肩", subcategory: "中束", equipmentType: "绳索"),
        .init(code: "FRONT_RAISE", name: "哑铃前平举", category: "肩", subcategory: "前束", equipmentType: "哑铃"),
        .init(code: "CABLE_FRONT_RAISE", name: "绳索前平举", category: "肩", subcategory: "前束", equipmentType: "绳索"),
        .init(code: "REAR_DELT_FLY", name: "俯身飞鸟", category: "肩", subcategory: "后束", equipmentType: "哑铃"),
        .init(code: "REVERSE_PEC_DECK", name: "反向蝴蝶机", category: "肩", subcategory: "后束", equipmentType: "器械"),
        .init(code: "FACE_PULL", name: "面拉", category: "肩", subcategory: "后束", equipmentType: "绳索"),
        .init(code: "UPRIGHT_ROW", name: "杠铃直立划船", category: "肩", subcategory: "中束", equipmentType: "杠铃"),
        .init(code: "DB_UPRIGHT_ROW", name: "哑铃直立划船", category: "肩", subcategory: "中束", equipmentType: "哑铃"),
        .init(code: "BTN_PRESS", name: "颈后推举", category: "肩", subcategory: "前束", equipmentType: "杠铃"),
        .init(code: "MACHINE_LATERAL_RAISE", name: "器械侧平举", category: "肩", subcategory: "中束", equipmentType: "器械"),

        // MARK: 斜方肌
        .init(code: "SHRUG_BB", name: "杠铃耸肩", category: "斜方肌", equipmentType: "杠铃"),
        .init(code: "SHRUG_DB", name: "哑铃耸肩", category: "斜方肌", equipmentType: "哑铃"),

        // MARK: 二头
        .init(code: "BB_CURL", name: "杠铃弯举", category: "二头", equipmentType: "杠铃"),
        .init(code: "EZ_BAR_CURL", name: "EZ杠弯举", category: "二头", equipmentType: "杠铃"),
        .init(code: "DB_CURL", name: "哑铃弯举", category: "二头", equipmentType: "哑铃"),
        .init(code: "HAMMER_CURL", name: "锤式弯举", category: "二头", equipmentType: "哑铃"),
        .init(code: "INCLINE_DB_CURL", name: "上斜哑铃弯举", category: "二头", equipmentType: "哑铃"),
        .init(code: "CONCENTRATION_CURL", name: "集中弯举", category: "二头", equipmentType: "哑铃"),
        .init(code: "SPIDER_CURL", name: "蜘蛛弯举", category: "二头", equipmentType: "哑铃"),
        .init(code: "PREACHER_CURL", name: "牧师凳弯举", category: "二头", equipmentType: "杠铃"),
        .init(code: "CABLE_CURL", name: "绳索弯举", category: "二头", equipmentType: "绳索"),
        .init(code: "MACHINE_CURL", name: "器械弯举", category: "二头", equipmentType: "器械"),
        .init(code: "ZOTTMAN_CURL", name: "扎特曼弯举", category: "二头", equipmentType: "哑铃"),
        .init(code: "REVERSE_CURL", name: "反握弯举", category: "二头", equipmentType: "杠铃"),

        // MARK: 三头
        .init(code: "TRICEP_PUSHDOWN", name: "绳索下压", category: "三头", equipmentType: "绳索"),
        .init(code: "ROPE_PUSHDOWN", name: "绳柄下压", category: "三头", equipmentType: "绳索"),
        .init(code: "SKULL_CRUSHER", name: "仰卧臂屈伸", category: "三头", equipmentType: "杠铃"),
        .init(code: "CLOSE_GRIP_BENCH", name: "窄距卧推", category: "三头", equipmentType: "杠铃"),
        .init(code: "OVERHEAD_TRICEP_EXT", name: "哑铃过顶臂屈伸", category: "三头", equipmentType: "哑铃"),
        .init(code: "CABLE_OVERHEAD_EXT", name: "绳索过顶臂屈伸", category: "三头", equipmentType: "绳索"),
        .init(code: "TRICEP_KICKBACK", name: "哑铃臂屈伸后踢", category: "三头", equipmentType: "哑铃"),
        .init(code: "TRICEP_DIP", name: "双杠臂屈伸(三头)", category: "三头", equipmentType: "自重"),
        .init(code: "BENCH_DIP", name: "凳上臂屈伸", category: "三头", equipmentType: "自重"),
        .init(code: "MACHINE_TRICEP_EXT", name: "器械臂屈伸", category: "三头", equipmentType: "器械"),
        .init(code: "JM_PRESS", name: "JM推", category: "三头", equipmentType: "杠铃"),

        // MARK: 前臂
        .init(code: "WRIST_CURL", name: "腕弯举", category: "前臂", equipmentType: "杠铃"),
        .init(code: "REVERSE_WRIST_CURL", name: "反向腕弯举", category: "前臂", equipmentType: "杠铃"),

        // MARK: 腿
        .init(code: "BB_SQUAT", name: "杠铃深蹲", category: "腿", subcategory: "股四头", equipmentType: "杠铃"),
        .init(code: "FRONT_SQUAT", name: "颈前深蹲", category: "腿", subcategory: "股四头", equipmentType: "杠铃"),
        .init(code: "SMITH_SQUAT", name: "史密斯深蹲", category: "腿", subcategory: "股四头", equipmentType: "史密斯"),
        .init(code: "HACK_SQUAT", name: "哈克深蹲", category: "腿", subcategory: "股四头", equipmentType: "器械"),
        .init(code: "GOBLET_SQUAT", name: "高脚杯深蹲", category: "腿", subcategory: "股四头", equipmentType: "哑铃"),
        .init(code: "LEG_PRESS", name: "腿举", category: "腿", subcategory: "股四头", equipmentType: "器械"),
        .init(code: "LEG_EXTENSION", name: "腿屈伸", category: "腿", subcategory: "股四头", equipmentType: "器械"),
        .init(code: "BULGARIAN_SPLIT_SQUAT", name: "保加利亚分腿蹲", category: "腿", subcategory: "股四头", equipmentType: "哑铃"),
        .init(code: "LUNGE", name: "箭步蹲", category: "腿", subcategory: "股四头", equipmentType: "哑铃"),
        .init(code: "WALKING_LUNGE", name: "行走箭步蹲", category: "腿", subcategory: "股四头", equipmentType: "哑铃"),
        .init(code: "STEP_UP", name: "箱式登踏", category: "腿", subcategory: "股四头", equipmentType: "哑铃"),
        .init(code: "SISSY_SQUAT", name: "西西里深蹲", category: "腿", subcategory: "股四头", equipmentType: "自重"),
        .init(code: "PISTOL_SQUAT", name: "单腿深蹲", category: "腿", subcategory: "股四头", equipmentType: "自重"),
        .init(code: "LEG_CURL", name: "俯卧腿弯举", category: "腿", subcategory: "腘绳肌", equipmentType: "器械"),
        .init(code: "SEATED_LEG_CURL", name: "坐姿腿弯举", category: "腿", subcategory: "腘绳肌", equipmentType: "器械"),
        .init(code: "ROMANIAN_DL", name: "罗马尼亚硬拉", category: "腿", subcategory: "腘绳肌", equipmentType: "杠铃"),
        .init(code: "DB_RDL", name: "哑铃罗马尼亚硬拉", category: "腿", subcategory: "腘绳肌", equipmentType: "哑铃"),
        .init(code: "STIFF_LEG_DL", name: "直腿硬拉", category: "腿", subcategory: "腘绳肌", equipmentType: "杠铃"),
        .init(code: "NORDIC_CURL", name: "北欧挺", category: "腿", subcategory: "腘绳肌", equipmentType: "自重"),
        .init(code: "HIP_ADDUCTION", name: "髋内收", category: "腿", equipmentType: "器械"),
        .init(code: "BOX_SQUAT", name: "箱式深蹲", category: "腿", subcategory: "股四头", equipmentType: "杠铃"),
        .init(code: "GLUTE_HAM_RAISE", name: "臀腿挺", category: "腿", subcategory: "腘绳肌", equipmentType: "自重"),

        // MARK: 小腿
        .init(code: "STANDING_CALF_RAISE", name: "站姿提踵", category: "小腿", equipmentType: "器械"),
        .init(code: "SEATED_CALF_RAISE", name: "坐姿提踵", category: "小腿", equipmentType: "器械"),
        .init(code: "DB_CALF_RAISE", name: "哑铃提踵", category: "小腿", equipmentType: "哑铃"),
        .init(code: "DONKEY_CALF_RAISE", name: "驴式提踵", category: "小腿", equipmentType: "器械"),

        // MARK: 臀
        .init(code: "HIP_ABDUCTION", name: "髋外展", category: "臀", subcategory: "臀中肌", equipmentType: "器械"),
        .init(code: "HIP_THRUST", name: "杠铃臀冲", category: "臀", subcategory: "臀大肌", equipmentType: "杠铃"),
        .init(code: "BB_GLUTE_BRIDGE", name: "杠铃臀桥", category: "臀", subcategory: "臀大肌", equipmentType: "杠铃"),
        .init(code: "SINGLE_LEG_HIP_THRUST", name: "单腿臀冲", category: "臀", subcategory: "臀大肌", equipmentType: "自重"),
        .init(code: "CABLE_KICKBACK", name: "绳索后踢腿", category: "臀", subcategory: "臀大肌", equipmentType: "绳索"),
        .init(code: "GLUTE_KICKBACK_MACHINE", name: "器械后踢腿", category: "臀", subcategory: "臀大肌", equipmentType: "器械"),
        .init(code: "SUMO_DEADLIFT", name: "相扑硬拉", category: "臀", subcategory: "臀大肌", equipmentType: "杠铃"),
        .init(code: "SUMO_SQUAT", name: "相扑深蹲", category: "臀", subcategory: "臀大肌", equipmentType: "哑铃"),
        .init(code: "CURTSY_LUNGE", name: "屈膝礼箭步蹲", category: "臀", subcategory: "臀中肌", equipmentType: "哑铃"),
        .init(code: "FROG_PUMP", name: "蛙泵", category: "臀", subcategory: "臀大肌", equipmentType: "自重"),
        .init(code: "KETTLEBELL_SWING", name: "壶铃摆荡", category: "臀", subcategory: "臀大肌", equipmentType: "壶铃"),

        // MARK: 核心
        .init(code: "PLANK", name: "平板支撑", category: "核心", subcategory: "核心稳定", equipmentType: "自重"),
        .init(code: "SIDE_PLANK", name: "侧平板支撑", category: "核心", subcategory: "核心稳定", equipmentType: "自重"),
        .init(code: "HANGING_LEG_RAISE", name: "悬垂举腿", category: "核心", subcategory: "下腹", equipmentType: "自重"),
        .init(code: "HANGING_KNEE_RAISE", name: "悬垂提膝", category: "核心", subcategory: "下腹", equipmentType: "自重"),
        .init(code: "LEG_RAISE", name: "仰卧举腿", category: "核心", subcategory: "下腹", equipmentType: "自重"),
        .init(code: "CRUNCH", name: "卷腹", category: "核心", subcategory: "上腹", equipmentType: "自重"),
        .init(code: "CABLE_CRUNCH", name: "绳索卷腹", category: "核心", subcategory: "上腹", equipmentType: "绳索"),
        .init(code: "BICYCLE_CRUNCH", name: "单车卷腹", category: "核心", subcategory: "腹斜肌", equipmentType: "自重"),
        .init(code: "V_UP", name: "V字两头起", category: "核心", subcategory: "上腹", equipmentType: "自重"),
        .init(code: "RUSSIAN_TWIST", name: "俄罗斯转体", category: "核心", subcategory: "腹斜肌", equipmentType: "自重"),
        .init(code: "AB_WHEEL", name: "健腹轮", category: "核心", subcategory: "上腹", equipmentType: "自重"),
        .init(code: "MOUNTAIN_CLIMBER", name: "登山者", category: "核心", subcategory: "核心稳定", equipmentType: "自重"),
        .init(code: "DEAD_BUG", name: "死虫式", category: "核心", subcategory: "核心稳定", equipmentType: "自重"),
        .init(code: "WOODCHOPPER", name: "绳索伐木", category: "核心", subcategory: "腹斜肌", equipmentType: "绳索"),
        .init(code: "PALLOF_PRESS", name: "帕洛夫推", category: "核心", subcategory: "腹斜肌", equipmentType: "绳索"),
        .init(code: "TOE_TOUCH", name: "仰卧摸脚", category: "核心", subcategory: "上腹", equipmentType: "自重"),
        .init(code: "FLUTTER_KICK", name: "交替踢腿", category: "核心", subcategory: "下腹", equipmentType: "自重"),
        .init(code: "HOLLOW_HOLD", name: "空心支撑", category: "核心", subcategory: "核心稳定", equipmentType: "自重"),

        // MARK: 功能性
        .init(code: "POWER_CLEAN", name: "高翻", category: "功能性", equipmentType: "杠铃"),
        .init(code: "HANG_CLEAN", name: "悬垂翻", category: "功能性", equipmentType: "杠铃"),
        .init(code: "CLEAN_AND_JERK", name: "挺举", category: "功能性", equipmentType: "杠铃"),
        .init(code: "SNATCH", name: "抓举", category: "功能性", equipmentType: "杠铃"),
        .init(code: "THRUSTER", name: "推举深蹲", category: "功能性", equipmentType: "杠铃"),
        .init(code: "KB_CLEAN", name: "壶铃翻", category: "功能性", equipmentType: "壶铃"),
        .init(code: "KB_SNATCH", name: "壶铃抓举", category: "功能性", equipmentType: "壶铃"),
        .init(code: "TURKISH_GET_UP", name: "土耳其起立", category: "功能性", equipmentType: "壶铃"),
        .init(code: "BURPEE", name: "波比跳", category: "功能性", equipmentType: "自重"),
        .init(code: "FARMER_CARRY", name: "农夫行走", category: "功能性", equipmentType: "哑铃"),
    ]
}
