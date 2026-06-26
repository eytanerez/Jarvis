// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Jarvis",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "JarvisLegacyNotch", targets: ["JarvisNotch"]),
        .executable(name: "JarvisTestHarness", targets: ["JarvisTestHarness"]),
        .library(name: "JarvisCore", targets: ["JarvisCore"]),
        .library(name: "JarvisMac", targets: ["JarvisMac"]),
        .library(name: "JarvisContext", targets: ["JarvisContext"]),
        .library(name: "JarvisUI", targets: ["JarvisUI"])
    ],
    targets: [
        .target(
            name: "JarvisCore"
        ),
        .target(
            name: "JarvisContext",
            dependencies: ["JarvisCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices")
            ]
        ),
        .target(
            name: "JarvisMac",
            dependencies: ["JarvisCore", "JarvisContext"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("FoundationModels"),
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("Speech")
            ]
        ),
        .target(
            name: "JarvisUI",
            dependencies: ["JarvisCore", "JarvisMac", "JarvisContext"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .executableTarget(
            name: "JarvisNotch",
            dependencies: ["JarvisCore", "JarvisMac", "JarvisContext", "JarvisUI"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .executableTarget(
            name: "JarvisTestHarness",
            dependencies: ["JarvisCore", "JarvisMac", "JarvisContext"]
        ),
        .testTarget(
            name: "JarvisTests",
            dependencies: ["JarvisCore"]
        )
    ]
)
