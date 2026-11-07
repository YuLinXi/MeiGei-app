import Foundation
import SwiftData
import Testing
@testable import DontLift

@Suite(.serialized)
@MainActor
struct SyncCrashRegressionTests {
    /// 1.1(5) 结束训练闪退回归：毫秒编码四舍五入后，刚推送的训练被原样拉回时「看起来更新」，
    /// 曾触发 replaceChildren 删除整棵子树，与后台勋章读取并发即 SwiftData 断言崩溃。
    @Test func echoedPushWithRoundedUpTimestampKeepsLocalChildren() async throws {
        try await withFixture { context, engine, _, _ in
            let workout = Workout(title: "同步回声回归")
            let exercise = WorkoutExercise(exerciseName: "卧推", orderIndex: 0)
            exercise.sets = [WorkoutSet(setIndex: 0, weightKg: 20, reps: 10, completed: true)]
            workout.exercises = [exercise]
            // .1236 编码为 .124，回传后比本地晚 0.4ms。
            workout.updatedAt = Date(timeIntervalSince1970: 1_790_000_000.1236)
            context.insert(workout)
            try context.save()
            let exerciseIds = workout.exercises.map(\.persistentModelID)
            let setIds = workout.exercises.flatMap(\.sets).map(\.persistentModelID)

            await engine.syncAll()

            #expect(workout.syncStatus == .synced)
            #expect(workout.exercises.map(\.persistentModelID) == exerciseIds)
            #expect(workout.exercises.flatMap(\.sets).map(\.persistentModelID) == setIds)
            #expect(try context.fetchCount(FetchDescriptor<WorkoutSet>()) == setIds.count)
        }
    }

    @Test func syncClockIgnoresSubMillisecondTransportRounding() throws {
        let local = Date(timeIntervalSince1970: 1_790_000_000.1236)
        let echoed = try #require(JSONCoding.date(from: JSONCoding.string(from: local)))
        #expect(echoed > local)
        #expect(!SyncClock.isNewer(echoed, than: local))
        #expect(SyncClock.isNewer(local.addingTimeInterval(0.002), than: local))
    }

    @Test func newLocalStorePullsHistoryInsteadOfReusingPreviousStoreWatermark() async throws {
        try await withHTTPFixture { api, server, defaults in
            let directory = try makeStoreDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            server.seedWorkout()
            let first = try makeStore(at: directory.appending(path: "first.store"))
            await SyncEngine(modelContext: first.mainContext, api: api, watermarkDefaults: defaults).syncAll()
            #expect(try first.mainContext.fetchCount(FetchDescriptor<Workout>()) == 1)
            #expect(SyncDomain.workouts.watermark(in: defaults) != nil)

            let replacement = try makeStore(at: directory.appending(path: "replacement.store"))
            await SyncEngine(modelContext: replacement.mainContext, api: api, watermarkDefaults: defaults).syncAll()

            #expect(try replacement.mainContext.fetchCount(FetchDescriptor<Workout>()) == 1)
            #expect(server.pullSinceValues(for: "workouts") == [nil, nil])
        }
    }

    @Test func sameLocalStoreKeepsIncrementalWatermarkAcrossEngineRestarts() async throws {
        try await withHTTPFixture { api, server, defaults in
            let directory = try makeStoreDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            server.seedWorkout()
            let store = try makeStore(at: directory.appending(path: "history.store"))
            await SyncEngine(modelContext: store.mainContext, api: api, watermarkDefaults: defaults).syncAll()
            await SyncEngine(modelContext: store.mainContext, api: api, watermarkDefaults: defaults).syncAll()

            #expect(try store.mainContext.fetchCount(FetchDescriptor<Workout>()) == 1)
            let requests = server.pullSinceValues(for: "workouts")
            try #require(requests.count == 2)
            #expect(requests[0] == nil)
            #expect(requests[1] != nil)
        }
    }

    @Test func legacyWatermarkWithoutStoreIdentityCannotSkipRestoringHistory() async throws {
        try await withHTTPFixture { api, server, defaults in
            let directory = try makeStoreDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            server.seedWorkout()
            for domain in SyncDomain.allCases { domain.setWatermark(.now, in: defaults) }
            let store = try makeStore(at: directory.appending(path: "empty.store"))

            await SyncEngine(modelContext: store.mainContext, api: api, watermarkDefaults: defaults).syncAll()

            #expect(try store.mainContext.fetchCount(FetchDescriptor<Workout>()) == 1)
            #expect(server.pullSinceValues(for: "workouts") == [nil])
        }
    }

