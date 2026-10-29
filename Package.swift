// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Peekaboo",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Peekaboo", targets: ["Peekaboo"]),
        .executable(name: "peekaboo-hook", targets: ["peekaboo-hook"]),
    ],
    targets: [
        .target(name: "PeekabooCore"),
        .executableTarget(name: "peekaboo-hook", dependencies: ["PeekabooCore"]),
        .executableTarget(name: "Peekaboo", dependencies: ["PeekabooCore"]),
    ]
)
