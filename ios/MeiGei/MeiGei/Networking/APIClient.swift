import Foundation

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
    /// 取当前 JWT；登录后由 SessionStore 注入。
    var tokenProvider: (@Sendable () -> String?)?

    init(baseURL: URL = AppConfig.apiBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func setTokenProvider(_ provider: @escaping @Sendable () -> String?) {
        self.tokenProvider = provider
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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.http(status: -1, body: "无 HTTP 响应")
        }
        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.http(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
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
