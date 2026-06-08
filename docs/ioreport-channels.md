# 검증된 IOReport 채널 맵 (M1 Max, macOS 26.5)

> ktop이 사용하는 IOReport 채널의 실측 위치. 칩마다 다를 수 있으니 다른 모델에서 재검증 필요.
> 링크는 `-undefined dynamic_lookup` (CLAUDE.md §5). 전부 sudo 불필요.

## 전력 (Power) — group `Energy Model`, format Simple, 단위 mJ
| 채널 | 의미 | 비고 |
|---|---|---|
| `CPU Energy` | CPU 총 전력 | = EACC + PACC 합 |
| `EACC_CPU` | E 클러스터 | suffix `_CPU` = 클러스터 합 |
| `PACC0_CPU`, `PACC1_CPU` | P 클러스터 0/1 | M1 Max는 P클러스터 2개 |
| `GPU0`, `GPU SRAM0` | GPU | `GPU Energy`는 단위 다름(~nJ) → 제외 |
| `ANE0` (`ANE1`) | Neural Engine | 유휴 시 0 (정상) |
| `DRAM0` | 메모리 | |

W = (mJ delta / interval_s) / 1000

## CPU 사용률/주파수 — group `CPU Stats`, subgroup `CPU Complex Performance States`, format State
| 채널 | 클러스터 |
|---|---|
| `ECPU` | E |
| `PCPU`, `PCPU1` | P (2 클러스터) |
- state[0] = `IDLE`; usage = (total − IDLE) / total
- 활성 state(`V0P4`…`V14P0`) residency × DVFS MHz 가중 = 평균 주파수
- `*CPM` 변종은 IDLE=0(fabric) → 제외

## DVFS 주파수 테이블 — IORegistry `AppleARMIODevice`
| key | 클러스터 | 실측(M1 Max) |
|---|---|---|
| `voltage-states1-sram` | E | 600…2064 MHz (5단) |
| `voltage-states5-sram` | P | 600…3228 MHz (15단) |
| `voltage-states9` | GPU | — |
- (freqHz, voltage) UInt32 쌍 배열, freqHz/1e6 = MHz, 0 제외

## 메모리 대역폭 — group `AMC Stats`, subgroup `Perf Counters`, format Simple, 단위 bytes
| 채널 패턴 | 분류 |
|---|---|
| `ECPU DCS RD/WR`, `PCPU0/1 DCS RD/WR` | CPU |
| `GFX DCS RD/WR` | GPU |
| `DISP/ISP/ANS/PRORES/STRM CODEC/PCIE LN DCS …` | 기타/미디어 |

GB/s = (bytes / interval_s) / 1e9

## 비-IOReport 소스
- 토폴로지: sysctl `hw.perflevel0`(=Performance/P), `hw.perflevel1`(=Efficiency/E)
- 메모리: `host_statistics64(HOST_VM_INFO64)` + sysctl `hw.memsize`, `vm.swapusage`
- 팬: SMC `FNum`, `F{i}Ac` (AppleSMC, IOConnectCallStructMethod kernel index 2)
- thermal pressure: `ProcessInfo.thermalState`
- 온도: IOHIDEventSystemClient (PrimaryUsagePage 0xff00, PrimaryUsage 5, event type 15, field=type<<16).
  센서명이 cryptic(`PMU tdie*/tdev*/tcal/TP*`)해 CPU/GPU 분리 불가 → die 평균/최고로 집계, battery(gas gauge) 제외.
  `CIOReport.ktopCopyTemperatureSensors()` C 헬퍼 사용 (Swift에선 `Unmanaged` → `takeRetainedValue`).
