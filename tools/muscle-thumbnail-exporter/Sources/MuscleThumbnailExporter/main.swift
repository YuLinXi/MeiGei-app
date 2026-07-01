import AppKit
import Foundation
import MuscleMap
import SwiftUI

private enum ThumbnailSex: String {
    case male

    var gender: BodyGender {
        .male
    }
}

private enum ThumbnailFocus {
    case upper
    case armsUpper
    case armsBiceps
    case armsTriceps
    case armsForearms
    case shoulders
    case torso
    case lower
    case lowerAdductors
    case lowerCalves
    case glutes
    case full

    var scaleX: CGFloat {
        switch self {
        case .upper: return 2.95
        case .armsUpper: return 2.30
        case .armsBiceps: return 2.30
        case .armsTriceps: return 2.30
        case .armsForearms: return 2.05
        case .shoulders: return 2.35
        case .torso: return 2.45
        case .lower: return 2.55
        case .lowerAdductors: return 2.35
        case .lowerCalves: return 2.55
        case .glutes: return 2.45
        case .full: return 1.55
        }
    }

    var scaleY: CGFloat {
        switch self {
        case .armsUpper: return scaleX
        case .armsBiceps: return scaleX
        case .armsTriceps: return scaleX
        case .armsForearms: return scaleX
        case .shoulders: return 3.05
        default: return scaleX
        }
    }

    var artworkWidthRatio: CGFloat {
        switch self {
        case .shoulders: return 1.08
        default: return 0.98
        }
    }

    func offset(for size: CGFloat) -> CGSize {
        switch self {
        case .upper: return CGSize(width: 0, height: size * 1.18)
        case .armsUpper: return CGSize(width: 0, height: size * 0.94)
        case .armsBiceps: return CGSize(width: 0, height: size * 0.84)
        case .armsTriceps: return CGSize(width: 0, height: size * 0.84)
        case .armsForearms: return CGSize(width: 0, height: size * 0.18)
        case .shoulders: return CGSize(width: 0, height: size * 1.18)
        case .torso: return CGSize(width: 0, height: size * 0.30)
        case .lower: return CGSize(width: 0, height: -size * 0.42)
        case .lowerAdductors: return CGSize(width: 0, height: -size * 0.16)
        case .lowerCalves: return CGSize(width: 0, height: -size * 0.70)
        case .glutes: return CGSize(width: 0, height: -size * 0.12)
        case .full: return CGSize(width: 0, height: size * 0.04)
        }
    }
}

private struct ThumbnailSpec {
    let key: String
    let muscles: [Muscle]
    let side: BodySide
    let focus: ThumbnailFocus
}

private struct ThumbnailArtwork: View {
    let sex: ThumbnailSex
    let spec: ThumbnailSpec
    let size: CGFloat

    private var style: BodyViewStyle {
        BodyViewStyle(
            defaultFillColor: Color(red: 0.866, green: 0.835, blue: 0.788),
            strokeColor: Color(red: 0.79, green: 0.76, blue: 0.70),
            strokeWidth: 0.5,
            headColor: Color(red: 0.866, green: 0.835, blue: 0.788),
            hairColor: Color(red: 0.866, green: 0.835, blue: 0.788)
        )
    }

    var body: some View {
        ZStack {
            Color(red: 0.937, green: 0.925, blue: 0.898)
            BodyView(gender: sex.gender, side: spec.side, style: style)
                .highlight(spec.muscles, color: Color(red: 0.851, green: 0.282, blue: 0.169))
                .frame(width: size * spec.focus.artworkWidthRatio, height: size * 1.46)
                .scaleEffect(x: spec.focus.scaleX, y: spec.focus.scaleY)
                .offset(spec.focus.offset(for: size))
        }
        .frame(width: size, height: size)
        .clipped()
    }
}

@main
private struct Exporter {
    private static let logicalSize: CGFloat = 48
    private static let scale: CGFloat = 3

