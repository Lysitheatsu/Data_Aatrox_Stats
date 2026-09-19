import { chromium } from 'playwright';

const URL = process.env.ELLY_URL ?? 'http://localhost:8081';
const OUT = process.env.ELLY_SHOT_DIR ?? '/tmp';
// Capture both palettes by default so dark mode regressions are visible.
// Set ELLY_SCHEMES=light to capture just one.
const SCHEMES = (process.env.ELLY_SCHEMES ?? 'light,dark').split(',');

const browser = await chromium.launch();

for (const scheme of SCHEMES) {
  const page = await browser.newPage({
    viewport: { width: 390, height: 844 }, // iPhone-ish, matches the mockups
    deviceScaleFactor: 2,
    colorScheme: scheme,
  });

  console.log(`loading ${URL} (${scheme})`);
  await page.goto(URL, { waitUntil: 'networkidle', timeout: 60000 });
  // The app text mounts into the DOM even if RN-web marks measurement nodes
  // "hidden"; wait for it to be attached, then give fonts/icons time to paint.
  await page.getByText('ELLY Maps').first().waitFor({ state: 'attached', timeout: 60000 });
  // The map needs longer than the rest of the UI: tiles and glyphs are fetched
  // over HTTP and drawn on a canvas, which networkidle does not wait for.
  await page.waitForTimeout(5000);

  // Must match the screens registered in src/navigation/RootTabs.tsx.
  const tabs = ['Map', 'Connections', 'Emergency'];
  for (const tab of tabs) {
    // Tab labels live in the bottom bar; click the last match with force
    // (RN-web wrappers can confuse Playwright's visibility check).
    try {
      await page.getByText(tab, { exact: true }).last().click({ force: true, timeout: 4000 });
      await page.waitForTimeout(600);
    } catch {
      console.log(`  (could not click "${tab}", capturing current view)`);
    }
    const file = `${OUT}/elly-${scheme}-${tab.replace(/\s+/g, '').toLowerCase()}.png`;
    await page.screenshot({ path: file });
    console.log('shot', file);
  }

  await page.close();
}

await browser.close();
console.log('done');
