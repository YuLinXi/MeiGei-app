import SwiftUI
import SwiftData

/// 严肃力量成就徽章馆二级全屏页
struct BadgeWallView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BadgeGrant.unlockedAt, order: .reverse) private var allGrants: [BadgeGrant]
    @Query(sort: \Workout.startedAt, order: .forward) private var rawWorkouts: [Workout]

    private var allWorkouts: [Workout] {
        rawWorkouts.filter { $0.deletedAt == nil && $0.endedAt != nil }
    }

    @State private var selectedBadge: BadgeProgress?
    @State private var openedWorkout: Workout?
    @State private var showingWeightSheet: Bool = false
    @State private var caloriePreferences = WorkoutCaloriePreferences.current()

    private var progressList: [BadgeProgress] {
        BadgeEngine.calculateProgress(
            allFinishedWorkouts: allWorkouts,
            grants: allGrants,
            currentWeight: caloriePreferences.bodyWeightKg
        )
    }

    private var unlockedCount: Int {
        progressList.filter(\.isUnlocked).count
    }

    private var totalCount: Int {
        BadgeDefinition.all.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 1. 顶部总览卡片
                summaryHeaderCard

                // 2. 按四大板块分节呈现
                ForEach(BadgeCategory.allCases) { category in
                    categorySection(category: category)
                }

                Color.clear.frame(height: 32)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(Theme.Color.bg.ignoresSafeArea())
        .navigationTitle("成就勋章馆")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .navigationDestination(item: $openedWorkout) { workout in
            WorkoutDetailView(workout: workout)
        }
        .sheet(item: $selectedBadge) { progress in
            badgeDetailSheet(progress: progress)
        }
        .sheet(isPresented: $showingWeightSheet) {
            CalorieBodyWeightSheet(
                currentWeight: caloriePreferences.bodyWeightKg,
                enableAfterSave: false,
                onSave: { kg, _ in
                    WorkoutCaloriePreferences.setBodyWeightKg(kg)
                    caloriePreferences = WorkoutCaloriePreferences.current()
                    BadgeEngine.runBackfillIfNeeded(in: modelContext, force: true)
                }
            )
        }
        .onAppear {
            caloriePreferences = WorkoutCaloriePreferences.current()
            BadgeEngine.runBackfillIfNeeded(in: modelContext)
        }
        .task {
            BadgeEngine.runBackfillIfNeeded(in: modelContext)
            #if DEBUG
            if let targetId = UITestHooks.testBadgeDetailId {
                try? await Task.sleep(for: .milliseconds(350))
                if let match = progressList.first(where: { $0.definition.id == targetId }) {
                    selectedBadge = match
                }
            }
            #endif
        }
    }

    // MARK: - 顶部总览卡片

    private var summaryHeaderCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL BADGES UNLOCKED")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Color(hex: "E04328"))

                    Text("已点亮荣誉刻度")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.primary)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(unlockedCount)")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.primary)
                    Text("/ \(totalCount)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.secondary)
                }
            }

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "E04328"), Color(hex: "FF6E54")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, geo.size.width * CGFloat(unlockedCount) / CGFloat(totalCount)), height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text("完成率 \(Int((Double(unlockedCount) / Double(totalCount) * 100).rounded()))%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.secondary)
                Spacer()
                Text("24 枚独立不折叠")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - 分类 Section 与 3 列网格

    private func categorySection(category: BadgeCategory) -> some View {
        let categoryItems = progressList.filter { $0.definition.category == category }
        let categoryUnlocked = categoryItems.filter(\.isUnlocked).count

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.primary)
                    Text(category.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                Text("\(categoryUnlocked) / \(categoryItems.count)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(hex: "E04328"))
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(categoryItems, id: \.definition.code) { item in
                    badgeGridCell(item: item)
                }
            }
        }
    }

    private func badgeGridCell(item: BadgeProgress) -> some View {
        Button {
            selectedBadge = item
        } label: {
            VStack(spacing: 8) {
                BadgeIconView(
                    definition: item.definition,
                    isUnlocked: item.isUnlocked,
                    size: .regular
                )
                .padding(.top, 4)

                VStack(spacing: 2) {
                    Text(item.definition.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(item.isUnlocked ? Color.primary : Color.secondary)
                        .lineLimit(1)

                    if item.isUnlocked {
                        if let grant = item.grant {
                            Text(grant.unlockedAt.formatted(date: .numeric, time: .omitted))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color(hex: "E04328"))
                                .lineLimit(1)
                        } else {
                            Text("已达成")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(hex: "E04328"))
                        }
                    } else {
                        if item.progressRatio > 0 {
                            Text("\(Int(item.progressRatio * 100))%")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.secondary)
                        } else if item.progressText.contains("完善体重") {
                            Text("待完善体重")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.secondary.opacity(0.8))
                        } else {
                            Text("未解锁")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.secondary.opacity(0.7))
                        }
                    }
                }

                // 进度微条
                if !item.isUnlocked {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 3)
                        .overlay(
                            GeometryReader { g in
                                Capsule()
                                    .fill(Color(hex: "E04328").opacity(0.6))
                                    .frame(width: g.size.width * CGFloat(item.progressRatio), height: 3)
                            },
                            alignment: .leading
                        )
                        .padding(.horizontal, 10)
                        .padding(.bottom, 6)
                } else {
                    Color.clear.frame(height: 3).padding(.bottom, 6)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(item.isUnlocked ? Theme.Color.surface : Theme.Color.surface.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(item.isUnlocked ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 勋章详情弹窗

    @ViewBuilder
    private func badgeDetailSheet(progress: BadgeProgress) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 36, height: 4)
                    .padding(.top, 8)

                BadgeIconView(
                    definition: progress.definition,
                    isUnlocked: progress.isUnlocked,
                    size: .large
                )
                .padding(.top, 8)

                VStack(spacing: 6) {
                    Text(progress.definition.category.displayName)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Color(hex: "E04328"))

                    Text(progress.definition.name)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(Color.primary)

                    Text(progress.definition.requirementDescription)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // 达成/未达成进度与快照卡片
                VStack(spacing: 10) {
                    if progress.isUnlocked {
                        if let grant = progress.grant {
                            HStack {
                                Text("解锁时间")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.secondary)
                                Spacer()
                                Text(grant.unlockedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Color.primary)
                            }
                            if grant.snapshotMetric > 0 {
                                HStack {
                                    Text("达成记录")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.secondary)
                                    Spacer()
                                    Text(formatSnapshot(grant.snapshotMetric, unit: progress.definition.unit))
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color(hex: "E04328"))
                                }
                            }
                        }
                    } else {
                        HStack {
                            Text("当前进度")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.secondary)
                            Spacer()
                            Text(progress.progressText)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color(hex: "E04328"))
                        }

                        ProgressView(value: progress.progressRatio)
                            .tint(Color(hex: "E04328"))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.Color.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)

                Spacer()

                // 操作按钮
                if progress.isUnlocked, let grant = progress.grant, let workoutId = grant.workoutId {
                    Button {
                        if let found = allWorkouts.first(where: { $0.localId == workoutId }) {
                            selectedBadge = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                openedWorkout = found
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("查看当日训练")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(hex: "E04328"))
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                } else if !progress.isUnlocked && progress.progressText.contains("完善体重") {
                    Button {
                        selectedBadge = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showingWeightSheet = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "scalemass")
                            Text("完善体重数据以开启")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(hex: "E04328"))
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                } else {
                    Button {
                        selectedBadge = nil
                    } label: {
                        Text("关闭")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Theme.Color.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }
            .background(Theme.Color.bg.ignoresSafeArea())
        }
        .presentationDetents([.height(440)])
        .presentationDragIndicator(.hidden)
    }

    private func formatSnapshot(_ value: Double, unit: String) -> String {
        if unit == "kg" {
            if value >= 10_000 {
                return "\(Int(value)) kg"
            }
            return String(format: "%.1f kg", value)
        } else if unit.contains("BW") {
            return String(format: "%.2f x BW", value)
        } else if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value)) \(unit)"
        } else {
            return String(format: "%.1f \(unit)", value)
        }
    }
}

extension BadgeProgress: Identifiable {
    var id: String { definition.code }
}
