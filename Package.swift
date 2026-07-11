// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClipboardStation",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ClipboardStation", targets: ["ClipboardStation"])
    ],
    targets: [
        .executableTarget(
            name: "ClipboardStation",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("CryptoKit"),
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Vision")
            ]
        )
    ]
)
