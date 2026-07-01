// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MuscleThumbnailExporter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "muscle-thumbnail-exporter", targets: ["MuscleThumbnailExporter"])
    ],
    dependencies: [
        .package(url: "https://github.com/melihcolpan/MuscleMap.git", exact: "1.6.4")
    ],
    targets: [
        .executableTarget(
            name: "MuscleThumbnailExporter",
            dependencies: ["MuscleMap"]
        )
    ]
)
