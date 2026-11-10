#if DEBUG
import Foundation

extension UITestHooks {
    static var isCaloriePreferencesUITest: Bool {
        isAutoLogin && ProcessInfo.processInfo.arguments.contains("-uitest-calorie-preferences")
    }

    @MainActor static var profileCalorieDefaults: UserDefaults {
        isCaloriePreferencesUITest ? calorieFixtureDefaults : .standard
    }

    /// 每次隔离启动使用独立偏好域，保留普通 App 的体重与显示选择。
    @MainActor private static let calorieFixtureDefaults: UserDefaults = {
        let defaults = UserDefaults(suiteName: "dontlift.uitest.calorie.\(UUID().uuidString)")!
        let flags = ProcessInfo.processInfo.arguments
        if flags.contains("-uitest-calorie-known-on") || flags.contains("-uitest-calorie-known-off") {
            WorkoutCaloriePreferences.setBodyWeightKg(70, defaults: defaults)
            WorkoutCaloriePreferences.setShowsEstimates(flags.contains("-uitest-calorie-known-on"), defaults: defaults)
        }
        return defaults
    }()
}
#endif
