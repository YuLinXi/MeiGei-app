import Foundation
import Testing
@testable import DontLift

struct APIErrorPresentationTests {
    @Test(arguments: [400, 401, 403, 404, 409, 422, 429, 500, 503])
    func httpErrorsDoNotExposeRawBody(status: Int) {
        let body = "{\"detail\":\"private-diagnostic-marker\",\"type\":\"urn:internal\"}"
        let message = APIError.http(status: status, body: body).localizedDescription
        #expect(!message.contains("private-diagnostic-marker"))
        #expect(!message.contains("urn:internal"))
        #expect(!message.contains("{"))
        #expect(!message.isEmpty)
    }

    @Test func malformedBodyAndDecodeErrorsHaveActionableFallback() {
        let http = APIError.http(status: 502, body: "<html>private-diagnostic-marker</html>").localizedDescription
        let decoding = APIError.decoding(DecodingError.dataCorrupted(.init(
            codingPath: [], debugDescription: "private-diagnostic-marker"))).localizedDescription
        for message in [http, decoding] {
            #expect(!message.contains("private-diagnostic-marker"))
            #expect(message.contains("重试"))
        }
    }

    @Test func offlineErrorExplainsRecoveryWithoutUnprovenSaveClaim() {
        let message = APIError.transport(URLError(.notConnectedToInternet)).localizedDescription
        #expect(message.contains("网络"))
        #expect(message.contains("重试"))
        #expect(!message.contains("已保存"))
    }
}
