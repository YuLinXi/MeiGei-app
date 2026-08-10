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

    @Test func restDefaultRoundTripsAndLegacyDefaultsToGlobal() throws {
        let configured = PlanItem(exerciseName: "卧推", orderIndex: 0, restAfterSetSeconds: 120)
        let disabled = PlanItem(exerciseName: "划船", orderIndex: 1, restAfterSetSeconds: 0)

        let data = try JSONCoding.encoder.encode([configured, disabled])
        let decoded = try JSONCoding.decoder.decode([PlanItem].self, from: data)

        #expect(decoded.map(\.restAfterSetSeconds) == [120, 0])
        #expect(try JSONCoding.decoder.decode([PlanItem].self, from: Data("""
        [{"itemId":"\(UUID().uuidString)","exerciseName":"深蹲","orderIndex":0}]
        """.utf8)).first?.restAfterSetSeconds == nil)
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
        #expect(items.first?.restAfterSetSeconds == nil)
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

    @Test func missingWarmupFlagDecodesAsFormalPrescription() throws {
        let json = """
        [{
          "itemId": "\(UUID().uuidString)",
          "builtinExerciseCode": "BB_BENCH",
          "exerciseName": "卧推",
          "orderIndex": 0,
          "suggestedSets": 1,
          "suggestedReps": 8,
          "setPrescriptions": [{
            "prescriptionId": "\(UUID().uuidString)",
            "setTypeRaw": "working",
            "orderIndex": 0,
            "weightKg": 60,
            "reps": 8,
            "segments": []
          }]
        }]
        """

        let item = try #require(JSONCoding.decoder.decode([PlanItem].self, from: Data(json.utf8)).first)

        #expect(item.warmupSetPrescriptions.isEmpty)
        #expect(item.formalSetPrescriptions.count == 1)
        #expect(item.formalSetCount == 1)
    }
}
