// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PulseAnalytics",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PulseAnalytics",
            targets: ["PulseAnalytics"]
        ),
    ],
    targets: [
        .target(
            name: "PulseAnalytics",
            path: "Sources/PulseAnalytics",
            resources: [
                .copy("PrivacyInfo.xcprivacy")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "PulseAnalyticsTests",
            dependencies: ["PulseAnalytics"],
            path: "Tests/PulseAnalyticsTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
