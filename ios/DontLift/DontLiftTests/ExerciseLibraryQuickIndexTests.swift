import CoreGraphics
import Testing
@testable import DontLift

struct ExerciseLibraryQuickIndexTests {
    @Test func mapsDragLocationToIndex() {
        let itemHeight: CGFloat = 28
        let spacing: CGFloat = 6

        #expect(LibraryQuickIndexHitTesting.itemIndex(at: 0, itemCount: 4, itemHeight: itemHeight, spacing: spacing) == 0)
        #expect(LibraryQuickIndexHitTesting.itemIndex(at: 27, itemCount: 4, itemHeight: itemHeight, spacing: spacing) == 0)
        #expect(LibraryQuickIndexHitTesting.itemIndex(at: 34, itemCount: 4, itemHeight: itemHeight, spacing: spacing) == 1)
        #expect(LibraryQuickIndexHitTesting.itemIndex(at: 68, itemCount: 4, itemHeight: itemHeight, spacing: spacing) == 2)
    }

    @Test func clampsDragLocationInsideIndexRange() {
        let itemHeight: CGFloat = 28
        let spacing: CGFloat = 6

        #expect(LibraryQuickIndexHitTesting.itemIndex(at: -20, itemCount: 4, itemHeight: itemHeight, spacing: spacing) == 0)
        #expect(LibraryQuickIndexHitTesting.itemIndex(at: 10_000, itemCount: 4, itemHeight: itemHeight, spacing: spacing) == 3)
    }

    @Test func invalidInputReturnsNil() {
        #expect(LibraryQuickIndexHitTesting.itemIndex(at: 0, itemCount: 0, itemHeight: 28, spacing: 6) == nil)
        #expect(LibraryQuickIndexHitTesting.itemIndex(at: 0, itemCount: 4, itemHeight: 0, spacing: 6) == nil)
        #expect(LibraryQuickIndexHitTesting.itemIndex(at: 0, itemCount: 4, itemHeight: 28, spacing: -1) == nil)
    }
}
