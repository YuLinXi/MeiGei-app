import Foundation
import os.log

/// 网络层统一日志：可在 Xcode 控制台与 Console.app 按 subsystem/category=Network 过滤。
private let netLog = Logger(subsystem: "com.yulinxi.app.DontLift", category: "Network")

enum APIError: Error, LocalizedError {
    case unauthorized
    case http(status: Int, body: String)
    case transport(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "登录已失效，请重新登录。"
        case .http(let status, let body): return "请求失败（\(status)）：\(body)"
        case .transport(let e): return "网络异常：\(e.localizedDescription)"
        case .decoding(let e): return "数据解析失败：\(e.localizedDescription)"
        }
    }
}

/// 轻量 HTTP 客户端：注入 Bearer token、可选 Idempotency-Key、统一 JSON 编解码与错误映射。
actor APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    /// 请求自增序号，用于在并发日志里把同一请求的「发起/响应」多行关联起来。
    private var seq = 0
    /// 取当前 JWT；登录后由 SessionStore 注入。
    var tokenProvider: (@Sendable () -> String?)?

    init(baseURL: URL = AppConfig.apiBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func setTokenProvider(_ provider: @escaping @Sendable () -> String?) {
        self.tokenProvider = provider
    }

    /// 日志辅助：JSON 数据美化为紧凑可读字符串（失败回退原文），超长截断避免刷屏。
    private static func prettyJSON(_ data: Data, limit: Int = 1200) -> String {
        let text: String
        if let obj = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
           let s = String(data: pretty, encoding: .utf8) {
            text = s
        } else {
            text = String(data: data, encoding: .utf8) ?? "<\(data.count) 字节二进制>"
        }
        return text.count > limit ? String(text.prefix(limit)) + " …(截断)" : text
    }

    /// 有响应体的请求。
    func send<Response: Decodable>(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        idempotencyKey: String? = nil,
        authorized: Bool = true
    ) async throws -> Response {
        let data = try await raw(method, path, query: query, body: body,
                                 idempotencyKey: idempotencyKey, authorized: authorized)
        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }
        do {
            return try JSONCoding.decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// 无响应体的请求（返回 200/204）。
    @discardableResult
    func sendVoid(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        idempotencyKey: String? = nil,
        authorized: Bool = true
    ) async throws -> Data {
        try await raw(method, path, query: query, body: body,
                      idempotencyKey: idempotencyKey, authorized: authorized)
    }

    private func raw(
        _ method: String,
        _ path: String,
        query: [URLQueryItem],
        body: (any Encodable)?,
        idempotencyKey: String?,
        authorized: Bool
    ) async throws -> Data {
        var comps = URLComponents(url: baseURL.appformatPath(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if authorized, let token = tokenProvider?() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let idempotencyKey {
            req.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONCoding.encoder.encode(AnyEncodable(body))
        }

        // ── 请求发起日志：序号 + 方法 + endpoint + 鉴权/幂等标记（绝不输出 token 本身）。
        seq += 1
        let id = seq
        var endpoint = comps.path
        if let q = comps.query, !q.isEmpty { endpoint += "?\(q)" }
        let hasAuth = req.value(forHTTPHeaderField: "Authorization") != nil
        let tags = "auth=\(hasAuth ? "Y" : "N")\(idempotencyKey != nil ? " idem=Y" : "")"
        netLog.info("#\(id, privacy: .public) \(method, privacy: .public) \(endpoint, privacy: .public)  \(tags, privacy: .public)")
        #if DEBUG
        if let httpBody = req.httpBody, !httpBody.isEmpty {
            netLog.debug("   #\(id, privacy: .public) 入参 \(Self.prettyJSON(httpBody), privacy: .public)")
        }
        #endif

        let started = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            let ms = Int(Date().timeIntervalSince(started) * 1000)
            netLog.error("❌ #\(id, privacy: .public) \(method, privacy: .public) \(endpoint, privacy: .public) · ⏱\(ms, privacy: .public)ms · 网络异常：\(error.localizedDescription, privacy: .public)")
            throw APIError.transport(error)
        }

        let ms = Int(Date().timeIntervalSince(started) * 1000)
        guard let http = response as? HTTPURLResponse else {
            netLog.error("❌ #\(id, privacy: .public) \(method, privacy: .public) \(endpoint, privacy: .public) · ⏱\(ms, privacy: .public)ms · 无 HTTP 响应")
            throw APIError.http(status: -1, body: "无 HTTP 响应")
        }
        switch http.statusCode {
        case 200...299:
            netLog.info("✅ #\(id, privacy: .public) \(http.statusCode, privacy: .public) \(method, privacy: .public) \(endpoint, privacy: .public) · ⏱\(ms, privacy: .public)ms · \(data.count, privacy: .public)B")
            #if DEBUG
            if !data.isEmpty {
                netLog.debug("   #\(id, privacy: .public) 出参 \(Self.prettyJSON(data), privacy: .public)")
            }
            #endif
            return data
        case 401:
            netLog.error("❌ #\(id, privacy: .public) 401 \(method, privacy: .public) \(endpoint, privacy: .public) · ⏱\(ms, privacy: .public)ms · 登录失效")
            throw APIError.unauthorized
        default:
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            netLog.error("❌ #\(id, privacy: .public) \(http.statusCode, privacy: .public) \(method, privacy: .public) \(endpoint, privacy: .public) · ⏱\(ms, privacy: .public)ms")
            netLog.error("   #\(id, privacy: .public) 错误体 \(Self.prettyJSON(data), privacy: .public)")
            throw APIError.http(status: http.statusCode, body: bodyStr)
        }
    }
}

/// 空响应占位。
struct EmptyResponse: Decodable {}

/// 类型擦除编码，便于以 `any Encodable` 传 body。
private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ wrapped: any Encodable) {
        self.encodeFunc = wrapped.encode
    }
    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}

private extension URL {
    /// 拼接 path（path 以 "/" 开头）。
    func appformatPath(_ path: String) -> URL {
        appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path)
    }
}
