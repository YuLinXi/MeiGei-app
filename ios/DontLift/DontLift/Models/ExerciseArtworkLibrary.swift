import CryptoKit
import Foundation
import UIKit

private final class ExerciseArtworkBundleMarker {}

struct ExerciseArtworkRecord: Codable, Equatable {
    let file: String
    let sha256: String
    let pixelWidth: Int
    let pixelHeight: Int
    let sizeBytes: Int
}

private struct ExerciseArtworkManifest: Codable {
    let schemaVersion: Int
    let assets: [String: ExerciseArtworkRecord]
}

enum ExerciseArtworkCatalogError: Error, Equatable {
    case unsupportedSchema(Int)
    case unknownCode(String)
    case invalidRecord(String)
}

/// 已随 App 打包的动作缩略图目录。只按稳定 code 查询，不接受动作名称猜测。
final class ExerciseArtworkCatalog {
    private let records: [String: ExerciseArtworkRecord]
    private let resourceDirectory: URL
    private let cache = NSCache<NSString, UIImage>()

    init(manifestData: Data,
         resourceDirectory: URL,
         allowedCodes: Set<String>) throws {
        let manifest = try JSONDecoder().decode(ExerciseArtworkManifest.self, from: manifestData)
        guard manifest.schemaVersion == 1 else {
            throw ExerciseArtworkCatalogError.unsupportedSchema(manifest.schemaVersion)
        }
        for (code, record) in manifest.assets {
            guard allowedCodes.contains(code) else {
                throw ExerciseArtworkCatalogError.unknownCode(code)
            }
            guard record.file == "exercise_\(code).jpg",
                  URL(fileURLWithPath: record.file).lastPathComponent == record.file,
                  record.sha256.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
                  record.pixelWidth == 288,
                  record.pixelHeight == 288,
                  record.sizeBytes > 0,
                  record.sizeBytes <= 24_576 else {
                throw ExerciseArtworkCatalogError.invalidRecord(code)
            }
        }
        records = manifest.assets
        self.resourceDirectory = resourceDirectory
    }

    func record(forCode code: String) -> ExerciseArtworkRecord? {
        records[code]
    }

    func image(forCode code: String) -> UIImage? {
        if let cached = cache.object(forKey: code as NSString) {
            return cached
        }
        guard let record = records[code] else { return nil }
        let fileURL = resourceDirectory.appendingPathComponent(record.file, isDirectory: false)
        guard let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe),
              data.count == record.sizeBytes,
              Self.sha256(data) == record.sha256,
              let image = UIImage(data: data),
              image.cgImage?.width == record.pixelWidth,
              image.cgImage?.height == record.pixelHeight else {
            return nil
        }
        cache.setObject(image, forKey: code as NSString)
        return image
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

enum ExerciseArtworkLibrary {
    private static let subdirectory = "Resources/ExerciseArtwork"
    private static let catalog: ExerciseArtworkCatalog? = loadCatalog()

    static func image(forBuiltinCode code: String?) -> UIImage? {
        guard let code else { return nil }
        return catalog?.image(forCode: code)
    }

    static func record(forBuiltinCode code: String) -> ExerciseArtworkRecord? {
        catalog?.record(forCode: code)
    }

    private static func loadCatalog() -> ExerciseArtworkCatalog? {
        let allowedCodes = Set(BuiltinExercise.starter.map(\.code))
        for bundle in candidateBundles {
            let urls = [
                bundle.url(forResource: "exercise_artwork_manifest_v1",
                           withExtension: "json",
                           subdirectory: subdirectory),
                bundle.url(forResource: "exercise_artwork_manifest_v1", withExtension: "json")
            ].compactMap { $0 }
            for url in urls {
                guard let data = try? Data(contentsOf: url),
                      let catalog = try? ExerciseArtworkCatalog(
                        manifestData: data,
                        resourceDirectory: url.deletingLastPathComponent(),
                        allowedCodes: allowedCodes
                      ) else {
                    continue
                }
                return catalog
            }
        }
        return nil
    }

    private static var candidateBundles: [Bundle] {
        var bundles = [Bundle.main, Bundle(for: ExerciseArtworkBundleMarker.self)]
        if let resourceBundle = Bundle(identifier: "com.yulinxi.app.DontLift") {
            bundles.append(resourceBundle)
        }
        var seen = Set<String>()
        return bundles.filter { seen.insert($0.bundlePath).inserted }
    }
}
