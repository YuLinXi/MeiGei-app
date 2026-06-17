import SwiftUI
import MuscleMap

// MARK: - 肌群高亮图
//
// 基于 MuscleMap SDK（melihcolpan/MuscleMap，MIT）的 BodyView 渲染：男/女 × 正/背 四套人体，
// SVG path → SwiftUI Canvas，36 肌群细分。正反并排同屏，主动肌朱砂红 / 协同肌浅朱砂。
// 注：SDK 无独立背阔肌(lats)，映射到 upper-back（中上背）；性别由 sex 驱动男/女体型。
// 对外 API 不变：primary / secondary / sex。

struct MuscleMapView: View {
    let primary: [MuscleRegion]
    let secondary: [MuscleRegion]
    var sex: BodySex = .male

    private static let idleColor = Color(red: 0.866, green: 0.835, blue: 0.788)      // 身体/静默肌底色（米色）
    private static let lineColor = Color(red: 0.79, green: 0.76, blue: 0.70)          // 肌肉分块描边
    private static let secondaryColor = Color(red: 0.859, green: 0.585, blue: 0.510) // 协同肌浅朱砂

    private var gender: BodyGender { sex == .female ? .female : .male }

    /// MuscleRegion → MuscleMap.Muscle。SDK 无 lats，背阔肌落到 upper-back；三角肌前/后束统一
    /// 映射 deltoids，由正/背面天然区分（正面显前束、背面显后束）。
    private func muscles(_ regions: [MuscleRegion]) -> [Muscle] {
        regions.map { r in
            switch r {
            case .traps:      return .trapezius
            case .deltFront:  return .deltoids
            case .deltRear:   return .deltoids
            case .chest:      return .chest
            case .biceps:     return .biceps
            case .triceps:    return .triceps
            case .forearms:   return .forearm
            case .abs:        return .abs
            case .obliques:   return .obliques
            case .lats:       return .upperBack
            case .lowerBack:  return .lowerBack
            case .glutes:     return .gluteal
            case .quads:      return .quadriceps
            case .adductors:  return .adductors
            case .hams:       return .hamstring
            case .calves:     return .calves
            // 补齐区：美术未拆前优雅回退到最近 SDK 肌肉（deltSide→三角肌、菱形→中上背、臀中→臀、颈部→斜方）
            case .deltSide:   return .deltoids
            case .rhomboids:  return .upperBack
            case .gluteMed:   return .gluteal
            case .neck:       return .trapezius
            }
        }
    }

    /// 纸感极简配色：米色肌底 + 淡描边；头发设为底色以视觉隐藏。
    private var style: BodyViewStyle {
        BodyViewStyle(
            defaultFillColor: Self.idleColor,
            strokeColor: Self.lineColor,
            strokeWidth: 0.5,
            headColor: Self.idleColor,
            hairColor: Self.idleColor
        )
    }

    private func face(_ side: BodySide) -> some View {
        BodyView(gender: gender, side: side, style: style)
            .highlight(muscles(secondary), color: Self.secondaryColor)
            .highlight(muscles(primary), color: Theme.Color.accent)
    }

    var body: some View {
        if primary.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: Theme.Spacing.sm) {
                // 正面 + 背面并排同时展示（无切换按钮）。
                HStack(spacing: Theme.Spacing.md) {
                    face(.front)
                    face(.back)
                }
                .frame(height: 300)
                legend
            }
        }
    }

    private var legend: some View {
        HStack(spacing: Theme.Spacing.md) {
            legendItem(Theme.Color.accent, "主要部位")
            legendItem(Self.secondaryColor, "次要部位")
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 9, height: 9)
            Text(label).font(Theme.Font.mono(size: 11)).foregroundStyle(Theme.Color.muted)
        }
    }
}

#if DEBUG
#Preview("卧推 · 男") {
    MuscleMapView(primary: [.chest], secondary: [.deltFront, .triceps], sex: .male)
        .padding()
}
#Preview("引体 · 女") {
    MuscleMapView(primary: [.lats], secondary: [.biceps, .deltRear, .forearms], sex: .female)
        .padding()
}
#endif
