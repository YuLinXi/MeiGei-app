import Foundation

/// 动作库搜索：极简中文模糊匹配（多关键词 AND）。
/// 只做两件事——① 中文子串 `localizedCaseInsensitiveContains`；② query 按空格（含全角）拆词，
/// 名称需包含**全部**关键词（顺序无关、大小写不敏感）方为命中。
/// 明确不做：拼音 / 相关度排序 / debounce / 预建索引。
enum ExerciseSearch {
    /// 把 query 拆成关键词（半角/全角空格分隔，去空段）。
    static func tokens(_ query: String) -> [String] {
        query.trimmingCharacters(in: .whitespaces)
            .split(whereSeparator: { $0 == " " || $0 == "\u{3000}" })
            .map(String.init)
    }

    /// name 是否命中 query（空 query 恒命中；多词需全部包含）。
    static func matches(_ name: String, query: String) -> Bool {
        let t = tokens(query)
        if t.isEmpty { return true }
        return t.allSatisfy { name.localizedCaseInsensitiveContains($0) }
    }

    /// 内置动作搜索额外匹配别名和 legacy code；命中后仍展示标准动作。
    static func matches(_ exercise: BuiltinExercise, query: String) -> Bool {
        ExerciseLibrary.matches(exercise, query: query)
    }
}
