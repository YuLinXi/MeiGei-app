import SwiftUI

struct SupersetCreationResult {
    struct Member {
        var memberId: UUID?
        var pick: ExercisePick
        var weightKg: Double?
        var reps: Int?
    }

    var roundCount: Int
    var first: Member
    var second: Member
}

struct SupersetCreationSheet: View {
    private enum PickerSlot: Int, Identifiable {
        case first
        case second
        var id: Int { rawValue }
    }

    private enum InputField: Int, CaseIterable {
        case firstWeight
        case firstReps
        case secondWeight
        case secondReps
        case roundCount

        var decimalEnabled: Bool {
            switch self {
            case .firstWeight, .secondWeight: return true
            case .roundCount, .firstReps, .secondReps: return false
            }
        }

        var integerLimit: Int {
            switch self {
            case .roundCount: return 3
            case .firstReps, .secondReps: return 4
            case .firstWeight, .secondWeight: return 4
            }
        }
    }

    let title: String
    let initial: SupersetCreationResult?
    let onSave: (SupersetCreationResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var firstPick: ExercisePick?
    @State private var secondPick: ExercisePick?
    @State private var firstMemberId: UUID?
    @State private var secondMemberId: UUID?
    @State private var firstWeight: String
    @State private var firstReps: String
    @State private var secondWeight: String
    @State private var secondReps: String
    @State private var roundText: String
    @State private var pickerSlot: PickerSlot?
    @State private var focusedField: InputField?
    @State private var pendingReplace = false

    init(title: String = "创建超级组",
         initial: SupersetCreationResult? = nil,
         onSave: @escaping (SupersetCreationResult) -> Void) {
        self.title = title
        self.initial = initial
        self.onSave = onSave
        _firstPick = State(initialValue: initial?.first.pick)
        _secondPick = State(initialValue: initial?.second.pick)
        _firstMemberId = State(initialValue: initial?.first.memberId)
        _secondMemberId = State(initialValue: initial?.second.memberId)
        _firstWeight = State(initialValue: initial?.first.weightKg.map { formatKg($0) } ?? "")
        _firstReps = State(initialValue: initial?.first.reps.map(String.init) ?? "\(PlanDefaults.suggestedReps)")
        _secondWeight = State(initialValue: initial?.second.weightKg.map { formatKg($0) } ?? "")
        _secondReps = State(initialValue: initial?.second.reps.map(String.init) ?? "\(PlanDefaults.suggestedReps)")
        _roundText = State(initialValue: "\(initial?.roundCount ?? PlanDefaults.suggestedSets)")
    }

    var body: some View {
        VStack(spacing: 0) {
            PaperSheetHeader(
                title: title,
                cancelTitle: "取消",
                confirmTitle: "完成",
                confirmEnabled: canSave,
                background: Theme.Color.bg,
                onCancel: { dismiss() },
                onConfirm: save
            )

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    memberEditor(slot: .first,
                                 title: "动作 1",
                                 pick: firstPick,
                                 weightField: .firstWeight,
                                 repsField: .firstReps)
                    memberEditor(slot: .second,
                                 title: "动作 2",
                                 pick: secondPick,
                                 weightField: .secondWeight,
                                 repsField: .secondReps)
                    roundEditor
                    Color.clear.frame(height: 18)
                }
                .padding(Theme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Theme.Color.bg)
        }
        .safeAreaInset(edge: .bottom) {
            if let focusedField {
                NumericFormKeypad(decimalEnabled: focusedField.decimalEnabled,
                                  onDigit: keypadDigit,
                                  onDot: keypadDot,
                                  onBackspace: keypadBackspace,
                                  onPrev: keypadPrev,
                                  onNext: keypadNext,
                                  onDone: dismissKeypad)
            }
        }
        .background(Theme.Color.bg.ignoresSafeArea())
        .presentationBackground(Theme.Color.bg)
        .presentationDetents([.large])
        .sheet(item: $pickerSlot) { slot in
            ExercisePickerView { pick in
                switch slot {
                case .first:
                    firstPick = pick
                case .second:
                    secondPick = pick
                }
            }
        }
    }

