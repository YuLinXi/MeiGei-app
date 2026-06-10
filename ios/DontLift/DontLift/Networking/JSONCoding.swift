import Foundation

/// 与后端（Spring + Jackson JavaTimeModule）对齐的 JSON 编解码。
/// 时间统一 ISO-8601；解码兼容「带/不带小数秒」「Z/数字偏移」多种形态。
enum JSONCoding {

    /// 后端写时间为带偏移的 ISO-8601；编码统一用 UTC + `Z`（避免 `+` 在 query/body 边界出问题）。
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func string(from date: Date) -> String {
        isoFractional.string(from: date)
    }

    static func date(from string: String) -> Date? {
        isoFractional.date(from: string) ?? isoPlain.date(from: string)
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(string(from: date))
        }
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            guard let date = date(from: s) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "无法解析时间: \(s)")
            }
            return date
        }
        return d
    }()
}
