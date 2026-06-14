//
//  File:      Bottleneck.swift
//  Created:   2026-06-12
//  Updated:   2026-06-12
//  Developer: Kennt Kim / Calida Lab
//  Overview:  The AI-workload bottleneck classifier (hero feature). Given a snapshot,
//             the unified-memory-bandwidth ceiling, and whether the GPU is throttling,
//             it returns the single dominant bottleneck. Also holds the per-chip
//             bandwidth ceiling table used for the "% of ceiling" gauge.
//  Notes:     Pure value logic, no UI. Color mapping lives in the UI layer (Theme).
//             Ceilings are theoretical unified-memory bandwidth (GB/s) from Apple's
//             specs; callers should take max(ceiling, observedPeak) so the figure
//             self-corrects upward if a chip exceeds the table.
//
import Foundation

public enum Bottleneck: String, Sendable {
    case idle               // GPU effectively idle
    case gpuActive          // GPU busy, no single dominant limiter
    case bandwidthBound     // memory BW near ceiling, GPU not maxed (LLM token generation)
    case computeBound       // GPU saturated, BW has headroom (prompt processing)
    case thermalThrottled   // thermal pressure + GPU clock held below its peak
    case memoryPressured    // unified memory full (macOS pressure critical)

    /// Short UI label.
    public var label: String {
        switch self {
        case .idle:             return "Idle"
        case .gpuActive:        return "GPU active"
        case .bandwidthBound:   return "Bandwidth-bound"
        case .computeBound:     return "Compute-bound"
        case .thermalThrottled: return "Thermal-throttled"
        case .memoryPressured:  return "Memory-pressured"
        }
    }

    /// One-line, workload-agnostic explanation of the limiter. (Whether the work is AI,
    /// graphics, or video is asserted separately — only when there's evidence — so these
    /// stay honest for any GPU workload.)
    public var detail: String {
        switch self {
        case .idle:             return "No significant GPU workload"
        case .gpuActive:        return "GPU busy — no single bottleneck"
        case .bandwidthBound:   return "Memory bandwidth is the limiter"
        case .computeBound:     return "GPU compute is the limiter"
        case .thermalThrottled: return "Clock held down by heat — sustained performance limited"
        case .memoryPressured:  return "Unified memory full — swapping limits throughput"
        }
    }

    /// Whether this verdict is a problem the user should act on (vs a neutral profile).
    public var isProblem: Bool {
        self == .thermalThrottled || self == .memoryPressured
    }

    // MARK: - Classification

    /// Classifies the dominant bottleneck. `ceilingGBs` is the unified-memory bandwidth
    /// ceiling; `throttling` is the GPU-clock-vs-peak throttle decision (UI-tracked).
    /// Precedence: memory > thermal > (workload profile).
    public static func classify(_ s: SystemSnapshot,
                                ceilingGBs: Double,
                                throttling: Bool) -> Bottleneck {
        classify(memoryCritical: s.memory.pressure == .critical,
                 gpuUsage: s.gpu.usage, bandwidthGBs: s.bandwidth.totalGBs,
                 ceilingGBs: ceilingGBs, throttling: throttling)
    }

    /// Primitive form taking explicit inputs, so the UI can feed *smoothed* GPU/bandwidth
    /// (a short rolling average) to keep the verdict from flickering on single-sample noise.
    public static func classify(memoryCritical: Bool,
                                gpuUsage: Double,
                                bandwidthGBs: Double,
                                ceilingGBs: Double,
                                throttling: Bool) -> Bottleneck {
        if memoryCritical { return .memoryPressured }
        if throttling { return .thermalThrottled }
        // Desktop compositing keeps a resting GPU around 10–25%; below this is "idle".
        if gpuUsage < 0.30 { return .idle }

        // Calibrated on real M1 Max LLM runs (vs the THEORETICAL ceiling, which the memory
        // controllers rarely reach): dense 12B decode ~51%, sparse MoE 26B decode ~44%
        // (GPU-bound), prefill ~30% (compute-bound). Decode keeps the GPU ~95% busy while
        // stalled on memory, so we do NOT gate bandwidth-bound on a non-maxed GPU.
        // bandwidth >= ~50% ⇒ bandwidth-bound; otherwise a pegged GPU ⇒ compute-bound.
        // (A truly robust prefill/decode split needs tokens/sec — see NEXT_VERSION.)
        let bwFraction = ceilingGBs > 0 ? bandwidthGBs / ceilingGBs : 0
        if bwFraction >= 0.50 { return .bandwidthBound }
        if gpuUsage >= 0.90 { return .computeBound }
        return .gpuActive
    }

    // MARK: - Per-chip bandwidth ceiling table

    /// Theoretical unified-memory bandwidth ceiling (GB/s) for an Apple Silicon SoC,
    /// matched from the sysctl brand string (e.g. "Apple M3 Max"). Max-tier chips ship
    /// in two memory bins; `pCoreCount` disambiguates (full vs binned). Returns 0 for an
    /// unrecognized chip so the caller can fall back to the observed peak.
    public static func bandwidthCeilingGBs(chipName: String, pCoreCount: Int) -> Double {
        let n = chipName.lowercased()
        func has(_ s: String) -> Bool { n.contains(s) }

        if has("m1") {
            if has("ultra") { return 800 }
            if has("max")   { return 400 }
            if has("pro")   { return 200 }
            return 68
        }
        if has("m2") {
            if has("ultra") { return 800 }
            if has("max")   { return 400 }
            if has("pro")   { return 200 }
            return 100
        }
        if has("m3") {
            if has("ultra") { return 800 }
            if has("max")   { return pCoreCount >= 12 ? 400 : 300 }   // full vs binned
            if has("pro")   { return 150 }
            return 100
        }
        if has("m4") {
            if has("max")   { return pCoreCount >= 12 ? 546 : 410 }   // full vs binned
            if has("pro")   { return 273 }
            return 120
        }
        return 0   // unknown → caller uses observed peak
    }
}
