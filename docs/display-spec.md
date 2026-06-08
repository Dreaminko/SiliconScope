# ktop — Display Spec (표시 정보 정의)

> 무엇을 사용자에게 보여줄지 정의한다. btop / neoasitop / iStat Menus 분석 + 온디바이스 AI 추세 반영.
> (설계 문서라 한국어. 단, **In-app 라벨은 영어** — 아래 표의 영문명이 실제 UI 라벨이다.)

---

## 0. 핵심 설계 통찰 — "AI 워크로드는 어디서 도는가"

요즘 늘어나는 부하를 데이터로 추적해보면 ktop의 차별점이 분명해진다:

| 워크로드 | 실제 사용 엔진 | 병목 |
|---|---|---|
| **로컬 LLM** (llama.cpp / MLX / Ollama) | **Metal GPU + 통합메모리** (ANE 미사용) | **메모리 대역폭** (특히 27B+) |
| **AI 사진보정 / 영상 업스케일 / Siri / 분류** (CoreML 기반) | **ANE** (+ 일부 GPU) | ANE 처리량 / 전력·발열 |
| 대용량 모델 상주 | 통합메모리 용량 | **메모리 압력 / 스왑** |

**결론 (설계 원칙):**
1. **GPU + 메모리 대역폭 + 메모리 압력**을 전면에 — LLM 사용자의 진짜 관심사.
2. **ANE는 "어떤 엔진이 일하는지"를 보여주는 신호** — LLM이면 GPU만 뜨고 ANE는 잠잠, CoreML 기반 앱이면 ANE가 뜬다. 이 대비가 교육적 가치.
3. **발열/스로틀 + 지속 전력** — AI는 지속 부하라 throttle이 성능을 좌우.
4. 통합메모리 특성상 wired(=Metal/GPU 점유) 메모리를 별도로 보여준다.

> ⚠️ ANE "사용률"은 전력 기반 근사치(애플 미공개). UI에 "est." 표기.

---

## 1. 도구 비교 — 무엇을 보여주나

| 항목 | btop | neoasitop | iStat Menus | **ktop 결정** |
|---|---|---|---|---|
| Per-core CPU | ✓ | ✗(E/P 집계만) | ✓ | ✓ |
| **E/P 코어 구분** | ✗ | ✓ | ✓(freq) | **✓✓ 핵심** |
| GPU usage/freq | Linux만 | ✓ | ✓ | ✓ |
| **ANE** | ✗ | ✓ | ✗ | **✓ 차별** |
| **Memory bandwidth** | ✗ | ✓(E/P/GPU/Media) | ✗ | **✓✓ 차별** |
| Memory pressure | ✗ | ✗ | ✓ | **✓ 차별** |
| Wired/compressed/swap | swap만 | ✗ | ✓ | ✓ |
| Power (도메인별) | ✗ | ✓(CPU/GPU/sys/RAM) | ✓ | ✓ |
| Thermal / throttle | temp | ✗ | sensors | **✓ 강화** |
| Fans | 제한적 | ✓ | ✓✓ | ✓ |
| Processes (top/tree/kill) | ✓✓ | ✗ | top앱 | ✓ |
| Disk / Network | ✓ | ✗ | ✓✓ | ✓(후순위) |
| Battery + BT기기 | basic | ✗ | ✓✓ | ✓(후순위) |
| Alerts/notify | ✗ | ✗ | ✓ | Tier2 |

**해석:** neoasitop = 칩 지표 강함(UI 단순) / iStat = 폭넓음(AI 특화 약함, ANE·대역폭 없음) / btop = 프로세스·UX 강함(Apple Silicon 미흡).
→ **ktop = neoasitop의 칩 지표 + iStat의 메모리압력/발열 폭 + btop의 프로세스/UX**, 거기에 **AI 워크로드 뷰**를 얹는다.

---

## 2. ktop 정보 집합 (Information Set)

소스 검증: IOReport sudoless 링크는 ✅ 확인됨(CLAUDE.md §5).

