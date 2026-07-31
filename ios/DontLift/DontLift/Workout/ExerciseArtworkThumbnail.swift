import SwiftUI

/// 动作库卡片正式动作图；完整显示主体，留白和裁切边界由卡片媒体区统一处理。
struct ExerciseArtworkThumbnail: View {
    let image: UIImage
    var size: CGFloat = 48

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
