import SwiftUI

// MARK: - 肌群周负荷复盘（周复盘页 + 首页小卡共用组件）

/// 近 4 周有效组数迷你趋势：四个圆角柱，高度按序列最大值归一；
/// 用色阶表达时间方向——最近一周主色、越早越浅，全 0 序列绘制基线。
struct MuscleLoadSparkline: View {
    let values: [Int]

    private func color(for index: Int) -> Color {
        // 最后一根（本周）最深，向前逐周变浅。
        index == values.count - 1 ? Theme.Color.accent : Theme.Color.accentSoft
    }

    var body: some View {
        let maxValue = max(values.max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(value > 0 ? color(for: index) : Theme.Color.border)
                    .frame(width: 7, height: value > 0 ? max(4, 22 * CGFloat(value) / CGFloat(maxValue)) : 2)
            }
        }
        .frame(height: 24, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("近 4 周趋势")
        .accessibilityValue(values.map(String.init).joined(separator: "、") + " 组")
    }
}

/// 单个肌群负荷行：肌群名 + 负荷条 + 组数与容量 + 可选趋势。首页小卡与复盘页共用。
/// 负荷条统一主色（朱砂红），「其他」桶整体弱化；组数为视觉主数字，容量弱化色紧随（「12 组 · 8.6 t」）。
/// 行内不展示同期对比增量——对比详情在复盘页点按展开的贡献明细面板中呈现。
struct MuscleLoadRowView: View {
    let name: String
    let entry: MuscleLoadEntry
    /// 相对最大组数的条宽比例（0...1）。
    let barFraction: Double
    /// 近 4 周趋势序列；nil 隐藏趋势（首页小卡）。
    var series: [Int]? = nil
    /// 次要行（「其他」桶）：弱化展示，不绘制主色条。
    var isSecondary = false

    var body: some View {
        HStack(spacing: 10) {
            Text(name)
                .font(Theme.Font.body(size: 13, weight: .semibold))
                .foregroundStyle(isSecondary ? Theme.Color.muted : Theme.Color.fg)
                .frame(width: 34, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Color.accentSofter.opacity(0.6))
                    Capsule()
                        .fill(isSecondary ? Theme.Color.muted : Theme.Color.accent)
                        .frame(width: geo.size.width * CGFloat(min(1, max(0, barFraction))))
                }
            }
            .frame(height: 6)

            HStack(spacing: 3) {
                Text("\(entry.workingSets) 组")
                    .font(Theme.Font.mono(size: 12, weight: .semibold))
                    .foregroundStyle(isSecondary ? Theme.Color.muted : Theme.Color.fg)
                Text("· \(formatMuscleLoadVolume(entry.volumeKg))")
                    .font(Theme.Font.mono(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Color.muted)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(width: 88, alignment: .trailing)

            if let series {
                MuscleLoadSparkline(values: series)
            }
        }
        .frame(height: 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name)，\(entry.workingSets) 组，\(formatMuscleLoadVolume(entry.volumeKg))")
    }
}

/// 肌群负荷格式化：>= 1000 kg 显示吨，否则整数 kg。
func formatMuscleLoadVolume(_ kg: Double) -> String {
    kg >= 1000 ? "\(formatTons(kg)) t" : "\(Int(kg.rounded())) kg"
}

/// 周复盘页：八肌群负荷板 + 同期对比 + 近 4 周趋势 + 点按展开贡献明细。
struct MuscleLoadReviewView: View {
    @Environment(WorkoutHistoryStore.self) private var historyStore
    @Environment(\.dismiss) private var dismiss
    /// false = 本周（进行中，对比上周同期）；true = 上一完整周（对比上上周）。
    @State private var viewingPreviousWeek = false
    /// 展开贡献明细的桶 id（`MuscleLoadEntry.id`，肌群 rawValue 或 "other"）。
    @State private var expandedBucketId: String?

    private var snapshot: MuscleLoadSnapshot { historyStore.muscleLoad }

    private var board: [MuscleLoadEntry] {
        viewingPreviousWeek ? snapshot.previousBoard : snapshot.board
    }

