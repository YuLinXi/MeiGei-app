import SwiftUI

enum GlobalMessageStyle: Equatable {
    case info
    case success
    case warning
    case error

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "clock.badge.exclamationmark.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var background: Color {
        switch self {
        case .info: return Theme.Color.fg
        case .success: return Theme.Color.ok
        case .warning: return Theme.Color.accent
        case .error: return Theme.Color.danger
        }
    }
}

@Observable
final class GlobalMessageCenter {
    struct Message: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let style: GlobalMessageStyle
        let duration: TimeInterval
    }

    private(set) var current: Message?
    private var dismissTask: Task<Void, Never>?

    func show(_ text: String,
              style: GlobalMessageStyle = .info,
              duration: TimeInterval = 2.8) {
        dismissTask?.cancel()
        let message = Message(text: text, style: style, duration: duration)
        current = message
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.dismiss(id: message.id)
            }
        }
    }

    func dismiss(id: UUID? = nil) {
        guard id == nil || current?.id == id else { return }
        dismissTask?.cancel()
        dismissTask = nil
        current = nil
    }
}

struct GlobalMessageOverlay: View {
    @Environment(GlobalMessageCenter.self) private var center
    @Environment(SyncProgressCenter.self) private var syncProgress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                if let message = center.current {
                    GlobalMessageBanner(message: message)
                        .frame(maxWidth: bannerWidth(in: proxy.size.width))
                        .padding(.top, syncProgress.isVisible ? 52 : 8)
                        .transition(transition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.easeOut(duration: reduceMotion ? 0.12 : 0.2), value: center.current?.id)
        }
        .allowsHitTesting(false)
    }

    private var transition: AnyTransition {
        reduceMotion
            ? .opacity
            : .move(edge: .top).combined(with: .opacity)
    }

    private func bannerWidth(in containerWidth: CGFloat) -> CGFloat {
        min(320, max(220, containerWidth - 144))
    }
}

private struct GlobalMessageBanner: View {
    let message: GlobalMessageCenter.Message

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: message.style.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Text(message.text)
                .font(Theme.Font.body(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(message.style.background, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .paperShadow(.md, cornerRadius: Theme.Radius.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.text)
    }
}
