import SwiftUI
import UIKit

/// 训练结算高光成就庆祝弹窗
struct WorkoutBadgeCelebrationSheet: View {
    let candidates: [BadgeGrantCandidate]
    let summary: String
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var validCandidates: [(candidate: BadgeGrantCandidate, definition: BadgeDefinition)] {
        candidates.compactMap { c in
            guard let def = BadgeDefinition.lookup(c.badgeCode) else { return nil }
            return (c, def)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 36, height: 4)
                        .padding(.top, 8)
                        .accessibilityHidden(true)
                    if validCandidates.count == 1, let item = validCandidates.first {
                        singleBadgeView(candidate: item.candidate, definition: item.definition)
                    } else if !validCandidates.isEmpty {
                        multiBadgeView(items: validCandidates)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(action: handleClose) {
                    Text("收下荣誉")
                        .font(Theme.Font.body(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .frame(minHeight: 50)
                        .background(Theme.Color.action, in: RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color(hex: "E04328").opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .background(Theme.Color.bg)
            }
            .background(Theme.Color.bg.ignoresSafeArea())
            .onAppear { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        }
        .presentationDetents(dynamicTypeSize >= .xxLarge ? [.large]
                             : [.height(validCandidates.count > 1 ? 460 : 470), .large])
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private func singleBadgeView(candidate: BadgeGrantCandidate, definition: BadgeDefinition) -> some View {
        VStack(spacing: 16) {
            // 大勋章图腾
            BadgeIconView(definition: definition, isUnlocked: true, size: .large)
                .accessibilityHidden(true)
                .padding(.top, 12)

            VStack(spacing: 6) {
                Text("新徽章已解锁")
                    .font(Theme.Font.body(size: 15, weight: .bold))
                    .foregroundStyle(Theme.Color.action)

                Text(definition.name)
                    .font(Theme.Font.display(size: 26, weight: .heavy))
                    .foregroundStyle(Theme.Color.fg)

                if !summary.isEmpty {
                    Text(summary)
                        .font(Theme.Font.body(size: 13, weight: .regular))
                        .foregroundStyle(Theme.Color.muted)
                }
            }

            // 达成要求卡片
            VStack(spacing: 8) {
                Text(definition.requirementDescription)
                    .font(Theme.Font.body(size: 14, weight: .medium))
                    .foregroundStyle(Theme.Color.fg)
                    .multilineTextAlignment(.center)

                if candidate.snapshotMetric > 0, definition.unit != "次" {
                    Text("达成记录: \(formatSnapshot(candidate.snapshotMetric, unit: definition.unit))")
                        .font(Theme.Font.body(size: 12, weight: .semibold, relativeTo: .caption))
                        .foregroundStyle(Theme.Color.action)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.Color.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )
        }
    }

    @ViewBuilder
    private func multiBadgeView(items: [(candidate: BadgeGrantCandidate, definition: BadgeDefinition)]) -> some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("新徽章已解锁")
                    .font(Theme.Font.body(size: 15, weight: .bold))
                    .foregroundStyle(Theme.Color.action)
                    .padding(.top, 8)

                Text("同时突破 \(items.count) 项荣誉勋章！")
                    .font(Theme.Font.display(size: 22, weight: .heavy))
                    .foregroundStyle(Theme.Color.fg)

                if !summary.isEmpty {
                    Text(summary)
                        .font(Theme.Font.body(size: 13, weight: .regular))
                        .foregroundStyle(Theme.Color.muted)
                }
            }

            if dynamicTypeSize >= .xxLarge {
                VStack(spacing: 12) {
                    ForEach(items, id: \.candidate.badgeCode) { item in
                        celebrationCard(item.definition)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items, id: \.candidate.badgeCode) { item in
                            celebrationCard(item.definition)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func celebrationCard(_ definition: BadgeDefinition) -> some View {
        VStack(spacing: 8) {
            BadgeIconView(definition: definition, isUnlocked: true, size: .regular)
                .accessibilityHidden(true)
            Text(definition.name)
                .font(Theme.Font.body(size: 13, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
                .fixedSize(horizontal: false, vertical: true)
            Text(definition.requirementDescription)
                .font(Theme.Font.body(size: 10, relativeTo: .caption))
                .foregroundStyle(Theme.Color.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: dynamicTypeSize >= .xxLarge ? nil : 100)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .frame(maxWidth: dynamicTypeSize >= .xxLarge ? .infinity : nil)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.06), lineWidth: 1))
    }

    private func formatSnapshot(_ value: Double, unit: String) -> String {
        if unit == "kg" {
            if value >= 10_000 {
                return "\(Int(value)) kg"
            }
            return String(format: "%.1f kg", value)
        } else if unit.contains("BW") {
            return String(format: "%.2f 倍体重", value)
        } else if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value)) \(unit)"
        } else {
            return String(format: "%.1f \(unit)", value)
        }
    }

    private func handleClose() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onDismiss()
        dismiss()
    }
}
