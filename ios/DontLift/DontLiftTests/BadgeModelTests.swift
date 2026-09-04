import Foundation
import SwiftData
import Testing
@testable import DontLift

struct BadgeModelTests {

    @Test func badgeDefinitionHasExactly24UniqueBadgesAcrossFourCategories() {
        let all = BadgeDefinition.all
        #expect(all.count == 24)

        let uniqueCodes = Set(all.map(\.code))
        #expect(uniqueCodes.count == 24)

        let strength = BadgeDefinition.badges(in: .strength)
        let tonnage = BadgeDefinition.badges(in: .tonnage)
        let career = BadgeDefinition.badges(in: .career)
        let feats = BadgeDefinition.badges(in: .feats)

        #expect(strength.count == 9)
        #expect(tonnage.count == 5)
        #expect(career.count == 5)
        #expect(feats.count == 5)

        // 验证查找能力
        let bench1 = BadgeDefinition.lookup("strength_bw_bench_1_0")
        #expect(bench1 != nil)
        #expect(bench1?.name == "破阵")
        #expect(bench1?.targetValue == 1.0)
    }

    @Test @MainActor func badgeGrantPersistenceAndLookup() throws {
        let container = AppModelContainer.make(inMemory: true)
        let context = container.mainContext

        let workoutId = UUID()
        let grant = BadgeGrant(
            badgeCode: "tonnage_100t",
            unlockedAt: .now,
            workoutId: workoutId,
            snapshotMetric: 104_500
        )
        context.insert(grant)
        try context.save()

        var descriptor = FetchDescriptor<BadgeGrant>(predicate: #Predicate { $0.badgeCode == "tonnage_100t" })
        descriptor.fetchLimit = 1
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        let item = try #require(fetched.first)
        #expect(item.badgeCode == "tonnage_100t")
        #expect(item.workoutId == workoutId)
        #expect(item.snapshotMetric == 104_500)
        #expect(item.definition?.name == "巨阙")
    }
}
