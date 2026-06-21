//
//  File:      SensorClassificationTests.swift
//  Created:   2026-06-20
//  Updated:   2026-06-21
//  Developer: Kennt Kim / Calida Lab
//  Overview:  Pins the pure classification maps: SMC-key → category, raw HID name → friendly
//             label/category, the per-generation curated key catalog, and the bandwidth
//             requestor → bucket map (adapted from NeoAsitop). These are exactly the lookups
//             that silently rot if a prefix is mistyped, so they get regression coverage.
//
import XCTest
@testable import SiliconScopeCore

final class SensorClassificationTests: XCTestCase {

    // MARK: - SMC key → category (Apple Silicon prefixes)

    func testSMCCategoryByPrefix() {
        XCTAssertEqual(TemperatureSampler.category(for: "TB0T"), .battery)
        XCTAssertEqual(TemperatureSampler.category(for: "Tp01"), .cpu)
        XCTAssertEqual(TemperatureSampler.category(for: "Tg05"), .gpu)
        XCTAssertEqual(TemperatureSampler.category(for: "Tm02"), .memory)
        XCTAssertEqual(TemperatureSampler.category(for: "TC0D"), .other)
    }

    // MARK: - Raw HID name → friendly label + category

    func testFriendlyHIDClassification() {
        var r = TemperatureSampler.friendlyHID("gas gauge battery")
        XCTAssertEqual(r.category, .battery); XCTAssertEqual(r.label, "Battery")

        r = TemperatureSampler.friendlyHID("NAND CH0 temp")
        XCTAssertEqual(r.category, .memory); XCTAssertEqual(r.label, "NAND CH0 temp")

        r = TemperatureSampler.friendlyHID("PMU tdie3")          // "PMU " stripped → SoC/CPU
        XCTAssertEqual(r.category, .cpu); XCTAssertEqual(r.label, "tdie3")

        XCTAssertEqual(TemperatureSampler.friendlyHID("GPU something").category, .gpu)
    }

    // MARK: - Curated per-generation catalog

    func testM1CatalogShape() {
        let m1 = SensorCatalog.curated(for: .m1)
        XCTAssertEqual(m1.filter { $0.category == .cpu }.count, 10)   // 2 E + 8 P
        XCTAssertEqual(m1.filter { $0.category == .gpu }.count, 4)
        XCTAssertEqual(m1.filter { $0.category == .memory }.count, 4)
        // Known anchor keys/names must not drift.
        XCTAssertTrue(m1.contains { $0.key == "Tp01" && $0.name == "P-Core 1" })
        XCTAssertTrue(m1.contains { $0.key == "Tp09" && $0.name == "E-Core 1" })
        XCTAssertTrue(m1.contains { $0.key == "Tg05" && $0.name == "GPU 1" })
    }

    func testEveryKnownGenerationHasCpuAndGpuKeys() {
        for gen in [AppleSiliconGen.m1, .m2, .m3, .m4, .m5] {
            let t = SensorCatalog.curated(for: gen)
            XCTAssertFalse(t.filter { $0.category == .cpu }.isEmpty, "\(gen) missing CPU keys")
            XCTAssertFalse(t.filter { $0.category == .gpu }.isEmpty, "\(gen) missing GPU keys")
        }
    }

    func testUnknownGenerationIsEmpty() {
        XCTAssertTrue(SensorCatalog.curated(for: .unknown).isEmpty)
    }

    // MARK: - Partial-curated HID supplement (e.g. M4 Max reads no Memory key)

    /// When a die exposes only a subset of its generation's curated keys, the intended-but-
    /// absent category is filled from HID — without injecting unrelated HID sensors or
    /// fabricating per-core CPU readings.
    func testSupplementFillsOnlyMissingIntendedCategory() {
        var sample = TemperatureSample()
        sample.cpuCelsius = 40; sample.cpuMaxCelsius = 67; sample.gpuCelsius = 60
        sample.groups = [
            SensorGroup(category: .cpu, sensors: [TempSensor(rawName: "Tp01", name: "P-Core 1", celsius: 40)]),
            SensorGroup(category: .gpu, sensors: [TempSensor(rawName: "Tg0K", name: "GPU 3", celsius: 60)]),
        ]
        let hid: [(name: String, celsius: Double)] = [
            (name: "NAND CH0 temp", celsius: 36),   // → .memory
            (name: "PMU tdie3", celsius: 58),        // → .cpu (must NOT be injected)
            (name: "gas gauge battery", celsius: 35) // → .battery (must NOT be injected)
        ]
        let out = TemperatureSampler.supplement(sample, withHID: hid, categories: [.memory])

        XCTAssertEqual(out.groups.first { $0.category == .memory }?.sensors.first?.name, "NAND CH0 temp")
        XCTAssertEqual(out.groups.first { $0.category == .cpu }?.sensors.count, 1)   // unchanged
        XCTAssertNil(out.groups.first { $0.category == .battery })                   // not requested
        XCTAssertEqual(out.cpuCelsius, 40); XCTAssertEqual(out.gpuCelsius, 60)       // representatives kept
        XCTAssertEqual(out.groups.map(\.category), [.cpu, .gpu, .memory])            // canonical order
    }

    func testSupplementWithNoMatchingHIDLeavesSampleUnchanged() {
        var sample = TemperatureSample()
        sample.groups = [SensorGroup(category: .cpu, sensors: [TempSensor(rawName: "Tp01", name: "P-Core 1", celsius: 40)])]
        let hid: [(name: String, celsius: Double)] = [(name: "PMU tdie3", celsius: 58)]   // .cpu only
        let out = TemperatureSampler.supplement(sample, withHID: hid, categories: [.memory])
        XCTAssertEqual(out.groups.count, 1)
        XCTAssertEqual(out.groups.first?.category, .cpu)
    }

    // MARK: - Bandwidth requestor → bucket (NeoAsitop-adapted map)

    func testBandwidthRequestorMap() {
        XCTAssertEqual(BandwidthSampler.classify(requestor: "DCS"),   .total)
        XCTAssertEqual(BandwidthSampler.classify(requestor: "ECPU0"), .cpu)
        XCTAssertEqual(BandwidthSampler.classify(requestor: "PCPU1"), .cpu)
        XCTAssertEqual(BandwidthSampler.classify(requestor: "GFX0"),  .gpu)
        for media in ["VENC", "VDEC", "ISP0", "JPG", "JPEG", "PRORES0", "STRM CODEC"] {
            XCTAssertEqual(BandwidthSampler.classify(requestor: media), .media, "\(media)")
        }
        // MSR is explicitly NOT media (matches NeoAsitop); DISP/ANS fall through to other.
        XCTAssertEqual(BandwidthSampler.classify(requestor: "MSR"),  .other)
        XCTAssertEqual(BandwidthSampler.classify(requestor: "DISP"), .other)
    }
}
