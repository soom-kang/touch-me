// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TouchMe",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "TouchMe", targets: ["TouchMeApp"])],
    targets: [
        .target(name: "TouchMappingCore"),
        .target(name: "TouchMePlatform", dependencies: ["TouchMappingCore"]),
        .executableTarget(name: "TouchMeApp", dependencies: ["TouchMePlatform", "TouchMappingCore"]),
        .testTarget(name: "TouchMappingCoreTests", dependencies: ["TouchMappingCore"]),
        .testTarget(name: "TouchMePlatformTests", dependencies: ["TouchMePlatform", "TouchMappingCore"]),
    ],
    swiftLanguageModes: [.v5]
)
