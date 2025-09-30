// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftMail",
    defaultLocalization: "ja",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "SwiftMailApp",
            targets: ["SwiftMailApp"]
        )
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SwiftMailCore",
            dependencies: []
        ),
        .target(
            name: "SwiftMailDatabase",
            dependencies: ["SwiftMailCore"],
            cSettings: [
                .define("SQLITE_ENABLE_FTS5", .when(platforms: [.macOS]))
            ]
        ),
        .executableTarget(
            name: "SwiftMailApp",
            dependencies: [
                "SwiftMailCore",
                "SwiftMailDatabase"
            ]
        ),
        .testTarget(
            name: "SwiftMailCoreTests",
            dependencies: ["SwiftMailCore"]
        ),
        .testTarget(
            name: "SwiftMailDatabaseTests",
            dependencies: ["SwiftMailDatabase"]
        )
    ]
)
