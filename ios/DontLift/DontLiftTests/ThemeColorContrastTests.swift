import UIKit
import Testing
@testable import DontLift

@MainActor
struct ThemeColorContrastTests {
    private struct RGBA {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        var alpha: CGFloat

        func over(_ background: Self) -> Self {
            Self(red: red * alpha + background.red * (1 - alpha),
                 green: green * alpha + background.green * (1 - alpha),
                 blue: blue * alpha + background.blue * (1 - alpha), alpha: 1)
        }

        var luminance: CGFloat {
            func linear(_ value: CGFloat) -> CGFloat {
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }
    }

    @Test func interfaceTextMeetsContrastOnPaperSurfaces() throws {
        for background in ["bg", "surface", "surface2"] {
            let paper = try color(background)
            for foreground in ["fg", "fg2", "muted", "ok", "danger", "action"] {
                let ratio = contrast(try color(foreground), paper)
                #expect(ratio >= 4.5, "\(foreground) on \(background): \(ratio)")
            }
        }
    }

    @Test func whiteTextMeetsContrastOnFilledActions() throws {
        let white = RGBA(red: 1, green: 1, blue: 1, alpha: 1)
        let ratio = contrast(white, try color("action"))
        #expect(ratio >= 4.5)
        for background in ["bg", "surface", "surface2"] {
            var ink = try color("action")
            ink.alpha = 0.9
            #expect(contrast(white, ink.over(try color(background))) >= 4.5)
        }
    }

    @Test func selectedAndStatusTextMeetsContrastOnTintedPaper() throws {
        for background in ["bg", "surface", "surface2"] {
            let paper = try color(background)
            let action = try color("action")
            let selection = try color("accentSoft").over(paper)
            #expect(contrast(action, selection) >= 4.5)
            for status in ["ok", "danger"] {
                let ink = try color(status)
                var tint = ink
                tint.alpha = 0.10
                #expect(contrast(ink, tint.over(paper)) >= 4.5, "\(status) on tinted \(background)")
            }
        }
    }

    private func color(_ name: String) throws -> RGBA {
        let color = try #require(UIColor(named: name))
            .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        try #require(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        return RGBA(red: red, green: green, blue: blue, alpha: alpha)
    }

    private func contrast(_ foreground: RGBA, _ background: RGBA) -> CGFloat {
        let ink = foreground.over(background).luminance
        let paper = background.luminance
        return (max(ink, paper) + 0.05) / (min(ink, paper) + 0.05)
    }
}
