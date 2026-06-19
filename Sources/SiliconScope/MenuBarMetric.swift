//
//  File:      MenuBarMetric.swift
//  Created:   2026-06-19
//  Updated:   2026-06-19
//  Developer: Kennt Kim / Calida Lab
//  Overview:  iStat-style per-metric menu-bar items. Each dashboard card can be toggled
//             into its own menu-bar item (a stacked label + a mini histogram or two-line
//             value readout), with its own dropdown. Glyphs are drawn to NSImage (the only
//             reliable way to render a live MenuBarExtra label) and adapt to the menu-bar
//             appearance; value bars keep their metric color.
//  Notes:     Per-metric on/off persists in UserDefaults ("menubar.cpu" etc.); the App
//             conditionally inserts a MenuBarExtra per enabled metric. The combined SS
//             glyph (MenuBarIcon) stays on by default.
//
import SwiftUI
import AppKit
import SiliconScopeCore

// MARK: - Glyph rendering (NSImage)

enum MenuBarGlyph {
    private static let height: CGFloat = 18

    /// Stacked label like iStat ("CPU" → C/P/U). Returns the column width it occupied.
    @discardableResult
    private static func drawStackedLabel(_ text: String, ink: NSColor) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 6.5, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink.withAlphaComponent(0.85)]
        let chars = text.map { String($0) as NSString }
        let colW = ceil(chars.map { $0.size(withAttributes: attrs).width }.max() ?? 6)
        let slot = height / CGFloat(chars.count)
        for (i, ch) in chars.enumerated() {
            let sz = ch.size(withAttributes: attrs)
            let y = height - CGFloat(i + 1) * slot + (slot - sz.height) / 2
            ch.draw(at: NSPoint(x: (colW - sz.width) / 2, y: y), withAttributes: attrs)
        }
        return colW
    }

    /// Stacked label + a mini history histogram (CPU / GPU). `values` are 0...1.
    static func histogram(label: String, values: [Double], color: NSColor, dark: Bool) -> NSImage {
        let ink = dark ? NSColor.white : NSColor.black
        let barCount = 11
        let barW: CGFloat = 2.0, barGap: CGFloat = 1.0, gap: CGFloat = 2.5
        let barsW = CGFloat(barCount) * barW + CGFloat(barCount - 1) * barGap
        // measure label column once (re-measured in the draw block; cheap)
        let labelW: CGFloat = 7
        let width = ceil(labelW + gap + barsW) + 1
        let img = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let w = drawStackedLabel(label, ink: ink)
            let originX = w + gap
            let track = ink.withAlphaComponent(0.14)
            let vals = Array(values.suffix(barCount))
            for i in 0..<barCount {
                let x = originX + CGFloat(i) * (barW + barGap)
                track.setFill()
                NSBezierPath(rect: NSRect(x: x, y: 0, width: barW, height: height)).fill()
                let idx = i - (barCount - vals.count)
                if idx >= 0, idx < vals.count {
                    let v = max(0, min(1, vals[idx]))
                    color.setFill()
                    NSBezierPath(rect: NSRect(x: x, y: 0, width: barW, height: max(1.5, height * CGFloat(v)))).fill()
                }
            }
            return true
        }
        img.isTemplate = false
        return img
    }

    /// Stacked label + thick value bars (SS-glyph thickness), one color per bar with a
    /// full-height track. Used for CPU (E left, P right) and other few-value metrics.
    static func bars(label: String, values: [Double], colors: [NSColor], dark: Bool) -> NSImage {
        let ink = dark ? NSColor.white : NSColor.black
        let barW: CGFloat = 6.5, gap: CGFloat = 2.0, radius: CGFloat = 1.2
        let n = CGFloat(values.count)
        let barsW = barW * n + gap * (n - 1)
        let labelW: CGFloat = 8, lgap: CGFloat = 3
        let width = ceil(labelW + lgap + barsW) + 1
        let track = ink.withAlphaComponent(0.16)
        let img = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let w = drawStackedLabel(label, ink: ink)
            let originX = w + lgap
            for (i, v) in values.enumerated() {
                let x = originX + CGFloat(i) * (barW + gap)
                track.setFill()
                NSBezierPath(roundedRect: NSRect(x: x, y: 0, width: barW, height: height),
                             xRadius: radius, yRadius: radius).fill()
                let h = max(2.5, height * CGFloat(min(1, max(0, v))))
                colors[min(i, colors.count - 1)].setFill()
                NSBezierPath(roundedRect: NSRect(x: x, y: 0, width: barW, height: h),
                             xRadius: radius, yRadius: radius).fill()
            }
            return true
        }
        img.isTemplate = false
        return img
    }

    /// Stacked label + two short value lines (MEM / NET / SSD), iStat "U:/F:" style.
    static func twoLine(label: String, line1: String, line2: String, dark: Bool) -> NSImage {
        let ink = dark ? NSColor.white : NSColor.black
        let font = NSFont.systemFont(ofSize: 8.5, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink.withAlphaComponent(0.92)]
        let s1 = line1 as NSString, s2 = line2 as NSString
        let textW = ceil(max(s1.size(withAttributes: attrs).width, s2.size(withAttributes: attrs).width))
        let gap: CGFloat = 3, labelW: CGFloat = 7
        let width = ceil(labelW + gap + textW) + 2
        let img = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let w = drawStackedLabel(label, ink: ink)
            let originX = w + gap
            let lh = s1.size(withAttributes: attrs).height
            s1.draw(at: NSPoint(x: originX, y: height / 2 + (height / 2 - lh) / 2), withAttributes: attrs)  // top
            s2.draw(at: NSPoint(x: originX, y: (height / 2 - lh) / 2), withAttributes: attrs)               // bottom
            return true
        }
        img.isTemplate = false
        return img
    }
}

