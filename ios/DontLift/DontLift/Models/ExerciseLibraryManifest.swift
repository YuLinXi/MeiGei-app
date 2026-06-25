import Foundation

private final class ExerciseLibraryBundleMarker {}

struct ExerciseAlias: Codable, Hashable {
    var targetCode: String
    var targetName: String
    var legacyCodes: [String]
    var legacyNames: [String]
    var requiresNameMatch: Bool
}

struct RemovedExercise: Codable, Hashable {
    var name: String
    var reason: String
    var note: String
    var allowNewSelection: Bool
    var keepHistoricalDisplay: Bool
}

private struct PresetExerciseManifest: Codable {
    var schemaVersion: Int
    var generatedFrom: String
    var exercises: [BuiltinExercise]
}

private struct ExerciseAliasManifest: Codable {
    var schemaVersion: Int
    var generatedFrom: String
    var aliases: [ExerciseAlias]
}

private struct RemovedExerciseManifest: Codable {
    var schemaVersion: Int
    var generatedFrom: String
    var removed: [RemovedExercise]
}

enum ExerciseLibraryManifest {
    private static let subdirectory = "Resources/ExerciseLibrary"

    static func loadPresetExercises() -> [BuiltinExercise]? {
        load(PresetExerciseManifest.self, resource: "preset_exercises_v1")?.exercises
    }

    static let aliases: [ExerciseAlias] =
        load(ExerciseAliasManifest.self, resource: "exercise_aliases_v1")?.aliases ?? []

    static let removed: [RemovedExercise] =
        load(RemovedExerciseManifest.self, resource: "removed_exercises_v1")?.removed ?? []

    private static func load<T: Decodable>(_ type: T.Type, resource: String) -> T? {
        let decoder = JSONDecoder()
        for bundle in candidateBundles {
            let urls = [
                bundle.url(forResource: resource, withExtension: "json", subdirectory: subdirectory),
                bundle.url(forResource: resource, withExtension: "json")
            ].compactMap { $0 }
            for url in urls {
                guard let data = try? Data(contentsOf: url),
                      let value = try? decoder.decode(T.self, from: data) else {
                    continue
                }
                return value
            }
        }
        return nil
    }

    private static var candidateBundles: [Bundle] {
        var bundles = [Bundle.main, Bundle(for: ExerciseLibraryBundleMarker.self)]
        if let resourceBundle = Bundle(identifier: "com.yulinxi.app.DontLift") {
            bundles.append(resourceBundle)
        }
        var seen = Set<String>()
        return bundles.filter { seen.insert($0.bundlePath).inserted }
    }
}

enum ExerciseLibrary {
    private static var byCode: [String: BuiltinExercise] {
        Dictionary(uniqueKeysWithValues: BuiltinExercise.starter.map { ($0.code, $0) })
    }

    private static var aliasNamesByTargetCode: [String: Set<String>] {
        var result: [String: Set<String>] = [:]
        for alias in ExerciseLibraryManifest.aliases {
            result[alias.targetCode, default: []].formUnion(alias.legacyNames)
            result[alias.targetCode, default: []].formUnion(alias.legacyCodes)
        }
        return result
    }

    static func resolve(code: String?, name: String?) -> BuiltinExercise? {
        let trimmedCode = code?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        if let target = aliasTargetCode(code: trimmedCode, name: trimmedName, requiresNameMatchOnly: true),
           let exercise = byCode[target] {
            return exercise
        }
        if let trimmedCode, let exact = byCode[trimmedCode] {
            return exact
        }
        if let target = aliasTargetCode(code: trimmedCode, name: trimmedName),
           let exercise = byCode[target] {
            return exercise
        }
        if let trimmedName {
            return BuiltinExercise.starter.first { $0.name == trimmedName }
        }
        return nil
    }

    static func displayName(code: String?, snapshotName: String) -> String {
        resolve(code: code, name: snapshotName)?.name ?? snapshotName
    }

    static func searchableText(for exercise: BuiltinExercise) -> [String] {
        var values = Set([exercise.name, exercise.code])
        values.formUnion(aliasNamesByTargetCode[exercise.code] ?? [])
        return Array(values)
    }

    static func matches(_ exercise: BuiltinExercise, query: String) -> Bool {
        ExerciseSearch.tokens(query).isEmpty
            || searchableText(for: exercise).contains { ExerciseSearch.matches($0, query: query) }
    }

    static func isRemovedFromNewSelection(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return ExerciseLibraryManifest.removed.contains {
            !$0.allowNewSelection && $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }
    }

    private static func aliasTargetCode(code: String?, name: String?, requiresNameMatchOnly: Bool = false) -> String? {
        for alias in ExerciseLibraryManifest.aliases {
            if requiresNameMatchOnly && !alias.requiresNameMatch {
                continue
            }
            let codeMatches = code.map { alias.legacyCodes.contains($0) } ?? false
            let nameMatches = name.map { candidate in
                alias.legacyNames.contains { $0.localizedCaseInsensitiveCompare(candidate) == .orderedSame }
            } ?? false
            if alias.requiresNameMatch {
                if nameMatches && (codeMatches || code == nil || alias.legacyCodes.isEmpty) {
                    return alias.targetCode
                }
            } else if codeMatches || nameMatches {
                return alias.targetCode
            }
        }
        return nil
    }
}

extension WorkoutExercise {
    var resolvedBuiltinExercise: BuiltinExercise? {
        ExerciseLibrary.resolve(code: builtinExerciseCode, name: exerciseName)
    }

    var displayExerciseName: String {
        resolvedBuiltinExercise?.name ?? exerciseName
    }
}
