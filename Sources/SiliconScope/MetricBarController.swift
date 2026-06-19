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

        Spec(id: "gpu", key: "menubar.gpu",
             glyph: { m, dark in
                MenuBarGlyph.bars(label: "GPU",
                                  values: [m.snapshot.gpu.usage,
                                           min(1, m.snapshot.bandwidth.mediaGBs / max(m.mediaPeakGBs, 0.5)),
                                           min(1, m.snapshot.power.aneWatts / max(m.anePeakWatts, 0.1))],
                                  colors: [MetricPalette.gpu, MetricPalette.media, MetricPalette.ane], dark: dark)
             },
             dropdown: { m in AnyView(GPUMenuDropdown(monitor: m)) }),

        Spec(id: "mem", key: "menubar.mem",
             glyph: { m, dark in
                MenuBarGlyph.twoLine(label: "MEM",
                                     line1: "U " + compactGB(m.snapshot.memory.usedGB),
                                     line2: "F " + compactGB(m.snapshot.memory.freeGB), dark: dark)
             },
             dropdown: { m in AnyView(MEMMenuDropdown(monitor: m)) }),

        Spec(id: "net", key: "menubar.net",
             glyph: { m, dark in
                MenuBarGlyph.twoLine(label: "NET",
                                     line1: "↓" + compactRate(m.snapshot.network.downloadBytesPerSec),
                                     line2: "↑" + compactRate(m.snapshot.network.uploadBytesPerSec), dark: dark)
             },
             dropdown: { m in AnyView(NETMenuDropdown(monitor: m)) }),

        Spec(id: "ssd", key: "menubar.ssd",
             glyph: { m, dark in
                MenuBarGlyph.twoLine(label: "SSD",
                                     line1: "U " + compactBytes(m.snapshot.disk.totalBytes - m.snapshot.disk.freeBytes),
                                     line2: "F " + compactBytes(m.snapshot.disk.freeBytes), dark: dark)
             },
             dropdown: { m in AnyView(SSDMenuDropdown(monitor: m)) }),
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
