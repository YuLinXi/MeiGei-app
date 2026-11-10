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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var rowLayout: AnyLayout {
        dynamicTypeSize >= .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
    }

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
                            .accessibilityHidden(true)

                        Text("力量生涯成就回顾")
                            .font(Theme.Font.display(size: 22, weight: .bold))
                            .foregroundStyle(Theme.Color.fg)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 20)

                        Text("你的每一次向心收缩与流淌汗水，皆已被刻度量化")
                            .font(Theme.Font.body(size: 13, weight: .regular))
                            .foregroundStyle(Theme.Color.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    // 2. 生涯核心数据卡片
                    rowLayout {
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
                        rowLayout {
                            Text("已为你点亮 \(grants.count) 枚荣誉勋章")
                                .font(Theme.Font.body(size: 15, weight: .bold))
                                .foregroundStyle(Theme.Color.fg)
                            if dynamicTypeSize < .xxLarge { Spacer() }
                            Text("一次性解锁")
                                .font(Theme.Font.body(size: 12, weight: .regular, relativeTo: .caption))
                                .foregroundStyle(Theme.Color.action)
                        }
                        .padding(.horizontal, 16)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                           count: dynamicTypeSize.isAccessibilitySize ? 1 : (dynamicTypeSize >= .xxLarge ? 2 : 3)),
                            spacing: 14
                        ) {
                            ForEach(grants, id: \.badgeCode) { grant in
                                if let def = grant.definition {
                                    VStack(spacing: 6) {
                                        BadgeIconView(definition: def, isUnlocked: true, size: .regular)
                                            .accessibilityHidden(true)

                                        Text(def.name)
                                            .font(Theme.Font.body(size: 13, weight: .bold))
                                            .foregroundStyle(Theme.Color.fg)
                                            .fixedSize(horizontal: false, vertical: true)

                                        Text(def.category.displayName)
                                            .font(Theme.Font.body(size: 10, weight: .regular, relativeTo: .caption))
                                            .foregroundStyle(Theme.Color.muted)
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
                        .font(Theme.Font.body(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .frame(minHeight: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Theme.Color.action)
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
                    CircleIconButton(systemName: "xmark", accessibilityLabel: "关闭生涯回顾", action: handleDismiss)
                }
            }
        }
    }

    private func statCell(title: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(Theme.Font.body(size: 11, weight: .regular, relativeTo: .caption))
                .foregroundStyle(Theme.Color.muted)

            rowLayout {
                Text(value)
                    .font(Theme.Font.body(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Color.fg)
                if !unit.isEmpty {
                    Text(unit)
                        .font(Theme.Font.body(size: 10, weight: .medium, relativeTo: .caption))
                        .foregroundStyle(Theme.Color.muted)
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
