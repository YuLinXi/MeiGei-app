#if DEBUG
import Foundation
import SwiftData
import SwiftUI

extension UITestHooks {
    static var isSyncRecoveryUITest: Bool {
        isAutoLogin && (ProcessInfo.processInfo.arguments.contains("-uitest-sync-recovery") || isBulkSyncUITest)
    }

    nonisolated static var isBulkSyncUITest: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-dev-auto-login") && arguments.contains("-uitest-live-workout")
            && arguments.contains("-uitest-bulk-sync")
    }

    /// 仅为同步行交互提供隔离 HTTP fixture，不连接本地或线上服务器，也不改日常同步水位。
    @MainActor static func syncRecoveryEngine(context: ModelContext) -> SyncEngine {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UITestSyncURLProtocol.self]
        let api = APIClient(baseURL: URL(string: "https://sync-recovery.invalid")!,
                            session: URLSession(configuration: configuration))
        let suite = "dontlift.uitest.syncRecovery"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return SyncEngine(modelContext: context, api: api, watermarkDefaults: defaults)
    }
}

nonisolated private final class UITestSyncURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var hasFailedWorkouts = false
    private var pendingResponse: DispatchWorkItem?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "sync-recovery.invalid"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let isWorkout = request.url?.path.contains("/workouts/") == true
        let fail = Self.lock.withLock {
            if isWorkout && !UITestHooks.isBulkSyncUITest && !Self.hasFailedWorkouts {
                Self.hasFailedWorkouts = true
                return true
            }
            return false
        }
        let work = DispatchWorkItem { [weak self] in self?.respond(fail: fail) }
        pendingResponse = work
        DispatchQueue.global().asyncAfter(deadline: .now() + (fail ? 2 : 0.02), execute: work)
    }

    override func stopLoading() { pendingResponse?.cancel() }

    private func respond(fail: Bool) {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: fail ? 503 : 200,
                                             httpVersion: nil, headerFields: ["Content-Type": "application/json"]) else { return }
        do {
            let time = Date().ISO8601Format(.init(includingFractionalSeconds: true))
            let object: [String: Any]
            if fail { object = ["detail": "isolated UI fixture"] }
            else if url.path.hasSuffix("/pull") {
                let initialPull = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                    .contains(where: { $0.name == "since" }) != true
                let update = ProcessInfo.processInfo.arguments.contains("-uitest-bulk-sync-update") && !initialPull
                let changes = UITestHooks.isBulkSyncUITest && (initialPull || update) && url.path.contains("/workouts/")
                    ? Self.bulkWorkouts(updatedAt: update ? time : nil) : []
                object = ["changes": changes, "serverTime": time]
            }
            else {
                let body = try JSONSerialization.jsonObject(with: bodyData()) as? [String: Any]
                let items = body?["items"] as? [[String: Any]] ?? []
                let ids = items.compactMap { ($0["id"] ?? ($0["workout"] as? [String: Any])?["id"]) as? String }
                object = ["applied": ids, "conflicts": [], "serverTime": time]
            }
            let data = try JSONSerialization.data(withJSONObject: object)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }

    private static func bulkWorkouts(updatedAt: String?) -> [[String: Any]] {
        (0..<5000).map { index in
            // 固定测试身份让第二轮实际替换已有子树，避免变成又一次新增。
            let workoutId = String(format: "10000000-0000-4000-8000-%012d", index)
            let exercises: [[String: Any]] = (0..<6).map { order in
                let exerciseId = String(format: "20000000-0000-4000-8000-%012d", index * 6 + order)
                return ["exercise": ["id": exerciseId, "workoutId": workoutId,
                    "builtinExerciseCode": "BB_BENCH_PRESS", "exerciseName": "杠铃卧推", "orderIndex": order],
                    "sets": (0..<4).map { set in
                        ["id": String(format: "30000000-0000-4000-8000-%012d", index * 24 + order * 4 + set),
                         "workoutExerciseId": exerciseId, "setIndex": set,
                         "weightKg": 60, "reps": updatedAt == nil ? 10 : 11, "completed": true,
                         "plannedRestSeconds": 90, "actualRestSeconds": 60] as [String: Any]
                    }]
            }
            return ["workout": ["id": workoutId, "title": "UI 同步历史 \(index)", "version": updatedAt == nil ? 1 : 2,
                "startedAt": "2026-06-01T08:00:00.000Z", "endedAt": "2026-06-01T09:00:00.000Z",
                "updatedAt": updatedAt ?? "2026-06-01T09:00:00.000Z"], "exercises": exercises]
        }
    }

    private func bodyData() -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data("{}".utf8) }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
}

/// 仅在本场景显示进度；独立 context 读回实际落盘输入，不把同一对象的内存值当保存证据。
struct UITestBulkSyncProgress: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncEngine.self) private var engine
    @Environment(RestTimerController.self) private var restTimer
    @State private var snapshot = "count:0"

    var body: some View {
        Text("同步测试")
            .font(Theme.Font.l5)
            .foregroundStyle(Theme.Color.fg)
            .padding(Theme.Spacing.xs)
            .background(Theme.Color.surface)
            .accessibilityIdentifier("uitest.sync.progress")
            .accessibilityValue("\(engine.isSyncing ? "busy" : "idle")|\(snapshot)|restEnd:\(restTimer.endDate?.timeIntervalSince1970 ?? 0)")
            .allowsHitTesting(false)
            .task {
                let activeId = WorkoutSession.activeSession(in: context)?.localId
                while !Task.isCancelled {
                    let reader = ModelContext(context.container)
                    let count = (try? reader.fetchCount(FetchDescriptor<Workout>())) ?? -1
                    let updated = (try? reader.fetchCount(FetchDescriptor<Workout>(
                        predicate: #Predicate { $0.version == 2 && $0.endedAt != nil }))) ?? -1
                    snapshot = "count:\(count)|updated:\(updated)"
                    if let activeId {
                        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.localId == activeId })
                        if let active = try? reader.fetch(descriptor).first,
                           let set = active.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }).first?
                            .sets.sorted(by: { $0.setIndex < $1.setIndex }).first {
                            snapshot += "|active:\(active.localId)|set:\(set.localId)"
                            snapshot += "|weight:\(set.weightKg ?? 0)|completed:\(set.completed)"
                        }
                    }
                    try? await Task.sleep(for: .milliseconds(250))
                }
            }
    }
}
#endif
