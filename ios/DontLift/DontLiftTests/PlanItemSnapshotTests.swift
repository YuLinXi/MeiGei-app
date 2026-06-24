import Foundation
import Testing
@testable import DontLift

@MainActor
struct PlanItemSnapshotTests {
    @Test func encodesExerciseSnapshotFields() throws {
        let item = PlanItem(
            builtinExerciseCode: "FUTURE_BUILTIN",
            exerciseName: "未来动作",
            primaryMuscle: "背",
            equipmentType: "器械",
            orderIndex: 0,
            suggestedSets: 3,
            suggestedReps: 10
        )

        let data = try JSONCoding.encoder.encode([item])
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let encoded = try #require(object.first)

        #expect(encoded["exerciseName"] as? String == "未来动作")
        #expect(encoded["primaryMuscle"] as? String == "背")
        #expect(encoded["equipmentType"] as? String == "器械")
    }

    @Test func unknownBuiltinUsesSnapshotName() throws {
        let json = """
        [{
          "itemId": "\(UUID().uuidString)",
          "builtinExerciseCode": "FUTURE_BUILTIN",
          "exerciseName": "新版动作",
          "primaryMuscle": "胸",
          "equipmentType": "哑铃",
          "orderIndex": 0,
          "suggestedSets": 4,
          "suggestedReps": 8
        }]
        """

        let items = try JSONCoding.decoder.decode([PlanItem].self, from: Data(json.utf8))

        #expect(items.first?.displayExerciseName == "新版动作")
        #expect(items.first?.resolvedPrimaryMuscle == "胸")
        #expect(items.first?.resolvedEquipmentType == "哑铃")
        #expect(PlanItem.unstartableItems(in: items).isEmpty)
    }

    @Test func missingSnapshotBlocksStart() {
        let item = PlanItem(
            builtinExerciseCode: "FUTURE_BUILTIN",
            exerciseName: "   ",
            orderIndex: 0,
            suggestedSets: 3,
            suggestedReps: 10
        )

        let broken = PlanItem.unstartableItems(in: [item])

        #expect(broken.map(\.builtinExerciseCode) == ["FUTURE_BUILTIN"])
        #expect(PlanItem.unstartableMessage(for: broken).contains("FUTURE_BUILTIN"))
    }
}
