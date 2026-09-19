/**
 * Diagnostic: does the MapLibre map actually initialise on web?
 *
 * Reports console errors with full text, failed network requests, and whether
 * a WebGL canvas was created inside the map container.
 * Run with the dev server up: node scripts/map-check.mjs
 */
import { chromium } from 'playwright';

const URL = process.env.ELLY_URL ?? 'http://localhost:8081';

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 390, height: 844 } });

const errors = [];
const failed = [];

page.on('console', (m) => {
  if (m.type() === 'error') errors.push(m.text());
});
page.on('pageerror', (e) => errors.push(`PAGEERROR: ${e.message}`));
page.on('requestfailed', (r) => failed.push(`${r.failure()?.errorText} ${r.url()}`));

await page.goto(URL, { waitUntil: 'networkidle', timeout: 60000 });
await page.waitForTimeout(4000);

const map = await page.evaluate(() => {
  const container = document.querySelector('[data-testid="elly-map-canvas"]');
  const canvas = container?.querySelector('canvas');
  return {
    containerFound: !!container,
    canvasFound: !!canvas,
    canvasSize: canvas ? { w: canvas.width, h: canvas.height } : null,
    // maplibre paints the style's background-color layer even with no tiles.
    containerBg: container ? getComputedStyle(container).backgroundColor : null,
  };
});

console.log('MAP:', JSON.stringify(map, null, 2));
console.log('\nCONSOLE ERRORS:');
errors.forEach((e) => console.log('  -', e.slice(0, 300)));
console.log('\nFAILED REQUESTS:');
[...new Set(failed)].slice(0, 10).forEach((f) => console.log('  -', f.slice(0, 200)));

await browser.close();
