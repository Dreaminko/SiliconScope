//
//  File:      SystemSampler.swift
//  Created:   2026-06-08
//  Updated:   2026-06-22
//  Developer: Kennt Kim / Calida Lab
//  Overview:  Aggregates every SiliconScopeCore sampler into one SystemSnapshot. Intended
//             to run on a single background thread driven by the UI's refresh loop.
//  Notes:     @unchecked Sendable: the underlying samplers hold non-Sendable IOReport
//             handles, but SiliconScope only ever calls sample() from one serial background
//             task, so this is safe. Do not call sample() concurrently.
//
import Foundation

public final class SystemSampler: @unchecked Sendable {
    private let power = PowerSampler()
    private let cpu = CPUSampler()
    private let gpu: GPUSampler?
    private let bandwidth = BandwidthSampler()
    private let memory = MemorySampler()
    private let thermal = ThermalSampler()
    private let temperature: TemperatureSampler
    private let network = NetworkSampler()
    private let disk = DiskSampler()
    private let battery = BatterySampler()
    private let processes = ProcessSampler()
    private let aiRuntime = AIRuntimeSampler()

    // Peripheral battery (Magic/AirPods): heavier than a 1 s tick (IORegistry scan + a
    // ~0.2 s system_profiler), so sample on a short cadence and reuse between ticks. 5 s keeps a
    // newly-connected device appearing quickly without polling system_profiler every second.
    private let peripheralSampler = PeripheralBatterySampler()
    private var cachedPeripherals: [PeripheralBattery] = []
    private var lastPeripheralSample: Date = .distantPast
    private let peripheralInterval: TimeInterval = 5

    public init() {
        let topology = cpu?.topology
        gpu = topology.flatMap { GPUSampler(topology: $0) }
        let coreCount = topology.map { $0.eCoreCount + $0.pCoreCount } ?? 0
        temperature = TemperatureSampler(coreCount: coreCount)
    }

    public var topology: CPUTopology? { cpu?.topology }

    /// Produces one full snapshot. The IOReport samplers each sleep `interval`
    /// internally, so this blocks for roughly 3 * interval — call it off the main thread.
    public func sample(interval: TimeInterval = 0.2) -> SystemSnapshot {
        var snapshot = SystemSnapshot()
        snapshot.power = power?.sample(interval: interval) ?? PowerSample()
        snapshot.cpu = cpu?.sample(interval: interval) ?? CPUSample()
        snapshot.gpu = gpu?.sample(interval: interval) ?? GPUSample()
        snapshot.bandwidth = bandwidth?.sample(interval: interval) ?? BandwidthSample()
        snapshot.memory = memory.sample()
        snapshot.thermal = thermal.sample()
        snapshot.temperature = temperature.sample()
        snapshot.network = network.sample()
        snapshot.disk = disk.sample()
        snapshot.battery = battery.sample()
        snapshot.peripherals = sampledPeripherals()
        snapshot.processes = processes.sample()   // full set; UI sorts/filters/limits
        snapshot.aiRuntime = aiRuntime.sample(from: snapshot.processes)
        // Budget after detection so the resident runtime's RSS lifts `loadable`
        // (pure arithmetic on the already-taken memory sample — no extra syscalls/sleep).
        snapshot.memoryBudget = MemoryBudget.estimate(
            memory: snapshot.memory,
            activeRuntimeRSS: snapshot.aiRuntime.primaryMemoryBytes
        )
        return snapshot
    }

    /// Peripheral battery on a slow cadence (re-sampled every `peripheralInterval`s, reused
    /// otherwise) so the per-second tick stays cheap.
    private func sampledPeripherals() -> [PeripheralBattery] {
        if Date().timeIntervalSince(lastPeripheralSample) >= peripheralInterval {
            lastPeripheralSample = Date()
            cachedPeripherals = peripheralSampler.sample()
        }
        return cachedPeripherals
    }
}
