// @ts-check
import { defineConfig } from 'astro/config';

// Static landing for SiliconScope. EN at /, KO at /ko/ (mirrors the Spectalo site).
export default defineConfig({
  site: 'https://siliconscope.calidalab.ai',
  i18n: {
    locales: ['en', 'ko'],
    defaultLocale: 'en',
    routing: { prefixDefaultLocale: false },
  },
});
