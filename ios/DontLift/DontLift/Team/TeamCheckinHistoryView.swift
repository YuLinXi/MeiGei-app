import SwiftUI

struct TeamCheckinHistoryView: View {
    @Environment(TeamService.self) private var teamService
    @Environment(\.dismiss) private var dismiss

    let team: TeamDTO

    @State private var displayedMonth = Self.initialDisplayedMonth
    @State private var selectedDate = Calendar.currentMondayFirst.startOfDay(for: .now)
    @State private var members: [TeamMemberDTO] = []
    @State private var loadedMonths: [Date: TeamCheckinHistoryMonthData] = [:]
    @State private var loadingMonths: Set<Date> = []
    @State private var openedCheckin: TeamCheckinDTO?
    @State private var error: String?

    private let calendar = Calendar.currentMondayFirst
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    private static var initialDisplayedMonth: Date {
        let calendar = Calendar.currentMondayFirst
        let today = calendar.startOfDay(for: .now)
        let components = calendar.dateComponents([.year, .month], from: today)
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) } ?? today
    }

    private var displayedMonthStart: Date {
        monthStart(for: displayedMonth)
    }

    private var month: CalendarHistoryMonthSnapshot<TeamCheckinHistoryRow> {
        TeamCheckinHistoryModels.monthSnapshot(
            monthStart: displayedMonthStart,
            cachedMonth: loadedMonths[displayedMonthStart],
            memberName: displayName(for:),
            calendar: calendar
        )
    }

    private var archiveGroups: [CalendarHistoryYearArchiveGroup] {
        TeamCheckinHistoryModels.archiveGroups(
            currentMonth: monthStart(for: .now),
            loadedMonths: loadedMonths,
            memberName: displayName(for:),
            calendar: calendar
        )
    }

    private var teamCreatedDate: Date? {
        team.createdAt.map { calendar.startOfDay(for: $0) }
    }

    private var teamCreatedMonthStart: Date? {
        teamCreatedDate.map(monthStart(for:))
    }

    var body: some View {
        CalendarHistoryScaffold(
            displayedMonth: $displayedMonth,
            selectedDate: $selectedDate,
            eyebrow: "Team 历史",
            month: month,
            archiveGroups: archiveGroups,
            calendar: calendar,
            minimumSelectableDate: teamCreatedDate,
            monthSummaryText: { month in
                month.rowCount == 0
                ? "本月没有 Team 训练"
                : "\(month.rowCount) 次训练 · \(month.setCount) 组 · \(formatTons(month.volumeKg)) t"
            },
            selectedSummaryText: { summary in
                summary.map { "\($0.rowCount) 次训练 · \($0.setCount) 组 · \(formatTons($0.volumeKg)) t" } ?? "这天没有 Team 训练"
            },
            emptySelectedDayText: "这天还没有分享到 Team 的训练。",
            daySummaryTitle: dayTitle,
            selectedBadges: { _ in [] },
            rowContent: { row, compact in
                teamCheckinRow(row, compact: compact)
            },
            onRowTap: { row in
                openedCheckin = row.checkin
            },
            selectedDateAfterPickingMonth: selectedDateAfterPickingMonth,
            onMonthChange: { month in
                Task { await load(month: month) }
            }
        )
        .paperToolbar(title: "历史训练", onBack: { dismiss() })
        .overlay(alignment: .top) {
            if loadingMonths.contains(displayedMonthStart) {
                ProgressView()
                    .padding(10)
                    .background(Theme.Color.surface, in: Capsule())
                    .overlay(Capsule().stroke(Theme.Color.border, lineWidth: 1))
                    .padding(.top, 4)
            }
        }
        .refreshable {
            await load(month: displayedMonthStart, force: true)
        }
        .sheet(item: $openedCheckin) { checkin in
            TeamCheckinDetailSheet(checkin: checkin, memberName: displayName(for: checkin.userId))
        }
        .task {
            await loadMembersIfNeeded()
            await load(month: displayedMonthStart)
        }
        .alert("出错了", isPresented: .constant(error != nil)) {
            Button("好") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func loadMembersIfNeeded() async {
        guard members.isEmpty else { return }
        do {
            members = try await teamService.members(of: team.id)
        } catch {
            guard !error.isCancellationError else { return }
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func load(month rawMonth: Date, force: Bool = false) async {
        let month = monthStart(for: rawMonth)
        if let teamCreatedMonthStart, month < teamCreatedMonthStart { return }
        guard force || loadedMonths[month] == nil else { return }
        guard !loadingMonths.contains(month) else { return }
        loadingMonths.insert(month)
        defer { loadingMonths.remove(month) }
        do {
            let feed = try await teamService.checkinHistory(teamId: team.id, month: month)
            loadedMonths[month] = TeamCheckinHistoryMonthData(
                monthStart: month,
                checkins: feed.checkins,
                reactions: feed.reactions
            )
        } catch {
            guard !error.isCancellationError else { return }
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func selectedDateAfterPickingMonth(_ monthStart: Date) -> Date {
        let monthStart = self.monthStart(for: monthStart)
        if calendar.isDate(monthStart, equalTo: .now, toGranularity: .month) {
            return calendar.startOfDay(for: .now)
        }
        if let firstCheckinDay = TeamCheckinHistoryModels
            .monthSnapshot(
                monthStart: monthStart,
                cachedMonth: loadedMonths[monthStart],
                memberName: displayName(for:),
                calendar: calendar
            )
            .days
            .filter(\.isInDisplayedMonth)
            .compactMap({ $0.summary?.date })
            .sorted()
            .first {
            return firstCheckinDay
        }
        return monthStart
    }

    private func dayTitle(_ summary: CalendarHistoryDaySummary<TeamCheckinHistoryRow>) -> String {
        let first = summary.rows.first
        let title = first.map { "\($0.memberName) · \($0.title)" } ?? "Team 训练"
        guard summary.rowCount > 1 else { return title }
        return "\(title) +\(summary.rowCount - 1)"
    }

    private func teamCheckinRow(_ row: TeamCheckinHistoryRow, compact: Bool) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(spacing: 2) {
                Text(Self.timeFormatter.string(from: row.checkin.createdAt ?? row.date))
                    .font(Theme.Font.mono(size: compact ? 10 : 11, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                Text(String(row.memberName.prefix(1)))
                    .font(Theme.Font.body(size: compact ? 9 : 10, weight: .bold))
                    .foregroundStyle(Theme.Color.accent)
            }
            .frame(width: compact ? 48 : 52, height: compact ? 40 : 46)
            .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("\(row.memberName) · \(row.title)")
                    .font(Theme.Font.body(size: compact ? 13 : 14, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                    .lineLimit(1)
                if row.summary == nil {
                    Text("训练快照不可用")
                        .font(Theme.Font.body(size: compact ? 10.5 : 11.5))
                        .foregroundStyle(Theme.Color.muted)
                        .lineLimit(1)
                } else {
                    Text("\(row.exerciseCount) 动作 · \(row.setCount) 组 · \(formatTons(row.volumeKg))t")
                        .font(Theme.Font.body(size: compact ? 10.5 : 11.5))
                        .foregroundStyle(Theme.Color.fg2)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
        }
        .padding(compact ? 8 : 10)
        .background(Theme.Color.bg, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(Theme.Color.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func displayName(for userId: UUID) -> String {
        if let member = members.first(where: { $0.userId == userId }),
           let name = member.displayName,
           !name.isEmpty {
            return name
        }
        return userId == team.ownerUserId ? "队长" : "队友"
    }

    private func monthStart(for date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps).map { calendar.startOfDay(for: $0) } ?? calendar.startOfDay(for: date)
    }
}

struct TeamCheckinDetailSheet: View {
    let checkin: TeamCheckinDTO
    let memberName: String

    private var summary: CheckinSummary? { checkin.decodedSummary }
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            PaperSheetTitleHeader(title: "训练详情", background: Theme.Color.bg)
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header
                    if let summary, !summary.exercises.isEmpty {
                        exerciseList(summary.exercises)
                    } else {
                        snapshotUnavailable
                    }
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .background(Theme.Color.bg.ignoresSafeArea())
        .presentationBackground(Theme.Color.bg)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        let title = summary?.title?.isEmpty == false ? summary?.title ?? "训练" : "训练"
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(String(memberName.prefix(1)))
                    .font(Theme.Font.body(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Color.accent)
                    .frame(width: 34, height: 34)
                    .background(Theme.Color.accentSoft, in: Circle())
                    .overlay(Circle().stroke(Theme.Color.accentSofter, lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(memberName)
                        .font(Theme.Font.body(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Color.fg)
                    Text(checkin.createdAt.map { Self.timeFormatter.string(from: $0) } ?? checkin.checkinDate)
                        .font(Theme.Font.mono(size: 10))
                        .foregroundStyle(Theme.Color.muted)
                }
            }

            Text(title)
                .font(Theme.Font.display(size: 26, weight: .heavy))
                .foregroundStyle(Theme.Color.fg)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            HStack(spacing: 8) {
                statPill(title: "动作", value: summary.map { "\($0.exerciseCount)" } ?? "—")
                statPill(title: "组数", value: summary.map { "\($0.totalSets)" } ?? "—")
                statPill(title: "容量", value: summary.map { formatKg($0.totalVolumeKg) + "kg" } ?? "—")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.Font.mono(size: 13, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
            Text(title)
                .font(Theme.Font.body(size: 10))
                .foregroundStyle(Theme.Color.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

    private func exerciseList(_ exercises: [CheckinSummary.ExerciseSummary]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("动作")
                .eyebrowStyle()
            ForEach(exercises) { exercise in
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(exercise.name)
                        .font(Theme.Font.body(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Color.fg)
                    if exercise.sets.isEmpty {
                        Text("没有组记录")
                            .font(Theme.Font.body(size: 12))
                            .foregroundStyle(Theme.Color.muted)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                                checkinSetRow(set, index: index)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
        }
    }

    @ViewBuilder
    private func checkinSetRow(_ set: CheckinSummary.SetSummary, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("#\(index + 1)")
                    .font(Theme.Font.mono(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Color.muted)
                    .frame(width: 34, alignment: .leading)
                if set.setType == .drop {
                    Text("递减组")
                        .font(Theme.Font.body(size: 11, weight: .bold))
                        .foregroundStyle(Theme.Color.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Theme.Color.accentSofter, in: Capsule())
                } else {
                    setValueLine(weightKg: set.weightKg, reps: set.reps)
                }
                Spacer(minLength: 0)
            }
            if set.setType == .drop {
                ForEach((set.segments ?? []).filter { $0.weightKg != nil || $0.reps != nil }) { segment in
                    HStack {
                        Text("段 \(segment.segmentIndex + 1)")
                            .font(Theme.Font.mono(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.Color.muted)
                            .frame(width: 34, alignment: .leading)
                        setValueLine(weightKg: segment.weightKg, reps: segment.reps)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 34)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.Color.bg, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous).stroke(Theme.Color.border, lineWidth: 1))
    }

    private func setValueLine(weightKg: Double?, reps: Int?) -> some View {
        HStack(spacing: 6) {
            Text(weightKg.map { formatKg($0) + " kg" } ?? "— kg")
                .font(Theme.Font.mono(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
            Text("×")
                .font(Theme.Font.mono(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
            Text(reps.map { "\($0) 次" } ?? "— 次")
                .font(Theme.Font.mono(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
        }
    }

    private var snapshotUnavailable: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.Color.accent)
            Text("训练快照不可用")
                .font(Theme.Font.body(size: 16, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
            Text("这条 Team 打卡的分享快照无法解析，不能展示动作和组详情。")
                .font(Theme.Font.body(size: 13))
                .foregroundStyle(Theme.Color.fg2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
