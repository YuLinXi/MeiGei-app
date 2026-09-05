import Foundation
import SwiftUI
import SwiftData
import Testing
@testable import DontLift

struct BadgeModelTests {

    @Test @MainActor func diagonalFillRetainsVisibleUnfilledAreaForEveryShape() {
        let rect = CGRect(x: 0, y: 0, width: 64, height: 64)
        let shapes: [(BadgeShapeKind, Path)] = [
            (.circle, Circle().path(in: rect)), (.octagon, OctagonShape().path(in: rect)),
            (.hexagon, HexagonShape().path(in: rect)), (.diamond, DiamondShape().path(in: rect))
        ]
        for (kind, shape) in shapes {
            let capped = BadgeDiagonalFill(progress: 0.94, kind: kind).path(in: rect)
            #expect(capped == BadgeDiagonalFill(progress: 0.9999, kind: kind).path(in: rect))
            #expect(capped == BadgeDiagonalFill(progress: 1, kind: kind).path(in: rect))
            var total = 0
            var unfilled = 0
            for y in 0..<128 {
                for x in 0..<128 {
                    let point = CGPoint(x: (Double(x) + 0.5) / 2, y: (Double(y) + 0.5) / 2)
                    if shape.contains(point) {
                        total += 1
                        if !capped.contains(point) { unfilled += 1 }
                    }
                }
            }
            let ratio = Double(unfilled) / Double(total)
            #expect(ratio >= 0.055 && ratio <= 0.075)
            #expect(BadgeDiagonalFill(progress: 0, kind: kind).path(in: rect).isEmpty)
        }
    }

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
