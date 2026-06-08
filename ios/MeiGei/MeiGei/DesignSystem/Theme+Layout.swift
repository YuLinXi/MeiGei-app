import CoreGraphics

extension Theme {
    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 14
        static let lg:  CGFloat = 22
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 44
    }

    enum Radius {
        // 对齐 C 设计稿：r-sm 8 / r-md 13 / r-lg 18 / pill
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 13
        static let lg:   CGFloat = 18
        /// 用于 capsule，配合 `RoundedRectangle` 时用一个大数即可。
        static let pill: CGFloat = 999
    }
}
