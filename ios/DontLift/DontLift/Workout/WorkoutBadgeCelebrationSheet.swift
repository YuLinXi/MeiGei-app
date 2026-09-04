import SwiftUI
import UIKit

/// 训练结算高光成就庆祝弹窗
struct WorkoutBadgeCelebrationSheet: View {
    let candidates: [BadgeGrantCandidate]
    let summary: String
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var validCandidates: [(candidate: BadgeGrantCandidate, definition: BadgeDefinition)] {
        candidates.compactMap { c in
            guard let def = BadgeDefinition.lookup(c.badgeCode) else { return nil }
            return (c, def)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 顶部抓手指示
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 36, height: 4)
                    .padding(.top, 8)

                if validCandidates.count == 1, let item = validCandidates.first {
                    singleBadgeView(candidate: item.candidate, definition: item.definition)
                } else if !validCandidates.isEmpty {
                    multiBadgeView(items: validCandidates)
                }

                Spacer()

                // 底部 CTA
                Button(action: handleClose) {
                    Text("收下荣誉")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(hex: "E04328"))
                        )
                        .shadow(color: Color(hex: "E04328").opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 16)
            .background(Theme.Color.bg.ignoresSafeArea())
            .onAppear {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
        .presentationDetents([.height(validCandidates.count > 1 ? 460 : 470)])
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private func singleBadgeView(candidate: BadgeGrantCandidate, definition: BadgeDefinition) -> some View {
        VStack(spacing: 16) {
            // 大勋章图腾
            BadgeIconView(definition: definition, isUnlocked: true, size: .large)
                .padding(.top, 12)

            VStack(spacing: 6) {
                Text("NEW BADGE UNLOCKED")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color(hex: "E04328"))

                Text(definition.name)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Color.primary)

                if !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                }
            }

            // 达成要求卡片
            VStack(spacing: 8) {
                Text(definition.requirementDescription)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.center)

                if candidate.snapshotMetric > 0 {
                    Text("达成记录: \(formatSnapshot(candidate.snapshotMetric, unit: definition.unit))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "E04328"))
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
                Text("NEW ACHIEVEMENTS UNLOCKED")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color(hex: "E04328"))
                    .padding(.top, 8)

                Text("同时突破 \(items.count) 项荣誉勋章！")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Color.primary)

                if !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items, id: \.candidate.badgeCode) { item in
                        let def = item.definition
                        VStack(spacing: 8) {
                            BadgeIconView(definition: def, isUnlocked: true, size: .regular)

                                Text(def.name)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.primary)

                                Text(def.requirementDescription)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(width: 100)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 10)
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
                .padding(.horizontal, 8)
            }
        }
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

    private func handleClose() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onDismiss()
        dismiss()
    }
}