    private var canSave: Bool {
        guard let firstPick, let secondPick else { return false }
        guard firstPick.id != secondPick.id else { return false }
        return (Int(roundText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) > 0
    }

    private var roundEditor: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("统一组数").eyebrowStyle()
            inputButton(field: .roundCount,
                        placeholder: "组数",
                        height: 42,
                        cornerRadius: Theme.Radius.sm,
                        fontSize: 18)
        }
    }

    private func memberEditor(slot: PickerSlot,
                              title: String,
                              pick: ExercisePick?,
                              weightField: InputField,
                              repsField: InputField) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title).eyebrowStyle()
            Button {
                dismissKeypad()
                pickerSlot = slot
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Color.accent)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(pick?.name ?? "选择动作")
                            .font(Theme.Font.body(size: 15, weight: .bold))
                            .foregroundStyle(pick == nil ? Theme.Color.muted : Theme.Color.fg)
                            .lineLimit(1)
                        if let pick {
                            Text([pick.primaryMuscle, pick.equipmentType].compactMap { $0 }.joined(separator: " · "))
                                .font(Theme.Font.body(size: 12))
                                .foregroundStyle(Theme.Color.fg2)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Color.muted)
                }
                .cardStyle(padding: 12, cornerRadius: Theme.Radius.md)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                valueField(title: "重量", placeholder: "kg", field: weightField)
                Text("×")
                    .font(Theme.Font.mono(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Color.muted)
                    .padding(.top, 18)
                valueField(title: "次数", placeholder: "次", field: repsField)
            }
        }
    }

    private func valueField(title: String,
                            placeholder: String,
                            field: InputField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.Font.mono(size: 9, weight: .semibold))
                .foregroundStyle(Theme.Color.muted)
            inputButton(field: field,
                        placeholder: placeholder,
                        height: 42,
                        cornerRadius: Theme.Radius.sm,
                        fontSize: 16)
        }
    }

    private func inputButton(field: InputField,
                             placeholder: String,
                             height: CGFloat,
                             cornerRadius: CGFloat,
                             fontSize: CGFloat) -> some View {
        let text = text(for: field)
        let isFocused = focusedField == field
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return Button {
            focus(field)
        } label: {
            Text(text.isEmpty ? placeholder : text)
                .font(Theme.Font.number(size: fontSize, weight: .bold))
                .foregroundStyle(text.isEmpty ? Theme.Color.muted : Theme.Color.fg)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(Theme.Color.surface, in: shape)
                .overlay(shape.stroke(isFocused ? Theme.Color.accent : Theme.Color.border,
                                      lineWidth: isFocused ? 1.7 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(inputAccessibilityLabel(for: field))
        .accessibilityValue(text.isEmpty ? "未填写" : text)
    }

    private func focus(_ field: InputField) {
        focusedField = field
        pendingReplace = true
    }

    private func dismissKeypad() {
        focusedField = nil
        pendingReplace = false
    }

    private func keypadDigit(_ digit: Int) {
        guard let field = focusedField else { return }
        var next = pendingReplace ? "" : text(for: field)
        pendingReplace = false

        if field.decimalEnabled {
            if let dot = next.firstIndex(of: ".") {
                let decimals = next.distance(from: next.index(after: dot), to: next.endIndex)
                if decimals >= 2 { return }
            } else if next.count >= field.integerLimit {
                return
            }
        } else if next.count >= field.integerLimit {
            return
        }

        next += String(digit)
        setText(next, for: field)
    }

    private func keypadDot() {
        guard let field = focusedField, field.decimalEnabled else { return }
        var next = pendingReplace ? "" : text(for: field)
        pendingReplace = false
        guard !next.contains(".") else { return }
        next = next.isEmpty ? "0." : next + "."
        setText(next, for: field)
    }

    private func keypadBackspace() {
        guard let field = focusedField else { return }
        pendingReplace = false
        var next = text(for: field)
        if !next.isEmpty { next.removeLast() }
        setText(next, for: field)
    }

    private func keypadPrev() {
        guard let field = focusedField,
              let index = InputField.allCases.firstIndex(of: field),
              index > InputField.allCases.startIndex else { return }
        focus(InputField.allCases[InputField.allCases.index(before: index)])
    }

    private func keypadNext() {
        guard let field = focusedField,
              let index = InputField.allCases.firstIndex(of: field) else {
            dismissKeypad()
            return
        }
        let nextIndex = InputField.allCases.index(after: index)
        if nextIndex < InputField.allCases.endIndex {
            focus(InputField.allCases[nextIndex])
        } else {
            dismissKeypad()
        }
    }

    private func text(for field: InputField) -> String {
        switch field {
        case .roundCount: return roundText
        case .firstWeight: return firstWeight
        case .firstReps: return firstReps
        case .secondWeight: return secondWeight
        case .secondReps: return secondReps
        }
    }

    private func setText(_ value: String, for field: InputField) {
        switch field {
        case .roundCount: roundText = value
        case .firstWeight: firstWeight = value
        case .firstReps: firstReps = value
        case .secondWeight: secondWeight = value
        case .secondReps: secondReps = value
        }
    }

    private func inputAccessibilityLabel(for field: InputField) -> String {
        switch field {
        case .roundCount: return "统一组数"
        case .firstWeight: return "动作一重量"
        case .firstReps: return "动作一次数"
        case .secondWeight: return "动作二重量"
        case .secondReps: return "动作二次数"
        }
    }

    private func save() {
        guard let firstPick, let secondPick, canSave else { return }
        let result = SupersetCreationResult(
            roundCount: max(1, Int(roundText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? PlanDefaults.suggestedSets),
            first: .init(memberId: firstMemberId,
                         pick: firstPick,
                         weightKg: supersetDecimalValue(firstWeight),
                         reps: supersetIntValue(firstReps)),
            second: .init(memberId: secondMemberId,
                          pick: secondPick,
                          weightKg: supersetDecimalValue(secondWeight),
                          reps: supersetIntValue(secondReps))
        )
        onSave(result)
        dismiss()
    }
}

func supersetDecimalValue(_ text: String) -> Double? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: ",", with: ".")
    return trimmed.isEmpty ? nil : Double(trimmed)
}

func supersetIntValue(_ text: String) -> Int? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : Int(trimmed)
}
