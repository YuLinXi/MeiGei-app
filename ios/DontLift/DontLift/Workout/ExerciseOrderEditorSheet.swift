import SwiftUI

struct ExerciseOrderItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
}

struct ExerciseOrderEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let items: [ExerciseOrderItem]
    let onCommit: ([UUID]) -> Void

    @State private var draft: [ExerciseOrderItem]
    @State private var editMode: EditMode = .active

    init(title: String, items: [ExerciseOrderItem], onCommit: @escaping ([UUID]) -> Void) {
        self.title = title
        self.items = items
        self.onCommit = onCommit
        _draft = State(initialValue: items)
    }

    var body: some View {
        VStack(spacing: 0) {
            PaperSheetHeader(
                title: title,
                cancelTitle: "取消",
                confirmTitle: "完成",
                background: Theme.Color.bg,
                onCancel: { dismiss() },
                onConfirm: commit
            )

            List {
                ForEach(Array(draft.enumerated()), id: \.element.id) { idx, item in
                    row(index: idx, item: item)
                        .listRowBackground(Theme.Color.surface)
                }
                .onMove { source, destination in
                    draft.move(fromOffsets: source, toOffset: destination)
                    Theme.Haptics.selection()
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Color.bg)
            .environment(\.editMode, $editMode)
        }
        .background(Theme.Color.bg.ignoresSafeArea())
        .presentationBackground(Theme.Color.bg)
        .presentationCornerRadius(26)
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
    }

    private func row(index: Int, item: ExerciseOrderItem) -> some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index + 1))
                .font(Theme.Font.mono(size: 12, weight: .bold))
                .foregroundStyle(Theme.Color.muted)
                .frame(width: 28, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(Theme.Font.body(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Color.fg)
                    .lineLimit(1)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(Theme.Font.body(size: 13))
                        .foregroundStyle(Theme.Color.fg2)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func commit() {
        onCommit(draft.map(\.id))
        dismiss()
    }
}
