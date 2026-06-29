import SwiftUI
import UIKit
import Photos

enum WorkoutPosterStyle: String, CaseIterable, Identifiable {
    case receipt
    case social

    var id: String { rawValue }

    var title: String {
        switch self {
        case .receipt: return "训练收据"
        case .social: return "视觉卡"
        }
    }
}

struct WorkoutPosterData: Equatable {
    struct ExerciseLine: Identifiable, Equatable {
        let id: String
        let name: String
        let setText: String
        let topSetText: String
    }

    struct PRLine: Identifiable, Equatable {
        let id: String
        let name: String
        let weightText: String
    }

    let title: String
    let dateText: String
    let timeText: String
    let durationText: String
    let volumeText: String
    let setCountText: String
    let repCountText: String
    let exerciseCountText: String
    let visibleExercises: [ExerciseLine]
    let hiddenExerciseCount: Int
    let prLines: [PRLine]

    init(workout: Workout, personalRecords: [PersonalRecord] = []) {
        let exercises = workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
        let completedSets = exercises.flatMap(\.sets).filter(\.completed)
        let statSets = completedSets.filter(\.countsForStats)
        let totalVolume = statSets.reduce(0.0) { acc, set in
            acc + (set.weightKg ?? 0) * Double(set.reps ?? 0)
        }
        let totalReps = statSets.reduce(0) { $0 + ($1.reps ?? 0) }

        self.title = Self.title(for: workout, exercises: exercises)
        self.dateText = Self.dateFormatter.string(from: workout.startedAt)
        self.timeText = Self.timeText(start: workout.startedAt, end: workout.endedAt)
        self.durationText = Self.durationText(start: workout.timerStartedAt ?? workout.startedAt,
                                              end: workout.endedAt ?? workout.startedAt)
        self.volumeText = Self.volumeText(totalVolume)
        self.setCountText = "\(completedSets.count)"
        self.repCountText = "\(totalReps)"
        self.exerciseCountText = "\(exercises.count)"

        let lines = exercises.enumerated().map { index, exercise in
            Self.exerciseLine(exercise, index: index)
        }
        self.visibleExercises = Array(lines.prefix(4))
        self.hiddenExerciseCount = max(0, lines.count - visibleExercises.count)
        self.prLines = personalRecords.prefix(3).map {
            PRLine(id: $0.exerciseKey,
                   name: $0.exerciseName,
                   weightText: "\(formatKg($0.weightKg))kg")
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd · EEE"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static func title(for workout: Workout, exercises: [WorkoutExercise]) -> String {
        if let title = trimmed(workout.title) { return title }
        if let title = trimmed(workout.sourcePlanNameSnapshot) { return title }
        if let first = exercises.first?.displayExerciseName { return first }
        return "训练"
    }

    private static func trimmed(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }

    private static func timeText(start: Date, end: Date?) -> String {
        let startText = timeFormatter.string(from: start)
        guard let end else { return startText }
        return "\(startText)-\(timeFormatter.string(from: end))"
    }

    private static func durationText(start: Date, end: Date) -> String {
        let minutes = max(0, Int(end.timeIntervalSince(start) / 60))
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }

    private static func volumeText(_ value: Double) -> String {
        if value >= 10_000 { return String(format: "%.1f万", value / 10_000) }
        if value >= 1000 { return String(format: "%.1fk", value / 1000) }
        return String(format: "%.0f", value)
    }

    private static func exerciseLine(_ exercise: WorkoutExercise, index: Int) -> ExerciseLine {
        let completedSets = exercise.displaySortedSets.filter(\.completed)
        let statSets = completedSets.filter(\.countsForStats)
        let setText = "\(completedSets.count) 组"
        let top = topSet(in: statSets)
        let topText: String
        if let top {
            var parts = ["\(formatKg(top.weightKg))kg"]
            if let reps = top.reps { parts.append("× \(reps)") }
            topText = parts.joined(separator: " ")
        } else {
            topText = "未记录重量"
        }
        return ExerciseLine(id: "\(index)-\(exercise.localId.uuidString)",
                            name: exercise.displayExerciseName,
                            setText: setText,
                            topSetText: topText)
    }

    private static func topSet(in sets: [WorkoutSet]) -> (weightKg: Double, reps: Int?)? {
        var best: (weightKg: Double, reps: Int?)?
        for set in sets {
            guard let weight = set.weightKg else { continue }
            if let current = best {
                if weight > current.weightKg {
                    best = (weight, set.reps)
                }
            } else {
                best = (weight, set.reps)
            }
        }
        return best
    }
}

struct WorkoutPosterPreviewSheet: View {
    let workout: Workout
    let personalRecords: [PersonalRecord]

    @Environment(\.dismiss) private var dismiss
    @State private var style: WorkoutPosterStyle = .receipt
    @State private var shareItem: WorkoutPosterShareItem?
    @State private var isSaving = false
    @State private var message: String?

