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
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 14
        static let lg:   CGFloat = 22
        /// 用于 capsule，配合 `RoundedRectangle` 时用一个大数即可。
        static let pill: CGFloat = 999
    }
}
