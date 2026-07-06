import SwiftUI
import UIKit
import Photos

struct WorkoutPosterData: Equatable {
    struct ExerciseLine: Identifiable, Equatable {
        let id: String
        let structureKind: WorkoutStructureIconKind?
        let name: String
        let topSetText: String
    }

    struct PRLine: Identifiable, Equatable {
        let id: String
        let name: String
        let weightText: String
    }

    let title: String
    let dateText: String
    let durationText: String
    let volumeText: String
    let setCountText: String
    let exerciseCountText: String
    let calorieValueText: String?
    let exerciseLines: [ExerciseLine]
    let prLines: [PRLine]

    init(
        workout: Workout,
        personalRecords: [PersonalRecord] = [],
        caloriePreferences: WorkoutCaloriePreferences = WorkoutCaloriePreferences()
    ) {
        let exercises = workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
        let statSets = exercises.flatMap(\.sets).filter(\.countsForStats)
        let totalVolume = statSets.reduce(0.0) { acc, set in
            acc + set.statEntries.reduce(0.0) { entryAcc, entry in
                entryAcc + (entry.weightKg ?? 0) * Double(entry.reps ?? 0)
            }
        }
        let statSetCount = statSets.count

        self.title = Self.title(for: workout, exercises: exercises)
        self.dateText = Self.dateFormatter.string(from: workout.startedAt)
        self.durationText = Self.durationText(start: workout.timerStartedAt ?? workout.startedAt,
                                              end: workout.endedAt ?? workout.startedAt)
        self.volumeText = Self.volumeText(totalVolume)
        self.setCountText = "\(statSetCount)"
        self.exerciseCountText = "\(exercises.count)"
        self.calorieValueText = WorkoutCalorieEstimator
            .estimate(workout: workout, preferences: caloriePreferences)
            .map { String($0.kcal) }

        let lines = Self.exerciseLines(workout: workout)
        self.exerciseLines = lines
        self.prLines = personalRecords.prefix(3).map {
            PRLine(id: $0.exerciseKey,
                   name: $0.exerciseName,
                   weightText: "\(formatKg($0.weightKg))kg")
        }
    }

