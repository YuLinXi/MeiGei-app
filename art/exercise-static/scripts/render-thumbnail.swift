#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let outputPixels = 288
private let whiteBackgroundDistance = 52.0

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("错误：\(message)\n".utf8))
    exit(1)
}

guard CommandLine.arguments.count == 3 || CommandLine.arguments.count == 4 else {
    fail("用法：render-thumbnail.swift <input.png> <output.jpg> [jpegQuality]")
}

let jpegQuality: Double = {
    guard CommandLine.arguments.count == 4 else { return 0.82 }
    guard let value = Double(CommandLine.arguments[3]), (0...1).contains(value) else {
        fail("jpegQuality 必须是 0 到 1 之间的数字")
    }
    return value
}()

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fail("无法解码输入图片：\(inputURL.path)")
}

let cropSide = min(image.width, image.height)
let cropRect = CGRect(
    x: (image.width - cropSide) / 2,
    y: (image.height - cropSide) / 2,
    width: cropSide,
    height: cropSide
)
guard let cropped = image.cropping(to: cropRect) else {
    fail("无法执行居中方形裁切：\(inputURL.path)")
}

guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(
        data: nil,
        width: outputPixels,
        height: outputPixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
      ) else {
    fail("无法创建 sRGB 渲染上下文")
}

// JPG 不支持透明通道，统一合成纯白底，避免卡片内出现烘焙色块。
context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
context.fill(CGRect(x: 0, y: 0, width: outputPixels, height: outputPixels))
context.interpolationQuality = .high
context.draw(cropped, in: CGRect(x: 0, y: 0, width: outputPixels, height: outputPixels))

// imagegen 母版可能已把暖粉底烘焙为不透明像素。以四角颜色为基准，
// 将相近的浅色背景确定性归一为纯白，不改变人物、肌肉和器械主体。
guard let rawData = context.data else {
    fail("无法读取缩略图像素")
}
let bytesPerRow = context.bytesPerRow
let pixels = rawData.bindMemory(to: UInt8.self, capacity: bytesPerRow * outputPixels)
let cornerSize = 10
let cornerOrigins = [
    (0, 0),
    (outputPixels - cornerSize, 0),
    (0, outputPixels - cornerSize),
    (outputPixels - cornerSize, outputPixels - cornerSize)
]
var redTotal = 0.0
var greenTotal = 0.0
var blueTotal = 0.0
var sampleCount = 0.0
for (originX, originY) in cornerOrigins {
    for y in originY..<(originY + cornerSize) {
        for x in originX..<(originX + cornerSize) {
            let offset = y * bytesPerRow + x * 4
            redTotal += Double(pixels[offset])
            greenTotal += Double(pixels[offset + 1])
            blueTotal += Double(pixels[offset + 2])
            sampleCount += 1
        }
    }
}
let background = (redTotal / sampleCount, greenTotal / sampleCount, blueTotal / sampleCount)
for y in 0..<outputPixels {
    for x in 0..<outputPixels {
        let offset = y * bytesPerRow + x * 4
        let distance = sqrt(
            pow(Double(pixels[offset]) - background.0, 2)
            + pow(Double(pixels[offset + 1]) - background.1, 2)
            + pow(Double(pixels[offset + 2]) - background.2, 2)
        )
        if distance <= whiteBackgroundDistance {
            pixels[offset] = 255
            pixels[offset + 1] = 255
            pixels[offset + 2] = 255
            pixels[offset + 3] = 255
        }
    }
}

guard let rendered = context.makeImage() else {
    fail("无法生成缩略图像素")
}

try? FileManager.default.removeItem(at: outputURL)
try? FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

guard let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    UTType.jpeg.identifier as CFString,
    1,
    nil
) else {
    fail("无法创建 JPG 输出：\(outputURL.path)")
}

let properties: [CFString: Any] = [
    kCGImageDestinationLossyCompressionQuality: jpegQuality,
    kCGImagePropertyColorModel: kCGImagePropertyColorModelRGB,
    kCGImagePropertyProfileName: "sRGB IEC61966-2.1"
]
CGImageDestinationAddImage(destination, rendered, properties as CFDictionary)
guard CGImageDestinationFinalize(destination) else {
    fail("JPG 编码失败：\(outputURL.path)")
}

print(outputURL.path)
