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
            let rightEdge = w + gap + textW   // both lines right-aligned so values line up
            let w1 = s1.size(withAttributes: attrs).width
            let w2 = s2.size(withAttributes: attrs).width
            let lh = s1.size(withAttributes: attrs).height
            s1.draw(at: NSPoint(x: rightEdge - w1, y: height / 2 + (height / 2 - lh) / 2), withAttributes: attrs)  // top
            s2.draw(at: NSPoint(x: rightEdge - w2, y: (height / 2 - lh) / 2), withAttributes: attrs)               // bottom
            return true
        }
        img.isTemplate = false
        return img
    }
}

// MARK: - Shared palette + helpers

enum MetricPalette {
    static let eCPU  = NSColor(srgbRed: 0.95, green: 0.70, blue: 0.30, alpha: 1)  // E-cores amber
    static let pCPU  = NSColor(srgbRed: 0.36, green: 0.62, blue: 0.98, alpha: 1)  // P-cores blue
    static let gpu   = NSColor(srgbRed: 0.40, green: 0.82, blue: 0.55, alpha: 1)  // green
    static let media = NSColor(srgbRed: 0.98, green: 0.62, blue: 0.30, alpha: 1)  // orange
    static let ane   = NSColor(srgbRed: 0.74, green: 0.53, blue: 0.99, alpha: 1)  // purple
    static let down  = NSColor(srgbRed: 0.34, green: 0.74, blue: 0.62, alpha: 1)  // teal
    static let up    = NSColor(srgbRed: 0.98, green: 0.62, blue: 0.30, alpha: 1)  // orange
    // SwiftUI mirrors for dropdown views.
    static var gpuC: Color { Color(nsColor: gpu) }
    static var mediaC: Color { Color(nsColor: media) }
    static var aneC: Color { Color(nsColor: ane) }
    static var downC: Color { Color(nsColor: down) }
    static var upC: Color { Color(nsColor: up) }
}

// Compact one-token formatters for the tiny two-line glyphs ("44G", "3.4T", "202K").
func compactGB(_ gb: Double) -> String { gb >= 1024 ? String(format: "%.1fT", gb / 1024) : String(format: "%.0fG", gb) }
func compactBytes(_ b: UInt64) -> String { compactGB(Double(b) / 1_073_741_824) }
func compactRate(_ bytesPerSec: Double) -> String {
    let k = bytesPerSec / 1024
    return k >= 1024 ? String(format: "%.1fM", k / 1024) : String(format: "%.0fK", k)
}

// MARK: - Shared dropdown components

/// Small faint caption above a history sparkline so it's not a mystery line.
struct GraphCaption: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 8.5, design: .monospaced)).foregroundStyle(Theme.faint)
    }
}

struct MenuKV: View {
    let label: String, value: String
    var color: Color = Theme.text
    var body: some View {
        HStack {
            Text(label).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim)
            Spacer()
            Text(value).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(color)
        }
    }
}

/// Horizontal stacked segments (fractions summing ~1), iStat memory-bar style.
struct MenuStackedBar: View {
    let segments: [(Double, Color)]
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                    Rectangle().fill(seg.1).frame(width: max(0, geo.size.width * seg.0))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 9)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

/// Colored swatch + label + value (memory legend).
struct MenuLegendRow: View {
    let color: Color, label: String, value: String
    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 9, height: 9)
            Text(label).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.text)
            Spacer()
            Text(value).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Theme.text)
        }
    }
}

func memSize(_ bytes: UInt64) -> String {
    let gb = Double(bytes) / 1_073_741_824
    return gb >= 1 ? String(format: "%.2f GB", gb) : String(format: "%.0f MB", Double(bytes) / 1_048_576)
}

/// Label + value + a fixed-color fill bar (0...1).
struct MenuMeterRow: View {
    let label: String, value: String
    let fraction: Double, color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(label).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.text)
                Spacer(minLength: 0)
                Text(value).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Theme.dim)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule().fill(color).frame(width: max(2, geo.size.width * min(1, max(0, fraction))))
                }
            }.frame(height: 5)
        }
    }
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
            GraphCaption("E (amber) / P (blue) usage · 60s")
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

struct OpenDashboardButton: View {
    var body: some View {
        Button { openMainDashboard() } label: {
            Label("Open Dashboard", systemImage: "macwindow").frame(maxWidth: .infinity)
        }
    }
}

// MARK: - GPU / MEM / NET / SSD dropdowns

struct GPUMenuDropdown: View {
    let monitor: SiliconScopeMonitor
    var body: some View {
        let s = monitor.snapshot
        VStack(alignment: .leading, spacing: 7) {
            MenuSectionHeader("GPU / Media / Neural")
            MenuMeterRow(label: "GPU",
                         value: String(format: "%.0f%%  %.1f W  %.0f MHz", s.gpu.usagePercent, s.power.gpuWatts, s.gpu.freqMHz),
                         fraction: s.gpu.usage, color: MetricPalette.gpuC)
            MenuMeterRow(label: "Media",
                         value: String(format: "%.1f GB/s", s.bandwidth.mediaGBs),
                         fraction: min(1, s.bandwidth.mediaGBs / max(monitor.mediaPeakGBs, 0.5)), color: MetricPalette.mediaC)
            MenuMeterRow(label: "ANE est.",
                         value: String(format: "%.1f W", s.power.aneWatts),
                         fraction: min(1, s.power.aneWatts / max(monitor.anePeakWatts, 0.1)), color: MetricPalette.aneC)
            MenuKV(label: "DRAM power", value: String(format: "%.1f W", s.power.dramWatts))
            GraphCaption("GPU (green) / Media (orange) / ANE (purple) · 60s")
            ZStack {   // all three normalized to 0...1 (each vs its tracked peak)
                Sparkline(values: monitor.history.gpu, color: MetricPalette.gpuC, height: 30, yDomain: 0...1)
                Sparkline(values: monitor.history.media.map { min(1, $0 / max(monitor.mediaPeakGBs, 0.5)) },
                          color: MetricPalette.mediaC, height: 30, yDomain: 0...1)
                Sparkline(values: monitor.history.ane.map { min(1, $0 / max(monitor.anePeakWatts, 0.1)) },
                          color: MetricPalette.aneC, height: 30, yDomain: 0...1)
            }
            Divider()
            OpenDashboardButton()
        }
        .padding(12).frame(width: 285).background(Theme.bg).foregroundStyle(Theme.text)
    }
}

