import SwiftUI

/// 5.8 训练分享海报：客户端用结构化数据本地渲染（design.md D8），服务端不参与排版。
/// 入口在打卡详情与训练完成页，数据统一来自 CheckinSummary。
struct SharePosterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    let summary: CheckinSummary
    @State private var rendered: Image?

    var body: some View {
        NavigationStack {
            ScrollView {
                SharePosterView(summary: summary)
                    .padding()
            }
            .navigationTitle("训练海报")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    if let rendered {
                        ShareLink(item: rendered, preview: SharePreview("训练海报", image: rendered)) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        ProgressView()
                    }
                }
            }
            .task { renderImage() }
        }
    }

    @MainActor
    private func renderImage() {
        let renderer = ImageRenderer(content: SharePosterView(summary: summary).frame(width: 360))
        renderer.scale = displayScale
        if let ui = renderer.uiImage {
            rendered = Image(uiImage: ui)
        }
    }
}

/// 海报视觉。固定宽度、深色渐变卡片 + 大字统计 + 动作清单。
struct SharePosterView: View {
    let summary: CheckinSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateText).font(.caption).foregroundStyle(.white.opacity(0.7))
                Text(summary.title ?? "训练完成").font(.title.bold()).foregroundStyle(.white)
            }

            HStack(spacing: 0) {
                stat("\(summary.exerciseCount)", "动作")
                divider
                stat("\(summary.totalSets)", "组")
                if summary.totalVolumeKg > 0 {
                    divider
                    stat(formatKg(summary.totalVolumeKg), "kg 容量")
                }
            }

            if !summary.exercises.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(summary.exercises) { ex in
                        HStack {
                            Text(ex.name).foregroundStyle(.white)
                            Spacer()
                            Text(bestSet(ex)).foregroundStyle(.white.opacity(0.8)).font(.callout)
                        }
                    }
                }
                .padding(.top, 4)
            }

            HStack {
                Image(systemName: "figure.strengthtraining.traditional").foregroundStyle(.white.opacity(0.8))
                Text("MeiGei").font(.headline).foregroundStyle(.white)
                Spacer()
                if let d = durationText { Text(d).font(.caption).foregroundStyle(.white.opacity(0.7)) }
            }
        }
        .padding(24)
        .background(
            LinearGradient(colors: [Color(red: 0.10, green: 0.12, blue: 0.20),
                                    Color(red: 0.20, green: 0.10, blue: 0.30)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: 36).padding(.horizontal, 12)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title.bold().monospacedDigit()).foregroundStyle(.white)
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.7))
        }
    }

    /// 取该动作完成组里容量最高的一组作展示亮点。
    private func bestSet(_ ex: CheckinSummary.ExerciseSummary) -> String {
        let best = ex.sets.max { a, b in
            ((a.weightKg ?? 0) * Double(a.reps ?? 0)) < ((b.weightKg ?? 0) * Double(b.reps ?? 0))
        }
        guard let best, let w = best.weightKg, let r = best.reps else { return "\(ex.sets.count) 组" }
        return "\(formatKg(w)) kg × \(r)"
    }

    private var dateText: String {
        (summary.startedAt ?? .now).formatted(date: .long, time: .omitted)
    }

    private var durationText: String? {
        guard let s = summary.startedAt, let e = summary.endedAt, e > s else { return nil }
        let mins = Int(e.timeIntervalSince(s) / 60)
        return mins >= 60 ? "\(mins / 60)h\(mins % 60)m" : "\(mins) 分钟"
    }
}
