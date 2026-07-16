import SwiftUI
import UIKit
import Photos

enum WorkoutPosterLayoutKind: String, Equatable {
    case topCompact
    case upperCenter
    case centerReceipt
}

struct WorkoutPosterContext: Equatable {
    let workoutId: UUID
    let hasPersonalRecord: Bool
    let isFromTeamShare: Bool
    let durationMinutes: Int
    let totalVolumeKg: Double
    let setCount: Int
    let exerciseCount: Int
    let structuredUnitCount: Int

    var isHighEffort: Bool {
        durationMinutes >= 60 || setCount >= 20 || totalVolumeKg >= 10_000
    }

    var hasRichOrComplexStructure: Bool {
        exerciseCount >= 5 || structuredUnitCount > 0
    }
}

enum WorkoutPosterBackground: String, Identifiable, Hashable {
    case celebration
    case energyTrail
    case miniGym
    case highFive
    case equipmentWreath

    static let catalog: [Self] = [
        .celebration,
        .energyTrail,
        .miniGym,
        .highFive,
        .equipmentWreath
    ]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .celebration: return "完成庆典台"
        case .energyTrail: return "能量环游轨迹"
        case .miniGym: return "迷你综合训练场"
        case .highFive: return "伙伴击掌"
        case .equipmentWreath: return "训练装备花环"
        }
    }

    var assetName: String {
        switch self {
        case .celebration: return "posterBackgroundCelebration"
        case .energyTrail: return "posterBackgroundEnergyTrail"
        case .miniGym: return "posterBackgroundMiniGym"
        case .highFive: return "posterBackgroundHighFive"
        case .equipmentWreath: return "posterBackgroundEquipmentWreath"
        }
    }

    var layoutKind: WorkoutPosterLayoutKind {
        switch self {
        case .celebration, .miniGym, .highFive: return .topCompact
        case .energyTrail: return .upperCenter
        case .equipmentWreath: return .centerReceipt
        }
    }

    static func resolve(rawValue: String?) -> Self {
        rawValue.flatMap(Self.init(rawValue:)) ?? .equipmentWreath
    }

    static func recommended(for context: WorkoutPosterContext) -> Self {
        if context.hasPersonalRecord { return .celebration }
        if context.isFromTeamShare { return .highFive }
        if context.exerciseCount >= 5, context.isHighEffort {
            return stableChoice(for: context.workoutId, from: [.energyTrail, .miniGym])
        }
        if context.hasRichOrComplexStructure { return .miniGym }
        if context.isHighEffort { return .energyTrail }
        return .equipmentWreath
    }

    static func stableChoice(for workoutId: UUID, from choices: [Self]) -> Self {
        guard !choices.isEmpty else { return .equipmentWreath }

        // 使用固定 FNV-1a 折叠 UUID 字节，避免 Swift hashValue 的跨进程随机种子。
        let hash = withUnsafeBytes(of: workoutId.uuid) { bytes in
            bytes.reduce(UInt64(14_695_981_039_346_656_037)) { partialResult, byte in
                (partialResult ^ UInt64(byte)) &* 1_099_511_628_211
            }
        }
        return choices[Int(hash % UInt64(choices.count))]
    }
}

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
    let context: WorkoutPosterContext

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

        let durationMinutes = Self.durationMinutes(start: workout.timerStartedAt ?? workout.startedAt,
                                                   end: workout.endedAt ?? workout.startedAt)
        self.title = Self.title(for: workout, exercises: exercises)
        self.dateText = Self.dateFormatter.string(from: workout.startedAt)
        self.durationText = "\(durationMinutes)"
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
        self.context = WorkoutPosterContext(
            workoutId: workout.localId,
            hasPersonalRecord: !personalRecords.isEmpty,
            isFromTeamShare: workout.sourceShareId != nil,
            durationMinutes: durationMinutes,
            totalVolumeKg: totalVolume,
            setCount: statSetCount,
            exerciseCount: exercises.count,
            structuredUnitCount: workout.trainingUnits.filter { $0.kind != .singleExercise }.count
        )
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

    private static func durationMinutes(start: Date, end: Date) -> Int {
        max(0, Int(end.timeIntervalSince(start) / 60))
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
    @State private var selectedBackground: WorkoutPosterBackground

    init(workout: Workout, personalRecords: [PersonalRecord]) {
        self.workout = workout
        self.personalRecords = personalRecords
        let posterData = WorkoutPosterData(
            workout: workout,
            personalRecords: personalRecords,
            caloriePreferences: .current()
        )
        _selectedBackground = State(
            initialValue: WorkoutPosterBackground.recommended(for: posterData.context)
        )
    }

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
                    backgroundPicker
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
        WorkoutPosterCanvas(data: data, background: selectedBackground)
            .frame(maxWidth: 320)
            .aspectRatio(WorkoutPosterLayout.aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .paperShadow(.md, cornerRadius: Theme.Radius.lg)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("训练海报预览")
    }

    private var backgroundPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("海报背景")
                    .font(Theme.Font.body(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                Spacer()
                Text(selectedBackground.title)
                    .font(Theme.Font.mono(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Color.muted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(WorkoutPosterBackground.catalog) { background in
                        backgroundOption(background)
                    }
                }
            }
        }
        .frame(maxWidth: 320)
    }

    private func backgroundOption(_ background: WorkoutPosterBackground) -> some View {
        let isSelected = selectedBackground == background
        let isRecommended = recommendedBackground == background
        return Button {
            guard !isSelected else { return }
            Theme.Haptics.selection()
            selectedBackground = background
            hasSavedPoster = false
        } label: {
            VStack(spacing: 6) {
                Image(background.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 88)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                            .stroke(isSelected ? Theme.Color.accent : Theme.Color.border, lineWidth: isSelected ? 2 : 1)
                    )
                Text(background.title)
                    .font(Theme.Font.body(size: 10.5, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.Color.accent : Theme.Color.fg2)
                    .lineLimit(1)
                Text(isRecommended ? "推荐" : " ")
                    .font(Theme.Font.mono(size: 8.5, weight: .bold))
                    .foregroundStyle(isRecommended ? Theme.Color.accent : .clear)
            }
            .padding(6)
            .background(
                isSelected ? Theme.Color.accentSoft : Theme.Color.surface,
                in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(background.title)背景")
        .accessibilityValue([isSelected ? "已选择" : "未选择", isRecommended ? "系统推荐" : nil]
            .compactMap { $0 }
            .joined(separator: "，"))
    }

    private var recommendedBackground: WorkoutPosterBackground {
        WorkoutPosterBackground.recommended(for: data.context)
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
        guard let image = WorkoutPosterImageRenderer.render(data: data, background: selectedBackground) else {
            globalMessage.show("海报生成失败，请稍后重试。", style: .error)
            return
        }
        shareItem = WorkoutPosterShareItem(image: image)
    }

    private func savePoster() async {
        guard !isSaving, !hasSavedPoster else { return }
        isSaving = true
        defer { isSaving = false }

        guard let image = WorkoutPosterImageRenderer.render(data: data, background: selectedBackground) else {
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
    let background: WorkoutPosterBackground

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            WorkoutPosterVisualCardView(data: data,
                                        background: background,
                                        width: width,
                                        height: height)
        }
    }
}

private struct WorkoutPosterBackgroundLayer: View {
    let background: WorkoutPosterBackground

    private let fallback = Color(red: 0.98, green: 0.93, blue: 0.86)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                fallback
                if let image = UIImage(named: background.assetName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct WorkoutPosterVisualCardView: View {
    let data: WorkoutPosterData
    let background: WorkoutPosterBackground
    let width: CGFloat
    let height: CGFloat

    private let receiptPaper = Color(red: 1.0, green: 0.965, blue: 0.91)
    private let warmInk = Color(red: 0.25, green: 0.17, blue: 0.13)
    private let coral = Color(red: 0.91, green: 0.29, blue: 0.18)

    var body: some View {
        ZStack(alignment: .top) {
            WorkoutPosterBackgroundLayer(background: background)

            VStack(spacing: 0) {
                receipt
                    .frame(width: receiptWidth)
                    .padding(.top, receiptTopPadding)

                Spacer(minLength: 0)

                brandSignature
                    .padding(.bottom, 16)
            }
            .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private var receipt: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(data.dateText)
                    .font(Theme.Font.mono(size: 9.5, weight: .bold))
                    .foregroundStyle(warmInk.opacity(0.66))
                    .lineLimit(1)

                Spacer(minLength: 4)

                statusTag
            }

            Text(data.title)
                .font(Theme.Font.display(size: 25, weight: .heavy))
                .foregroundStyle(warmInk)
                .lineLimit(2)
                .minimumScaleFactor(0.76)

            metricRow

            Divider()
                .overlay(warmInk.opacity(0.13))

            exerciseSummary

            if let firstPR = data.prLines.first {
                HStack(spacing: 6) {
                    Text("PR")
                        .font(Theme.Font.mono(size: 9.5, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(coral, in: Capsule())
                    Text("\(firstPR.name) \(firstPR.weightText)")
                        .font(Theme.Font.body(size: 11.5, weight: .bold))
                        .foregroundStyle(warmInk)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .background(
            receiptPaper.opacity(receiptOpacity),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: warmInk.opacity(0.12), radius: 7, x: 0, y: 4)
    }

    private var statusTag: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.system(size: 8, weight: .bold))
            Text(statusTitle)
                .font(Theme.Font.mono(size: 8.5, weight: .heavy))
        }
        .foregroundStyle(coral)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(coral.opacity(0.10), in: Capsule())
    }

    private var statusTitle: String {
        if data.context.hasPersonalRecord { return "PR 新纪录" }
        if data.context.isFromTeamShare { return "TEAM 训练" }
        if data.context.isHighEffort { return "高投入" }
        if data.context.hasRichOrComplexStructure { return "复合训练" }
        return "训练完成"
    }

    private var statusIcon: String {
        if data.context.hasPersonalRecord { return "trophy.fill" }
        if data.context.isFromTeamShare { return "person.2.fill" }
        if data.context.isHighEffort { return "flame.fill" }
        if data.context.hasRichOrComplexStructure { return "square.stack.3d.up.fill" }
        return "checkmark.circle.fill"
    }

    private var metricRow: some View {
        HStack(alignment: .top, spacing: 5) {
            metric(data.durationText, "分钟")
            metric(data.volumeText, "KG·REP")
            metric(data.setCountText, "组")
            if let calorieValueText = data.calorieValueText {
                metric("≈\(calorieValueText)", "KCAL")
            }
        }
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(Theme.Font.number(size: 16, weight: .bold))
                .foregroundStyle(coral)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            Text(label)
                .font(Theme.Font.mono(size: 7.2, weight: .bold))
                .foregroundStyle(warmInk.opacity(0.48))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var exerciseSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            if visibleExerciseLines.isEmpty {
                Text("本次训练已完成")
                    .font(Theme.Font.body(size: 11.5, weight: .semibold))
                    .foregroundStyle(warmInk.opacity(0.72))
            } else {
                ForEach(visibleExerciseLines) { line in
                    HStack(spacing: 6) {
                        if let kind = line.structureKind {
                            Image(systemName: kind.systemImage)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(coral)
                                .frame(width: 12)
                        }
                        Text(line.name)
                            .font(Theme.Font.body(size: 11.5, weight: .semibold))
                            .foregroundStyle(warmInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                        Spacer(minLength: 6)
                        Text(line.topSetText)
                            .font(Theme.Font.mono(size: 10, weight: .bold))
                            .foregroundStyle(warmInk.opacity(0.72))
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                    }
                }
            }

            if hiddenExerciseCount > 0 {
                Text("另有 \(hiddenExerciseCount) 个动作")
                    .font(Theme.Font.mono(size: 9, weight: .bold))
                    .foregroundStyle(coral)
            }
        }
    }

    private var visibleExerciseLines: ArraySlice<WorkoutPosterData.ExerciseLine> {
        data.exerciseLines.prefix(maxExerciseLines)
    }

    private var hiddenExerciseCount: Int {
        max(0, data.exerciseLines.count - visibleExerciseLines.count)
    }

    private var maxExerciseLines: Int {
        background.layoutKind == .centerReceipt ? 4 : 3
    }

    private var receiptWidth: CGFloat {
        switch background.layoutKind {
        case .topCompact: return width * 0.87
        case .upperCenter: return width * 0.79
        case .centerReceipt: return width * 0.78
        }
    }

    private var receiptTopPadding: CGFloat {
        switch background.layoutKind {
        case .topCompact: return height * 0.035
        case .upperCenter: return height * 0.055
        case .centerReceipt: return height * 0.20
        }
    }

    private var receiptOpacity: Double {
        switch background.layoutKind {
        case .topCompact: return 0.88
        case .upperCenter: return 0.90
        case .centerReceipt: return 0.92
        }
    }

    private var brandSignature: some View {
        Text("别练了 · DON'T LIFT")
            .font(Theme.Font.mono(size: 9, weight: .heavy))
            .tracking(0.8)
            .foregroundStyle(warmInk.opacity(0.72))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(receiptPaper.opacity(0.76), in: Capsule())
    }
}

private enum WorkoutPosterLayout {
    static let size = CGSize(width: 360, height: 640)
    static let aspectRatio = size.width / size.height
}

@MainActor
enum WorkoutPosterImageRenderer {
    static func render(data: WorkoutPosterData, background: WorkoutPosterBackground) -> UIImage? {
        let size = WorkoutPosterLayout.size
        let renderer = ImageRenderer(
            content: WorkoutPosterCanvas(data: data, background: background)
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
