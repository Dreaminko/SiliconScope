//
//  File:      BandwidthSampler.swift
//  Created:   2026-06-08
//  Updated:   2026-06-08
//  Developer: Kennt Kim / Calida Lab
//  Overview:  Reads unified-memory bandwidth (GB/s) sudolessly via IOReport
//             "AMC Stats". Subscribes once; each sample() diffs two snapshots and
//             converts accumulated bytes to GB/s.
//  Notes:     Channels live in subgroup "Perf Counters" named "<unit> DCS RD/WR"
//             (Simple format, bytes). GB/s = (bytes / seconds) / 1e9. Requestors:
//             ECPU/PCPU* -> CPU, GFX -> GPU, everything else -> other.
//
import Foundation
import CIOReport

public final class BandwidthSampler {
    private let subscription: IOReportSubscriptionRef
    private let subscribedChannels: CFMutableDictionary

    public init?() {
        guard let channels = IOReportCopyChannelsInGroup("AMC Stats" as CFString, nil, 0, 0, 0)?
            .takeRetainedValue()
        else {
            return nil
        }
        var subbed: Unmanaged<CFMutableDictionary>?
        guard let sub = IOReportCreateSubscription(nil, channels, &subbed, 0, nil),
              let subscribed = subbed?.takeRetainedValue()
        else {
            return nil
        }
        self.subscription = sub
        self.subscribedChannels = subscribed
    }

    public func sample(interval: TimeInterval = 0.2) -> BandwidthSample {
        let first = IOReportCreateSamples(subscription, subscribedChannels, nil)
        Thread.sleep(forTimeInterval: interval)
        let second = IOReportCreateSamples(subscription, subscribedChannels, nil)

        guard let a = first?.takeRetainedValue(),
              let b = second?.takeRetainedValue(),
              let delta = IOReportCreateSamplesDelta(a, b, nil)?.takeRetainedValue()
        else {
            return BandwidthSample()
        }

        let seconds = max(interval, 0.001)
        var cpu = 0.0, gpu = 0.0, media = 0.0, other = 0.0

        IOReportIterate(delta) { channel in
            guard IOReportChannelGetFormat(channel) == kKtopIOReportFormatSimple,
                  let subgroupRef = IOReportChannelGetSubGroup(channel)?.takeUnretainedValue(),
                  (subgroupRef as String) == "Perf Counters",
                  let nameRef = IOReportChannelGetChannelName(channel)?.takeUnretainedValue()
            else {
                return Int32(kKtopIOReportIterOk)
            }

            let name = (nameRef as String).uppercased()
            guard name.contains("DCS") else { return Int32(kKtopIOReportIterOk) }

            let bytes = Double(IOReportSimpleGetIntegerValue(channel, 0))
            let gbs = (bytes / seconds) / 1_000_000_000.0

            if name.hasPrefix("ECPU") || name.hasPrefix("PCPU") {
                cpu += gbs
            } else if name.hasPrefix("GFX") {
                gpu += gbs
            } else if name.contains("PRORES") || name.contains("CODEC") {
                media += gbs          // Media Engine: video encode/decode, ProRes
            } else {
                other += gbs
            }
            return Int32(kKtopIOReportIterOk)
        }

        var result = BandwidthSample()
        result.cpuGBs = cpu
        result.gpuGBs = gpu
        result.mediaGBs = media
        result.otherGBs = other
        return result
    }
}
