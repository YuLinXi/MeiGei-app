import SwiftUI

/// 页面通过布局锚点提供可用区域和主操作区域，不向训练状态发布几何更新。
struct WorkoutOverlayRegions {
    var viewport: Anchor<CGRect>?
    var actions: [Anchor<CGRect>] = []
}

struct WorkoutOverlayRegionsKey: PreferenceKey {
    static var defaultValue: WorkoutOverlayRegions { WorkoutOverlayRegions() }

    static func reduce(value: inout WorkoutOverlayRegions, nextValue: () -> WorkoutOverlayRegions) {
        let next = nextValue()
        if let viewport = next.viewport { value.viewport = viewport }
        value.actions += next.actions
    }
}

extension View {
    func workoutOverlayViewport() -> some View {
        transformAnchorPreference(key: WorkoutOverlayRegionsKey.self, value: .bounds) { regions, anchor in
            regions.viewport = anchor
        }
    }

    func workoutOverlayObstacle() -> some View {
        transformAnchorPreference(key: WorkoutOverlayRegionsKey.self, value: .bounds) { regions, anchor in
            regions.actions.append(anchor)
        }
    }
}