    private static func exerciseLines(workout: Workout) -> [ExerciseLine] {
        let exercises = workout.exercises.sorted { $0.orderIndex < $1.orderIndex }
        let byId = Dictionary(uniqueKeysWithValues: exercises.map { ($0.localId, $0) })
        return workout.trainingUnits.enumerated().compactMap { index, unit in
            switch unit.kind {
            case .singleExercise, .dropSet:
                guard let id = unit.singleExerciseId, let exercise = byId[id] else { return nil }
                let line = Self.exerciseLine(exercise, index: index)
                guard unit.kind == .dropSet else {
                    return line
                }
                return ExerciseLine(id: line.id,
                                    structureKind: .dropSet,
                                    name: line.name,
                                    topSetText: line.topSetText)
            case .superset:
                let members = unit.superset?.members
                    .sorted { $0.orderIndex < $1.orderIndex }
                    .compactMap { byId[$0.exerciseId] } ?? []
                guard members.count == 2 else { return nil }
                let counts = members.map { member in
                    member.sets.filter(\.countsForStats).count
                }
                let rounds = counts.min() ?? 0
                let actionSets = counts.reduce(0, +)
                return ExerciseLine(id: "\(index)-\(unit.unitId.uuidString)",
                                    structureKind: .superset,
                                    name: "超级组 · \(members[0].displayExerciseName) + \(members[1].displayExerciseName)",
                                    topSetText: "\(rounds) 组 · 共 \(actionSets) 组动作")
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd · EEE"
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

    private static func durationText(start: Date, end: Date) -> String {
        let minutes = max(0, Int(end.timeIntervalSince(start) / 60))
        return "\(minutes)"
    }

    private static func volumeText(_ value: Double) -> String {
        if value >= 10_000 { return String(format: "%.1f万", value / 10_000) }
        if value >= 1000 { return String(format: "%.1fk", value / 1000) }
        return String(format: "%.0f", value)
    }

    private static func exerciseLine(_ exercise: WorkoutExercise, index: Int) -> ExerciseLine {
        let statSets = exercise.displaySortedSets.filter { $0.completed && $0.countsForStats }
        return ExerciseLine(id: "\(index)-\(exercise.localId.uuidString)",
                            structureKind: nil,
                            name: exercise.displayExerciseName,
                            topSetText: topSetText(in: statSets))
    }

    private static func topSetText(in sets: [WorkoutSet]) -> String {
        guard !sets.isEmpty else { return "已完成" }
        let count = sets.count
        if let weighted = topWeightedSet(in: sets) {
            if let reps = weighted.reps {
                return "\(formatKg(weighted.weightKg))kg × \(reps)次 · 共\(count)组"
            }
            return "\(formatKg(weighted.weightKg))kg · 共\(count)组"
        }
        if let reps = sets.flatMap(\.statEntries).compactMap(\.reps).max() {
            return "\(reps)次 · 共\(count)组"
        }
        return "共\(count)组"
    }

    private static func topWeightedSet(in sets: [WorkoutSet]) -> (weightKg: Double, reps: Int?)? {
        var best: (weightKg: Double, reps: Int?)?
        for set in sets {
            guard let entry = set.topStatEntry, let weight = entry.weightKg else { continue }
            if let current = best {
                if weight > current.weightKg {
                    best = (weight, entry.reps)
                }
            } else {
                best = (weight, entry.reps)
            }
        }
        return best
    }
}

struct WorkoutPosterPreviewSheet: View {
    let workout: Workout
    let personalRecords: [PersonalRecord]

    @Environment(GlobalMessageCenter.self) private var globalMessage
    @State private var shareItem: WorkoutPosterShareItem?
    @State private var isSaving = false
    @State private var hasSavedPoster = false

    private var data: WorkoutPosterData {
        WorkoutPosterData(workout: workout,
                          personalRecords: personalRecords,
                          caloriePreferences: .current())
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    posterPreview
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, posterPreviewTopPadding)
                .padding(.bottom, posterPreviewBottomPadding)
                .frame(maxWidth: .infinity)
            }

            actions
        }
        .background(Theme.Color.bg.ignoresSafeArea())
        .presentationBackground(Theme.Color.bg)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(item: $shareItem) { item in
            ActivityView(activityItems: [item.image])
        }
    }

    private var posterPreview: some View {
        WorkoutPosterCanvas(data: data)
            .frame(maxWidth: 360)
            .aspectRatio(WorkoutPosterLayout.aspectRatio(for: data), contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .paperShadow(.md, cornerRadius: Theme.Radius.lg)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("训练海报预览")
    }

    private var posterPreviewTopPadding: CGFloat {
        Theme.Spacing.xl + Theme.Spacing.lg
    }

    private var posterPreviewBottomPadding: CGFloat {
        Theme.Spacing.lg
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                Task { await savePoster() }
            } label: {
                Label(saveButtonTitle, systemImage: saveButtonIcon)
                    .font(Theme.Font.body(size: 14, weight: .bold))
                    .foregroundStyle(saveButtonForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(saveButtonBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(saveButtonBorder, lineWidth: 1))
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(isSaving || hasSavedPoster)

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

    private var saveButtonTitle: String {
        if isSaving { return "保存中" }
        if hasSavedPoster { return "已保存" }
        return "保存图片"
    }

    private var saveButtonIcon: String {
        hasSavedPoster ? "checkmark.circle" : "square.and.arrow.down"
    }

    private var saveButtonForeground: Color {
        if isSaving { return Theme.Color.muted }
        if hasSavedPoster { return Theme.Color.ok }
        return Theme.Color.fg
    }

    private var saveButtonBackground: Color {
        if isSaving { return Theme.Color.surface2.opacity(0.72) }
        if hasSavedPoster { return Theme.Color.ok.opacity(0.10) }
        return Theme.Color.surface
    }

    private var saveButtonBorder: Color {
        hasSavedPoster ? Theme.Color.ok.opacity(0.22) : Theme.Color.border
    }

    private func sharePoster() {
        guard let image = WorkoutPosterImageRenderer.render(data: data) else {
            globalMessage.show("海报生成失败，请稍后重试。", style: .error)
            return
        }
        shareItem = WorkoutPosterShareItem(image: image)
    }

    private func savePoster() async {
        guard !isSaving, !hasSavedPoster else { return }
        isSaving = true
        defer { isSaving = false }

        guard let image = WorkoutPosterImageRenderer.render(data: data) else {
            globalMessage.show("海报生成失败，请稍后重试。", style: .error)
            return
        }
        do {
            try await WorkoutPosterPhotoSaver.save(image)
            hasSavedPoster = true
            globalMessage.show("已保存到相册", style: .success)
        } catch {
            let text = (error as? LocalizedError)?.errorDescription ?? "保存失败，请检查相册权限。"
            globalMessage.show(text, style: .error)
        }
    }
}

struct WorkoutPosterShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct WorkoutPosterCanvas: View {
    let data: WorkoutPosterData

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            WorkoutPosterVisualCardView(data: data, width: width, height: height)
        }
    }
}

private struct WorkoutPosterVisualCardView: View {
    let data: WorkoutPosterData
    let width: CGFloat
    let height: CGFloat

