import SwiftUI

@Observable
final class TeamShareCenter {
    var draft: TeamShareDraft?
    var notice: String?

    func present(_ workout: Workout) {
        draft = TeamShareDraft(workout: workout)
    }

    func presentNotice(_ message: String) {
        notice = message
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

    @Environment(TeamService.self) private var teamService
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var selected = Set<UUID>()
    @State private var isLoadingTeams = true
    @State private var isSubmitting = false
    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Theme.Color.border2)
                .frame(width: 38, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 16)

            VStack(alignment: .leading, spacing: 6) {
                Text("分享至 Team")
                    .font(Theme.Font.display(size: 24, weight: .heavy))
                    .foregroundStyle(Theme.Color.fg)
                Text("默认仅自己可见。选中的 Team 才能看到这次训练摘要和每组记录。")
                    .font(Theme.Font.body(size: 13))
                    .foregroundStyle(Theme.Color.fg2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            content
                .padding(.top, 22)

            if let message {
                Text(message)
                    .font(Theme.Font.body(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Color.fg2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)
            }

            HStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Text("仅自己可见")
                        .font(Theme.Font.body(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Color.fg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)

                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: 6) {
                        if isSubmitting { ProgressView().tint(.white) }
                        Text(selected.isEmpty ? "选择 Team" : "分享 \(selected.count) 个")
                    }
                    .font(Theme.Font.body(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(selected.isEmpty ? Theme.Color.muted : Theme.Color.accent,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
                .buttonStyle(.plain)
                .disabled(selected.isEmpty || isSubmitting)
            }
            .padding(.top, 22)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .presentationBackground(Theme.Color.surface)
        .presentationCornerRadius(24)
        .presentationDetents([.medium])
        .task { await loadTeams() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoadingTeams {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 90)
        } else if teamService.teams.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("还没有 Team")
                    .font(Theme.Font.body(size: 15, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                Text("这次训练会保持仅自己可见。")
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
                                .foregroundStyle(selected.contains(team.id) ? Theme.Color.accent : Theme.Color.muted)
                            Text(team.name)
                                .font(Theme.Font.body(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.Color.fg)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 46)
                        .background(Theme.Color.bg, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Theme.Color.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func loadTeams() async {
        isLoadingTeams = true
        defer { isLoadingTeams = false }
        do { try await teamService.loadMyTeams() }
        catch { message = "Team 列表加载失败，这次可先保持仅自己可见。" }
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
            message = "网络不可用，已记录分享请求；同步成功后会自动重试。"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { dismiss() }
        case .failed:
            message = "分享失败，请确认 Team 状态后重试。"
        }
    }
}
