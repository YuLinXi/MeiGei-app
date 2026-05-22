import Foundation
import CryptoKit

/// 每个同步域的标识 + 端点路径段 + 本地下拉水位线（since）存取。
enum SyncDomain: String, CaseIterable {
    case customExercises = "custom-exercises"
    case workoutPlans = "workout-plans"
    case customFoods = "custom-foods"
    case workouts = "workouts"

    var pullPath: String { "/sync/\(rawValue)/pull" }
    var pushPath: String { "/sync/\(rawValue)/push" }

    private var watermarkKey: String { "sync.since.\(rawValue)" }

    /// 上次成功 pull 的服务端时间，作为下次增量 since。
    var since: Date? {
        get {
            guard let s = UserDefaults.standard.string(forKey: watermarkKey) else { return nil }
            return JSONCoding.date(from: s)
        }
        nonmutating set {
            if let newValue {
                UserDefaults.standard.set(JSONCoding.string(from: newValue), forKey: watermarkKey)
            } else {
                UserDefaults.standard.removeObject(forKey: watermarkKey)
            }
        }
    }

    static func resetAllWatermarks() {
        allCases.forEach { $0.since = nil }
    }
}

/// 由一批待上传项派生稳定幂等键：同一批重试得到同一键，服务端据此去重（D4）。
enum IdempotencyKey {
    static func forBatch(domain: SyncDomain, parts: [String]) -> String {
        let joined = domain.rawValue + "|" + parts.sorted().joined(separator: ",")
        let digest = SHA256.hash(data: Data(joined.utf8))
        return domain.rawValue + "-" + digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// 一次同步后收集的「本地修改被服务端覆盖」提示（D3，供 UI toast）。
struct ConflictNotice: Identifiable {
    let id: UUID
    let domain: SyncDomain
    let name: String
}
