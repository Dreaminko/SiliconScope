//
//  File:      KtopApp.swift
//  Created:   2026-06-08
//  Updated:   2026-06-08
//  Developer: Kennt Kim / Calida Lab
//  Overview:  App entry point. Shows a full dashboard Window and a MenuBarExtra,
//             both backed by one shared KtopMonitor.
//  Notes:     Runs as an SPM executable (xcrun swift run ktop-app); activation policy
//             is set to .regular at runtime so the window + Dock icon appear without a
//             bundled Info.plist. A proper .app bundle comes in the packaging step.
//
import SwiftUI
import AppKit

@main
struct KtopApp: App {
    @State private var monitor = KtopMonitor()

    var body: some Scene {
        Window("WhisPlayInfo", id: "ktop-main") {
            DashboardView(monitor: monitor)
                .frame(minWidth: 756, minHeight: 760)
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
                       let icon = NSImage(contentsOf: url) {
                        NSApplication.shared.applicationIconImage = icon
                    }
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    monitor.start()
                }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 864, height: 800)

        MenuBarExtra("WhisPlayInfo", systemImage: "chart.bar.xaxis") {
            MenuBarView(monitor: monitor)
                .onAppear { monitor.start() }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
