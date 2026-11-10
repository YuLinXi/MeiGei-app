#if DEBUG
import Foundation
import Observation

extension UITestHooks {
    static var isTeamReadabilityUITest: Bool {
        isAutoLogin && (ProcessInfo.processInfo.arguments.contains("-uitest-team-readability") || isTeamSharingUITest)
    }

    static var isTeamSharingUITest: Bool {
        isAutoLogin && ProcessInfo.processInfo.arguments.contains("-uitest-team-sharing")
    }

    /// 仅隔离 Team 界面测试，所有请求由本进程响应，不连接真实服务器。
    @MainActor static func teamReadabilityService(userId: UUID) -> TeamService {
        UITestTeamURLProtocol.configure(userId: userId)
        UITestTeamSharingAudit.shared.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UITestTeamURLProtocol.self]
        return TeamService(api: APIClient(baseURL: URL(string: "https://team-readability.invalid")!,
                                          session: URLSession(configuration: configuration)))
    }
}

/// 仅隔离分享场景显示，记录替身实际收到的写请求与已分享目标。
@MainActor @Observable
final class UITestTeamSharingAudit {
    static let shared = UITestTeamSharingAudit()
    private var revision = -1
    var value = ""

    func reset() { revision = -1; value = "" }
    func update(revision: Int, value: String) {
        guard revision >= self.revision else { return }
        self.revision = revision
        self.value = value
    }
}

