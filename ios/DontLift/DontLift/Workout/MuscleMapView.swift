import SwiftUI

// MARK: - 肌群高亮图（muscle-map-detailed-art）
//
// 渲染开源 react-native-body-highlighter（MIT）的详细解剖 path（数据见 MuscleBodyArt.swift），
// 自写 SVG 解析器（M/m L/l H/h C/c Q/q A/a Z/z + 椭圆弧→贝塞尔），Canvas 按 slug 三态染色。
// 对外 API 不变：primary / secondary / sex / side。三态：主动肌 accent / 协同肌 accentSofter / idle。

// MARK: SVG path 解析器

private enum SVGPath {
    /// 解析为原始 viewBox 坐标系下的 Path（不缩放）。
    static func parse(_ d: String) -> Path {
        var path = Path()
        let chars = Array(d)
        var i = 0
        var cur = CGPoint.zero
        var start = CGPoint.zero
        var cmd: Character = " "

        func skipSep() {
            while i < chars.count, chars[i] == " " || chars[i] == "," || chars[i] == "\n" || chars[i] == "\t" || chars[i] == "\r" { i += 1 }
        }
        func num() -> CGFloat? {
            skipSep()
            guard i < chars.count else { return nil }
            var s = ""
            if chars[i] == "+" || chars[i] == "-" { s.append(chars[i]); i += 1 }
            while i < chars.count, chars[i].isNumber { s.append(chars[i]); i += 1 }
            if i < chars.count, chars[i] == "." { s.append("."); i += 1; while i < chars.count, chars[i].isNumber { s.append(chars[i]); i += 1 } }
            if i < chars.count, chars[i] == "e" || chars[i] == "E" {
                s.append("e"); i += 1
                if i < chars.count, chars[i] == "+" || chars[i] == "-" { s.append(chars[i]); i += 1 }
                while i < chars.count, chars[i].isNumber { s.append(chars[i]); i += 1 }
            }
            return Double(s).map { CGFloat($0) }
        }
        func pt(_ x: CGFloat, _ y: CGFloat, rel: Bool) -> CGPoint {
            rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
        }

        while true {
            skipSep()
            guard i < chars.count else { break }
            if chars[i].isLetter { cmd = chars[i]; i += 1 }
            let rel = cmd.isLowercase
            switch Character(cmd.lowercased()) {
            case "m":
                guard let x = num(), let y = num() else { return path }
                cur = pt(x, y, rel: rel); path.move(to: cur); start = cur
                cmd = rel ? "l" : "L"
            case "l":
                guard let x = num(), let y = num() else { return path }
                cur = pt(x, y, rel: rel); path.addLine(to: cur)
            case "h":
                guard let x = num() else { return path }
                cur = CGPoint(x: rel ? cur.x + x : x, y: cur.y); path.addLine(to: cur)
            case "v":
                guard let y = num() else { return path }
                cur = CGPoint(x: cur.x, y: rel ? cur.y + y : y); path.addLine(to: cur)
            case "c":
                guard let a = num(), let b = num(), let c = num(), let dd = num(), let e = num(), let f = num() else { return path }
                let c1 = pt(a, b, rel: rel), c2 = pt(c, dd, rel: rel), end = pt(e, f, rel: rel)
                path.addCurve(to: end, control1: c1, control2: c2); cur = end
            case "q":
                guard let a = num(), let b = num(), let c = num(), let dd = num() else { return path }
                let ctrl = pt(a, b, rel: rel), end = pt(c, dd, rel: rel)
                path.addQuadCurve(to: end, control: ctrl); cur = end
            case "a":
                guard let rx = num(), let ry = num(), let rot = num(),
                      let large = num(), let sweep = num(), let x = num(), let y = num() else { return path }
                let end = pt(x, y, rel: rel)
                appendArc(&path, from: cur, to: end, rx: rx, ry: ry,
                          phiDeg: rot, largeArc: large != 0, sweep: sweep != 0)
                cur = end
            case "z":
                path.closeSubpath(); cur = start
                // z 后若非新指令字母，避免空转
                skipSep()
                if i < chars.count, !chars[i].isLetter { return path }
            default:
                return path   // 未知指令：止损
            }
        }
        return path
    }