struct MEMMenuDropdown: View {
    let monitor: SiliconScopeMonitor
    private let wired = Color(red: 0.36, green: 0.62, blue: 0.98)       // blue
    private let active = Color(red: 0.92, green: 0.38, blue: 0.34)      // red (iStat-style)
    private let compressed = Color(red: 0.62, green: 0.55, blue: 0.95)  // purple
    private let freeC = Color.white.opacity(0.12)

    var body: some View {
        let m = monitor.snapshot.memory
        VStack(alignment: .leading, spacing: 6) {
            MenuSectionHeader("Memory")
            HStack {
                Text(String(format: "%.1f / %.0f GB", m.usedGB, m.totalGB))
                    .font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(Theme.text)
                Spacer()
                Text(String(format: "%.0f%%", m.usedPercent))
                    .font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(monitor.memoryRisk.color)
            }
            MenuStackedBar(segments: [(m.wiredFraction, wired), (m.activeFraction, active),
                                      (m.compressedFraction, compressed), (m.freeFraction, freeC)])
            MenuLegendRow(color: wired, label: "Wired", value: memSize(m.wiredBytes))
            MenuLegendRow(color: active, label: "Active", value: memSize(m.activeBytes))
            MenuLegendRow(color: compressed, label: "Compressed", value: memSize(m.compressedBytes))
            MenuLegendRow(color: freeC, label: "Free", value: memSize(m.freeBytes))

            if m.swapTotalBytes > 0 {
                Divider()
                MenuSectionHeader("Swap")
                MenuStackedBar(segments: [(Double(m.swapUsedBytes) / Double(m.swapTotalBytes), wired)])
                Text(String(format: "%.2f GB of %.2f GB", m.swapUsedGB, Double(m.swapTotalBytes) / 1_073_741_824))
                    .font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Theme.dim)
            }

            Divider()
            MenuSectionHeader("Top by Memory")
            let topMem = Dictionary(grouping: monitor.snapshot.processes, by: \.name)
                .map { (name: $0.key, bytes: $0.value.reduce(UInt64(0)) { $0 + $1.memoryBytes }) }
                .sorted { $0.bytes > $1.bytes }
                .prefix(5)
            ForEach(Array(topMem), id: \.name) { entry in
                HStack(spacing: 6) {
                    Text(entry.name).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.text)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 0)
                    Text(memSize(entry.bytes))
                        .font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Theme.dim)
                }
            }
            Divider()
            OpenDashboardButton()
        }
        .padding(12).frame(width: 285).background(Theme.bg).foregroundStyle(Theme.text)
    }
}

struct NETMenuDropdown: View {
    let monitor: SiliconScopeMonitor
    var body: some View {
        let n = monitor.snapshot.network
        VStack(alignment: .leading, spacing: 6) {
            MenuSectionHeader("Network")
            MenuKV(label: "↓ Download", value: formatRate(n.downloadBytesPerSec), color: MetricPalette.downC)
            Sparkline(values: monitor.history.netDown, color: MetricPalette.downC, height: 26)
            MenuKV(label: "↑ Upload", value: formatRate(n.uploadBytesPerSec), color: MetricPalette.upC)
            Sparkline(values: monitor.history.netUp, color: MetricPalette.upC, height: 26)
            Divider()
            OpenDashboardButton()
        }
        .padding(12).frame(width: 255).background(Theme.bg).foregroundStyle(Theme.text)
    }
}

struct SSDMenuDropdown: View {
    let monitor: SiliconScopeMonitor
    private let cyan = Color(red: 0.32, green: 0.82, blue: 0.86)
    var body: some View {
        let d = monitor.snapshot.disk
        VStack(alignment: .leading, spacing: 6) {
            MenuSectionHeader("Disk")
            MenuKV(label: "Read", value: formatRate(d.readBytesPerSec), color: MetricPalette.downC)
            MenuKV(label: "Write", value: formatRate(d.writeBytesPerSec), color: MetricPalette.upC)
            MenuMeterRow(label: "Used",
                         value: "free \(formatBytes(d.freeBytes)) / \(formatBytes(d.totalBytes))",
                         fraction: d.usedFraction, color: cyan)
            Sparkline(values: monitor.history.diskRead, color: MetricPalette.downC, height: 24)
            Sparkline(values: monitor.history.diskWrite, color: MetricPalette.upC, height: 24)
            Divider()
            OpenDashboardButton()
        }
        .padding(12).frame(width: 265).background(Theme.bg).foregroundStyle(Theme.text)
    }
}
