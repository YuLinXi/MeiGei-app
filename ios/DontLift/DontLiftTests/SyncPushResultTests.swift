import Foundation
import Testing
@testable import DontLift

struct SyncPushResultTests {
    @Test func decodesLegacyPushResultWithoutTimestampAdjustments() throws {
        let id = UUID()
        let json = """
        {
          "applied": ["\(id.uuidString)"],
          "conflicts": [],
          "serverTime": "2026-06-24T07:00:00Z"
        }
        """

        let result = try JSONCoding.decoder.decode(
            SyncPushResult<CustomExerciseDTO>.self,
            from: Data(json.utf8)
        )

        #expect(result.applied == [id])
        #expect(result.conflicts.isEmpty)
        #expect(result.timestampAdjustments.isEmpty)
    }

    @Test func decodesTimestampAdjustmentNotice() throws {
        let id = UUID()
        let json = """
        {
          "applied": ["\(id.uuidString)"],
          "conflicts": [],
          "serverTime": "2026-06-24T07:00:00Z",
          "timestampAdjustments": [{
            "id": "\(id.uuidString)",
            "domain": "workouts",
            "originalUpdatedAt": "2026-06-26T07:00:00Z",
            "adjustedAt": "2026-06-24T07:00:00Z",
            "reason": "client_clock_ahead"
          }]
        }
        """

        let result = try JSONCoding.decoder.decode(
            SyncPushResult<CustomExerciseDTO>.self,
            from: Data(json.utf8)
        )

        let adjustment = try #require(result.timestampAdjustments.first)
        #expect(adjustment.id == id)
        #expect(adjustment.domain == "workouts")
        #expect(adjustment.originalUpdatedAt == JSONCoding.date(from: "2026-06-26T07:00:00Z"))
        #expect(adjustment.adjustedAt == result.serverTime)
        #expect(adjustment.reason == "client_clock_ahead")
    }
}
