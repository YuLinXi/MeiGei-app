#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let transparentDistance: Double = 8
private let featherDistance: Double = 30

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("错误：\(message)\n".utf8))
    exit(1)
}

guard CommandLine.arguments.count == 2 else {
    fail("用法：normalize-muscle-thumbnail-background.swift <Assets.xcassets>")
}

let assetsURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
guard let enumerator = FileManager.default.enumerator(
    at: assetsURL,
    includingPropertiesForKeys: [.isRegularFileKey],
    options: [.skipsHiddenFiles]
) else {
    fail("无法遍历资源目录：\(assetsURL.path)")
}

let imageURLs = enumerator.compactMap { item -> URL? in
    guard let url = item as? URL,
          url.pathExtension.lowercased() == "png",
          url.lastPathComponent.hasPrefix("muscleThumb_male_") else {
        return nil
    }
    return url
}.sorted { $0.path < $1.path }

guard !imageURLs.isEmpty else {
    fail("没有找到 muscleThumb_male_*.png")
}

guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
    fail("无法创建 sRGB 色彩空间")
}

var normalizedCount = 0
var skippedCount = 0
for imageURL in imageURLs {
    guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fail("无法解码：\(imageURL.path)")
    }

    let bytesPerRow = image.width * 4
    var pixels = [UInt8](repeating: 0, count: bytesPerRow * image.height)
    guard let context = CGContext(
        data: &pixels,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        fail("无法创建像素上下文：\(imageURL.path)")
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

    let transparentPixelCount = stride(from: 3, to: pixels.count, by: 4)
        .reduce(into: 0) { count, offset in
            if pixels[offset] < 250 { count += 1 }
        }
    if transparentPixelCount > image.width * image.height / 10 {
        // 原始烘焙底图基本不含透明像素；超过 10% 即视为已经完成背景移除。
        skippedCount += 1
        continue
    }

    let cornerSize = max(2, min(8, min(image.width, image.height) / 8))
    let cornerOrigins = [
        (0, 0),
        (image.width - cornerSize, 0),
        (0, image.height - cornerSize),
        (image.width - cornerSize, image.height - cornerSize)
    ]
    var redTotal = 0.0
    var greenTotal = 0.0
    var blueTotal = 0.0
    var sampleCount = 0.0
    var cornerPixelCount = 0.0
    var transparentCornerCount = 0.0
    for (originX, originY) in cornerOrigins {
        for y in originY..<(originY + cornerSize) {
            for x in originX..<(originX + cornerSize) {
                let offset = y * bytesPerRow + x * 4
                cornerPixelCount += 1
                guard pixels[offset + 3] >= 250 else {
                    transparentCornerCount += 1
                    continue
                }
                redTotal += Double(pixels[offset])
                greenTotal += Double(pixels[offset + 1])
                blueTotal += Double(pixels[offset + 2])
                sampleCount += 1
            }
        }
    }
    if transparentCornerCount > cornerPixelCount / 2 || sampleCount == 0 {
        // 原图背景四角完全不透明；处理后大多数四角像素透明。重复执行时不再次削弱轮廓。
        skippedCount += 1
        continue
    }
    let background = (redTotal / sampleCount, greenTotal / sampleCount, blueTotal / sampleCount)

    for y in 0..<image.height {
        for x in 0..<image.width {
            let offset = y * bytesPerRow + x * 4
            let originalAlpha = Double(pixels[offset + 3])
            guard originalAlpha > 0 else { continue }
            let distance = sqrt(
                pow(Double(pixels[offset]) - background.0, 2)
                + pow(Double(pixels[offset + 1]) - background.1, 2)
                + pow(Double(pixels[offset + 2]) - background.2, 2)
            )
            guard distance < featherDistance else { continue }

            let alphaFactor = distance <= transparentDistance
                ? 0
                : (distance - transparentDistance) / (featherDistance - transparentDistance)
            let newAlpha = UInt8((originalAlpha * alphaFactor).rounded())
            if originalAlpha > 0 {
                let scale = Double(newAlpha) / originalAlpha
                pixels[offset] = UInt8((Double(pixels[offset]) * scale).rounded())
                pixels[offset + 1] = UInt8((Double(pixels[offset + 1]) * scale).rounded())
                pixels[offset + 2] = UInt8((Double(pixels[offset + 2]) * scale).rounded())
            }
            pixels[offset + 3] = newAlpha
        }
    }

    guard let normalized = context.makeImage() else {
        fail("无法生成透明背景图片：\(imageURL.path)")
    }
    let temporaryURL = imageURL.deletingLastPathComponent()
        .appendingPathComponent(".\(imageURL.lastPathComponent).tmp")
    try? FileManager.default.removeItem(at: temporaryURL)
    guard let destination = CGImageDestinationCreateWithURL(
        temporaryURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        fail("无法创建临时 PNG：\(temporaryURL.path)")
    }
    CGImageDestinationAddImage(destination, normalized, nil)
    guard CGImageDestinationFinalize(destination) else {
        fail("PNG 编码失败：\(imageURL.path)")
    }
    do {
        _ = try FileManager.default.replaceItemAt(imageURL, withItemAt: temporaryURL)
    } catch {
        fail("替换图片失败：\(imageURL.path)，\(error.localizedDescription)")
    }
    normalizedCount += 1
}

print("已移除 \(normalizedCount) 张肌肉缩略图的烘焙背景，跳过 \(skippedCount) 张已透明图片")
