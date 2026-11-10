import SwiftUI
import UIKit
import Testing
@testable import DontLift

@Suite(.serialized)
@MainActor
struct ThemeTypographyTests {
    @Test func defaultReadingSizeKeepsEstablishedSystemTypeScale() {
        let cases: [(Theme.Font.Token, CGFloat)] = [
            (Theme.Font.hero, 32), (Theme.Font.l1, 23), (Theme.Font.l2, 16),
            (Theme.Font.l3, 15), (Theme.Font.l4, 13), (Theme.Font.l5, 11)
        ]
        for (token, expectedSize) in cases {
            let actual = measure(Text("训练记录 123").font(token), at: .large)
            let reference = measure(Text("训练记录 123").font(.system(size: expectedSize, weight: token.weight)), at: .large)
            #expect(abs(actual.height - reference.height) < 0.5)
        }
    }

    @Test func systemMonoFallbackUsesOneCaptionScale() {
        let token = Theme.Font.Token(size: 14, weight: .regular, relativeTo: .caption, family: .system(.monospaced))
        let expectedSize = UIFontMetrics(forTextStyle: .caption1).scaledValue(
            for: 14, compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))
        let actual = measure(Text("0123456789").font(token), at: .accessibility5)
        let reference = measure(Text("0123456789").font(.system(size: expectedSize, design: .monospaced)), at: .accessibility5)
        #expect(abs(actual.height - reference.height) < 1)
    }

    @Test func roundedDataKeepsItsFamilyAndScalesOnce() {
        for (size, category) in [(DynamicTypeSize.large, UIContentSizeCategory.large),
                                 (.accessibility5, .accessibilityExtraExtraExtraLarge)] {
            let points = UIFontMetrics(forTextStyle: .title1).scaledValue(
                for: 28, compatibleWith: UITraitCollection(preferredContentSizeCategory: category))
            let token = Theme.Font.display(size: 28, weight: .heavy, relativeTo: .title, design: .rounded)
            let actual = measure(Text("128 / 1234").font(token), at: size)
            let reference = measure(Text("128 / 1234").font(.system(size: points, weight: .heavy, design: .rounded)), at: size)
            #expect(abs(actual.width - reference.width) < 0.5)
            #expect(abs(actual.height - reference.height) < 0.5)
        }
    }

    @Test func registeredMonoUsesOneCaptionScale() throws {
        Theme.Font.verifyOrFallback()
        _ = try #require(UIFont(name: Theme.Font.monoRegularPS, size: 14))
        let expectedSize = UIFontMetrics(forTextStyle: .caption1).scaledValue(
            for: 14, compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))
        let actual = measure(Text("0123456789").font(Theme.Font.mono(size: 14)), at: .accessibility5)
        let reference = measure(Text("0123456789").font(.custom(Theme.Font.monoRegularPS, fixedSize: expectedSize)), at: .accessibility5)
        #expect(abs(actual.height - reference.height) < 1)
    }

    @Test func systemBodyFollowsReadingSize() {
        let text = Text("训练记录 123").font(Theme.Font.body(size: 16))
        let standard = measure(text, at: .large)
        let larger = measure(text, at: .xxxLarge)
        let accessibility = measure(text, at: .accessibility5)
        #expect(standard.height > 0)
        #expect(larger.height > standard.height)
        #expect(accessibility.height > standard.height * 1.5)
    }

    @Test func systemTitleFollowsReadingSize() {
        let text = Text("个人训练计划").font(Theme.Font.l1)
        let standard = measure(text, at: .large)
        let accessibility = measure(text, at: .accessibility5)
        #expect(accessibility.height > standard.height * 1.5)
    }

    @Test func registeredMonoFollowsReadingSize() {
        Theme.Font.verifyOrFallback()
        let text = Text("0123456789").font(Theme.Font.mono(size: 14))
        let standard = measure(text, at: .large)
        let accessibility = measure(text, at: .accessibility5)
        #expect(accessibility.height > standard.height * 1.5)
    }

    private func measure<Content: View>(_ content: Content, at size: DynamicTypeSize) -> CGSize {
        let controller = UIHostingController(rootView: content.environment(\.dynamicTypeSize, size).fixedSize())
        return controller.sizeThatFits(in: CGSize(width: 2000, height: 2000))
    }
}
