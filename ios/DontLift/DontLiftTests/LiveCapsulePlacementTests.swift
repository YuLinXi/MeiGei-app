import CoreGraphics
import Testing
@testable import DontLift

struct LiveCapsulePlacementTests {
    @Test func defaultUsesMeasuredActionTopWithGap() {
        let action = CGRect(x: 16, y: 680, width: 370, height: 64)
        let size = CGSize(width: 120, height: 60)
        let point = LiveCapsulePlacement.origin(preferred: nil, size: size,
            available: CGRect(x: 0, y: 0, width: 402, height: 800), exclusions: [action])
        #expect(point == CGPoint(x: 14, y: 612))
        #expect(CGRect(origin: point, size: size).maxY + 8 == action.minY)
    }

    @Test func defaultWithoutActionUsesViewportBottom() {
        let point = LiveCapsulePlacement.origin(preferred: nil, size: CGSize(width: 120, height: 60),
            available: CGRect(x: 0, y: 62, width: 402, height: 700), exclusions: [])
        #expect(point == CGPoint(x: 14, y: 694))
    }

    @Test(arguments: [CGSize(width: 76, height: 44), CGSize(width: 155, height: 86)])
    func dragAndSnapAvoidActionsAcrossViewports(_ size: CGSize) {
        for available in [CGRect(x: 0, y: 62, width: 320, height: 430),
                          CGRect(x: 0, y: 62, width: 402, height: 710),
                          CGRect(x: 20, y: 24, width: 728, height: 920)] {
            let action = CGRect(x: available.minX + 16, y: available.maxY - 160,
                                width: available.width - 32, height: 140)
            let add = CGRect(x: available.maxX - 64, y: available.minY + 170, width: 48, height: 48)
            for preferred in [CGPoint(x: -100, y: -100), CGPoint(x: 2000, y: 2000),
                              CGPoint(x: available.midX, y: action.midY),
                              CGPoint(x: add.minX, y: add.minY)] {
                for snapping in [false, true] {
                    let point = LiveCapsulePlacement.origin(preferred: preferred, size: size, available: available,
                                                           exclusions: [action, add], snapping: snapping)
                    let frame = CGRect(origin: point, size: size)
                    #expect(available.contains(frame))
                    #expect(!frame.intersects(action.insetBy(dx: -7.9, dy: -7.9)))
                    #expect(!frame.intersects(add.insetBy(dx: -7.9, dy: -7.9)))
                    if snapping {
                        #expect(point.x == available.minX + 14 || frame.maxX == available.maxX - 14)
                    }
                }
            }
        }
    }

    @Test func largerActionAndSmallerViewportReclampPriorOrigin() {
        let size = CGSize(width: 150, height: 85)
        let previous = CGPoint(x: 238, y: 700)
        let available = CGRect(x: 0, y: 62, width: 402, height: 420)
        let action = CGRect(x: 16, y: 330, width: 370, height: 140)
        let point = LiveCapsulePlacement.origin(preferred: previous, size: size, available: available,
                                               exclusions: [action])
        #expect(available.contains(CGRect(origin: point, size: size)))
        #expect(point.y + size.height <= action.minY - 8)
    }

    @Test func identicalGeometryHasStableValueWithoutStoredState() {
        let available = CGRect(x: 0, y: 62, width: 402, height: 710)
        let action = CGRect(x: 16, y: 650, width: 370, height: 90)
        let size = CGSize(width: 150, height: 85)
        let first = LiveCapsulePlacement.origin(preferred: nil, size: size, available: available, exclusions: [action])
        for _ in 0..<100 {
            #expect(LiveCapsulePlacement.origin(preferred: nil, size: size, available: available, exclusions: [action]) == first)
        }
    }
}
