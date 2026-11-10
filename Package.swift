// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "YetAltTab",
    platforms: [.macOS(.v12)],
    targets: [.executableTarget(name: "YetAltTab", path: "Sources/YetAltTab")]
)