    private let ink = Color(red: 0.08, green: 0.075, blue: 0.065)
    private let paper = Color(red: 0.96, green: 0.94, blue: 0.89)

    var body: some View {
        ZStack(alignment: .topLeading) {
            ink
            accentBlock
            rightRail
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("别练了")
                            .font(Theme.Font.body(size: 12, weight: .heavy))
                            .foregroundStyle(paper)
                        Text(data.dateText)
                            .font(Theme.Font.mono(size: 10, weight: .bold))
                            .foregroundStyle(paper.opacity(0.64))
                    }
                    Spacer()
                }

                Spacer(minLength: 0)

                Text("弱者在舒适区冬眠，强者在风雪中冬训。")
                    .font(Theme.Font.mono(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Color.accent)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .frame(width: blackContentWidth, alignment: .leading)

                Text(data.title)
                    .font(Theme.Font.display(size: 34, weight: .heavy))
                    .foregroundStyle(paper)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)
                    .padding(.top, 7)

                HStack(spacing: 8) {
                    if let calorieValueText = data.calorieValueText {
                        calorieMetric(calorieValueText)
                    }
                    visualMetric(data.durationText, "时长", unit: "min")
                    visualMetric(data.volumeText, "训练量", unit: "kg·rep")
                }
                .padding(.top, 24)

                exerciseList
                    .padding(.top, 22)
                    .frame(width: blackContentWidth, alignment: .leading)

                Spacer(minLength: 0)

