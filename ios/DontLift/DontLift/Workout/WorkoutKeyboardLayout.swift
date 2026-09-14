import CoreGraphics
import Foundation

/// 训练进行页键盘/滚动布局测量态：行框、视口、键盘顶边。
///
/// 这些值随滚动与键盘升降逐帧变化；若直接放视图 `@State`，每次 preference 更新
/// 都会让整页 body 重估（全部动作块跟着 diff）。收进独立 `@Observable` 后，
/// 只有真正读取它们的视图（FAB、键盘 overlay、滚动判定）才订阅更新，
/// 根 body 不再因逐帧测量值而重建。
@MainActor
@Observable
final class WorkoutKeyboardLayout {
    /// 各组行在 `.global` 坐标系的 frame（`SetRowFramesKey` preference 汇总）。
    var setRowFrames: [UUID: CGRect] = [:]
    /// ScrollView 视口在 `.global` 的 frame；仅键盘聚焦期间采集。
    var scrollViewport: CGRect = .zero
    /// 自研数字键盘顶边的 `.global` Y（0 = 键盘未升起或未测得）。
    var keypadTopY: CGFloat = 0
}
