import CryptoKit
import Foundation
import Testing
import UIKit
@testable import DontLift

struct ExerciseArtworkLibraryTests {
    @Test func bundledArtworkMatchesManifest() {
        let expectedAssets = [
            (code: "PEC_DECK_FLY", sizeBytes: 21_831),
            (code: "BB_BENCH_PRESS", sizeBytes: 18_702),
            (code: "BB_SQUAT", sizeBytes: 13_082),
            (code: "DEADLIFT", sizeBytes: 10_465),
            (code: "OHP", sizeBytes: 10_506),
            (code: "LATERAL_RAISE", sizeBytes: 11_424)
        ]

        for asset in expectedAssets {
            let record = ExerciseArtworkLibrary.record(forBuiltinCode: asset.code)
            #expect(record?.file == "exercise_\(asset.code).jpg")
            #expect(record?.pixelWidth == 288)
            #expect(record?.pixelHeight == 288)
            #expect(record?.sizeBytes == asset.sizeBytes)
            #expect(ExerciseArtworkLibrary.image(forBuiltinCode: asset.code) != nil)
        }
    }

    @Test func missingOrCorruptArtworkSafelyReturnsNil() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let corrupt = Data("not-a-jpeg".utf8)
        try corrupt.write(to: directory.appendingPathComponent("exercise_PEC_DECK_FLY.jpg"))
        let catalog = try ExerciseArtworkCatalog(
            manifestData: manifestData(code: "PEC_DECK_FLY", data: corrupt),
            resourceDirectory: directory,
            allowedCodes: ["PEC_DECK_FLY"]
        )

        #expect(catalog.image(forCode: "PEC_DECK_FLY") == nil)
        #expect(catalog.image(forCode: "BB_BENCH_PRESS") == nil)
    }

    @Test func unknownCodeIsRejectedAtManifestBoundary() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = Data("placeholder".utf8)

        #expect(throws: ExerciseArtworkCatalogError.unknownCode("UNKNOWN_CODE")) {
            try ExerciseArtworkCatalog(
                manifestData: manifestData(code: "UNKNOWN_CODE", data: data),
                resourceDirectory: directory,
                allowedCodes: ["PEC_DECK_FLY"]
            )
        }
    }

    @Test func nameOnlyCustomExerciseCannotResolveBuiltinArtwork() {
        #expect(ExerciseArtworkLibrary.image(forBuiltinCode: nil) == nil)
    }

    @Test func searchAndPickResolveTheSameBuiltinArtworkByCode() throws {
        let exercise = try #require(BuiltinExercise.starter.first { $0.code == "PEC_DECK_FLY" })
        #expect(ExerciseSearch.matches(exercise, query: "蝴蝶机 夹胸"))
        #expect(ExerciseArtworkLibrary.image(forBuiltinCode: exercise.code) != nil)

        let pick = ExercisePick(
            builtinCode: exercise.code,
            customId: nil,
            name: exercise.name,
            primaryMuscle: exercise.category,
            equipmentType: exercise.equipmentType
        )
        #expect(ExerciseArtworkLibrary.image(forBuiltinCode: pick.builtinCode) != nil)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("exercise-artwork-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func manifestData(code: String, data: Data) throws -> Data {
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let manifest: [String: Any] = [
            "schemaVersion": 1,
            "assets": [
                code: [
                    "file": "exercise_\(code).jpg",
                    "sha256": digest,
                    "pixelWidth": 288,
                    "pixelHeight": 288,
                    "sizeBytes": data.count
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: manifest)
    }
}
