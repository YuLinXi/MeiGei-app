import SwiftUI
import SwiftData
import os.log

/// Team 交互日志：可在 Xcode 控制台 / Console.app 按 category=TeamUI 过滤。
private let uiLog = Logger(subsystem: "com.yulinxi.app.DontLift", category: "TeamUI")

// MARK: - Team 列表（tab 根）

struct TeamListView: View {
    @Environment(TeamService.self) private var teamService
    @State private var creating = false
    @State private var joining = false
    /// Team 详情导航：用绑定式 navigationDestination(item:) 而非 NavigationLink(value:)。
    /// 本工程是「全局唯一 NavigationStack 包 TabView」，类型注册式 navigationDestination(for:)
    /// 从 TabView 子页注册不进外层 stack，value 链接点了不跳；绑定式可靠（与训练 tab 一致）。
    @State private var selectedTeam: TeamDTO?
    @State private var error: String?
    @State private var actionToast: String?   // 退出/解散返回后的黑底结果 toast
    @State private var isReloading = false

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    // 原型 scroll 直接铺团队卡（无「我的 Team」分组标签），下拉刷新走系统 refreshable。
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        if teamService.teams.isEmpty {
                            emptyState
                        } else {
                            ForEach(teamService.teams) { team in
                                Button { selectedTeam = team } label: {
                                    teamCard(team)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Color.clear.frame(height: 32)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
                }
            }
        }
        .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
            if !teamService.teams.isEmpty {
                floatingAddMenu
            }
        }
        .rootTabTopScrim()
        // Team 根页不展示顶部标题，隐藏系统导航栏。
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedTeam) { TeamDetailView(team: $0) }
        .sheet(isPresented: $creating) { CreateTeamSheet() }
        .sheet(isPresented: $joining) { JoinTeamSheet() }
        .overlay(alignment: .top) { resultToast }
        .task { await reload() }
        .refreshable { await reload() }
        .onAppear { consumePendingToast() }
        .alert("出错了", isPresented: .constant(error != nil)) {
            Button("好") { error = nil }
        } message: { Text(error ?? "") }
    }

    // 退出/解散成功后返回列表顶部的黑底 toast（朱砂红勾选圆点 + 队名文案）。
    @ViewBuilder
    private var resultToast: some View {
        if let actionToast {
            HStack(spacing: 9) {
                ZStack {
                    Circle().fill(Theme.Color.accent).frame(width: 18, height: 18)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                }
                Text(actionToast)
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(Color(white: 0.98))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Theme.Color.fg, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .paperShadow(.lg, cornerRadius: Theme.Radius.md)
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// 从 TeamService 取走详情页写入的结果文案，显示 2.5s 后清空。
    private func consumePendingToast() {
        guard let msg = teamService.pendingActionToast else { return }
        teamService.pendingActionToast = nil
        withAnimation(.easeOut(duration: 0.2)) { actionToast = msg }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeOut(duration: 0.2)) { actionToast = nil }
        }
    }

    // MARK: 右下角添加入口

    private var floatingAddMenu: some View {
        CircleAddMenu(items: teamHeaderMenuItems, accessibilityLabel: "创建或加入 Team")
            .frame(width: 48, height: 48)
            .padding(.trailing, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.md)
    }

    private var teamHeaderMenuItems: [PaperMenuItem] {
        [
            PaperMenuItem(title: "创建 Team", systemImage: "person.2.badge.plus") { creating = true },
            PaperMenuItem(title: "用邀请码加入", systemImage: "number.square") { joining = true }
        ]
    }

    // 原型团队卡：首字方块（朱砂红 8% 底 + 18% 描边 + accent 首字，社交温度）+ 名称 + 邀请码 mono。
    private func teamCard(_ team: TeamDTO) -> some View {
        HStack(spacing: 12) {
            Text(String(team.name.prefix(1)))
                .font(Theme.Font.display(size: 15, weight: .heavy))
                .foregroundStyle(Theme.Color.accent)
                .frame(width: 44, height: 44)
                .background(Theme.Color.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.Color.accentSofter, lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(team.name)
                    .font(Theme.Font.body(size: 15, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                Text("邀请码 \(team.inviteCode)")
                    .font(Theme.Font.mono(size: 12))
                    .tracking(0.48)            // 原型 letter-spacing .04em ≈ 0.48pt @12
                    .foregroundStyle(Theme.Color.muted)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 16))
                .foregroundStyle(Theme.Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // 原型空态（引导重设计）：虚化队友动态预览 → 价值三点 → 创建 / 加入双 CTA。
    // 用 containerRelativeFrame 撑满一屏，Spacer 把 CTA 压到底部（margin-top:auto 等效）。
    private var emptyState: some View {
        VStack(spacing: 0) {
            previewStack
                .padding(.top, Theme.Spacing.sm)

            Text("和训练搭子组队")
                .font(Theme.Font.display(size: 22, weight: .heavy))
                .tracking(-0.4)
                .foregroundStyle(Theme.Color.fg)
                .padding(.top, 18)

            Text("和训练搭子一起，认真训练、互相督促。\n加入后，队友的每次打卡都会出现在这里。")
                .font(Theme.Font.body(size: 12.5))
                .foregroundStyle(Theme.Color.fg2)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, Theme.Spacing.sm)

            Spacer(minLength: Theme.Spacing.xl)

            valueList

            Spacer(minLength: Theme.Spacing.xl)

            emptyCTAs
        }
        .frame(maxWidth: .infinity)
        .containerRelativeFrame(.vertical) { length, _ in length - 48 }
    }

    // 视觉引导区：2 张虚化背卡 + 1 张清晰前卡 + 朱砂红人群徽记（纯装饰，不请求数据）。
    private var previewStack: some View {
        ZStack {
            ghostFeedCard(initial: "铁", reactions: ["🔥"])
                .blur(radius: 1.6)
                .opacity(0.34)
                .rotationEffect(.degrees(-4.5))
                .offset(x: -30, y: -37)
            ghostFeedCard(initial: "L", reactions: ["💪"])
                .blur(radius: 1)
                .opacity(0.5)
                .rotationEffect(.degrees(3.5))
                .offset(x: 28, y: -27)
            ghostFeedCard(initial: "周", reactions: ["🔥", "💪"])
                .opacity(0.95)
                .offset(y: 21)
            groupEmblem
                .offset(y: -40)
        }
        .frame(height: 138)
    }

    private func ghostFeedCard(initial: String, reactions: [String]) -> some View {
        HStack(spacing: 9) {
            Text(initial)
                .font(Theme.Font.body(size: 11, weight: .bold))
                .foregroundStyle(Theme.Color.fg2)
                .frame(width: 30, height: 30)
                .background(Theme.Color.surface2, in: Circle())
                .overlay(Circle().stroke(Theme.Color.border, lineWidth: 1))
            VStack(alignment: .leading, spacing: 6) {
                Capsule().fill(Theme.Color.border2).frame(width: 78, height: 7)
                Capsule().fill(Theme.Color.border).frame(width: 108, height: 6)
            }
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                ForEach(reactions, id: \.self) { r in
                    Text(r)
                        .font(.system(size: 9))
                        .frame(width: 19, height: 19)
                        .background(Theme.Color.accentSoft, in: Circle())
                        .overlay(Circle().stroke(Theme.Color.accentSofter, lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(width: 206)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Color.border, lineWidth: 1))
        .paperShadow(.sm, cornerRadius: Theme.Radius.md)
    }

    private var groupEmblem: some View {
        Image(systemName: "person.2")
            .font(.system(size: 23, weight: .semibold))
            .foregroundStyle(Theme.Color.accent)
            .frame(width: 58, height: 58)
            .background(Theme.Color.surface, in: Circle())
            .overlay(Circle().stroke(Theme.Color.accentSofter, lineWidth: 1.6))
            .paperShadow(.md, cornerRadius: 29)
    }

    // 价值三点：为什么组队（朱砂红线性图标 + 标题 + 一行短描述）。
    private var valueList: some View {
        VStack(spacing: Theme.Spacing.lg) {
            valueRow(icon: "arrow.triangle.2.circlepath",
                     title: "训练即打卡",
                     desc: "完成训练自动同步到队里，无需手动发动态。")
            valueRow(icon: "flame",
                     title: "互相鼓励",
                     desc: "给队友的打卡点 🔥 💪 表情反应，看见彼此坚持。")
            valueRow(icon: "arrow.triangle.branch",
                     title: "共享计划",
                     desc: "复制队友分享的训练计划，或直接开练。")
        }
    }

    private func valueRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.Color.accent)
                .frame(width: 38, height: 38)
                .background(Theme.Color.accentSoft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Theme.Color.accentSofter, lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.Font.body(size: 16, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                Text(desc)
                    .font(Theme.Font.body(size: 13))
                    .foregroundStyle(Theme.Color.fg2)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // 双 CTA：主键「创建 Team」朱砂红实底 + 投影；次键「用邀请码加入」白底描边；脚注 mono。
    private var emptyCTAs: some View {
        VStack(spacing: Theme.Spacing.sm + 1) {
            Button { creating = true } label: {
                HStack(spacing: 7) {
                    Image(systemName: "plus").font(.system(size: 15, weight: .bold))
                    Text("创建 Team").font(Theme.Font.body(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .shadow(color: Theme.Color.accent.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(PressableButtonStyle())

            Button { joining = true } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.right.to.line")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Color.fg2)
                    Text("用邀请码加入")
                        .font(Theme.Font.body(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Color.fg)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Color.border2, lineWidth: 1))
                .paperShadow(.sm, cornerRadius: Theme.Radius.md)
            }
            .buttonStyle(PressableButtonStyle())

            Text("建队自动生成邀请码 · 分享给训练搭子")
                .font(Theme.Font.mono(size: 10))
                .tracking(0.5)
                .foregroundStyle(Theme.Color.muted)
                .padding(.top, 2)
        }
    }

    private func reload() async {
        guard !isReloading else { return }
        isReloading = true
        defer { isReloading = false }
        do { try await teamService.loadMyTeams() }
        catch {
            guard !error.isCancellationError else { return }
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - 创建 / 加入 sheet（纸感底部 sheet：自绘 取消/标题/确认 栏 + 朱砂红 CTA）

struct CreateTeamSheet: View {
    @Environment(TeamService.self) private var teamService
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var canSubmit: Bool { !busy && !trimmed.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏：取消(muted) · 标题(700) · 确认(accent)。与底部 CTA 同动作（双确认，按设计稿保留）。
            TeamSheetBar(title: "创建 Team", confirmText: "创建",
                         confirmEnabled: canSubmit,
                         onCancel: { dismiss() },
                         onConfirm: { Task { await submit() } })
            VStack(alignment: .leading, spacing: 0) {
                TeamSheetLabel("队名").padding(.bottom, 8)
                // 纸感输入框（内联以放大字号；paperField 固定 l2 无法覆盖）
                TextField("周三力量小队", text: $name)
                    .focused($focused)
                    .font(Theme.Font.body(size: 17))
                    .foregroundStyle(Theme.Color.fg)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.Color.border, lineWidth: 1))
                TeamSheetHint(error ?? "建队后自动生成邀请码，分享给训练搭子", isError: error != nil)
                    .padding(.top, 7)
                TeamSheetCTA(title: "创建 Team", enabled: canSubmit) { Task { await submit() } }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .fittedTeamSheet()
        .onAppear { focused = true }
    }

    private func submit() async {
        guard canSubmit else { return }
        busy = true; defer { busy = false }
        do { _ = try await teamService.create(name: trimmed); dismiss() }
        catch {
            guard !error.isCancellationError else { return }
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct JoinTeamSheet: View {
    @Environment(TeamService.self) private var teamService
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var busy = false
    @State private var error: String?

    /// 后端邀请码定长 6 位（`CODE_LEN = 6`）。
    private static let codeLength = 6
    private var canSubmit: Bool { !busy && code.count == Self.codeLength }

    var body: some View {
        VStack(spacing: 0) {
            TeamSheetBar(title: "加入 Team", confirmText: "加入",
                         confirmEnabled: canSubmit,
                         onCancel: { dismiss() },
                         onConfirm: { Task { await submit() } })
            VStack(alignment: .leading, spacing: 0) {
                TeamSheetLabel("邀请码").padding(.bottom, 8)
                SegmentedCodeField(code: $code, length: Self.codeLength)
                TeamSheetHint(error ?? "向队友要 6 位邀请码，输入自动转大写", isError: error != nil)
                    .padding(.top, 7)
                TeamSheetCTA(title: "加入 Team", enabled: canSubmit) { Task { await submit() } }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .fittedTeamSheet()
    }

    private func submit() async {
        guard canSubmit else { return }
        busy = true; defer { busy = false }
        do { _ = try await teamService.join(inviteCode: code); dismiss() }
        catch {
            guard !error.isCancellationError else { return }
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Team sheet 复用组件（栏 / 标签 / hint / CTA / 分段邀请码）

/// 内容自适应底部 sheet：按内容实际高度设 detent（贴合内容、CTA 紧贴 sheet 底），顶部圆角 26、白底。
private struct FittedTeamSheet: ViewModifier {
    @State private var height: CGFloat = 360
    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { height = proxy.size.height }
                        .onChange(of: proxy.size.height) { _, h in height = h }
                }
            }
            .presentationDetents([.height(height)])
            .presentationCornerRadius(26)
            .presentationBackground(Theme.Color.surface)
    }
}

private extension View {
    func fittedTeamSheet() -> some View { modifier(FittedTeamSheet()) }
}

/// 顶部栏：取消(muted l3) · 标题(700 l2) · 确认(accent l3，禁用转 muted) + 底边 1px border。
private struct TeamSheetBar: View {
    let title: String
    let confirmText: String
    let confirmEnabled: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        PaperSheetHeader(
            title: title,
            cancelTitle: "取消",
            confirmTitle: confirmText,
            confirmEnabled: confirmEnabled,
            topPadding: 15,
            bottomPadding: 13,
            background: Theme.Color.surface,
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

/// 字段标签：l4 12px / fg2 / 600。
private struct TeamSheetLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(Theme.Font.body(size: 14, weight: .semibold))
            .foregroundStyle(Theme.Color.fg2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 提示/错误：l5 10px，正常 muted、错误 danger。
private struct TeamSheetHint: View {
    let text: String
    let isError: Bool
    init(_ text: String, isError: Bool) { self.text = text; self.isError = isError }
    var body: some View {
        Text(text)
            .font(Theme.Font.body(size: 12))
            .foregroundStyle(isError ? Theme.Color.danger : Theme.Color.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 底部全宽 CTA：on=accent 白字 + 朱砂红投影；off=暖底 muted + border。l2 15px / 700。
private struct TeamSheetCTA: View {
    let title: String
    let enabled: Bool
    let action: () -> Void
    var body: some View {
        Button(action: { if enabled { action() } }) {
            Text(title)
                .font(Theme.Font.body(size: 17, weight: .bold))
                .foregroundStyle(enabled ? .white : Theme.Color.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(enabled ? Theme.Color.accent : Theme.Color.surface2,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay {
                    if !enabled {
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .stroke(Theme.Color.border, lineWidth: 1)
                    }
                }
                .shadow(color: enabled ? Theme.Color.accent.opacity(0.28) : .clear,
                        radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .padding(.top, 18)
        .padding(.bottom, 4)
    }
}

/// 分段邀请码输入：N 个方格（mono 24 / r-sm / border2），当前格朱砂红环 + 闪光游标；隐藏 TextField 承接键盘、输入自动转大写。
private struct SegmentedCodeField: View {
    @Binding var code: String
    let length: Int
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            TextField("", text: Binding(get: { code }, set: { code = normalize($0) }))
                .focused($focused)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(height: 1)
                .opacity(0.01)

            HStack(spacing: 8) {
                ForEach(0..<length, id: \.self) { cell(index: $0) }
            }
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
        }
        .onAppear { focused = true }
    }

    private func cell(index i: Int) -> some View {
        let chars = Array(code)
        let isActive = focused && i == chars.count && i < length
        let ch = i < chars.count ? String(chars[i]) : ""
        return ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(Theme.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .stroke(isActive ? Theme.Color.accent : Theme.Color.border2, lineWidth: 1)
                )
                // active 朱砂红 18% 外环（近似设计稿 box-shadow 0 0 0 2px accent-3）
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm + 2, style: .continuous)
                        .stroke(Theme.Color.accentSofter, lineWidth: 2)
                        .padding(-2)
                        .opacity(isActive ? 1 : 0)
                )
            if ch.isEmpty {
                if isActive { CodeCaret() }
            } else {
                Text(ch)
                    .font(Theme.Font.mono(size: 27, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func normalize(_ s: String) -> String {
        String(s.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(length))
    }
}

/// 朱砂红闪光游标（2×24）。
private struct CodeCaret: View {
    @State private var on = true
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Theme.Color.accent)
            .frame(width: 2, height: 24)
            .opacity(on ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    on = false
                }
            }
    }
}

// MARK: - Team 详情（Screen 16 · C 纸感极简）

struct TeamDetailView: View {
    @Environment(TeamService.self) private var teamService
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let team: TeamDTO
    @State private var members: [TeamMemberDTO] = []
    @State private var checkins: [TeamCheckinDTO] = []
    @State private var reactions: [UUID: [CheckinReactionDTO]] = [:]
    @State private var error: String?
    @State private var isReloading = false

    // ⋯ 操作菜单 → 二次确认 → 结果反馈 状态机
    @State private var showActionSheet = false
    @State private var confirmKind: ConfirmKind?
    @State private var confirmOverlayShown = false
    @State private var dissolveInput = ""
    @State private var actionBusy = false
    @State private var actionFailed = false   // 详情页顶部红 toast（操作失败）
    /// Team 计划三级页导航：绑定式，避免闭包式 NavigationLink 在嵌套 TabView 的 stack 里失灵。
    @State private var showingPlans = false
    @State private var showOwnerTakeoverNotice = false
    @State private var autoShareWorkouts = false
    @State private var autoSharePreferenceBusy = false
    @State private var confirmingAutoShareEnable = false
    @State private var pendingWithdrawCheckin: TeamCheckinDTO?
    @State private var confirmingWithdraw = false
    @State private var showingHistory = false
    @State private var openedCheckin: TeamCheckinDTO?

    private enum ConfirmKind: Identifiable { case leave, dissolve; var id: Int { hashValue } }

    private var isOwner: Bool { team.ownerUserId == session.currentUserId }
    private var ownerTakeoverSeenKey: String { "dontlift.team.ownerTakeoverSeen.\(team.id.uuidString)" }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        if showOwnerTakeoverNotice {
                            ownerTakeoverCard
                        }
                        headerCard
                        autoSharePreferenceCard
                        planEntry

                        todayFeedSection

                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
                }
                .refreshable { await reload() }
            }
        }
        // 子页统一导航栏：圆形返回 + ⋯（展开时 active/rotated 高亮，切换自定义 action sheet）。
        .paperToolbar(title: team.name, onBack: { dismiss() }) {
            CircleIconButton(systemName: "ellipsis", active: showActionSheet, rotated: showActionSheet) {
                withAnimation(.easeOut(duration: 0.18)) { showActionSheet = true }
            }
        }
        .fullScreenCover(isPresented: $showActionSheet) {
            actionSheetOverlay
                .presentationBackground(.clear)
        }
        .transaction(value: showActionSheet) { $0.disablesAnimations = true }
        .fullScreenCover(item: $confirmKind) { kind in
            confirmDialogOverlay(kind)
                .presentationBackground(.clear)
                .onAppear { withAnimation(confirmDialogAnimation) { confirmOverlayShown = true } }
        }
        .transaction(value: confirmKind) { $0.disablesAnimations = true }
        .paperConfirmDialog(
            isPresented: $confirmingAutoShareEnable,
            title: "开启自动分享?",
            message: "之后完成训练会自动分享到「\(team.name)」，Team 成员可看到训练摘要和每组记录。你可以随时关闭，已分享记录可在动态中撤回。",
            confirmTitle: "开启",
            destructive: false,
            onConfirm: { Task { await setAutoShareWorkouts(true) } }
        )
        .paperConfirmDialog(
            isPresented: $confirmingWithdraw,
            title: "撤回这次分享?",
            message: "这次训练将从「\(team.name)」动态中移除，相关表情回应也会删除。个人训练记录不受影响。",
            confirmTitle: "撤回",
            onConfirm: { [checkin = pendingWithdrawCheckin] in
                guard let checkin else { return }
                Task { await withdraw(checkin) }
            }
        )
        .navigationDestination(isPresented: $showingPlans) { TeamPlansView(team: team) }
        .navigationDestination(isPresented: $showingHistory) { TeamCheckinHistoryView(team: team) }
        .sheet(item: $openedCheckin) { checkin in
            TeamCheckinDetailSheet(checkin: checkin, memberName: displayName(for: checkin.userId))
        }
        .overlay(alignment: .top) { failureToast }
        .onAppear { prepareOwnerTakeoverNotice() }
        .task { await reload() }
        // 同步周期完成后重拉今日动态：删训练经同步使后端撤销 checkin，此处反映移除（无需手动下拉）。
        .onReceive(NotificationCenter.default.publisher(for: .dontliftSyncCompleted)) { _ in
            Task { await reload() }
        }
        // 回前台兜底刷新：删除/同步若在后台完成，切回前台时反映最新动态。
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await reload() } }
        }
        .alert("出错了", isPresented: .constant(error != nil)) {
            Button("好") { error = nil }
        } message: { Text(error ?? "") }
    }

    // MARK: 队头卡（左竖条 + 进度 pill + 邀请码 + monogram 头像栈）

    private var ownerTakeoverCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.Color.accent)
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 5) {
                Text("已接管 Team")
                    .font(Theme.Font.body(size: 15, weight: .bold))
                    .foregroundStyle(Theme.Color.fg)
                Text("原队长删除账号后，Team 与成员历史已保留。你可以继续管理，或在右上角解散 Team。")
                    .font(Theme.Font.body(size: 12))
                    .foregroundStyle(Theme.Color.fg2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                UserDefaults.standard.set(true, forKey: ownerTakeoverSeenKey)
                withAnimation(.easeOut(duration: 0.18)) { showOwnerTakeoverNotice = false }
            } label: {
                Text("知道了")
                    .font(Theme.Font.body(size: 12, weight: .bold))
                    .foregroundStyle(Theme.Color.accent)
            }
            .buttonStyle(.plain)
        }
        .cardStyle()
    }

    private var headerCard: some View {
        let totalMembers = members.count
        let trainedToday = Set(checkins.map(\.userId)).count
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top) {
                Text(isOwner ? "Team · 你是队长" : "Team").eyebrowStyle()
                Spacer(minLength: 8)
                Text("\(trainedToday) / \(totalMembers) 今日已练")
                    .font(Theme.Font.mono(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Color.accent)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Theme.Color.accentSoft, in: Capsule())
                    .overlay(Capsule().stroke(Theme.Color.accentSofter, lineWidth: 1))
                    .fixedSize()
            }
            Text(team.name)
                .font(Theme.Font.l2)
                .foregroundStyle(Theme.Color.fg)
            HStack {
                Button {
                    UIPasteboard.general.string = team.inviteCode
                } label: {
                    HStack(spacing: 5) {
                        Text("邀请码 \(team.inviteCode)")
                            .font(Theme.Font.mono(size: 12))
                            .tracking(0.48)
                            .foregroundStyle(Theme.Color.fg2)
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Color.muted)
                    }
                }
                .buttonStyle(.plain)
                Spacer(minLength: 8)
                avatarStack
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).stroke(Theme.Color.border, lineWidth: 1))
        // 左侧 4px 朱砂红竖条
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.Color.accent).frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .paperShadow(.sm, cornerRadius: Theme.Radius.lg)
    }

    private var autoSharePreferenceCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("训练完成后自动分享")
                .font(Theme.Font.body(size: 15, weight: .bold))
                .foregroundStyle(Theme.Color.fg)
            Spacer(minLength: 8)
            if autoSharePreferenceBusy {
                ProgressView()
                    .frame(width: 44, height: 31)
            } else {
                Toggle("", isOn: Binding(
                    get: { autoShareWorkouts },
                    set: { enabled in
                        if enabled {
                            confirmingAutoShareEnable = true
                        } else {
                            Task { await setAutoShareWorkouts(false) }
                        }
                    }
                ))
                .labelsHidden()
                .tint(Theme.Color.accent)
            }
        }
        .cardStyle()
    }

    private var todayFeedSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            todayFeedHeader
            if checkins.isEmpty {
                emptyFeedCard
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(checkins) { c in
                        let isMine = session.currentUserId.map { $0 == c.userId } ?? false
                        FeedItemCard(
                            checkin: c,
                            memberName: displayName(for: c.userId),
                            reactions: reactions[c.id] ?? [],
                            myUserId: session.currentUserId,
                            canWithdraw: isMine,
                            canOpenDetail: !isMine,
                            onReact: { emoji in await react(checkinId: c.id, emoji: emoji) },
                            onWithdraw: { presentWithdrawConfirmation(c) },
                            onOpen: { openedCheckin = c }
                        )
                    }
                }
            }
        }
    }

    private var todayFeedHeader: some View {
        HStack(spacing: 9) {
            Text("今日动态").eyebrowStyle()
            Button {
                showingHistory = true
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 28, height: 26)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("历史训练")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // monogram 头像栈：me 在前高亮，−7px 重叠，超 5 折叠 +N。
    private var avatarStack: some View {
        let sorted = members.sorted { a, _ in a.userId == session.currentUserId }
        let shown = Array(sorted.prefix(5))
        let overflow = max(0, members.count - shown.count)
        return HStack(spacing: -7) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { _, m in
                headerMonogram(name: displayName(for: m.userId), isMe: m.userId == session.currentUserId)
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(Theme.Font.mono(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg2)
                    .frame(width: 26, height: 26)
                    .background(Theme.Color.surface2, in: Circle())
                    .overlay(Circle().stroke(Theme.Color.border, lineWidth: 1))
                    .overlay(Circle().stroke(Theme.Color.surface, lineWidth: 1.5).padding(-0.75))
            }
        }
    }

    private func headerMonogram(name: String, isMe: Bool) -> some View {
        Text(String(name.prefix(1)))
            .font(Theme.Font.body(size: 9, weight: .bold))
            .foregroundStyle(isMe ? Theme.Color.accent : Theme.Color.fg2)
            .frame(width: 26, height: 26)
            .background(isMe ? Theme.Color.accentSoft : Theme.Color.surface2, in: Circle())
            .overlay(Circle().stroke(isMe ? Theme.Color.accentSofter : Theme.Color.border, lineWidth: 1))
            .overlay(Circle().stroke(Theme.Color.surface, lineWidth: 1.5).padding(-0.75))
    }

    // MARK: Team 计划入口

    private var planEntry: some View {
        Button { showingPlans = true } label: {
            HStack(spacing: 9) {
                Image(systemName: "doc.text")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.Color.fg2)
                Text("Team 计划")
                    .font(Theme.Font.l2)
                    .foregroundStyle(Theme.Color.fg)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.Color.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var emptyFeedCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("今天还没人打卡")
                .font(Theme.Font.body(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
            Text("开启自动分享或主动分享后，训练会出现在这里。")
                .font(Theme.Font.body(size: 13))
                .foregroundStyle(Theme.Color.fg2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: ⋯ Action Sheet（自绘毛玻璃底部 sheet）

    private var actionSheetOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.34).ignoresSafeArea()
                .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { showActionSheet = false } }
            VStack(spacing: 8) {
                VStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text(sheetHeaderTitle)
                            .font(Theme.Font.body(size: 13, weight: .bold))
                            .foregroundStyle(Theme.Color.fg2)
                        Text(sheetHeaderSub)
                            .font(Theme.Font.body(size: 11))
                            .foregroundStyle(Theme.Color.muted)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11).padding(.horizontal, 16)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.Color.border).frame(height: 1) }

                    Button {
                        let next = isOwner ? ConfirmKind.dissolve : .leave
                        withAnimation(.easeOut(duration: 0.18)) { showActionSheet = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            confirmKind = next
                        }
                    } label: {
                        Text(isOwner ? "解散 Team" : "退出 Team")
                            .font(Theme.Font.body(size: 16, weight: .bold))
                            .foregroundStyle(Theme.Color.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).stroke(Theme.Color.border, lineWidth: 1))

                Button { withAnimation(.easeOut(duration: 0.18)) { showActionSheet = false } } label: {
                    Text("取消")
                        .font(Theme.Font.body(size: 16, weight: .heavy))
                        .foregroundStyle(Theme.Color.fg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).stroke(Theme.Color.border, lineWidth: 1))
            }
            .padding(.horizontal, 9)
            .padding(.bottom, 12)
            .paperShadow(.lg, cornerRadius: Theme.Radius.lg)
            .transition(.move(edge: .bottom))
        }
    }

    private var sheetHeaderTitle: String {
        isOwner ? "\(team.name) · 队长" : team.name
    }

    private var sheetHeaderSub: String {
        let count = members.count
        if isOwner {
            if let days = ownerCreatedDaysAgo {
                return "你创建于 \(days) 天前 · \(count) 名成员"
            }
            return "\(count) 名成员"
        } else {
            if let days = myJoinedDaysAgo {
                return "\(count) 名成员 · 你已加入 \(days) 天"
            }
            return "\(count) 名成员"
        }
    }

    /// 当前用户加入天数（成员视角）。
    private var myJoinedDaysAgo: Int? {
        guard let me = members.first(where: { $0.userId == session.currentUserId }),
              let joined = me.joinedAt else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: joined, to: .now).day ?? 0)
    }

    /// 队长创建天数：用 owner 成员 joinedAt 近似（≈ 建队时间）。
    private var ownerCreatedDaysAgo: Int? {
        guard let owner = members.first(where: { $0.userId == team.ownerUserId }),
              let joined = owner.joinedAt else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: joined, to: .now).day ?? 0)
    }

    private func prepareOwnerTakeoverNotice() {
        guard isOwner, team.ownerTransferredAt != nil else { return }
        showOwnerTakeoverNotice = !UserDefaults.standard.bool(forKey: ownerTakeoverSeenKey)
    }

    // MARK: 二次确认弹窗

    @ViewBuilder
    private func confirmDialogOverlay(_ kind: ConfirmKind) -> some View {
        ZStack {
            Color.black.opacity(confirmOverlayShown ? 0.34 : 0).ignoresSafeArea()
                .onTapGesture { if !actionBusy { closeConfirm() } }
            VStack(spacing: 0) {
                // 图标
                ZStack {
                    Circle().fill(Theme.Color.accentSoft).frame(width: 46, height: 46)
                    Circle().stroke(Theme.Color.accentSofter, lineWidth: 1).frame(width: 46, height: 46)
                    Image(systemName: kind == .leave ? "rectangle.portrait.and.arrow.right" : "exclamationmark.triangle")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Theme.Color.accent)
                }
                .padding(.bottom, 13)

                Text(kind == .leave ? "退出「\(team.name)」?" : "解散「\(team.name)」?")
                    .font(Theme.Font.body(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.Color.fg)
                    .multilineTextAlignment(.center)

                dialogMessage(kind)
                    .font(Theme.Font.body(size: 12))
                    .foregroundStyle(Theme.Color.fg2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.top, 9)

                if kind == .dissolve {
                    dissolveConfirmField.padding(.top, 15)
                }

                HStack(spacing: Theme.Spacing.md) {
                    Button { closeConfirm() } label: {
                        Text("取消")
                            .font(Theme.Font.l2)
                            .foregroundStyle(Theme.Color.fg)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(actionBusy)

                    Button { Task { await performConfirmedAction(kind) } } label: {
                        ZStack {
                            Text(kind == .leave ? "退出" : "解散")
                                .opacity(actionBusy ? 0 : 1)
                            if actionBusy { ProgressView().tint(.white) }
                        }
                        .font(Theme.Font.l2)
                        .foregroundStyle(dangerEnabled(kind) ? .white : Theme.Color.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(dangerEnabled(kind) ? Theme.Color.accent : Theme.Color.surface2,
                                    in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(!dangerEnabled(kind) || actionBusy)
                }
                .padding(.top, Theme.Spacing.lg)
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .shadow(color: Theme.Color.fg.opacity(0.18), radius: 32, x: 0, y: 12)
            .padding(.horizontal, 40)
            .scaleEffect(confirmOverlayShown ? 1 : 0.94)
            .opacity(confirmOverlayShown ? 1 : 0)
        }
    }

    private func dialogMessage(_ kind: ConfirmKind) -> Text {
        switch kind {
        case .leave:
            return Text("退出后将不再接收队内动态与计划更新。你可以凭邀请码 ")
                + Text(team.inviteCode).foregroundColor(Theme.Color.fg).fontWeight(.bold)
                + Text(" 随时重新加入。")
        case .dissolve:
            return Text("此操作")
                + Text("不可恢复").foregroundColor(Theme.Color.accent).fontWeight(.bold)
                + Text("。\(members.count) 名成员将被移除，队内全部打卡动态与共享计划将被永久删除。")
        }
    }

    // 队长输入队名强校验字段
    private var dissolveConfirmField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("输入队名以确认").eyebrowStyle()
            TextField(team.name, text: $dissolveInput)
                .font(Theme.Font.body(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.fg)
                .autocorrectionDisabled()
                .padding(.horizontal, 12).padding(.vertical, 11)
                .background(Theme.Color.bg, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .stroke(dissolveMatches ? Theme.Color.accentSofter : Theme.Color.border2, lineWidth: 1.5))
        }
    }

    private var dissolveMatches: Bool {
        dissolveInput.trimmingCharacters(in: .whitespaces) == team.name
    }

    private func dangerEnabled(_ kind: ConfirmKind) -> Bool {
        kind == .leave ? true : dissolveMatches
    }

    private var confirmDialogAnimation: Animation {
        .easeInOut(duration: 0.25)
    }

    private func closeConfirm() {
        closeConfirm(after: nil)
    }

    private func closeConfirm(after action: (() -> Void)?) {
        withAnimation(confirmDialogAnimation) { confirmOverlayShown = false } completion: {
            confirmKind = nil
            dissolveInput = ""
            action?()
        }
    }

    // MARK: 失败 toast（顶部红条，弹窗保留）

    @ViewBuilder
    private var failureToast: some View {
        if actionFailed {
            HStack(spacing: 9) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                Text("操作失败，请重试")
                    .font(Theme.Font.body(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .paperShadow(.lg, cornerRadius: Theme.Radius.md)
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(5)
        }
    }

    // MARK: 名称解析（displayName 兜底）

    private func displayName(for userId: UUID) -> String {
        if let m = members.first(where: { $0.userId == userId }),
           let n = m.displayName, !n.isEmpty {
            return n
        }
        return userId == session.currentUserId ? "我" : "队友"
    }

    // MARK: 数据加载与动作

    private func reload() async {
        guard !isReloading else { return }
        isReloading = true
        defer { isReloading = false }
        do {
            async let m = teamService.members(of: team.id)
            async let feed = teamService.checkinFeed(teamId: team.id)
            let loadedMembers = try await m
            members = loadedMembers
            syncAutoSharePreference(from: loadedMembers)
            let loadedFeed = try await feed
            checkins = loadedFeed.checkins
            reactions = Dictionary(grouping: loadedFeed.reactions, by: \.checkinId)
        } catch {
            guard !error.isCancellationError else { return }
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// 6.5 乐观更新（单选·可取消）：一人一打卡只点一个表情。
    /// 再点同一个 = 取消，点另一个 = 切换；先本地预测，再请求，失败回滚。
    private func react(checkinId: UUID, emoji: String) async {
        guard let myId = session.currentUserId else {
            uiLog.error("react 跳过：currentUserId 为空（token 可能与本地档案 desync）")
            return
        }
        let prior = reactions[checkinId] ?? []
        let hadSame = prior.contains { $0.userId == myId && $0.emoji == emoji }
        var next = prior.filter { $0.userId != myId }   // 先清掉我在这条打卡的所有表情
        if !hadSame {                                    // 原本不是这个 → 切换/新增；原本就是这个 → 取消，不再追加
            next.append(CheckinReactionDTO(id: UUID(), checkinId: checkinId, userId: myId, emoji: emoji))
        }
        reactions[checkinId] = next
        do {
            _ = try await teamService.react(checkinId: checkinId, emoji: emoji)
            let server = (try? await teamService.reactions(checkinId: checkinId)) ?? next
            reactions[checkinId] = server
        } catch {
            reactions[checkinId] = prior
            guard !error.isCancellationError else { return }
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func withdraw(_ checkin: TeamCheckinDTO) async {
        do {
            try await teamService.withdrawCheckin(teamId: team.id, workoutId: checkin.workoutId)
            checkins.removeAll { $0.id == checkin.id }
            reactions[checkin.id] = nil
            pendingWithdrawCheckin = nil
        } catch {
            guard !error.isCancellationError else { return }
            self.error = "撤回失败，请稍后重试"
        }
    }

    private func presentWithdrawConfirmation(_ checkin: TeamCheckinDTO) {
        pendingWithdrawCheckin = checkin
        confirmingWithdraw = true
    }

    private func syncAutoSharePreference(from loadedMembers: [TeamMemberDTO]) {
        guard !autoSharePreferenceBusy,
              let myId = session.currentUserId,
              let me = loadedMembers.first(where: { $0.userId == myId }) else { return }
        autoShareWorkouts = me.autoShareWorkouts
        teamService.rememberAutoSharePreference(teamId: team.id, enabled: me.autoShareWorkouts, userId: myId)
    }

    private func setAutoShareWorkouts(_ enabled: Bool) async {
        guard let myId = session.currentUserId else { return }
        let previous = autoShareWorkouts
        autoSharePreferenceBusy = true
        defer { autoSharePreferenceBusy = false }
        do {
            let updated = try await teamService.updateAutoShareWorkouts(teamId: team.id, enabled: enabled, userId: myId)
            autoShareWorkouts = updated.autoShareWorkouts
            if let idx = members.firstIndex(where: { $0.userId == myId }) {
                members[idx] = updated
            }
        } catch {
            guard !error.isCancellationError else {
                autoShareWorkouts = previous
                return
            }
            autoShareWorkouts = previous
            self.error = enabled ? "开启自动分享失败，请稍后重试" : "关闭自动分享失败，请稍后重试"
        }
    }

    /// 退出/解散：成功写跨页 toast 并返回列表；失败保留弹窗 + 顶部红 toast。
    private func performConfirmedAction(_ kind: ConfirmKind) async {
        guard dangerEnabled(kind), !actionBusy else { return }
        actionBusy = true
        defer { actionBusy = false }
        do {
            if kind == .dissolve { try await teamService.dissolve(team.id) }
            else { try await teamService.leave(team.id) }
            teamService.pendingActionToast = kind == .dissolve
                ? "已解散「\(team.name)」"
                : "已退出「\(team.name)」"
            closeConfirm(after: { dismiss() })
        } catch {
            guard !error.isCancellationError else { return }
            await flashFailureToast()
        }
    }

    private func flashFailureToast() async {
        withAnimation(.easeOut(duration: 0.2)) { actionFailed = true }
        try? await Task.sleep(for: .seconds(2.5))
        withAnimation(.easeOut(duration: 0.2)) { actionFailed = false }
    }
}

// MARK: - FeedItemCard

struct FeedItemCard: View {
    let checkin: TeamCheckinDTO
    let memberName: String
    let reactions: [CheckinReactionDTO]
    let myUserId: UUID?
    let canWithdraw: Bool
    let canOpenDetail: Bool
    let onReact: (String) async -> Void
    let onWithdraw: () -> Void
    let onOpen: () -> Void

    @State private var busy = false

    /// 设计稿 4 emoji：🔥/💪/😱/👏。当前后端 enum 仅有 fire/muscle/clap/heart，
    /// 用 heart 替代 😱（震惊）以保持顺序稳定；后续扩 enum 再换。
    private let displayEmojis: [(code: String, glyph: String)] = [
        ("fire", "🔥"),
        ("muscle", "💪"),
        ("heart", "❤️"),
        ("clap", "👏"),
    ]

    private var summary: CheckinSummary { checkin.parsedSummary }

    var body: some View {
        ZStack(alignment: .trailing) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    tappableSummary
                    if canWithdraw {
                        withdrawButton
                    }
                }
                .padding(.trailing, detailAccessoryPadding)
                ReactionRow(
                    reactions: reactions,
                    myUserId: myUserId,
                    emojis: displayEmojis,
                    onTap: { emoji in
                        guard !busy else { return }
                        Task { busy = true; await onReact(emoji); busy = false }
                    }
                )
                .padding(.trailing, detailAccessoryPadding)
                .disabled(busy)
            }
            if canOpenDetail {
                openIndicator
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var detailAccessoryPadding: CGFloat {
        canOpenDetail ? 34 : 0
    }

    @ViewBuilder
    private var tappableSummary: some View {
        let summary = VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            memberHead
            body(text: bodyText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if canOpenDetail {
            summary
                .contentShape(Rectangle())
                .onTapGesture {
                    onOpen()
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    onOpen()
                }
        } else {
            summary
        }
    }

    private var memberHead: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(String(memberName.prefix(1)))
                .font(Theme.Font.body(size: 13, weight: .bold))
                .foregroundStyle(Theme.Color.accent)
                .frame(width: 32, height: 32)
                .background(Theme.Color.accentSoft, in: Circle())
                .overlay(Circle().stroke(Theme.Color.accentSofter, lineWidth: 1))
            VStack(alignment: .leading, spacing: 1) {
                Text(memberName)
                    .font(Theme.Font.body(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                Text(relativeTime(checkin.createdAt ?? Date()))
                    .font(Theme.Font.mono(size: 10))
                    .foregroundStyle(Theme.Color.muted)
            }
        }
    }

    private var withdrawButton: some View {
        Button {
            onWithdraw()
        } label: {
            Text("撤回")
                .font(Theme.Font.body(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Color.danger)
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(Theme.Color.bg, in: Capsule())
                .overlay(Capsule().stroke(Theme.Color.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .layoutPriority(1)
    }

    private var openIndicator: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.Color.muted)
            .frame(width: 28, height: 44)
            .contentShape(Rectangle())
            .onTapGesture {
                onOpen()
            }
            .accessibilityHidden(true)
    }

    private var bodyText: AttributedString {
        var s = AttributedString("完成训练 · ")
        s.foregroundColor = Theme.Color.fg2

        var name = AttributedString(summary.title ?? "训练")
        name.foregroundColor = Theme.Color.fg
        s.append(name)

        if summary.totalVolumeKg > 0 {
            var sep = AttributedString(" · ")
            sep.foregroundColor = Theme.Color.fg2
            s.append(sep)
            var vol = AttributedString("\(formatKg(summary.totalVolumeKg)) kg·rep")
            vol.foregroundColor = Theme.Color.fg
            s.append(vol)
        }
        if let pr = summary.headlinePR {
            var sep = AttributedString("  ")
            sep.foregroundColor = Theme.Color.fg2
            s.append(sep)
            var prAttr = AttributedString("★ \(pr)")
            prAttr.foregroundColor = Theme.Color.accent
            s.append(prAttr)
        }
        return s
    }

    private func body(text: AttributedString) -> some View {
        Text(text)
            .font(Theme.Font.body(size: 14, weight: .semibold))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func relativeTime(_ d: Date) -> String {
        d.formatted(.relative(presentation: .named))
    }
}

private extension CheckinSummary {
    /// 从汇总里提炼一段「PR …」高亮文字；MVP 仅根据 `headline` 文字匹配。
    var headlinePR: String? {
        let text = headline
        if let range = text.range(of: "PR") {
            return String(text[range.lowerBound...]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
}

// MARK: - 反应行

struct ReactionRow: View {
    let reactions: [CheckinReactionDTO]
    let myUserId: UUID?
    let emojis: [(code: String, glyph: String)]
    let onTap: (String) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(emojis, id: \.code) { item in
                let count = reactions.filter { $0.emoji == item.code }.count
                let mine = myUserId.map { my in
                    reactions.contains(where: { $0.userId == my && $0.emoji == item.code })
                } ?? false
                Button { onTap(item.code) } label: {
                    HStack(spacing: 5) {
                        Text(item.glyph)
                            .font(.system(size: 14))
                        if count > 0 {
                            Text("\(count)")
                                .font(Theme.Font.mono(size: 10, weight: .semibold))
                                .foregroundStyle(mine ? Theme.Color.accent : Theme.Color.fg2)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(
                        mine ? Theme.Color.accentSoft : Theme.Color.bg,
                        in: Capsule()
                    )
                    .overlay(Capsule().stroke(mine ? Theme.Color.accentSofter : Theme.Color.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

// MARK: - Team 计划浏览（保留功能，theme 微调）

struct TeamPlansView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TeamService.self) private var teamService
    @Environment(SyncEngine.self) private var syncEngine
    @Environment(SessionStore.self) private var session
    @Environment(RestTimerController.self) private var restTimer
    @Environment(WorkoutHistoryStore.self) private var historyStore
    @Environment(WorkoutPresentationCenter.self) private var workoutPresentation
    @Environment(\.dismiss) private var dismiss

    let team: TeamDTO
    @State private var shares: [TeamPlanShareCardDTO] = []
    @State private var error: String?
    @State private var toast: String?
    @State private var forking: UUID?
    @State private var conflict: Workout?
    @State private var pendingBuild: (() -> Workout)?
    @State private var pendingStartCard: TeamPlanShareCardDTO?
    @State private var selectedShare: TeamPlanShareCardDTO?
    @State private var deletingShare: TeamPlanShareCardDTO?
    @State private var deletingShareId: UUID?
    @State private var showConflict = false
    @State private var isReloading = false

    private var ownShares: [TeamPlanShareCardDTO] {
        shares.filter(isOwnShare)
    }

    private var memberShares: [TeamPlanShareCardDTO] {
        shares.filter { !isOwnShare($0) }
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    privacyNote
                    if isReloading && shares.isEmpty {
                        ProgressView()
                            .tint(Theme.Color.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.Spacing.lg)
                    } else if shares.isEmpty {
                        Text("还没有成员分享计划")
                            .font(Theme.Font.body(size: 13))
                            .foregroundStyle(Theme.Color.muted)
                            .padding(.top, Theme.Spacing.lg)
                    } else {
                        planSection(title: "我分享的计划", items: ownShares)
                        planSection(title: "成员分享计划", items: memberShares)
                    }
                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
        }
        // 子页统一导航栏：纸感圆形返回钮（取代系统蓝色箭头）。
        .paperToolbar(title: "Team 计划", onBack: { dismiss() })
        .navigationDestination(item: $selectedShare) { share in
            TeamPlanShareDetailView(
                share: share,
                isOwnShare: isOwnShare(share),
                isForking: forking == share.versionId,
                isDeleting: deletingShareId == share.shareId,
                onStart: { start(share) },
                onFork: { Task { await fork(share) } },
                onDelete: { deletingShare = share }
            )
        }
        .task { await reload() }
        .refreshable { await reload() }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(Theme.Font.body(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Color.bg)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.Color.accent, in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
        .alert("出错了", isPresented: .constant(error != nil)) {
            Button("好") { error = nil }
        } message: { Text(error ?? "") }
        .paperConfirmDialog(
            isPresented: $showConflict,
            title: "已有进行中的训练",
            message: "同一时间只能有一个进行中的训练。继续既有训练，或丢弃后开始新的。",
            confirmTitle: "丢弃并开始新训练",
            secondaryTitle: "继续训练",
            onSecondary: {
                if let existing = conflict { workoutPresentation.present(existing) }
                clearConflict()
            },
            showCancel: false,
            onConfirm: {
                if let existing = conflict {
                    WorkoutSession.discard(existing, in: modelContext)
                    restTimer.stop()
                    if let build = pendingBuild, let card = pendingStartCard {
                        commit(build, source: card)
                    }
                }
                clearConflict()
            }
        )
        .paperConfirmDialog(
            isPresented: Binding(
                get: { deletingShare != nil },
                set: { if !$0 { deletingShare = nil } }
            ),
            title: "取消分享?",
            message: deletingShare.map { "取消分享「\($0.planNameSnapshot)」后，Team 成员将不再从列表看到它；已复制的计划不受影响。" } ?? "",
            confirmTitle: "取消分享",
            onConfirm: {
                if let share = deletingShare {
                    Task { await deleteShare(share) }
                }
                deletingShare = nil
            }
        )
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.accent)
                .frame(width: 20)
            Text("只统计完成次数，不公开训练详情。是否出现在 Team 动态，仍取决于自动分享或本次分享。")
                .font(Theme.Font.body(size: 12))
                .foregroundStyle(Theme.Color.fg2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private func planSection(title: String, items: [TeamPlanShareCardDTO]) -> some View {
        if !items.isEmpty {
            Text(title)
                .font(Theme.Font.mono(size: 10, weight: .bold))
                .foregroundStyle(Theme.Color.muted)
                .textCase(.uppercase)
                .padding(.top, Theme.Spacing.xs)
            ForEach(items) { share in
                planRow(share)
            }
        }
    }

    private func planRow(_ p: TeamPlanShareCardDTO) -> some View {
        let own = isOwnShare(p)
        let rowBusy = forking != nil || deletingShareId != nil
        let canUse = !p.hasUnstartableItems && !rowBusy
        return VStack(alignment: .leading, spacing: 10) {
            Button { selectedShare = p } label: {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.planNameSnapshot)
                                .font(Theme.Font.body(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.Color.fg)
                            Text("\(updatedText(for: p)) · \(ownerName(for: p))")
                                .font(Theme.Font.mono(size: 10, weight: .bold))
                                .foregroundStyle(Theme.Color.muted)
                            Text("\(p.itemCount) 个动作 · \(p.exercisePreviewText)")
                                .font(Theme.Font.mono(size: 11))
                                .foregroundStyle(Theme.Color.muted)
                                .lineLimit(1)
                            if p.hasUnstartableItems {
                                Text("包含无法识别的动作，请更新 App 或联系分享者修复")
                                    .font(Theme.Font.body(size: 12))
                                    .foregroundStyle(Theme.Color.danger)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        HStack(spacing: 8) {
                            Label("\(p.displayCopyCount) 人复制", systemImage: "arrow.triangle.branch")
                            Label("总共 \(p.displayCompletionCount) 次完成", systemImage: "checkmark.circle")
                        }
                        .font(Theme.Font.mono(size: 10, weight: .bold))
                        .foregroundStyle(Theme.Color.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Color.muted)
                        .frame(width: 24, alignment: .trailing)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Button { start(p) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill").font(.system(size: 11, weight: .bold))
                        Text("开始训练")
                    }
                    .font(Theme.Font.body(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(canUse ? Theme.Color.accent : Theme.Color.muted.opacity(0.35),
                                in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    .opacity(canUse ? 1 : 0.72)
                }
                .buttonStyle(.plain)
                .disabled(!canUse)

                if !own {
                    Button { Task { await fork(p) } } label: {
                        if forking == p.versionId {
                            ProgressView().tint(Theme.Color.accent)
                                .frame(width: 86, height: 36)
                        } else {
                            HStack(spacing: 5) {
                                Image(systemName: "doc.on.doc").font(.system(size: 12, weight: .bold))
                                Text("复制")
                            }
                            .font(Theme.Font.body(size: 13, weight: .bold))
                            .foregroundStyle(canUse ? Theme.Color.accent : Theme.Color.muted)
                            .frame(width: 86, height: 36)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                    .stroke(canUse ? Theme.Color.accent : Theme.Color.border, lineWidth: 1.3)
                            )
                            .opacity(canUse ? 1 : 0.72)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canUse)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func isOwnShare(_ p: TeamPlanShareCardDTO) -> Bool {
        session.currentUserId.map { $0 == p.ownerUserId } ?? false
    }

    private func ownerName(for p: TeamPlanShareCardDTO) -> String {
        let name = p.ownerName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty { return name }
        return isOwnShare(p) ? "我" : "队友"
    }

    private func updatedText(for p: TeamPlanShareCardDTO) -> String {
        guard let date = p.createdAt else { return "上次更新未知" }
        return "上次更新 \(date.formatted(.relative(presentation: .named)))"
    }

    private func reload() async {
        guard !isReloading else { return }
        isReloading = true
        defer { isReloading = false }
        do { shares = try await teamService.planShares(of: team.id) }
        catch {
            guard !error.isCancellationError else { return }
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func start(_ p: TeamPlanShareCardDTO) {
        let items = p.decodedItems
        let brokenItems = PlanItem.unstartableItems(in: items)
        guard brokenItems.isEmpty else {
            error = PlanItem.unstartableMessage(for: brokenItems)
            return
        }
        let build = { buildWorkout(from: p) }
        if let existing = WorkoutSession.activeSession(in: modelContext) {
            pendingBuild = build
            pendingStartCard = p
            conflict = existing
            showConflict = true
        } else {
            commit(build, source: p)
        }
    }

    private func buildWorkout(from share: TeamPlanShareCardDTO) -> Workout {
        let w = PlanWorkoutBuilder.workout(title: share.planNameSnapshot,
                                           items: share.decodedItems,
                                           mode: share.planMode,
                                           lookup: historyStore.planLookup)
        w.sourceShareId = share.shareId
        w.sourceShareVersionId = share.versionId
        w.sourcePlanNameSnapshot = share.planNameSnapshot
        return w
    }

    private func commit(_ build: () -> Workout, source share: TeamPlanShareCardDTO) {
        let workout = build()
        modelContext.insert(workout)
        try? modelContext.save()
        historyStore.scheduleRefresh(reason: .workoutChanged, delayNanoseconds: 0)
        NotificationCenter.default.post(name: .dontliftActiveWorkoutChanged, object: nil)
        workoutPresentation.present(workout)
        Task {
            await teamService.recordPlanShareEventOrQueue(versionId: share.versionId,
                                                          eventType: "direct_start",
                                                          workoutId: workout.localId,
                                                          eventDate: .now,
                                                          userId: session.currentUserId)
            if let userId = session.currentUserId,
               teamService.hasPendingPlanShareEvents(userId: userId) {
                await syncEngine.syncAll()
            }
            await reload()
        }
    }

    private func clearConflict() {
        conflict = nil
        pendingBuild = nil
        pendingStartCard = nil
    }

    private func fork(_ p: TeamPlanShareCardDTO) async {
        guard !p.hasUnstartableItems else {
            error = PlanItem.unstartableMessage(for: PlanItem.unstartableItems(in: p.decodedItems))
            return
        }
        forking = p.versionId; defer { forking = nil }
        do {
            try await teamService.forkShareVersion(p.versionId)
            await syncEngine.syncAll()
            await reload()
            await showToast("已复制到「计划」")
        } catch {
            guard !error.isCancellationError else { return }
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func deleteShare(_ p: TeamPlanShareCardDTO) async {
        guard isOwnShare(p) else {
            error = "只能取消自己分享的计划"
            return
        }
        deletingShareId = p.shareId
        defer { deletingShareId = nil }
        do {
            try await teamService.deletePlanShare(p.shareId, in: p.teamId)
            shares.removeAll { $0.shareId == p.shareId }
            if selectedShare?.shareId == p.shareId {
                selectedShare = nil
            }
            await reload()
            await showToast("已取消分享")
        } catch {
            guard !error.isCancellationError else { return }
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func showToast(_ msg: String) async {
        withAnimation { toast = msg }
        try? await Task.sleep(for: .seconds(2))
        withAnimation { toast = nil }
    }
}

private struct TeamPlanShareDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedExercise: BuiltinExercise?

    let share: TeamPlanShareCardDTO
    let isOwnShare: Bool
    let isForking: Bool
    let isDeleting: Bool
    let onStart: () -> Void
    let onFork: () -> Void
    let onDelete: () -> Void

    private var orderedItems: [PlanItem] {
        share.decodedItems.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var canUse: Bool {
        !share.hasUnstartableItems && !isForking && !isDeleting
    }

    var body: some View {
        ZStack {
            Theme.Color.bg.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    headerCard
                    Text("训练动作")
                        .font(Theme.Font.mono(size: 10, weight: .bold))
                        .foregroundStyle(Theme.Color.muted)
                        .textCase(.uppercase)
                    ForEach(orderedItems, id: \.itemId) { item in
                        itemRow(item)
                    }
                    Color.clear.frame(height: 96)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .paperToolbar(title: "计划详情", onBack: { dismiss() }) {
            if isOwnShare {
                CircleIconMenu(systemName: "ellipsis",
                               items: detailMenuItems,
                               accessibilityLabel: "计划操作")
                    .disabled(isDeleting)
            }
        }
        .navigationDestination(item: $selectedExercise) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
    }

    private var detailMenuItems: [PaperMenuItem] {
        [
            PaperMenuItem(title: "取消分享",
                          systemImage: "trash",
                          role: .destructive,
                          isEnabled: !isDeleting) {
                onDelete()
            }
        ]
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(share.planNameSnapshot)
                .font(Theme.Font.display(size: 24, weight: .heavy))
                .foregroundStyle(Theme.Color.fg)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(updatedText) · \(ownerName)")
                .font(Theme.Font.mono(size: 11, weight: .bold))
                .foregroundStyle(Theme.Color.muted)
            HStack(spacing: 8) {
                Label("\(share.displayCopyCount) 人复制", systemImage: "arrow.triangle.branch")
                Label("总共 \(share.displayCompletionCount) 次完成", systemImage: "checkmark.circle")
            }
            .font(Theme.Font.mono(size: 10, weight: .bold))
            .foregroundStyle(Theme.Color.muted)
            if share.hasUnstartableItems {
                Text("包含无法识别的动作，请更新 App 或联系分享者修复")
                    .font(Theme.Font.body(size: 12))
                    .foregroundStyle(Theme.Color.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private func itemRow(_ item: PlanItem) -> some View {
        if let exercise = exerciseDetail(for: item) {
            Button {
                selectedExercise = exercise
            } label: {
                itemRowContent(item, canOpenDetail: true)
            }
            .buttonStyle(.plain)
            .accessibilityHint("查看动作库详情")
        } else {
            itemRowContent(item, canOpenDetail: false)
        }
    }

    private func itemRowContent(_ item: PlanItem, canOpenDetail: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if item.isDropSet {
                        WorkoutStructureIcon(kind: .dropSet)
                    } else if item.isSuperset {
                        WorkoutStructureIcon(kind: .superset)
                    }
                    Text(itemTitle(item))
                        .font(Theme.Font.body(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Color.fg)
                        .lineLimit(1)
                }
                Text(itemPrescription(item))
                    .font(Theme.Font.mono(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Color.muted)
                if !item.usableAlternatives.isEmpty {
                    Text("备选：\(item.usableAlternatives.map(\.displayExerciseName).joined(separator: "、"))")
                        .font(Theme.Font.body(size: 11.5))
                        .foregroundStyle(Theme.Color.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if canOpenDetail {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.Color.muted)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .cardStyle()
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button(action: onStart) {
                HStack(spacing: 7) {
                    Image(systemName: "play.fill").font(.system(size: 12, weight: .bold))
                    Text("开始训练")
                }
                .font(Theme.Font.body(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(canUse ? Theme.Color.accent : Theme.Color.muted.opacity(0.35),
                            in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                .opacity(canUse ? 1 : 0.72)
            }
            .buttonStyle(.plain)
            .disabled(!canUse)

            if !isOwnShare {
                Button(action: onFork) {
                    HStack(spacing: 7) {
                        if isForking {
                            ProgressView().tint(Theme.Color.accent)
                        } else {
                            Image(systemName: "doc.on.doc").font(.system(size: 13, weight: .bold))
                            Text("复制到我的计划")
                        }
                    }
                    .font(Theme.Font.body(size: 14, weight: .bold))
                    .foregroundStyle(canUse ? Theme.Color.accent : Theme.Color.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(canUse ? Theme.Color.accentSofter : Theme.Color.border, lineWidth: 1))
                    .opacity(canUse ? 1 : 0.72)
                }
                .buttonStyle(.plain)
                .disabled(!canUse)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Theme.Color.bg.opacity(0.96))
        .overlay(alignment: .top) { Rectangle().fill(Theme.Color.border).frame(height: 1) }
    }

    private var ownerName: String {
        let name = share.ownerName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty { return name }
        return isOwnShare ? "我" : "队友"
    }

    private var updatedText: String {
        guard let date = share.createdAt else { return "上次更新未知" }
        return "上次更新 \(date.formatted(.relative(presentation: .named)))"
    }

    private func itemPrescription(_ item: PlanItem) -> String {
        if item.isSuperset {
            return "\(item.supersetRounds) 组 · 共 \(item.supersetRounds * item.orderedSupersetMembers.count) 组动作"
        }
        let sets = max(1, item.formalSetCount)
        if let reps = item.suggestedReps {
            return "\(sets) 组 × \(reps) 次"
        }
        return "\(sets) 组"
    }

    private func itemTitle(_ item: PlanItem) -> String {
        if item.isSuperset { return item.supersetTitle }
        return item.displayExerciseName
    }

    private func exerciseDetail(for item: PlanItem) -> BuiltinExercise? {
        guard !item.isSuperset, item.customExerciseId == nil else { return nil }
        return ExerciseLibrary.resolve(code: item.builtinExerciseCode, name: item.exerciseName)
    }
}