    private var data: WorkoutPosterData {
        WorkoutPosterData(workout: workout, personalRecords: personalRecords)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 18) {
                        Picker("海报风格", selection: $style) {
                            ForEach(WorkoutPosterStyle.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)

                        posterPreview

                        if let message {
                            Text(message)
                                .font(Theme.Font.body(size: 12, weight: .medium))
                                .foregroundStyle(Theme.Color.fg2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
                    .padding(.bottom, 110)
                }

                actions
            }
            .background(Theme.Color.bg.ignoresSafeArea())
            .paperToolbar(title: "分享海报", onBack: { dismiss() })
            .sheet(item: $shareItem) { item in
                ActivityView(activityItems: [item.image])
            }
        }
    }

    private var posterPreview: some View {
        WorkoutPosterCanvas(data: data, style: style)
            .frame(maxWidth: 360)
            .aspectRatio(4.0 / 5.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .paperShadow(.md, cornerRadius: Theme.Radius.lg)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("训练海报预览")
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                Task { await savePoster() }
            } label: {
                Label(isSaving ? "保存中" : "保存图片", systemImage: "square.and.arrow.down")
                    .font(Theme.Font.body(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Color.border, lineWidth: 1))
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(isSaving)

            Button {
                sharePoster()
            } label: {
                Label("分享", systemImage: "square.and.arrow.up")
                    .font(Theme.Font.body(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .shadow(color: Theme.Color.accent.opacity(0.24), radius: 7, x: 0, y: 4)
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(.ultraThinMaterial)
    }

    private func sharePoster() {
        guard let image = WorkoutPosterImageRenderer.render(data: data, style: style) else {
            message = "海报生成失败，请稍后重试。"
            return
        }
        shareItem = WorkoutPosterShareItem(image: image)
    }

    private func savePoster() async {
        guard let image = WorkoutPosterImageRenderer.render(data: data, style: style) else {
            message = "海报生成失败，请稍后重试。"
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await WorkoutPosterPhotoSaver.save(image)
            message = "已保存到相册。"
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? "保存失败，请检查相册权限。"
        }
    }
}

struct WorkoutPosterShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct WorkoutPosterCanvas: View {
    let data: WorkoutPosterData
    let style: WorkoutPosterStyle

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            switch style {
            case .receipt:
                WorkoutPosterReceiptView(data: data, width: width, height: height)
            case .social:
                WorkoutPosterSocialView(data: data, width: width, height: height)
            }
        }
    }
}

private struct WorkoutPosterReceiptView: View {
    let data: WorkoutPosterData
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("DON'T LIFT")
                        .font(Theme.Font.mono(size: 10, weight: .bold))
                        .foregroundStyle(Theme.Color.accent)
                    Text(data.dateText)
                        .font(Theme.Font.mono(size: 10, weight: .medium))
                        .foregroundStyle(Theme.Color.muted)
                }
                Spacer()
                weakBrandMark
            }

            Text(data.title)
                .font(Theme.Font.display(size: 30, weight: .heavy))
                .foregroundStyle(Theme.Color.fg)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .padding(.top, 24)

            Text(data.timeText)
                .font(Theme.Font.mono(size: 12, weight: .medium))
                .foregroundStyle(Theme.Color.fg2)
                .padding(.top, 6)

            metricGrid
                .padding(.top, 24)

            Divider()
                .background(Theme.Color.border)
                .padding(.vertical, 18)

            exerciseList

            Spacer(minLength: 12)
            footer
        }
        .padding(24)
        .frame(width: width, height: height, alignment: .topLeading)
        .background(Theme.Color.surface)
    }

    private var metricGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                metric("时长", data.durationText)
                metric("容量", data.volumeText)
            }
            HStack(spacing: 10) {
                metric("组数", data.setCountText)
                metric("次数", data.repCountText)
            }
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.Font.mono(size: 9, weight: .bold))
                .foregroundStyle(Theme.Color.muted)
            Text(value)
                .font(Theme.Font.number(size: 23, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.Color.bg, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous).stroke(Theme.Color.border, lineWidth: 1))
    }

    private var exerciseList: some View {
        VStack(spacing: 9) {
            ForEach(data.visibleExercises) { line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(line.name)
                            .font(Theme.Font.body(size: 13, weight: .bold))
                            .foregroundStyle(Theme.Color.fg)
                            .lineLimit(1)
                        Text(line.topSetText)
                            .font(Theme.Font.mono(size: 10, weight: .medium))
                            .foregroundStyle(Theme.Color.fg2)
                    }
                    Spacer(minLength: 8)
                    Text(line.setText)
                        .font(Theme.Font.mono(size: 10, weight: .bold))
                        .foregroundStyle(Theme.Color.muted)
                }
            }
            if data.hiddenExerciseCount > 0 {
                Text("另 \(data.hiddenExerciseCount) 个动作")
                    .font(Theme.Font.mono(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Color.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if data.prLines.isEmpty {
                Text("\(data.exerciseCountText) 个动作已完成")
                    .font(Theme.Font.mono(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Color.muted)
            } else {
                Text("PR +\(data.prLines.count)")
                    .font(Theme.Font.mono(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Color.accent)
            }
            Spacer()
            Text("别练了")
                .font(Theme.Font.body(size: 11, weight: .bold))
                .foregroundStyle(Theme.Color.fg2)
        }
    }

    private var weakBrandMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.Color.border2, lineWidth: 1)
            Image(systemName: "qrcode")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.Color.muted.opacity(0.45))
        }
        .frame(width: 42, height: 42)
        .accessibilityHidden(true)
    }
}

