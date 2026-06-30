import SwiftUI

@MainActor
@Observable
final class WorkoutPresentationCenter {
    var presentedWorkout: Workout?
    var isExpanded = false

    func present(_ workout: Workout) {
        presentedWorkout = workout
        isExpanded = true
    }

    func minimize() {
        isExpanded = false
    }

    func closeFinished() {
        isExpanded = false
        presentedWorkout = nil
    }

    func reconcile(activeWorkout: Workout?) {
        guard activeWorkout == nil, presentedWorkout?.isActive == true else { return }
        isExpanded = false
        presentedWorkout = nil
    }
}

struct WorkoutLiveOverlayContainer: View {
    @Environment(WorkoutPresentationCenter.self) private var presentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let activeSession: Workout?

    private var capsuleWorkout: Workout? {
        if let activeSession { return activeSession }
        if let workout = presentation.presentedWorkout, workout.isActive { return workout }
        return nil
    }

    var body: some View {
        ZStack {
            if let workout = capsuleWorkout, !presentation.isExpanded {
                LiveSessionCapsule(title: workout.title ?? "训练",
                                   timerStartedAt: workout.timerStartedAt,
                                   nextSetBrief: nextSetBrief(for: workout)) {
                    presentation.present(workout)
                }
                .transition(capsuleTransition)
                .zIndex(1)
            }

            if let workout = presentation.presentedWorkout, presentation.isExpanded {
                WorkoutLivePanel(workout: workout)
                    .transition(panelTransition)
                    .zIndex(2)
            }
        }
        .animation(animation, value: presentation.isExpanded)
        .animation(animation, value: capsuleWorkout?.localId)
    }

    private var animation: Animation {
        reduceMotion ? .easeOut(duration: 0.14) : .spring(response: 0.38, dampingFraction: 0.9)
    }

    private func nextSetBrief(for workout: Workout) -> String? {
        for ex in workout.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            if ex.sets.contains(where: { !$0.completed }) {
                return ex.displayExerciseName
            }
        }
        return nil
    }

    private var capsuleTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .scale(scale: 0.9, anchor: .bottomLeading).combined(with: .opacity)
    }

    private var panelTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .scale(scale: 0.18, anchor: .bottomLeading).combined(with: .opacity)
            )
    }
}

private struct WorkoutLivePanel: View {
    @Environment(WorkoutPresentationCenter.self) private var presentation
    let workout: Workout

    var body: some View {
        NavigationStack {
            WorkoutLoggingView(
                workout: workout,
                onMinimize: { presentation.minimize() },
                onCloseFinished: { presentation.closeFinished() }
            )
        }
        .background(Theme.Color.bg.ignoresSafeArea())
        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
        .ignoresSafeArea()
    }
}

struct WorkoutMinimizeButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 12, weight: .bold))
                Text("收起")
                    .font(Theme.Font.body(size: 12, weight: .bold))
            }
            .foregroundStyle(Theme.Color.fg)
            .padding(.horizontal, 11)
            .frame(height: 36)
            .background(Theme.Color.surface, in: Capsule())
            .overlay(Capsule().stroke(Theme.Color.border, lineWidth: 1))
            .paperShadow(.sm, cornerRadius: 18)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("收起训练")
    }
}