    private static let specs: [ThumbnailSpec] = [
        ThumbnailSpec(key: "chest", muscles: [.chest], side: .front, focus: .upper),
        ThumbnailSpec(key: "shoulders", muscles: [.deltoids], side: .front, focus: .shoulders),
        ThumbnailSpec(key: "shoulders_front", muscles: [.deltoids], side: .front, focus: .shoulders),
        ThumbnailSpec(key: "shoulders_rear", muscles: [.deltoids], side: .back, focus: .shoulders),
        ThumbnailSpec(key: "back", muscles: [.upperBack, .trapezius, .lowerBack], side: .back, focus: .upper),
        ThumbnailSpec(key: "back_lats", muscles: [.upperBack], side: .back, focus: .upper),
        ThumbnailSpec(key: "back_traps", muscles: [.trapezius], side: .back, focus: .upper),
        ThumbnailSpec(key: "back_rhomboids", muscles: [.upperBack], side: .back, focus: .upper),
        ThumbnailSpec(key: "back_lowerBack", muscles: [.lowerBack], side: .back, focus: .torso),
        ThumbnailSpec(key: "arms", muscles: [.biceps, .triceps, .forearm], side: .front, focus: .armsUpper),
        ThumbnailSpec(key: "arms_biceps", muscles: [.biceps], side: .front, focus: .armsBiceps),
        ThumbnailSpec(key: "arms_triceps", muscles: [.triceps], side: .back, focus: .armsTriceps),
        ThumbnailSpec(key: "arms_forearms", muscles: [.forearm], side: .front, focus: .armsForearms),
        ThumbnailSpec(key: "legs", muscles: [.quadriceps, .adductors], side: .front, focus: .lower),
        ThumbnailSpec(key: "legs_quads", muscles: [.quadriceps], side: .front, focus: .lower),
        ThumbnailSpec(key: "legs_hams", muscles: [.hamstring], side: .back, focus: .lower),
        ThumbnailSpec(key: "legs_adductors", muscles: [.adductors], side: .front, focus: .lowerAdductors),
        ThumbnailSpec(key: "legs_calves", muscles: [.calves], side: .back, focus: .lowerCalves),
        ThumbnailSpec(key: "glutes", muscles: [.gluteal], side: .back, focus: .glutes),
        ThumbnailSpec(key: "glutes_glutes", muscles: [.gluteal], side: .back, focus: .glutes),
        ThumbnailSpec(key: "glutes_gluteMed", muscles: [.gluteal], side: .back, focus: .glutes),
        ThumbnailSpec(key: "core", muscles: [.abs, .obliques], side: .front, focus: .torso),
        ThumbnailSpec(key: "core_abs", muscles: [.abs], side: .front, focus: .torso),
        ThumbnailSpec(key: "core_obliques", muscles: [.obliques], side: .front, focus: .torso),
        ThumbnailSpec(key: "neck", muscles: [.trapezius], side: .front, focus: .upper)
    ]

    @MainActor
    static func main() throws {
        let outputRoot = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "../../ios/DontLift/DontLift/Assets.xcassets")
            .standardizedFileURL

        for sex in [ThumbnailSex.male] {
            for spec in specs {
                let assetName = "muscleThumb_\(sex.rawValue)_\(spec.key)"
                let imageSetURL = outputRoot.appendingPathComponent("\(assetName).imageset", isDirectory: true)
                try FileManager.default.createDirectory(at: imageSetURL, withIntermediateDirectories: true)

                let pngName = "\(assetName)@3x.png"
                let pngURL = imageSetURL.appendingPathComponent(pngName)
                let content = ThumbnailArtwork(sex: sex, spec: spec, size: logicalSize)
                let renderer = ImageRenderer(content: content)
                renderer.scale = scale
                guard let cgImage = renderer.cgImage else {
                    throw ExportError.renderFailed(assetName)
                }
                let bitmap = NSBitmapImageRep(cgImage: cgImage)
                guard let data = bitmap.representation(using: .png, properties: [:]) else {
                    throw ExportError.pngFailed(assetName)
                }
                try data.write(to: pngURL, options: .atomic)
                try contentsJSON(filename: pngName).write(to: imageSetURL.appendingPathComponent("Contents.json"), options: .atomic)
            }
        }

        print("Exported \(specs.count) muscle thumbnail assets to \(outputRoot.path)")
    }

    private static func contentsJSON(filename: String) -> Data {
        let json = """
        {
          "images" : [
            {
              "filename" : "\(filename)",
              "idiom" : "universal",
              "scale" : "3x"
            }
          ],
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }

        """
        return Data(json.utf8)
    }
}

private enum ExportError: Error, CustomStringConvertible {
    case renderFailed(String)
    case pngFailed(String)

    var description: String {
        switch self {
        case .renderFailed(let name): return "Failed to render \(name)"
        case .pngFailed(let name): return "Failed to encode \(name)"
        }
    }
}
