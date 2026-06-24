import Foundation
import Testing
@testable import DontLift

struct AppConfigTests {
    @Test func legalDocumentURLsAreDistinctHTTPSPages() {
        #expect(AppConfig.privacyPolicyURL.scheme == "https")
        #expect(AppConfig.termsOfServiceURL.scheme == "https")
        #expect(AppConfig.privacyPolicyURL != AppConfig.termsOfServiceURL)
        #expect(AppConfig.privacyPolicyURL.path == "/privacy")
        #expect(AppConfig.termsOfServiceURL.path == "/terms")
    }
}
