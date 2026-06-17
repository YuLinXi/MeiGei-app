import SwiftUI

// MARK: - 3.10 PR 自动识别与庆祝

/// PR 庆祝弹窗的 App 级承载器（注入根环境）。
///
/// 结束训练会让 `workout.isFinished` 翻转，首页导航随即把进行中页换成只读详情页，
/// 若庆祝 sheet 挂在被替换的页内会一闪即逝。故把待展示的庆祝数据提到此处，
/// 由稳定不被销毁的 `MainTabView` 统一呈现，避免随导航切换被销毁。
@Observable
final class PRCelebrationCenter {
    /// 待展示的新纪录；非 nil 即触发庆祝弹窗。展示后置 nil 收起。
    var records: [PersonalRecord]?
    /// 弹窗副标题摘要（`title · N 动作 · N 组 · N 分钟`）。
    var summary: String = ""

    func present(_ records: [PersonalRecord], summary: String) {
        self.summary = summary
        self.records = records
    }
}

/// 一条个人记录：由原始训练记录重算得出，不持久化（design.md Non-Goals）。
struct PersonalRecord: Identifiable {
    let exerciseName: String
    let weightKg: Double
    /// 此前历史最大重量；nil 表示该动作首次有重量记录。
    let previousBestKg: Double?
    var id: String { exerciseName }
}

/// 比较本次训练各动作的最大重量与历史最大值，识别新 PR。
/// - Parameters:
///   - workout: 刚完成的训练。
///   - history: 用于比较的历史训练（应排除本次；只传已完成、未删除的）。
func detectPersonalRecords(in workout: Workout, history: [Workout]) -> [PersonalRecord] {
    // 历史各动作最大重量。
    var bestByKey: [String: Double] = [:]
    for w in history {
        for ex in w.exercises {
            guard let m = ex.sets.filter(\.countsForStats).compactMap(\.weightKg).max() else { continue }
            bestByKey[ex.historyKey] = max(bestByKey[ex.historyKey] ?? m, m)
        }
    }
    var seen = Set<String>()
    var prs: [PersonalRecord] = []
    for ex in workout.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
        guard let sessionMax = ex.sets.filter(\.countsForStats).compactMap(\.weightKg).max() else { continue }
        let key = ex.historyKey
        guard !seen.contains(key) else { continue }
        let prior = bestByKey[key]
        if prior == nil || sessionMax > prior! {
            prs.append(PersonalRecord(exerciseName: ex.exerciseName, weightKg: sessionMax, previousBestKg: prior))
            seen.insert(key)
        }
    }
    return prs
}

/// 庆祝弹窗（设计稿 04 · C 纸感，严格对齐 `dontlift-c-pr-celebrate.md`）。
///
/// 结束/编辑训练检测到新 PR 时，从底部升起半屏白 sheet（墨色 scrim 由系统 sheet 提供）：
/// grabber → 64px 朱砂红奖杯徽记（白色线性图标 + 三点微光）→「PERSONAL RECORD」eyebrow
/// →「N 项新纪录！」标题 → 训练摘要副行 → 单容器 PR 列表（旧/首次 + 30px 红重量大数）→「太棒了」CTA。
/// 高度按内容自适应（半屏内），可点 CTA 关闭或下滑关闭。
struct PRCelebrationSheet: View {
    let records: [PersonalRecord]
    /// 训练摘要副行：`title · N 动作 · N 组 · N 分钟`（title 为空则省略首段）。
    let summary: String
    @Environment(\.dismiss) private var dismiss

    /// 内容自然高度（用于 presentationDetents 自适应），默认给一个略大初值待测量收敛。
    @State private var contentHeight: CGFloat = 460

    var body: some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: SheetHeightKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(SheetHeightKey.self) { contentHeight = $0 }
            .frame(maxWidth: .infinity)
            .presentationBackground(Theme.Color.surface)
            .presentationCornerRadius(26)
            .presentationDragIndicator(.hidden)
            .presentationDetents([.height(contentHeight)])
    }

    private var content: some View {
        VStack(spacing: 0) {
            // grabber：38×5，border2，顶 10 / 底 16。
            Capsule().fill(Theme.Color.border2)
                .frame(width: 38, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 16)

            badge
            Text("PERSONAL RECORD")
                .font(Theme.Font.mono(size: 10, weight: .bold))
                .tracking(0.2 * 10)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Color.accent)
                .padding(.top, 16)
            Text(records.count == 1 ? "1 项新纪录！" : "\(records.count) 项新纪录！")
                .font(Theme.Font.display(size: 23, weight: .heavy))
                .tracking(-0.02 * 23)
                .foregroundStyle(Theme.Color.fg)
                .padding(.top, 6)
            Text(summary)
                .font(Theme.Font.body(size: 12))
                .foregroundStyle(Theme.Color.muted)
                .padding(.top, 5)

            prList.padding(.top, 22)

            cta.padding(.top, 20)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 26)
    }

    // MARK: 徽记（64px 实心红圆 + 白色奖杯线性图标 + 三点微光）

    private var badge: some View {
        ZStack {
            Circle().fill(Theme.Color.accent)
                .frame(width: 64, height: 64)
                .shadow(color: Theme.Color.accent.opacity(0.32), radius: 9, x: 0, y: 6)
            Image(systemName: "trophy")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
            // 三颗 spark 点缀（相对 64 徽章中心的近似坐标，对齐原型 s1/s2/s3）。
            spark(size: 5, opacity: 0.7).offset(x: -21.5, y: -32.5)
            spark(size: 4, opacity: 1.0).offset(x: 35, y: -24)
            spark(size: 4, opacity: 0.8).offset(x: -34, y: 32)
        }
        .frame(width: 64, height: 64)
    }

    private func spark(size: CGFloat, opacity: Double) -> some View {
        Circle().fill(Theme.Color.accent).frame(width: size, height: size).opacity(opacity)
    }

    // MARK: PR 列表（单容器 + 行间分隔线）

    private var prList: some View {
        VStack(spacing: 0) {
            ForEach(Array(records.enumerated()), id: \.element.id) { index, pr in
                if index > 0 {
                    Rectangle().fill(Theme.Color.border).frame(height: 1)
                }
                prRow(pr)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(Theme.Color.border, lineWidth: 1)
        )
    }

    private func prRow(_ pr: PersonalRecord) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(pr.exerciseName)
                    .font(Theme.Font.display(size: 15, weight: .bold))
                    .tracking(-0.01 * 15)
                    .foregroundStyle(Theme.Color.fg)
                if let prev = pr.previousBestKg {
                    // 刷新型：灰字「旧纪录 N kg」。
                    Text("旧纪录 \(formatKg(prev)) kg")
                        .font(Theme.Font.body(size: 12))
                        .foregroundStyle(Theme.Color.muted)
                } else {
                    // 首次型：朱砂红 mono「首次记录」标签。
                    Text("首次记录")
                        .font(Theme.Font.mono(size: 10, weight: .regular))
                        .tracking(0.06 * 10)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.Color.accent)
                }
            }
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: 3) {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.Color.accent)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(formatKg(pr.weightKg))
                        .numStyle(size: 30, weight: .bold)
                        .foregroundStyle(Theme.Color.accent)
                    Text("kg")
                        .font(Theme.Font.mono(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Color.accent.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
    }

    // MARK: CTA

    private var cta: some View {
        Button { dismiss() } label: {
            Text("太棒了")
                .font(Theme.Font.display(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .shadow(color: Theme.Color.accent.opacity(0.26), radius: 7, x: 0, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// 测量 sheet 内容自然高度，喂给 presentationDetents 实现内容自适应。
private struct SheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