nonisolated private final class UITestTeamURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static let teamId = "A1000000-0000-0000-0000-000000000001"
    private static let teammateId = "A1000000-0000-0000-0000-000000000002"
    private static let checkinId = "A1000000-0000-0000-0000-000000000003"
    private static var userId = ""
    private static var hasTeam = true
    private static var failedWrites: Set<String> = []
    private static var autoShare = false
    private static var notifications = true
    private static var myReaction: String?
    private static var sharingFixture = false
    private static var revision = 0
    private static var shareWrites = 0
    private static var deleteWrites = 0
    private static var preferenceWrites = 0
    private static var otherWrites = 0
    private static var lastShareTargets: [String] = []
    private static var sharedTeamIds: Set<String> = []
    private static var listReads = 0
    private static var historyReads: [String: Int] = [:]
    private var pendingResponse: DispatchWorkItem?

    static func configure(userId: UUID) {
        lock.withLock {
            self.userId = userId.uuidString
            hasTeam = !ProcessInfo.processInfo.arguments.contains("-uitest-team-empty")
            failedWrites = []
            autoShare = false
            notifications = true
            myReaction = nil
            sharingFixture = ProcessInfo.processInfo.arguments.contains("-uitest-team-sharing")
            if sharingFixture { autoShare = true }
            revision = 0
            shareWrites = 0; deleteWrites = 0; preferenceWrites = 0; otherWrites = 0
            lastShareTargets = []
            sharedTeamIds = ProcessInfo.processInfo.arguments.contains("-uitest-team-already-shared") ? [teamId] : []
            listReads = 0
            historyReads = [:]
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {
        pendingResponse?.cancel()
    }

    override func startLoading() {
        guard let url = request.url else { return }
        let (status, object, revision, audit, delay) = Self.lock.withLock {
            let result = Self.response(for: request, body: bodyData())
            Self.revision += 1
            let audit = Self.sharingFixture
                ? "share=\(Self.shareWrites);delete=\(Self.deleteWrites);preferences=\(Self.preferenceWrites);other=\(Self.otherWrites);targets=\(Self.lastShareTargets.joined(separator: ","));existing=\(Self.sharedTeamIds.sorted().joined(separator: ","))"
                : nil
            let slowList = request.httpMethod == "GET" && url.path == "/teams"
                && ProcessInfo.processInfo.arguments.contains("-uitest-team-list-slow") && Self.listReads == 1
            let month = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "month" })?.value ?? ""
            let flags = ProcessInfo.processInfo.arguments
            let slowHistory = url.path.hasSuffix("/checkins/history") && month == Self.currentMonthKey
                && Self.historyReads[month] == 1
                && (flags.contains("-uitest-team-history-slow") || flags.contains("-uitest-team-history-race"))
            return (result.0, result.1, Self.revision, audit, slowList ? 12.0 : (slowHistory ? 10.0 : 0.0))
        }
        if let audit {
            Task { @MainActor in UITestTeamSharingAudit.shared.update(revision: revision, value: audit) }
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if status == NSURLErrorNotConnectedToInternet {
                client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
                return
            }
            guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil,
                                                 headerFields: ["Content-Type": "application/json"]),
                  let data = try? JSONSerialization.data(withJSONObject: object) else { return }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
        pendingResponse = work
        if delay == 0 { work.perform() }
        else { DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: work) }
    }

    private static func response(for request: URLRequest, body: Data) -> (Int, Any) {
        let path = request.url?.path ?? ""
        let method = request.httpMethod ?? "GET"
        if ProcessInfo.processInfo.arguments.contains("-uitest-finish-flow"),
           method == "POST", path == "/checkins" {
            return (NSURLErrorNotConnectedToInternet, [:] as [String: Any])
        }
        if method == "GET", path == "/teams" {
            listReads += 1
            let flags = ProcessInfo.processInfo.arguments
            if (flags.contains("-uitest-team-list-offline-once") && listReads == 1)
                || (flags.contains("-uitest-team-list-refresh-failure") && listReads == 2) {
                return (NSURLErrorNotConnectedToInternet, [:] as [String: Any])
            }
        }
        let payload = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
        let now = Date().ISO8601Format(.init(includingFractionalSeconds: true))
        if sharingFixture, !["GET", "HEAD"].contains(method) {
            if method == "POST", path == "/checkins" { shareWrites += 1 }
            else if method == "DELETE" { deleteWrites += 1 }
            else if method == "PATCH", path.hasSuffix("preferences") { preferenceWrites += 1 }
            else { otherWrites += 1 }
        }
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let today = dayFormatter.string(from: .now)
        let historyFixture = ProcessInfo.processInfo.arguments.contains("-uitest-team-history-loading")
        let createdAt = historyFixture
            ? Calendar.current.date(byAdding: .month, value: -6, to: .now)!.ISO8601Format(.init(includingFractionalSeconds: true))
            : now
        let team: [String: Any] = ["id": teamId, "name": "UI 大字 Team · 长期力量与稳定控制",
                                   "ownerUserId": userId, "inviteCode": "ABC123", "createdAt": createdAt]
        if sharingFixture, method == "GET", path == "/teams" {
            if ProcessInfo.processInfo.arguments.contains("-uitest-team-share-load-failure"),
               failedWrites.insert("GET:/teams").inserted { return (503, ["detail": "隔离首次读取失败"]) }
            var second = team
            second["id"] = "A1000000-0000-0000-0000-000000000004"
            second["name"] = "UI 目标 Team B · 独立分享与稳定控制"
            return (200, hasTeam ? [team, second] : [])
        }
        if sharingFixture, method == "POST", path == "/checkins" {
            lastShareTargets = (payload["teamIds"] as? [String] ?? []).map { $0.uppercased() }.sorted()
            sharedTeamIds.formUnion(lastShareTargets)
            let summaryData = try! JSONSerialization.data(withJSONObject: payload["summary"] ?? [:])
            let summary = String(data: summaryData, encoding: .utf8)!
            return (200, lastShareTargets.map { id in
                ["id": id, "teamId": id, "userId": userId,
                 "workoutId": payload["workoutId"] as? String ?? checkinId,
                 "checkinDate": today, "summary": summary, "createdAt": now]
            })
        }
        func member(_ id: String, name: String, role: String) -> [String: Any] {
            ["id": id, "teamId": teamId, "userId": id, "role": role,
             "displayName": name, "autoShareWorkouts": autoShare]
        }
        let me = member(userId, name: "测试用户", role: "owner")
        let teammate = member(teammateId, name: "UI 长名称训练搭子 · 胸背力量复盘", role: "member")
        let nudge: [String: Any] = ["date": today, "nudgedRecipientUserIds": [],
                                    "receivableRecipientUserIds": [teammateId],
                                    "receiveTeamNotifications": notifications]
        let reactions: [[String: Any]] = myReaction.map {
            [["id": checkinId, "checkinId": checkinId, "userId": userId, "emoji": $0]]
        } ?? []
        if method == "POST", path.hasSuffix("/reactions") {
            let next = payload["emoji"] as? String
            myReaction = myReaction == next ? nil : next
            return (200, [:] as [String: Any])
        }
        if method == "GET", path.hasSuffix("/reactions") { return (200, reactions) }
        if method == "POST", path == "/teams" || path == "/teams/join" {
            if failedWrites.insert(path).inserted { return (503, ["detail": "隔离响应：稍后重试"]) }
            hasTeam = true
            return (200, team)
        }
        if method == "PATCH", path.hasSuffix("/share-preferences") {
            autoShare = payload["autoShareWorkouts"] as? Bool ?? autoShare
            return (200, member(userId, name: "测试用户", role: "owner"))
        }
        if method == "PATCH", path.hasSuffix("/notification-preferences") {
            notifications = payload["receiveTeamNotifications"] as? Bool ?? notifications
            return (200, ["date": today, "nudgedRecipientUserIds": [],
                          "receivableRecipientUserIds": [teammateId], "receiveTeamNotifications": notifications])
        }
        if method == "GET", path == "/teams" { return (200, hasTeam ? [team] : []) }
        if method == "GET", path.hasSuffix("/members") { return (200, [me, teammate]) }
        if method == "GET", path.hasSuffix("/share-preferences") { return (200, [me]) }
        if method == "GET", path.hasSuffix("/nudges/today") { return (200, nudge) }
        if historyFixture, method == "GET", path.hasSuffix("/checkins/history") {
            let month = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "month" })?.value ?? currentMonthKey
            historyReads[month, default: 0] += 1
            let flags = ProcessInfo.processInfo.arguments
            if (flags.contains("-uitest-team-history-offline-once") && historyReads[month] == 1)
                || (flags.contains("-uitest-team-history-refresh-failure") && historyReads[month] == 2) {
                return (NSURLErrorNotConnectedToInternet, [:] as [String: Any])
            }
            if flags.contains("-uitest-team-history-empty") {
                return (200, ["checkins": [], "reactions": []] as [String: Any])
            }
            let date = month == currentMonthKey ? today : month + "-01"
            let count = month == currentMonthKey ? 1 : 2
            let checkins = (0..<count).map { index -> [String: Any] in
                let id = "A2000000-0000-0000-0000-" + month.replacingOccurrences(of: "-", with: "") + "00000\(index)"
                let summary: [String: Any] = ["title": "UI 月份 \(month) Team 训练 \(index + 1)",
                    "startedAt": now, "endedAt": now, "exerciseCount": 1, "totalSets": 2, "totalVolumeKg": 960,
                    "exercises": [["name": "杠铃卧推", "builtinExerciseCode": "BB_BENCH_PRESS",
                                   "sets": [["weightKg": 60, "reps": 8], ["weightKg": 60, "reps": 8]]]]]
                let encoded = String(data: try! JSONSerialization.data(withJSONObject: summary), encoding: .utf8)!
                return ["id": id, "teamId": teamId, "userId": teammateId, "workoutId": id,
                        "checkinDate": date, "summary": encoded, "createdAt": now]
            }
            return (200, ["checkins": checkins, "reactions": []] as [String: Any])
        }
        if method == "GET", path.hasSuffix("/checkins/feed") || path.hasSuffix("/checkins/history") {
            let summary: [String: Any] = ["title": "UI 队友历史训练 · 胸背力量与稳定控制复盘",
                "startedAt": now, "endedAt": now, "exerciseCount": 1, "totalSets": 2, "totalVolumeKg": 960,
                "exercises": [["name": "杠铃卧推", "builtinExerciseCode": "BB_BENCH_PRESS",
                               "sets": [["weightKg": 60, "reps": 8], ["weightKg": 40, "reps": 12]]]]]
            let summaryString = String(data: try! JSONSerialization.data(withJSONObject: summary), encoding: .utf8)!
            return (200, ["checkins": [["id": checkinId, "teamId": teamId, "userId": teammateId,
                                       "workoutId": checkinId, "checkinDate": today,
                                       "summary": summaryString, "createdAt": now]], "reactions": reactions])
        }
        if method == "GET", path.hasSuffix("/plan-shares") {
            let items: [[String: Any]] = [["itemId": checkinId, "builtinExerciseCode": "BB_BENCH_PRESS",
                "exerciseName": "杠铃卧推", "orderIndex": 0, "suggestedSets": 3, "suggestedReps": 8]]
            let itemsString = String(data: try! JSONSerialization.data(withJSONObject: items), encoding: .utf8)!
            return (200, [["shareId": checkinId, "versionId": checkinId, "teamId": teamId,
                "ownerUserId": teammateId, "ownerName": "UI 长名称训练搭子 · 胸背力量复盘",
                "title": "UI Team 计划", "planNameSnapshot": "UI Team 计划 · 胸背力量与稳定控制逐组安排",
                "items": itemsString, "createdAt": now, "copyCount": 128, "completionCount": 1234]])
        }
        return (404, ["detail": "未配置的隔离 Team 请求"])
    }

    private static var currentMonthKey: String {
        let parts = Calendar.current.dateComponents([.year, .month], from: .now)
        return String(format: "%04d-%02d", parts.year!, parts.month!)
    }

    private func bodyData() -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 2048)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
}
#endif
