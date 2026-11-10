// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BiscuitTab",
    platforms: [.macOS(.v12)],
    targets: [.executableTarget(name: "BiscuitTab", path: "Sources/BiscuitTab")]
)