    /// 本周的对比基准（上周整周）。上周视图为纯数据回看，不展示对比。
    private var baselineBoard: [MuscleLoadEntry] {
        snapshot.baseline
    }

    private var contributions: [ExerciseCategory?: [MuscleLoadContribution]] {
        viewingPreviousWeek ? snapshot.previousContributions : snapshot.contributions
    }

    private var maxSets: Int { max(board.map(\.workingSets).max() ?? 0, 1) }

    private var totalSets: Int { board.reduce(0) { $0 + $1.workingSets } }

    /// 全板总容量（含「其他」桶，与 totalSets 同范围）。
    private var totalVolume: Double { board.reduce(0) { $0 + $1.volumeKg } }

    /// 全板相对上周整周的有效组数变化（仅八肌群，不含「其他」）。
    private var totalDelta: Int {
        let baselineTotal = baselineBoard
            .filter { $0.category != nil }
            .reduce(0) { $0 + $1.workingSets }
        return board.filter { $0.category != nil }.reduce(0) { $0 + $1.workingSets } - baselineTotal
    }

    /// 全板相对上周整周的容量变化（仅八肌群，与 totalDelta 同范围）。
    private var totalVolumeDelta: Double {
        let baselineTotal = baselineBoard
            .filter { $0.category != nil }
            .reduce(0.0) { $0 + $1.volumeKg }
        return board.filter { $0.category != nil }.reduce(0.0) { $0 + $1.volumeKg } - baselineTotal
    }

