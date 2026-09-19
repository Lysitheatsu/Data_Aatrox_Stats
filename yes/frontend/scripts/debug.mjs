import { chromium } from 'playwright';

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
const errors = [];
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', (e) => errors.push('PAGEERROR: ' + e.message));

await page.goto('http://localhost:8081', { waitUntil: 'networkidle', timeout: 60000 });
await page.waitForTimeout(2500);

const info = await page.evaluate(() => {
  const el = [...document.querySelectorAll('div')].find(
    (d) => d.textContent?.trim() === 'ELLY Maps'
  );
  const out = { fontsStatus: document.fonts.status, fontFamilies: [] };
  document.fonts.forEach((f) => out.fontFamilies.push(`${f.family} ${f.status}`));
  if (el) {
    const cs = getComputedStyle(el);
    const r = el.getBoundingClientRect();
    out.title = {
      text: el.textContent,
      color: cs.color,
      fontSize: cs.fontSize,
      fontFamily: cs.fontFamily,
      visibility: cs.visibility,
      display: cs.display,
      opacity: cs.opacity,
      rect: { w: Math.round(r.width), h: Math.round(r.height) },
    };
  } else {
    out.title = 'NOT FOUND';
  }
  return out;
});

console.log(JSON.stringify(info, null, 2));
console.log('CONSOLE ERRORS:', errors.slice(0, 8));
await browser.close();
