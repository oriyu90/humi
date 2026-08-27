// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Humi",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Humi", targets: ["Humi"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.20.0")
    ],
    targets: [
        .target(
            name: "HumiKit",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/HumiKit",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                // Lets the self-test executable use `@testable import HumiKit`
                // without needing XCTest/swift-testing (absent under Command Line Tools).
                // Unconditional (not debug-only): a plain `swift build` / `swift build -c
                // release` resolves every product, so gating this to debug made those
                // commands fail to compile HumiTests. The cost on a UI app this size is
                // negligible.
                .unsafeFlags(["-enable-testing"])
            ]
        ),
        .executableTarget(
            name: "Humi",
            dependencies: ["HumiKit"],
            path: "Sources/Humi",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "HumiTests",
            dependencies: ["HumiKit"],
            path: "Tests/HumiTests",
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .unsafeFlags(["-enable-testing"])
            ]
        )
    ]
)
