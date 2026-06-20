// Landing copy for both locales. Keys mirror the section structure in Landing.astro.
export type Lang = 'en' | 'ko';

export const REPO = 'https://github.com/kennss/SiliconScope';
export const RELEASES_LATEST = 'https://github.com/kennss/SiliconScope/releases/latest';
export const SPECTALO = 'https://spectalo.calidalab.ai';

export const STRINGS = {
  en: {
    nav: { features: 'Features', privacy: 'Privacy', download: 'Download' },
    hero: {
      title: 'See what your Apple Silicon is really doing.',
      sub: 'A sudoless macOS monitor with first-class ANE, Media Engine, and memory-bandwidth tracking — the signals Activity Monitor and btop don’t show. Menu bar and full dashboard.',
      download: 'Download for Apple Silicon',
      github: 'View on GitHub',
      badges: ['Free', 'Open source · MIT', 'No sudo', 'macOS 14+'],
    },
    features: [
      { tag: 'Menu-bar cockpit', title: 'Your whole Mac in one glyph',
        body: 'The combined SiliconScope menu-bar item: live CPU / GPU / ANE / Media / memory bars plus bandwidth, and a dropdown with six color-matched 60-second trends, top processes, and the live workload verdict.',
        img: '/img/ss.png' },
      { tag: 'ANE · Media · Bandwidth', title: 'The metrics others hide',
        body: 'First-class Neural Engine and Media Engine power, plus unified-memory bandwidth with the CPU / GPU / Media split — the real bottleneck signal for on-device AI and video.',
        img: '/img/gpu.png' },
      { tag: 'AI workload', title: 'Bandwidth-bound or compute-bound?',
        body: 'A live verdict for your local LLM, a “% of your chip’s bandwidth ceiling” gauge, and a one-click tokens/sec + tokens-per-watt benchmark.',
        img: '/img/benchmark.png' },
    ],
    gallery: {
      title: 'Pin any metric to its own item',
      sub: 'CPU · GPU · Memory · Network · SSD · Sensors · Battery — each with a live glyph and a rich, iStat-style dropdown.',
      items: [
        { img: '/img/cpu.png', label: 'CPU — E/P cores, frequency, temp, top processes' },
        { img: '/img/memory.png', label: 'Memory — pressure, app/cached, swap, page rates' },
        { img: '/img/menubar-sensors.png', label: 'Sensors — per-unit temperatures & fans' },
        { img: '/img/menubar-battery.png', label: 'Battery — health, cycles, power draw' },
      ],
    },
    privacy: { title: 'Nothing leaves your Mac',
      body: '100% sudoless and offline by design — no telemetry, no analytics, no outbound calls. Open source, Developer-ID signed and Apple-notarized, and it updates itself.' },
    download: { title: 'Download', button: 'Download for Apple Silicon', source: 'or build from source →',
      note: 'macOS 14+ on Apple Silicon. Opens with no Gatekeeper prompt, then auto-updates.' },
    footer: { tagline: 'An Apple Silicon system monitor by Calida Lab.', other: 'Also from Calida Lab: Spectalo' },
  },
  ko: {
    nav: { features: '기능', privacy: '프라이버시', download: '다운로드' },
    hero: {
      title: '당신의 Apple Silicon, 속까지 본다.',
      sub: 'ANE·미디어 엔진·메모리 대역폭까지 보여주는 sudo 없는 macOS 모니터. Activity Monitor도 btop도 안 보여주는 지표를, 메뉴바와 풀 대시보드로.',
      download: 'Apple Silicon용 다운로드',
      github: 'GitHub에서 보기',
      badges: ['무료', '오픈소스 · MIT', 'sudo 불필요', 'macOS 14+'],
    },
    features: [
      { tag: '메뉴바 cockpit', title: '맥 전체를 글리프 하나로',
        body: '통합 SiliconScope 메뉴바 아이템: CPU / GPU / ANE / Media / 메모리 막대 + 대역폭을 라이브로. 드롭다운엔 색 맞춘 60초 추세 6개, 상위 프로세스, 실시간 워크로드 판정.',
        img: '/img/ss.png' },
      { tag: 'ANE · 미디어 · 대역폭', title: '남들이 안 보여주는 지표',
        body: 'Neural Engine·미디어 엔진 전력, 그리고 CPU / GPU / 미디어로 분해된 통합 메모리 대역폭 — 온디바이스 AI·영상의 진짜 병목 신호.',
        img: '/img/gpu.png' },
      { tag: 'AI 워크로드', title: '대역폭 병목? 연산 병목?',
        body: '로컬 LLM의 실시간 병목 판정, “칩 대역폭 천장 대비 %” 게이지, 그리고 원클릭 tok/s·tok/Wh 벤치마크.',
        img: '/img/benchmark.png' },
    ],
    gallery: {
      title: '지표마다 자기 아이템으로',
      sub: 'CPU · GPU · 메모리 · 네트워크 · SSD · 센서 · 배터리 — 각각 라이브 글리프 + iStat식 풍부한 드롭다운.',
      items: [
        { img: '/img/cpu.png', label: 'CPU — E/P 코어, 주파수, 온도, 상위 프로세스' },
        { img: '/img/memory.png', label: '메모리 — 압력, app/캐시, 스왑, 페이지 속도' },
        { img: '/img/menubar-sensors.png', label: '센서 — 유닛별 온도 & 팬' },
        { img: '/img/menubar-battery.png', label: '배터리 — 건강도, 사이클, 전력' },
      ],
    },
    privacy: { title: '아무것도 Mac 밖으로 나가지 않는다',
      body: '설계부터 100% sudo 없이, 오프라인. 텔레메트리·분석·외부 통신 0. 오픈소스이고 Developer ID 서명 + Apple 공증, 그리고 자동 업데이트.' },
    download: { title: '다운로드', button: 'Apple Silicon용 다운로드', source: '또는 소스에서 빌드 →',
      note: 'macOS 14+ Apple Silicon. 게이트키퍼 경고 없이 열리고, 이후 자동 업데이트.' },
    footer: { tagline: 'Calida Lab이 만든 Apple Silicon 시스템 모니터.', other: 'Calida Lab의 다른 앱: Spectalo' },
  },
} as const;
