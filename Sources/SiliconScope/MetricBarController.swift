//
//  File:      MetricBarController.swift
//  Created:   2026-06-19
//  Updated:   2026-06-19
//  Developer: Kennt Kim / Calida Lab
//  Overview:  iStat-style per-metric menu-bar items via AppKit NSStatusItem. SwiftUI's
//             MenuBarExtra can't do dynamic toggling here (a conditional scene won't compile
//             — SceneBuilder has no buildOptional — and `isInserted:` triggers a main-menu
//             update loop), so each toggled metric gets a real NSStatusItem with a live
//             glyph and an NSPopover hosting its SwiftUI dropdown.
//  Notes:     Driven from the monitor loop via sync(monitor:): it adds/removes items as the
//             per-metric UserDefaults toggles flip and refreshes each glyph every tick. The
//             combined "SS" glyph stays a SwiftUI MenuBarExtra (always on).
//
import AppKit
import SwiftUI
import SiliconScopeCore

@MainActor
final class MetricBarController: NSObject {
    static let shared = MetricBarController()

    private struct Spec {
        let id: String
        let key: String
        let glyph: (SiliconScopeMonitor, Bool) -> NSImage
        let dropdown: (SiliconScopeMonitor) -> AnyView
    }

    private struct Entry { let item: NSStatusItem; let popover: NSPopover }

    private var entries: [String: Entry] = [:]
    private weak var monitor: SiliconScopeMonitor?

    private static let specs: [Spec] = [
        Spec(id: "cpu", key: "menubar.cpu",
             glyph: { m, dark in
                MenuBarGlyph.bars(label: "CPU",
                                  values: [m.snapshot.cpu.eUsage, m.snapshot.cpu.pUsage],  // left E, right P
                                  colors: [MetricPalette.eCPU, MetricPalette.pCPU], dark: dark)
             },
             dropdown: { m in AnyView(CPUMenuDropdown(monitor: m)) }),
    ]

    /// Called each monitor tick: reconcile items with toggles, refresh glyphs.
    func sync(monitor: SiliconScopeMonitor) {
        self.monitor = monitor
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        for spec in Self.specs {
            if UserDefaults.standard.bool(forKey: spec.key) {
                if entries[spec.id] == nil { entries[spec.id] = makeEntry(spec) }
                entries[spec.id]?.item.button?.image = spec.glyph(monitor, dark)
            } else if let e = entries[spec.id] {
                e.popover.performClose(nil)
                NSStatusBar.system.removeStatusItem(e.item)
                entries[spec.id] = nil
            }
        }
    }

    private func makeEntry(_ spec: Spec) -> Entry {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let popover = NSPopover()
        popover.behavior = .transient
        if let m = monitor {
            popover.contentViewController = NSHostingController(rootView: spec.dropdown(m))
        }
        if let button = item.button {
            button.target = self
            button.action = #selector(buttonClicked(_:))
            button.identifier = NSUserInterfaceItemIdentifier(spec.id)
        }
        return Entry(item: item, popover: popover)
    }

    @objc private func buttonClicked(_ sender: NSStatusBarButton) {
        guard let id = sender.identifier?.rawValue, let e = entries[id] else { return }
        if e.popover.isShown {
            e.popover.performClose(nil)
        } else {
            e.popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            e.popover.contentViewController?.view.window?.makeKey()
        }
    }
}
