#if DEBUG
import SwiftUI
import SwiftData
import Observation

extension UITestHooks {
    static var isHistoryLoadingUITest: Bool {
        isAutoLogin && ProcessInfo.processInfo.arguments.contains("-uitest-history-loading")
    }

    @MainActor static func makeHistoryStore(modelContext: ModelContext) -> WorkoutHistoryStore {
        guard isHistoryLoadingUITest else { return WorkoutHistoryStore(modelContext: modelContext) }
        UITestHistoryReadProbe.shared.count = 0
        let reader = UITestHistoryReadScenario(flags: Set(ProcessInfo.processInfo.arguments))
        return WorkoutHistoryStore(modelContext: modelContext, readHistory: { container in
            try await reader.read(container: container)
        })
    }
}

@MainActor @Observable
final class UITestHistoryReadProbe {
    static let shared = UITestHistoryReadProbe()
    var count = 0
}

struct UITestHistoryReadCounter: View {
    var body: some View {
        Text("历史读取 \(UITestHistoryReadProbe.shared.count)")
            .font(Theme.Font.l5)
            .dynamicTypeSize(.large)
            .foregroundStyle(Theme.Color.muted)
            .padding(2)
            .background(Theme.Color.bg)
            .accessibilityIdentifier("uitest.history.readCount")
            .accessibilityValue(String(UITestHistoryReadProbe.shared.count))
            .allowsHitTesting(false)
    }
}

private actor UITestHistoryReadScenario {
    private struct InjectedReadError: Error {}
    let flags: Set<String>
    private var reads = 0

    init(flags: Set<String>) { self.flags = flags }

    func read(container: ModelContainer) async throws -> [HistoryWorkout] {
        reads += 1
        let index = reads
        await MainActor.run { UITestHistoryReadProbe.shared.count = index }
        if flags.contains("-uitest-history-slow"), index == 1 {
            try await Task.sleep(for: .seconds(20))
        }
        if flags.contains("-uitest-finish-slow-history"), index == 2 {
            try await Task.sleep(for: .seconds(12))
        }
        if (flags.contains("-uitest-history-first-failure") && index == 1)
            || (flags.contains("-uitest-history-refresh-failure") && index == 2) {
            try await Task.sleep(for: .seconds(2))
            throw InjectedReadError()
        }
        if flags.contains("-uitest-history-empty") { return [] }
        return try await WorkoutHistoryReader(modelContainer: container).read()
    }
}
#endif
