//
//  File:      SiliconScopeApp.swift
//  Created:   2026-06-08
//  Updated:   2026-06-16
//  Developer: Kennt Kim / Calida Lab
//  Overview:  App entry point. Shows a full dashboard Window and a MenuBarExtra (with a
//             live 5-bar MenuBarIcon glyph), both backed by one shared SiliconScopeMonitor.
//  Notes:     Runs as an SPM executable (xcrun swift run SiliconScope); activation
//             policy is set to .regular at runtime so the window + Dock icon appear
//             without a bundled Info.plist. A proper .app bundle comes in packaging.
//             Icon is loaded via loadAppIcon() — never SwiftPM's Bundle.module, whose
//             generated accessor fatalErrors when the flat resource bundle is not a
//             valid bundle (crashes on macOS 27's stricter bundle validation).
//
import SwiftUI
import AppKit

@main
struct SiliconScopeApp: App {
    @State private var monitor = SiliconScopeMonitor()

    var body: some Scene {
        dashboardWindow
        mainMenuBar
        Settings { SettingsView() }
    }

    private var dashboardWindow: some Scene {
        Window("SiliconScope", id: "siliconscope-main") {
            DashboardView(monitor: monitor)
                .frame(minWidth: 640, minHeight: 600)
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    if let icon = Self.loadAppIcon() {
                        NSApplication.shared.applicationIconImage = icon
                    }
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    monitor.start()
                }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 700, height: 740)
    }

    private var mainMenuBar: some Scene {
        MenuBarExtra {
            MenuBarView(monitor: monitor)
                .onAppear { monitor.start() }
        } label: {
            MenuBarIcon(monitor: monitor)
        }
        .menuBarExtraStyle(.window)
    }

    /// Resolves the app icon without ever touching SwiftPM's `Bundle.module`.
    /// `Bundle.module`'s generated accessor calls `fatalError` when its resource
    /// bundle is not recognized as a bundle; the SwiftPM bundle is a flat folder
    /// with no Info.plist, which macOS 27's stricter validation rejects -> crash.
    private static func loadAppIcon() -> NSImage? {
        // Packaged .app: AppIcon.icns sits directly in Contents/Resources.
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            return icon
        }
        // Dev run (`swift run`): it lives inside the SwiftPM resource bundle next to
        // the executable. Resolve the path by hand so we never invoke Bundle.module.
        for base in [Bundle.main.resourceURL, Bundle.main.bundleURL].compactMap({ $0 }) {
            let url = base.appendingPathComponent("SiliconScope_SiliconScope.bundle/AppIcon.icns")
            if let icon = NSImage(contentsOf: url) { return icon }
        }
        return nil
    }
}