private struct WorkoutPosterSocialView: View {
    let data: WorkoutPosterData
    let width: CGFloat
    let height: CGFloat

    private let ink = Color(red: 0.08, green: 0.075, blue: 0.065)
    private let paper = Color(red: 0.96, green: 0.94, blue: 0.89)

    var body: some View {
        ZStack(alignment: .topLeading) {
            ink
            accentBlock
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(data.dateText)
                        .font(Theme.Font.mono(size: 10, weight: .bold))
                        .foregroundStyle(paper.opacity(0.64))
                    Spacer()
                    weakBrandMark
                }

                Spacer(minLength: 0)

                Text("今天练完了")
                    .font(Theme.Font.mono(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Color.accent)

                Text(data.title)
                    .font(Theme.Font.display(size: 34, weight: .heavy))
                    .foregroundStyle(paper)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)
                    .padding(.top, 7)

                HStack(spacing: 8) {
                    socialMetric(data.durationText, "MIN")
                    socialMetric(data.volumeText, "VOL")
                    socialMetric(data.setCountText, "SETS")
                }
                .padding(.top, 24)

                exerciseList
                    .padding(.top, 22)

                Spacer(minLength: 0)

                footer
            }
            .padding(24)
        }
        .frame(width: width, height: height)
    }

    private var accentBlock: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.Color.accent)
                .frame(width: width * 0.24, height: height)
        }
        .opacity(0.92)
        .offset(x: width * 0.76)
    }

    private func socialMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(Theme.Font.number(size: 22, weight: .bold))
                .foregroundStyle(paper)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(Theme.Font.mono(size: 8.5, weight: .bold))
                .foregroundStyle(paper.opacity(0.52))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var exerciseList: some View {
        VStack(spacing: 8) {
            ForEach(data.visibleExercises) { line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(line.name)
                        .font(Theme.Font.body(size: 13, weight: .semibold))
                        .foregroundStyle(paper)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(line.topSetText)
                        .font(Theme.Font.mono(size: 10, weight: .bold))
                        .foregroundStyle(paper.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            if data.hiddenExerciseCount > 0 {
                Text("+ \(data.hiddenExerciseCount) MORE")
                    .font(Theme.Font.mono(size: 10, weight: .bold))
                    .foregroundStyle(paper.opacity(0.54))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let firstPR = data.prLines.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PR")
                        .font(Theme.Font.mono(size: 9, weight: .bold))
                        .foregroundStyle(Theme.Color.accent)
                    Text("\(firstPR.name) \(firstPR.weightText)")
                        .font(Theme.Font.body(size: 12, weight: .bold))
                        .foregroundStyle(paper)
                        .lineLimit(1)
                }
            } else {
                Text("\(data.exerciseCountText) EXERCISES")
                    .font(Theme.Font.mono(size: 10, weight: .bold))
                    .foregroundStyle(paper.opacity(0.64))
            }
            Spacer()
            Text("别练了")
                .font(Theme.Font.body(size: 11, weight: .bold))
                .foregroundStyle(paper.opacity(0.72))
        }
    }

    private var weakBrandMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(paper.opacity(0.24), lineWidth: 1)
            Image(systemName: "qrcode")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(paper.opacity(0.28))
        }
        .frame(width: 42, height: 42)
        .accessibilityHidden(true)
    }
}

@MainActor
enum WorkoutPosterImageRenderer {
    static func render(data: WorkoutPosterData, style: WorkoutPosterStyle) -> UIImage? {
        let renderer = ImageRenderer(
            content: WorkoutPosterCanvas(data: data, style: style)
                .frame(width: 360, height: 450)
        )
        renderer.scale = 3
        return renderer.uiImage
    }
}

enum WorkoutPosterPhotoSaver {
    enum SaveError: LocalizedError {
        case denied
        case failed

        var errorDescription: String? {
            switch self {
            case .denied: return "未获得相册写入权限。"
            case .failed: return "保存失败，请稍后重试。"
            }
        }
    }

    static func save(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw SaveError.denied }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: SaveError.failed)
                }
            }
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct WorkoutPosterShareButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Color.accent)
                    .frame(width: 38, height: 38)
                    .background(Theme.Color.accentSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("分享训练海报")
                        .font(Theme.Font.body(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Color.fg)
                    Text("生成图片，可保存或发到外部 App")
                        .font(Theme.Font.mono(size: 11))
                        .foregroundStyle(Theme.Color.muted)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Color.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("分享训练海报")
    }
}
