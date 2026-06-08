# Roadmap — next version

v1.0.0 is a general Apple Silicon monitor. The next version specializes toward
**AI-inference monitoring** on Apple Silicon — the niche neither terminal monitors
nor Activity Monitor cover.

## Planned

- **AI Workload view (hero)** — a bottleneck classifier:
  - *Bandwidth-bound* (memory BW near ceiling, GPU not maxed) — typical LLM token generation
  - *Compute-bound* (GPU ~100%, BW has headroom) — prompt processing
  - *Thermal-throttled* (pressure + frequency drop)
  - *Memory-pressured* (macOS pressure red)
- **Per-chip memory-bandwidth ceiling table** → a "% of ceiling" gauge (M1/Pro/Max/Ultra, M2–M4)
- **AI runtime detection** — recognize `ollama`, `llama.cpp`, `MLX`, `LM Studio`, etc. and surface them
- **Engine attribution** — GPU/Metal vs ANE, as a clear hint
- **Model memory budget** — estimate the largest model that fits in free unified memory
- **WhisPlay process detect / pin**
- **Packaging** — `.app` bundle (icon, signing/notarization) + Homebrew cask

## Out of scope (sudoless limits)

- Per-process GPU / ANE attribution (not reliably available without elevated access)
- tokens/sec (needs runtime-log integration, not chip telemetry)