    @Test func failedLocalSaveDoesNotAdvancePullWatermarks() async throws {
        try await withHTTPFixture { api, server, defaults in
            let directory = try makeStoreDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let url = directory.appending(path: "readonly.store")
            let writable = try makeStore(at: url)
            try writable.mainContext.save()
            server.seedWorkout()
            let readonly = try makeStore(at: url, allowsSave: false)

            await SyncEngine(modelContext: readonly.mainContext, api: api, watermarkDefaults: defaults).syncAll()

            for domain in SyncDomain.allCases { #expect(domain.watermark(in: defaults) == nil) }
            withExtendedLifetime(writable) {}
        }
    }

    private func makeStoreDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "SyncHistoryRegression-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeStore(at url: URL, allowsSave: Bool = true) throws -> ModelContainer {
        let config = ModelConfiguration(schema: AppModelContainer.schema, url: url,
                                        allowsSave: allowsSave, cloudKitDatabase: .none)
        return try ModelContainer(for: AppModelContainer.schema, configurations: [config])
    }

    private func withFixture(
        _ operation: (ModelContext, SyncEngine, APIClient, SyncCrashHTTPFixture) async throws -> Void) async throws {
        try await withHTTPFixture { api, server, defaults in
            let container = AppModelContainer.make(inMemory: true)
            let context = ModelContext(container)
            try await operation(context, SyncEngine(modelContext: context, api: api, watermarkDefaults: defaults), api, server)
            withExtendedLifetime(container) {}
        }
    }

    private func withHTTPFixture(
        _ operation: (APIClient, SyncCrashHTTPFixture, UserDefaults) async throws -> Void) async throws {
        let suite = "SyncCrashRegressionTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let host = UUID().uuidString.lowercased() + ".invalid"
        let server = SyncCrashHTTPFixture()
        SyncCrashHTTPRegistry.shared.register(server, host: host)
        defer { SyncCrashHTTPRegistry.shared.remove(host) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SyncCrashURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let api = APIClient(baseURL: try #require(URL(string: "https://" + host)), session: session)
        try await operation(api, server, defaults)
    }
}

nonisolated private final class SyncCrashHTTPFixture: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: [[String: Any]]] = [:]
    private var pullSince: [String: [String?]] = [:]

    func seedWorkout() {
        lock.lock()
        defer { lock.unlock() }
        items["workouts"] = [["workout": [
            "id": UUID().uuidString, "title": "待恢复历史", "version": 1,
            "startedAt": "2026-06-01T08:00:00.000Z",
            "endedAt": "2026-06-01T09:00:00.000Z",
            "updatedAt": "2026-06-01T09:00:00.000Z"
        ], "exercises": []]]
    }

    func pullSinceValues(for domain: String) -> [String?] {
        lock.lock()
        defer { lock.unlock() }
        return pullSince[domain] ?? []
    }

    func respond(_ request: URLRequest) throws -> (Int, Data) {
        lock.lock()
        defer { lock.unlock() }
        let path = request.url?.path ?? ""
        let body = Self.body(request)
        let domain = path.split(separator: "/").dropFirst().first.map(String.init) ?? ""
        let time = Date().ISO8601Format(.init(includingFractionalSeconds: true))
        if path.hasSuffix("/pull") {
            let since = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "since" }?.value
            pullSince[domain, default: []].append(since)
            let changes = (items[domain] ?? []).filter { item in
                guard let since else { return true }
                let root = item["workout"] as? [String: Any] ?? item
                return (root["updatedAt"] as? String).map { $0 > since } ?? false
            }
            return (200, try JSONSerialization.data(withJSONObject: ["changes": changes, "serverTime": time]))
        }
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let incoming = object?["items"] as? [[String: Any]] ?? []
        items[domain] = incoming
        let ids = incoming.compactMap { ($0["id"] ?? ($0["workout"] as? [String: Any])?["id"]) as? String }
        return (200, try JSONSerialization.data(withJSONObject: ["applied": ids, "conflicts": [], "serverTime": time]))
    }

    private static func body(_ request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
}

nonisolated private final class SyncCrashHTTPRegistry: @unchecked Sendable {
    static let shared = SyncCrashHTTPRegistry()
    private let lock = NSLock()
    private var fixtures: [String: SyncCrashHTTPFixture] = [:]
    func register(_ fixture: SyncCrashHTTPFixture, host: String) { lock.lock(); defer { lock.unlock() }; fixtures[host] = fixture }
    func remove(_ host: String) { lock.lock(); defer { lock.unlock() }; fixtures.removeValue(forKey: host) }
    func fixture(_ host: String) -> SyncCrashHTTPFixture? { lock.lock(); defer { lock.unlock() }; return fixtures[host] }
}

nonisolated private final class SyncCrashURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host.flatMap { SyncCrashHTTPRegistry.shared.fixture($0) } != nil
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let url = request.url, let host = url.host, let server = SyncCrashHTTPRegistry.shared.fixture(host),
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil) else { return }
            let (status, data) = try server.respond(request)
            let actual = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]) ?? response
            client?.urlProtocol(self, didReceive: actual, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}
