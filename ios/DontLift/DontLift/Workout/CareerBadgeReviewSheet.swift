import SwiftUI
import UIKit

/// 老用户首次升级生涯回顾汇总弹窗
struct CareerBadgeReviewSheet: View {
    let grants: [BadgeGrant]
    let totalTonnage: Double
    let workoutCount: Int
    let big3: (bench: Double?, squat: Double?, deadlift: Double?)
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var big3TotalText: String {
        guard let b = big3.bench, let s = big3.squat, let d = big3.deadlift else {
            return "—"
        }
        return "\(Int(b + s + d)) kg"
    }

    private var formattedTonnage: String {
        if totalTonnage >= 1_000_000 {
            return String(format: "%.2f M", totalTonnage / 1_000_000)
        } else if totalTonnage >= 10_000 {
            return String(format: "%.1f k", totalTonnage / 1_000)
        } else {
            return "\(Int(totalTonnage))"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. 顶部桂冠印记与标题
                    VStack(spacing: 8) {
                        Image(systemName: "laurel.leading")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "E04328"), Color(hex: "FF6E54")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(.top, 8)

                        Text("力量生涯成就回顾")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.primary)

                        Text("你的每一次向心收缩与流淌汗水，皆已被刻度量化")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    // 2. 生涯核心数据卡片
                    HStack(spacing: 12) {
                        statCell(
                            title: "累计总吨位",
                            value: formattedTonnage,
                            unit: totalTonnage >= 10_000 ? "吨级" : "kg"
                        )
                        statCell(
                            title: "总训练次数",
                            value: "\(workoutCount)",
                            unit: "次"
                        )
                        statCell(
                            title: "三大项总成绩",
                            value: big3TotalText,
                            unit: ""
                        )
                    }
                    .padding(.horizontal, 16)

                    // 3. 已点亮徽章橱窗
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("已为你点亮 \(grants.count) 枚荣誉勋章")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.primary)
                            Spacer()
                            Text("一次性解锁")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "E04328"))
                        }
                        .padding(.horizontal, 16)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 14
                        ) {
                            ForEach(grants, id: \.badgeCode) { grant in
                                if let def = grant.definition {
                                    VStack(spacing: 6) {
                                        BadgeIconView(definition: def, isUnlocked: true, size: .regular)

                                        Text(def.name)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Color.primary)
                                            .lineLimit(1)

                                        Text(def.category.displayName)
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.secondary)
                                    }
                                    .padding(.vertical, 10)
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
                        }
                        .padding(.horizontal, 16)
                    }

                    Color.clear.frame(height: 80)
                }
                .padding(.vertical, 16)
            }
            .background(Theme.Color.bg.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                // 底部 CTA：全部收入我的徽章馆
                Button(action: handleDismiss) {
                    Text("全部收入我的徽章馆")
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
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .background(
                    Theme.Color.bg
                        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: -4)
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: handleDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
        }
    }

    private func statCell(title: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func handleDismiss() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UserDefaults.standard.set(true, forKey: BadgeEngine.careerReviewShownKey)
        onDismiss()
        dismiss()
    }
}