### Tier 0 — Apple Silicon / AI 시그니처 (차별점, MVP 필수)

| In-app 라벨 | 내용 | 소스 | sudoless |
|---|---|---|---|
| `E-Cores` / `P-Cores` | 클러스터별 usage %, 주파수, active residency | IOReport CPU Stats + sysctl | ✅ |
| `GPU` | usage %, 주파수, power | IOReport GPU Stats + Energy Model | ✅ |
| `ANE (est.)` | 전력 기반 활성도 + "engine in use" 신호 | IOReport Energy Model | ✅ |
| `Memory Bandwidth` | CPU/GPU/Media/Total GB/s | IOReport Bandwidth/AMC | ✅ |
| `Memory Pressure` | green/yellow/red + wired/compressed/swap | mach vm_stat + host_stats | ✅ |
| `Power` | Package/CPU/GPU/ANE/DRAM W, peak + rolling avg | IOReport Energy Model | ✅ |
| `Thermal` | thermal pressure / throttle, 지속 주파수 | IOHID + IOReport residency | ✅ |

### Tier 1 — 코어 시스템 (parity, MVP~직후)

| In-app 라벨 | 내용 | 소스 | sudoless |
|---|---|---|---|
| `CPU` | 집계 + per-core, load avg, uptime | host_processor_info | ✅ |
| `Memory` | used/free/cached/wired/compressed, swap | vm_statistics64 | ✅ |
| `Temperatures` | 주요 센서 °C | IOHID appleSiliconSensors | ✅ |
| `Fans` | RPM (+ 팬리스 기기 분기) | SMC | ✅ |
| `Processes` | top by CPU/MEM, tree, kill/signal | libproc / sysctl | ✅ |
| `Battery` | %, 잔여시간, 충/방전 W, 사이클, 온도 | IOPowerSources | ✅ |

### Tier 2 — 추후 / 스트레치

| 항목 | 비고 |
|---|---|
| `Disk` (usage/IO/SMART) | statfs + IOKit |
| `Network` (throughput/IP) | getifaddrs |
| Per-app Network/Disk breakdown | private NetworkStatistics — 난이도↑ |
| **Per-process GPU/ANE attribution** | ⚠️ sudoless로 신뢰성 있게 불가 — 스트레치/보류 |
| Alerts / notifications, History 로깅 | iStat 패리티 |
| Bluetooth 기기 배터리 (AirPods 등) | nice-to-have |

---

## 3. "AI Workload" 뷰 — 헤드라인 기능

별도 모드/패널로, AI 사용자가 한눈에 보는 큐레이션 화면:

```
┌─ AI Workload ──────────────────────────────┐
│ GPU    ███████████░  88%   24.3 W           │
│ ANE    ░░░░░░░░░░░░   2%  (est.)  idle       │
│ Mem BW ██████████░░  142 / 160 GB/s         │
│ Mem    wired 38.2 GB · pressure ●Yellow     │
│ Power  package 41 W   ▸peak 52  ~avg 39     │
│ Thermal ● nominal (no throttle)             │
│ ─ Likely engine: GPU/Metal (LLM-style)  ─   │
└─────────────────────────────────────────────┘
```

- "Likely engine" 힌트: GPU 높고 ANE 낮음 → "GPU/Metal (LLM-style)" / ANE 높음 → "ANE (CoreML-style)".
- 대역폭이 상한 근처면 "Bandwidth-bound" 경고 → LLM 토큰 생성 병목 신호.

---

## 4. MVP 범위 제안

**MVP = Tier 0 전부 + Tier 1의 CPU/Memory/Processes + AI Workload 뷰.**
(Disk/Network/Battery/Alerts는 그 다음 라운드.)

이유: Tier 0는 데이터 소스가 IOReport 하나로 거의 다 모이고(이미 검증됨), AI 차별점을 즉시 보여줄 수 있다. 프로세스/CPU/메모리는 mach API로 sudoless 확보가 쉽다.
