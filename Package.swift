// swift-tools-version: 6.1
//
//  File:      Package.swift
//  Created:   2026-06-08
//  Updated:   2026-06-08
//  Developer: Kennt Kim / Calida Lab
//  Overview:  SwiftPM manifest for ktop. Builds CIOReport (private-API C shim),
//             KtopCore (sudoless data layer, no UI), and ktop-cli (verification).
//  Notes:     IOReport has no SDK stub, so the final binary links with
//             -undefined dynamic_lookup; symbols resolve at runtime via dyld.
//             SwiftUI app is added later as a separate Xcode target (see CLAUDE.md).
//
import PackageDescription

let package = Package(
    name: "ktop",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KtopCore", targets: ["KtopCore"]),
        .executable(name: "ktop-cli", targets: ["ktop-cli"]),
        .executable(name: "WhisPlayInfo", targets: ["WhisPlayInfo"]),
    ],
    targets: [
        // Private IOReport declarations exposed to Swift.
        .target(name: "CIOReport"),

        // Sudoless data layer. Must NOT import SwiftUI.
        .target(
            name: "KtopCore",
            dependencies: ["CIOReport"]
        ),

        // Terminal verification tool for the data layer.
        .executableTarget(
            name: "ktop-cli",
            dependencies: ["KtopCore"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-undefined", "-Xlinker", "dynamic_lookup"]),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("IOKit"),
            ]
        ),

        // SwiftUI app (menu bar + full window). Runs via `xcrun swift run WhisPlayInfo`.
        .executableTarget(
            name: "WhisPlayInfo",
            dependencies: ["KtopCore"],
            resources: [.process("Resources")],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-undefined", "-Xlinker", "dynamic_lookup"]),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("IOKit"),
            ]
        ),
    ]
)