// MARK: - Shared palette + helpers

enum MetricPalette {
    static let eCPU = NSColor(srgbRed: 0.95, green: 0.70, blue: 0.30, alpha: 1)  // E-cores amber
    static let pCPU = NSColor(srgbRed: 0.36, green: 0.62, blue: 0.98, alpha: 1)  // P-cores blue
}

/// Brings the main dashboard window forward from AppKit (the per-metric popovers are hosted
/// outside the SwiftUI scene, so @Environment(\.openWindow) isn't available there).
@MainActor func openMainDashboard() {
    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.activate(ignoringOtherApps: true)
    if let w = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "siliconscope-main" }) {
        w.makeKeyAndOrderFront(nil)
    } else {
        NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
    }
}

/// Centered accent section header, iStat-style.
struct MenuSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1)
            .foregroundStyle(Theme.accent).frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - CPU dropdown

struct CPUMenuDropdown: View {
    let monitor: SiliconScopeMonitor
    @AppStorage("temperatureFahrenheit") private var fahrenheit = false

    var body: some View {
        let s = monitor.snapshot
        let e = Color(nsColor: MetricPalette.eCPU)
        let p = Color(nsColor: MetricPalette.pCPU)
        VStack(alignment: .leading, spacing: 7) {
            MenuSectionHeader("CPU")
            coreRow("E-cores", s.cpu.eUsage, s.cpu.eUsagePercent, s.cpu.eFreqMHz, e)
            coreRow("P-cores", s.cpu.pUsage, s.cpu.pUsagePercent, s.cpu.pFreqMHz, p)
            ZStack {   // E (amber) + P (blue) usage history, overlaid
                Sparkline(values: monitor.history.eCPU, color: e, height: 32, yDomain: 0...1)
                Sparkline(values: monitor.history.pCPU, color: p, height: 32, yDomain: 0...1)
            }
            kv("Temperature", formatTemperature(s.temperature.cpuCelsius, fahrenheit: fahrenheit))
            kv("Load avg", SystemInfo.loadAverageString())
            kv("Uptime", SystemInfo.uptimeString())
            Divider()
            MenuSectionHeader("Top Processes")
            ForEach(Array(s.processes.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(5))) { proc in
                HStack(spacing: 6) {
                    Text(proc.name).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.text)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 0)
                    Text(String(format: "%.0f%%", proc.cpuPercent))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.heat(min(1, proc.cpuPercent / 100)))
                }
            }
            Divider()
            Button { openMainDashboard() } label: {
                Label("Open Dashboard", systemImage: "macwindow").frame(maxWidth: .infinity)
            }
        }
        .padding(12).frame(width: 280).background(Theme.bg).foregroundStyle(Theme.text)
    }

    private func coreRow(_ label: String, _ v: Double, _ pct: Double, _ mhz: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(label).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.text)
                Spacer(minLength: 0)
                Text(String(format: "%.0f%%", pct)).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Theme.dim)
                Text(String(format: "%.0f MHz", mhz)).font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Theme.faint).frame(width: 64, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule().fill(color).frame(width: max(2, geo.size.width * min(1, max(0, v))))
                }
            }.frame(height: 5)
        }
    }

    private func kv(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim)
            Spacer()
            Text(value).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Theme.text)
        }
    }
}

// MARK: - Card-title toggle (promote a card to its own menu-bar item)

/// Small, unobtrusive toggle in a card title — promotes the card to its own menu-bar item.
/// A compact icon button (a full switch overpowers the card header).
struct MenuBarPin: View {
    @Binding var isOn: Bool
    var body: some View {
        Button { isOn.toggle() } label: {
            Image(systemName: isOn ? "menubar.rectangle" : "rectangle.dashed")
                .font(.system(size: 10.5))
                .foregroundStyle(isOn ? Theme.accent : Theme.faint)
        }
        .buttonStyle(.plain)
        .help(isOn ? "Showing in the menu bar — click to hide" : "Show this in the menu bar")
    }
}