                footer
                    .frame(width: blackContentWidth, alignment: .leading)
            }
            .padding(24)
        }
        .frame(width: width, height: height)
    }

    private var accentBlock: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.Color.accent)
                .frame(width: railWidth, height: height)
        }
        .opacity(0.92)
        .offset(x: width - railWidth)
    }

    private var rightRail: some View {
        VStack(spacing: 0) {
            rightRailQRCode
                .padding(.top, 30)

            Spacer(minLength: 28)

            Text("DON'T LIFT")
                .font(Theme.Font.mono(size: 14, weight: .heavy))
                .foregroundStyle(paper.opacity(0.72))
                .tracking(2.2)
                .rotationEffect(.degrees(90))
                .fixedSize()
                .frame(width: railWidth, height: 132)

            Spacer(minLength: 28)

            Text("WORKOUT LOG")
                .font(Theme.Font.mono(size: 8.5, weight: .bold))
                .foregroundStyle(paper.opacity(0.38))
                .tracking(1.3)
                .rotationEffect(.degrees(90))
                .fixedSize()
                .frame(width: railWidth, height: 86)
                .padding(.bottom, 30)
        }
        .frame(width: railWidth, height: height)
        .offset(x: width - railWidth)
        .accessibilityHidden(true)
    }

    private func visualMetric(_ value: String, _ label: String, unit: String? = nil, highlighted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(Theme.Font.number(size: 22, weight: .bold))
                .foregroundStyle(highlighted ? Theme.Color.accent : paper)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(label)
                    .font(Theme.Font.mono(size: 9.5, weight: .bold))
                    .foregroundStyle(highlighted ? Theme.Color.accent.opacity(0.74) : paper.opacity(0.52))
                if let unit {
                    Text("(\(unit))")
                        .font(Theme.Font.mono(size: 7.2, weight: .bold))
                        .foregroundStyle(highlighted ? Theme.Color.accent.opacity(0.54) : paper.opacity(0.42))
                }
            }
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func calorieMetric(_ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("≈")
                    .font(Theme.Font.number(size: 14, weight: .bold))
                Text(value)
                    .font(Theme.Font.number(size: 22, weight: .bold))
            }
            .foregroundStyle(Theme.Color.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("消耗")
                    .font(Theme.Font.mono(size: 9.5, weight: .bold))
                    .foregroundStyle(Theme.Color.accent.opacity(0.74))
                Text("(kcal)")
                    .font(Theme.Font.mono(size: 7.2, weight: .bold))
                    .foregroundStyle(Theme.Color.accent.opacity(0.54))
            }
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var exerciseList: some View {
        VStack(spacing: exerciseRowSpacing) {
            ForEach(data.exerciseLines) { line in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    HStack(spacing: 6) {
                        if let kind = line.structureKind {
                            WorkoutStructureIcon(kind: kind, size: 18, symbolSize: 9)
                        }
                        Text(line.name)
                            .font(Theme.Font.body(size: exerciseNameFontSize, weight: .semibold))
                            .foregroundStyle(paper)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                    .frame(width: exerciseNameColumnWidth, alignment: .leading)
                    Text(line.topSetText)
                        .font(Theme.Font.mono(size: exerciseValueFontSize, weight: .bold))
                        .foregroundStyle(paper.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                }
            }
        }
    }

    private var exerciseRowSpacing: CGFloat {
        data.exerciseLines.count > 8 ? 6 : 8
    }

    private var exerciseNameFontSize: CGFloat {
        data.exerciseLines.count > 8 ? 13.5 : 14.5
    }

    private var exerciseValueFontSize: CGFloat {
        data.exerciseLines.count > 8 ? 12.5 : 13.5
    }

    private var exerciseNameColumnWidth: CGFloat {
        min(86, blackContentWidth * 0.38)
    }

    private var blackContentWidth: CGFloat {
        max(180, width - railWidth - 58)
    }

    private var railWidth: CGFloat {
        width * 0.24
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
                Text("\(data.exerciseCountText) 个动作")
                    .font(Theme.Font.mono(size: 11, weight: .bold))
                    .foregroundStyle(paper.opacity(0.64))
            }
            Spacer()
        }
    }

    private var rightRailQRCode: some View {
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

private enum WorkoutPosterLayout {
    private static let baseWidth: CGFloat = 360
    private static let baseHeight: CGFloat = 450

    static func size(for data: WorkoutPosterData) -> CGSize {
        let extraExercises = max(0, data.exerciseLines.count - 4)
        return CGSize(width: baseWidth, height: baseHeight + CGFloat(extraExercises * 28))
    }

    static func aspectRatio(for data: WorkoutPosterData) -> CGFloat {
        let size = size(for: data)
        return size.width / size.height
    }
}

@MainActor
enum WorkoutPosterImageRenderer {
    static func render(data: WorkoutPosterData) -> UIImage? {
        let size = WorkoutPosterLayout.size(for: data)
        let renderer = ImageRenderer(
            content: WorkoutPosterCanvas(data: data)
                .frame(width: size.width, height: size.height)
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
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(x: controller.view.bounds.midX,
                                        y: controller.view.bounds.midY,
                                        width: 1,
                                        height: 1)
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        if let popover = uiViewController.popoverPresentationController {
            popover.sourceView = uiViewController.view
            popover.sourceRect = CGRect(x: uiViewController.view.bounds.midX,
                                        y: uiViewController.view.bounds.midY,
                                        width: 1,
                                        height: 1)
        }
    }
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
