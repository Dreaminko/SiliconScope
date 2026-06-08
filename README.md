# WhisPlayInfo

A **sudoless Apple Silicon system monitor** with a native SwiftUI GUI — and
first-class **ANE (Neural Engine)**, **Media Engine**, and **memory-bandwidth**
tracking that terminal monitors and Activity Monitor don't surface.

Originally built to watch how an on-device AI/media app uses the Apple Silicon
accelerators while developing **WhisPlay** — hence the focus on ANE / Media / bandwidth.

![WhisPlayInfo dashboard](docs/img/screenshot.png)

## Highlights

- **E-core / P-core split** — per-cluster utilization + real DVFS frequency
- **GPU** — utilization, power, frequency
- **ANE & Media Engine** — Neural-Engine power and media-codec bandwidth (the differentiators)
- **Memory bandwidth** — CPU / GPU / Media / total GB/s (the local-LLM bottleneck signal)
- **Memory** — Wired / Active / Compressed / Free stacked bar + macOS **memory-pressure** alerts
- **Network** ↑/↓ and **Disk** read/write + free space, with live graphs
- **Temperatures** — grouped CPU / GPU / Memory / Battery (SMC), fan RPM, thermal pressure
- **Power** — per-domain CPU / GPU / ANE / DRAM / SoC, plus battery %
- **Processes** — sort, filter, kill (in-card scroll)
- **No `sudo` required.** Menu-bar mode **and** full dashboard.

## Build & run

Requires macOS on Apple Silicon and the Xcode toolchain.

```bash
xcrun swift run WhisPlayInfo        # SwiftUI GUI (dashboard + menu bar)
xcrun swift run -q ktop-cli         # data-layer verification CLI
xcrun swift build                   # build everything
```

> Use `xcrun`. A non-Xcode `swift` (e.g. swiftly) may not match the macOS SDK and
> will fail with `Failed to build module 'Foundation'`.

## How it works (all sudoless)

| Data | Source |
|---|---|
| Power (CPU/GPU/ANE/DRAM), residency, memory bandwidth | private **IOReport** framework (symbols resolved at runtime via dyld) |
| CPU usage | `host_processor_info` ticks (matches Activity Monitor) |
| CPU/GPU frequency | IOReport `CPU Stats` / `GPU Stats` × IORegistry DVFS table |
| Memory / swap / pressure | `host_statistics64`, `sysctl` |
| Temperatures, fans | **SMC** via IOKit |
| Network / Disk / Battery | `getifaddrs`, IOBlockStorageDriver, IOPowerSources |
| Processes | `libproc` |

Verified IOReport channel map: [`docs/ioreport-channels.md`](docs/ioreport-channels.md).
Display spec: [`docs/display-spec.md`](docs/display-spec.md).

## Not on the Mac App Store

WhisPlayInfo uses private (un-entitled) APIs (IOReport, SMC, HID), so it cannot be
sandboxed/notarized for the App Store. Distribute directly. This is the same
trade-off as NeoAsitop, macmon, mactop, and Stats.

## Acknowledgements

- IOReport / SMC / sensor knowledge referenced from **NeoAsitop** (MIT) and
  **SocPowerBuddy**; sensor naming informed by **Stats**. The data layer here is
  written from scratch — declarations/facts referenced, no code copied.
- Design language inspired by **btop**.

## License

MIT © 2026 Kennt Kim — see [LICENSE](LICENSE).
