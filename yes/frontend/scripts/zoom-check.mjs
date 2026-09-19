/**
 * Diagnostic: how much map data exists as you zoom out.
 *
 * The local dev archive only covers a Melbourne bounding box, so tiles
 * outside it come back 204 No Content. This counts them per zoom level.
 * Run with the tile server and dev server up: node scripts/zoom-check.mjs
 */
import { chromium } from 'playwright';

const URL = process.env.ELLY_URL ?? 'http://localhost:8081';
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 390, height: 844 } });

let withData = 0;
let empty = 0;
page.on('response', (r) => {
  if (!r.url().includes('.mvt')) return;
  if (r.status() === 204) empty += 1;
  else if (r.status() === 200) withData += 1;
});

await page.goto(URL, { waitUntil: 'networkidle', timeout: 60000 });
await page.waitForTimeout(4000);

// the bottom sheet overlays the canvas, so focus it directly rather than clicking
await page.evaluate(() => document.querySelector('.maplibregl-canvas')?.focus());

for (let step = 0; step < 6; step += 1) {
  withData = 0;
  empty = 0;
  await page.keyboard.press('Minus');
  await page.keyboard.press('Minus');
  await page.waitForTimeout(2500);
  const shot = `tiles/zoom-out-${step}.png`;
  await page.screenshot({ path: shot });
  console.log(`after ${(step + 1) * 2} zoom-outs: tiles with data=${withData}, empty(204)=${empty}  -> ${shot}`);
}

await browser.close();
