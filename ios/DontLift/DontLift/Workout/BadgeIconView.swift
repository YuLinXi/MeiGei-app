import SwiftUI

/// 勋章几何外形枚举
enum BadgeShapeKind {
    case circle
    case octagon
    case hexagon
    case diamond

    static func from(category: BadgeCategory) -> BadgeShapeKind {
        switch category {
        case .strength: return .circle
        case .tonnage:  return .octagon
        case .career:   return .hexagon
        case .feats:    return .diamond
        }
    }
}

/// 八边形 Shape
struct OctagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let corner = min(w, h) * 0.28

        path.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + corner))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - corner))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        path.closeSubpath()
        return path
    }
}

/// 六角形 Shape
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let r = min(w, h) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)

        for i in 0..<6 {
            let angle = CGFloat(i) * (.pi / 3) - (.pi / 6)
            let pt = CGPoint(
                x: center.x + r * cos(angle),
                y: center.y + r * sin(angle)
            )
            if i == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
        }
        path.closeSubpath()
        return path
    }
}

/// 菱形 Shape
struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// 勋章尺寸规格
enum BadgeIconSize {
    case mini       // 34pt (Profile 概览卡片小缩略图)
    case regular    // 64pt (徽章馆 3 列网格卡片)
    case large      // 88pt (结算/回顾高光大弹窗)

    var dimension: CGFloat {
        switch self {
        case .mini:    return 34
        case .regular: return 64
        case .large:   return 88
        }
    }

    var symbolSize: CGFloat {
        switch self {
        case .mini:    return 14
        case .regular: return 24
        case .large:   return 36
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .mini:    return 1.2
        case .regular: return 2.0
        case .large:   return 2.8
        }
    }
}

/// 严肃力量暗钛金属质感勋章图腾呈现组件
struct BadgeIconView: View {
    let definition: BadgeDefinition
    var isUnlocked: Bool = true
    var size: BadgeIconSize = .regular

    private var shapeKind: BadgeShapeKind {
        BadgeShapeKind.from(category: definition.category)
    }

    var body: some View {
        ZStack {
            switch shapeKind {
            case .circle:
                renderShapeContent(shape: Circle())
            case .octagon:
                renderShapeContent(shape: OctagonShape())
            case .hexagon:
                renderShapeContent(shape: HexagonShape())
            case .diamond:
                renderShapeContent(shape: DiamondShape())
            }

            // 中心符号
            Image(systemName: definition.iconSystemName)
                .font(.system(size: size.symbolSize, weight: .bold))
                .foregroundColor(
                    isUnlocked ? Color(hex: "F45138") : Color(hex: "5A5D66")
                )
                .shadow(
                    color: isUnlocked ? Color(hex: "E04328").opacity(0.6) : .clear,
                    radius: isUnlocked ? 6 : 0,
                    x: 0,
                    y: 1
                )
        }
        .frame(width: size.dimension, height: size.dimension)
        .shadow(
            color: isUnlocked ? Color.black.opacity(0.35) : Color.black.opacity(0.15),
            radius: isUnlocked ? 5 : 2,
            x: 0,
            y: 2
        )
    }

    @ViewBuilder
    private func renderShapeContent<S: Shape>(shape: S) -> some View {
        // 背景底板与金属拉丝渐变
        shape
            .fill(
                isUnlocked
                    ? LinearGradient(
                        colors: [Color(hex: "2A2C32"), Color(hex: "17181C")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [Color(hex: "1F2124").opacity(0.6), Color(hex: "141517").opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
            )

        // 内圈光晕 / 蚀刻金属质感边框
        if isUnlocked {
            shape
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "E04328").opacity(0.85),
                            Color(hex: "FF6E54").opacity(0.4),
                            Color(hex: "E04328").opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: size.borderWidth
                )

            // 核心图腾居中微光
            Circle()
                .fill(Color(hex: "E04328").opacity(0.18))
                .frame(width: size.dimension * 0.55, height: size.dimension * 0.55)
                .blur(radius: size.dimension * 0.12)
        } else {
            shape
                .stroke(Color(hex: "34373E").opacity(0.5), lineWidth: size.borderWidth)
        }
    }
}
