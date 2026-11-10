import CoreGraphics

/// 胶囊的纯几何约束；输入由页面实际布局提供，不读取训练或历史。
nonisolated enum LiveCapsulePlacement {
    static func origin(preferred: CGPoint?, size: CGSize, available: CGRect,
                       exclusions: [CGRect], snapping: Bool = false) -> CGPoint {
        let minX = available.minX + 14
        let maxX = max(minX, available.maxX - 14 - size.width)
        let minY = available.minY + 8
        let maxY = max(minY, available.maxY - 8 - size.height)
        func x(_ value: CGFloat) -> CGFloat { min(max(value, minX), maxX) }
        func y(_ value: CGFloat) -> CGFloat { min(max(value, minY), maxY) }
        var base = preferred.map { CGPoint(x: x($0.x), y: y($0.y)) } ?? CGPoint(x: minX, y: maxY)
        if snapping {
            base.x = base.x + size.width / 2 < available.midX ? minX : maxX
        }
        let blocked = exclusions.filter { !$0.isEmpty && !$0.isNull }
            .map { $0.insetBy(dx: -8, dy: -8) }
        func fits(_ point: CGPoint) -> Bool {
            let frame = CGRect(origin: point, size: size)
            return !blocked.contains { $0.intersects(frame) }
        }
        if fits(base) { return base }

        // 只需检查障碍的边界组合；普通拖动允许横向绕开，吸附时保持在左右边缘。
        var xs = snapping ? [minX, maxX] : [base.x, minX, maxX]
        var ys = [base.y, minY, maxY]
        for frame in blocked {
            if !snapping { xs += [x(frame.minX - size.width), x(frame.maxX)] }
            ys += [y(frame.minY - size.height), y(frame.maxY)]
        }
        var nearest: CGPoint?
        var distance = CGFloat.infinity
        for candidateX in xs {
            for candidateY in ys {
                let candidate = CGPoint(x: candidateX, y: candidateY)
                guard fits(candidate) else { continue }
                let dx = candidateX - base.x
                let dy = candidateY - base.y
                let candidateDistance = dx * dx + dy * dy
                if candidateDistance < distance {
                    nearest = candidate
                    distance = candidateDistance
                }
            }
        }
        return nearest ?? base
    }
}