    /// 较上周整周的对比文案：组数与容量两个分量各自独立，持平（变化为 0）的分量省略，
    /// 两个分量均持平时返回 nil（整条不展示）。容量变化绝对值 < 0.5 kg 视为持平
    /// （低于 `formatMuscleLoadVolume` 的整数 kg 显示精度）。
    private func comparisonText(setsDelta: Int, volumeDelta: Double) -> String? {
        var parts: [String] = []
        if setsDelta != 0 {
            parts.append(setsDelta > 0 ? "多 \(setsDelta) 组" : "少 \(abs(setsDelta)) 组")
        }
        if abs(volumeDelta) >= 0.5 {
            parts.append(volumeDelta > 0
                         ? "多 \(formatMuscleLoadVolume(volumeDelta))"
                         : "少 \(formatMuscleLoadVolume(abs(volumeDelta)))")
        }
        guard !parts.isEmpty else { return nil }
        return "较上周" + parts.joined(separator: " · ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                if totalSets == 0 {
                    emptyState
                } else {
                    boardSection
                }
                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)
        }
        .background(Theme.Color.bg.ignoresSafeArea())
        .paperToolbar(title: "肌群负荷", onBack: { dismiss() })
    }

    // MARK: - 头部（周切换 + 总览）

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(viewingPreviousWeek ? "上周" : "本周")
                    .font(Theme.Font.display(size: 24, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                Text("共 \(totalSets) 有效组")
                    .font(Theme.Font.body(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg2)
                Text("· \(formatMuscleLoadVolume(totalVolume))")
                    .font(Theme.Font.body(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Color.muted)
                Spacer(minLength: 0)
                // 总量文案变长时（如「共 210 有效组 · 120.4 t」）不许挤压切换器——
                // 固定理想尺寸，避免「本周/上周」被截断成省略号。
                weekToggle
                    .fixedSize()
            }
            // 仅本周视图展示较上周整周的对比；组数与容量双分量，均持平时整行隐藏（含圆点）。
            if !viewingPreviousWeek,
               let comparison = comparisonText(setsDelta: totalDelta, volumeDelta: totalVolumeDelta) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(totalDelta > 0 || (totalDelta == 0 && totalVolumeDelta > 0)
                              ? Theme.Color.accent : Theme.Color.fg2)
                        .frame(width: 6, height: 6)
                    Text(comparison)
                        .font(Theme.Font.body(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Color.muted)
                }
            }
        }
    }

    private var weekToggle: some View {
        HStack(spacing: 4) {
            weekToggleButton(title: "本周", active: !viewingPreviousWeek) { viewingPreviousWeek = false }
            weekToggleButton(title: "上周", active: viewingPreviousWeek) { viewingPreviousWeek = true }
        }
        .padding(3)
        .background(Theme.Color.surface, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(Theme.Color.border, lineWidth: 1))
    }

    private func weekToggleButton(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.body(size: 12, weight: .semibold))
                .foregroundStyle(active ? .white : Theme.Color.fg2)
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(active ? Theme.Color.accent : Color.clear,
                            in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("查看\(title)")
        .accessibilityValue(active ? "已选择" : "未选择")
    }

    // MARK: - 负荷板

    private var boardSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(board.enumerated()), id: \.element.id) { index, entry in
                if index > 0 {
                    Rectangle().fill(Theme.Color.border.opacity(0.55)).frame(height: 1)
                }
                rowWithDetail(for: entry)
            }
        }
        .cardStyle(padding: 14)
    }

    @ViewBuilder
    private func rowWithDetail(for entry: MuscleLoadEntry) -> some View {
        let name = entry.category?.rawValue ?? "其他"
        let isSecondary = entry.category == nil
        let isExpanded = expandedBucketId == entry.id
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedBucketId = isExpanded ? nil : entry.id
                }
            } label: {
                MuscleLoadRowView(
                    name: name,
                    entry: entry,
                    barFraction: Double(entry.workingSets) / Double(maxSets),
                    series: snapshot.series[entry.category],
                    isSecondary: isSecondary
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(name)，\(entry.workingSets) 组，\(formatMuscleLoadVolume(entry.volumeKg))")
            .accessibilityHint("点按\(isExpanded ? "收起" : "展开")贡献明细")

            if isExpanded {
                contributionDetail(for: entry)
                    .padding(.top, 8)
            }
        }
        .padding(.vertical, 8)
    }

    /// 展开面板顶部的较上周对比详情：组数与容量双分量；「其他」桶不参与对比，均持平时不展示；
    /// 上周视图为纯数据回看，不展示对比。
    @ViewBuilder
    private func panelComparisonLine(for entry: MuscleLoadEntry) -> some View {
        if !viewingPreviousWeek, let category = entry.category,
           let text = comparisonText(setsDelta: entry.workingSets - MuscleLoadAggregator.sets(of: category, in: baselineBoard),
                                     volumeDelta: entry.volumeKg - MuscleLoadAggregator.volumeKg(of: category, in: baselineBoard)) {
            Text(text)
                .font(Theme.Font.body(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Color.fg2)
        }
    }

    /// 贡献明细：顶部为较上周对比详情（组数 + 容量），下方按有效组数降序列出各动作的组数与训练量；
    /// 左侧主色竖线标示从属肌群。无贡献时展示空态说明。
    @ViewBuilder
    private func contributionDetail(for entry: MuscleLoadEntry) -> some View {
        let items = contributions[entry.category] ?? []
        VStack(alignment: .leading, spacing: 8) {
            panelComparisonLine(for: entry)
            if items.isEmpty {
                Text(entry.workingSets == 0 ? "本期该肌群还没有完成的正式组。" : "暂无可分解的动作明细。")
                    .font(Theme.Font.body(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Color.muted)
            } else {
                ForEach(items) { item in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(Theme.Color.accentSoft)
                            .frame(width: 3, height: 14)
                        Text(item.exerciseName)
                            .font(Theme.Font.body(size: 12, weight: .medium))
                            .foregroundStyle(Theme.Color.fg2)
                        Spacer(minLength: 8)
                        Text("\(item.workingSets) 组")
                            .font(Theme.Font.mono(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.Color.fg)
                        Text(formatMuscleLoadVolume(item.volumeKg))
                            .font(Theme.Font.mono(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Color.muted)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.leading, 44)
        .padding(.top, 2)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewingPreviousWeek ? "上周没有有效组" : "本周还没有有效组")
                .font(Theme.Font.l2)
                .foregroundStyle(Theme.Color.fg)
            Text("完成一次训练后，这里会展示各肌群的有效组数与趋势。")
                .font(Theme.Font.body(size: 13, weight: .medium))
                .foregroundStyle(Theme.Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
