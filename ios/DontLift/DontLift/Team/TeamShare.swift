import SwiftUI

@Observable
final class TeamShareCenter {
    var draft: TeamShareDraft?

    func present(_ workout: Workout) {
        draft = TeamShareDraft(workout: workout)
    }
}

struct TeamShareDraft: Identifiable, Codable, Hashable {
    var workoutId: UUID
    var checkinDate: String
    var summary: CheckinSummary
    var updatedAt: Date
    var workoutSyncStatusRaw: String

    var id: UUID { workoutId }
    var isWorkoutSynced: Bool { workoutSyncStatusRaw == SyncStatus.synced.rawValue }

    init(workout: Workout) {
        self.workoutId = workout.localId
        self.checkinDate = TeamService.dateOnly(workout.startedAt)
        self.summary = CheckinSummary(workout: workout)
        self.updatedAt = workout.updatedAt
        self.workoutSyncStatusRaw = workout.syncStatus.rawValue
    }
}

struct TeamShareSheet: View {
    let draft: TeamShareDraft

    @Environment(SyncEngine.self) private var syncEngine
    @Environment(TeamService.self) private var teamService
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selected = Set<UUID>()
    @State private var isLoadingTeams = true
    @State private var teamLoadFailed = false
    @State private var isSubmitting = false
    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            PaperSheetHandle()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("分享至 Team")
                            .font(Theme.Font.display(size: 24, weight: .heavy))
                            .foregroundStyle(Theme.Color.fg)
                        Text("选择 Team 发送或更新这次训练快照。取消不会撤回已经分享的内容。")
                            .font(Theme.Font.body(size: 13))
                            .foregroundStyle(Theme.Color.fg2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    content
                    if let message {
                        Text(message)
                            .font(Theme.Font.body(size: 12, weight: .medium))
                            .foregroundStyle(Theme.Color.fg2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            shareActions
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
        }
        .presentationBackground(Theme.Color.surface)
        .presentationCornerRadius(24)
        .presentationDetents(dynamicTypeSize >= .xxLarge ? [.large] : [.medium, .large])
        .presentationDragIndicator(.hidden)
        .accessibilityAction(.escape) { dismiss() }
        .task { await loadTeams() }
    }

    private var shareActions: some View {
        let layout = dynamicTypeSize >= .xxLarge
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            Button { dismiss() } label: {
                Text("取消")
                    .font(Theme.Font.body(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .frame(minHeight: 48)
                    .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
            .accessibilityLabel("取消本次分享")
            .accessibilityIdentifier("team.share.cancel")

            Button { Task { await submit() } } label: {
                HStack(spacing: 6) {
                    if isSubmitting { ProgressView().tint(.white) }
                    Text(selected.isEmpty ? "选择 Team" : "分享 \(selected.count) 个")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(Theme.Font.body(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .frame(minHeight: 48)
                .background(selected.isEmpty ? Theme.Color.muted : Theme.Color.action,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
            }
            .buttonStyle(.plain)
            .disabled(selected.isEmpty || isSubmitting)
            .accessibilityIdentifier("team.share.submit")
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoadingTeams {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 90)
        } else if teamLoadFailed {
            VStack(alignment: .leading, spacing: 12) {
                Text("未能加载 Team，请重试或取消本次分享。")
                    .font(Theme.Font.body(size: 13))
                    .foregroundStyle(Theme.Color.fg2)
                    .fixedSize(horizontal: false, vertical: true)
                Button("重试加载 Team") { Task { await loadTeams() } }
                    .font(Theme.Font.body(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Color.action)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
            }
        } else if teamService.teams.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("还没有 Team")
                    .font(Theme.Font.body(size: 15, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                Text("加入 Team 后，可在这里选择发送或更新训练快照。")
                    .font(Theme.Font.body(size: 13))
                    .foregroundStyle(Theme.Color.fg2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.Color.bg, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.Color.border, lineWidth: 1))
        } else {
            VStack(spacing: 8) {
                ForEach(teamService.teams) { team in
                    Button {
                        if selected.contains(team.id) { selected.remove(team.id) }
                        else { selected.insert(team.id) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selected.contains(team.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(selected.contains(team.id) ? Theme.Color.action : Theme.Color.muted)
                                .accessibilityHidden(true)
                            Text(team.name)
                                .font(Theme.Font.body(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.Color.fg)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(minHeight: 48)
                        .background(Theme.Color.bg, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Theme.Color.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(team.name)
                    .accessibilityAddTraits(selected.contains(team.id) ? .isSelected : [])
                    .accessibilityIdentifier("team.share.target.\(team.id.uuidString)")
                }
            }
        }
    }

    private func loadTeams() async {
        isLoadingTeams = true
        teamLoadFailed = false
        defer { isLoadingTeams = false }
        do { try await teamService.loadMyTeams() }
        catch {
            guard !error.isCancellationError else { return }
            teamLoadFailed = true
        }
    }

    private func submit() async {
        guard !selected.isEmpty else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        let result = await teamService.shareOrQueue(draft: draft, teamIds: Array(selected), userId: session.currentUserId)
        switch result {
        case .privateOnly:
            dismiss()
        case .shared:
            dismiss()
        case .queued:
            message = "已记录分享请求；同步成功后会自动重试。"
            Task { await syncEngine.syncAll() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { dismiss() }
        case .cancelled:
            break
        case .failed:
            message = "分享失败，请确认 Team 状态后重试。"
        }
    }
}