    /// 椭圆弧 → 三次贝塞尔（SVG endpoint→center 参数化 + ≤90° 分段）。
    private static func appendArc(_ path: inout Path, from p0: CGPoint, to p1: CGPoint,
                                  rx rxIn: CGFloat, ry ryIn: CGFloat,
                                  phiDeg: CGFloat, largeArc: Bool, sweep: Bool) {
        var rx = abs(rxIn), ry = abs(ryIn)
        if rx < 1e-6 || ry < 1e-6 { path.addLine(to: p1); return }
        let phi = phiDeg * .pi / 180
        let cosP = cos(phi), sinP = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1p = cosP * dx + sinP * dy
        let y1p = -sinP * dx + cosP * dy
        // 半径修正
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 { let s = sqrt(lambda); rx *= s; ry *= s }
        var num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        if num < 0 { num = 0 }
        var co = sqrt(num / den)
        if largeArc == sweep { co = -co }
        let cxp = co * rx * y1p / ry
        let cyp = -co * ry * x1p / rx
        let cx = cosP * cxp - sinP * cyp + (p0.x + p1.x) / 2
        let cy = sinP * cxp + cosP * cyp + (p0.y + p1.y) / 2
        func ang(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy
            let len = sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy))
            var a = acos(max(-1, min(1, dot / len)))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }
        let theta1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var dTheta = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !sweep && dTheta > 0 { dTheta -= 2 * .pi }
        if sweep && dTheta < 0 { dTheta += 2 * .pi }
        let segs = max(1, Int(ceil(abs(dTheta) / (.pi / 2))))
        let delta = dTheta / CGFloat(segs)
        let t = 4.0 / 3.0 * tan(delta / 4)
        var a0 = theta1
        func point(_ a: CGFloat) -> CGPoint {
            let cosA = cos(a), sinA = sin(a)
            return CGPoint(x: cx + rx * cosA * cosP - ry * sinA * sinP,
                           y: cy + rx * cosA * sinP + ry * sinA * cosP)
        }
        func deriv(_ a: CGFloat) -> CGPoint {
            let cosA = cos(a), sinA = sin(a)
            return CGPoint(x: -rx * sinA * cosP - ry * cosA * sinP,
                           y: -rx * sinA * sinP + ry * cosA * cosP)
        }
        for _ in 0..<segs {
            let a1 = a0 + delta
            let pA = point(a0), pB = point(a1)
            let dA = deriv(a0), dB = deriv(a1)
            let c1 = CGPoint(x: pA.x + t * dA.x, y: pA.y + t * dA.y)
            let c2 = CGPoint(x: pB.x - t * dB.x, y: pB.y - t * dB.y)
            path.addCurve(to: pB, control1: c1, control2: c2)
            a0 = a1
        }
    }
}

// MARK: 肌群高亮图

struct MuscleMapView: View {
    let primary: [MuscleRegion]
    let secondary: [MuscleRegion]
    var sex: BodySex = .male
    /// 外部可控当前面；nil 表示用「亮区更多」自动默认。
    var side: MuscleRegion.Side? = nil

    private static let idleColor = Color(red: 0.866, green: 0.835, blue: 0.788)   // 静默肌底色
    private static let lineColor = Color(red: 0.79, green: 0.76, blue: 0.70)

    private var primarySet: Set<MuscleRegion> { Set(primary) }
    private var secondarySet: Set<MuscleRegion> { Set(secondary) }

    private var resolvedBack: Bool {
        if let side { return side == .back }
        let regs = primary + secondary
        let f = regs.filter { $0.side == .front || $0.side == .both }.count
        let b = regs.filter { $0.side == .back || $0.side == .both }.count
        return b > f
    }

    /// 开源肌肉 slug → MuscleRegion（deltoids 按正/背分前/后束；无映射返回 nil = idle）。
    private func region(for slug: String, back: Bool) -> MuscleRegion? {
        switch slug {
        case "chest": return .chest
        case "biceps": return .biceps
        case "triceps": return .triceps
        case "abs": return .abs
        case "obliques": return .obliques
        case "forearm": return .forearms
        case "quadriceps": return .quads
        case "adductors": return .adductors
        case "calves": return .calves
        case "trapezius": return .traps
        case "deltoids": return back ? .deltRear : .deltFront
        case "upper-back": return .lats
        case "lower-back": return .lowerBack
        case "hamstring": return .hams
        case "gluteal": return .glutes
        default: return nil
        }
    }

    private func color(for slug: String, back: Bool) -> Color {
        guard let r = region(for: slug, back: back) else { return Self.idleColor }
        if primarySet.contains(r) { return Theme.Color.accent }
        if secondarySet.contains(r) { return Theme.Color.accentSofter }
        return Self.idleColor
    }

    private static func face(sex: BodySex, back: Bool) -> BodyFaceArt {
        switch (sex, back) {
        case (.male, false):   return MuscleBodyArt.maleFront
        case (.male, true):    return MuscleBodyArt.maleBack
        case (.female, false): return MuscleBodyArt.femaleFront
        case (.female, true):  return MuscleBodyArt.femaleBack
        }
    }

    private static func transform(vb: (x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat), size: CGSize) -> CGAffineTransform {
        let s = min(size.width / vb.w, size.height / vb.h)
        let ox = (size.width - vb.w * s) / 2 - vb.x * s
        let oy = (size.height - vb.h * s) / 2 - vb.y * s
        return CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: ox, ty: oy)
    }

    var body: some View {
        if primary.isEmpty {
            EmptyView()
        } else {
            let back = resolvedBack
            let f = Self.face(sex: sex, back: back)
            Canvas { ctx, size in
                let t = Self.transform(vb: f.vb, size: size)
                // 两遍：先 idle 底，再叠高亮（避免高亮被相邻 idle 覆盖）。
                for pass in 0..<2 {
                    for (slug, ds) in f.parts {
                        let col = color(for: slug, back: back)
                        let highlighted = col != Self.idleColor
                        if (pass == 0) == highlighted { continue }
                        var p = Path()
                        for d in ds { p.addPath(SVGPath.parse(d)) }
                        p = p.applying(t)
                        ctx.fill(p, with: .color(col))
                        ctx.stroke(p, with: .color(Self.lineColor), lineWidth: 0.6)
                    }
                }
            }
            .aspectRatio(f.vb.w / f.vb.h, contentMode: .fit)
        }
    }
}

#if DEBUG
#Preview("卧推 · 男正") {
    MuscleMapView(primary: [.chest], secondary: [.deltFront, .triceps], sex: .male, side: .front)
        .frame(height: 320).padding()
}
#Preview("引体 · 女背") {
    MuscleMapView(primary: [.lats], secondary: [.biceps, .deltRear, .forearms], sex: .female, side: .back)
        .frame(height: 320).padding()
}
#endif
