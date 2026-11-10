import Foundation
import CryptoKit

/// 每个同步域的标识 + 端点路径段 + 本地下拉水位线（since）存取。
enum SyncDomain: String, CaseIterable {
    case customExercises = "custom-exercises"
    case workoutPlanGroups = "workout-plan-groups"
    case workoutPlans = "workout-plans"
    case workouts = "workouts"

    var pullPath: String { "/sync/\(rawValue)/pull" }
    var pushPath: String { "/sync/\(rawValue)/push" }

    private var watermarkKey: String { "sync.since.\(rawValue)" }

    /// 上次成功 pull 的服务端时间，作为下次增量 since。
    var since: Date? {
        get { watermark(in: .standard) }
        nonmutating set { setWatermark(newValue, in: .standard) }
    }

    func watermark(in defaults: UserDefaults) -> Date? {
        guard let value = defaults.string(forKey: watermarkKey) else { return nil }
        return JSONCoding.date(from: value)
    }

    func setWatermark(_ value: Date?, in defaults: UserDefaults) {
        if let value {
            defaults.set(JSONCoding.string(from: value), forKey: watermarkKey)
        } else {
            defaults.removeObject(forKey: watermarkKey)
        }
    }

    static func resetAllWatermarks(in defaults: UserDefaults = .standard) {
        allCases.forEach { $0.setWatermark(nil, in: defaults) }
    }

    /// 增量水位只对产生它的本地库有效；新库／重建库必须先全量拉取，不能沿用偏好中的旧水位。
    static func prepareWatermarks(for storeIdentity: String, in defaults: UserDefaults) {
        let key = "sync.local-store-identity"
        guard defaults.string(forKey: key) != storeIdentity else { return }
        allCases.forEach { $0.setWatermark(nil, in: defaults) }
        defaults.set(storeIdentity, forKey: key)
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
