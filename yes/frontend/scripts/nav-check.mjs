/**
 * Fake a drive and check live navigation keeps up.
 *
 * A laptop never moves, so the only way to test live nav on web is to lie to
 * the browser about where it is. This walks the GPS through each turn of a real
 * route and checks the app moves to the next step on its own, without anyone
 * pressing Next. Then it jumps somewhere far away to check the off-route
 * warning shows up.
 *
 * Needs the backend on :8000 and the dev server on :8081.
 * Run with: npm run nav:check
 */
import { chromium } from 'playwright';

const URL = process.env.ELLY_URL ?? 'http://localhost:8081';
const API = process.env.ELLY_API ?? 'http://localhost:8000';

// Flinders Street Station to Melbourne Central, a short CBD drive.
const START = { latitude: -37.8183, longitude: 144.9671 };
const DESTINATION = { label: 'Melbourne Central', latitude: -37.81, longitude: 144.9628 };
// somewhere well off the route, to trigger the warning
const WRONG_WAY = { latitude: -37.85, longitude: 145.05 };

/** Ask the backend for the route so we test against real turns, not old ones. */
async function fetchRoute() {
  const reply = await fetch(`${API}/maps/routes`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      origin: { label: 'Start', ...START },
      destination: DESTINATION,
      mode: 'driving',
    }),
  });
  if (!reply.ok) throw new Error(`backend gave ${reply.status}, is it running?`);
  const data = await reply.json();
  return data.options[0];
}

/**
 * Read the turn card: the distance counting down and the turn itself.
 * There are no step numbers any more, it works like waze now.
 */
async function turnCard(page) {
  const distance = await page.locator('text=/^\\d+(\\.\\d+)? (m|km)$|^Arriving$/').first().textContent();
  const instruction = await page
    .getByText(/^(Turn|Keep|Continue|Make|Start|Arrive|Take|Head|Go|Exit)/)
    .first()
    .textContent();
  return { distance: distance.trim(), instruction: instruction.trim() };
}

const route = await fetchRoute();
const turns = route.steps.map((s) => s.location).filter(Boolean);
console.log(`route: ${route.distance_km} km, ${route.steps.length} steps\n`);

const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: { width: 390, height: 844 },
  permissions: ['geolocation'],
  geolocation: START,
});
const page = await context.newPage();

const errors = [];
page.on('pageerror', (e) => errors.push(e.message));

await page.goto(URL, { waitUntil: 'networkidle', timeout: 60000 });
await page.waitForTimeout(3000);

// search for the destination and take the first result
await page.getByPlaceholder('Where do you want to go?').fill(DESTINATION.label);
await page.keyboard.press('Enter');
await page.getByText(/Melbourne Central/i).first().click({ timeout: 20000 });
await page.waitForTimeout(2000);

// exact, because a card elsewhere says "Start Navigation" with a capital N
await page.getByText('Start navigation', { exact: true }).click();
await page.waitForTimeout(1500);

let card = await turnCard(page);
console.log(`start: ${card.distance} - ${card.instruction}`);

// drive to each turn and see if the app follows. skip turn 0, that's where we
// already are.
const seen = [card.instruction];
for (let i = 1; i < turns.length; i++) {
  const [longitude, latitude] = turns[i];
  await context.setGeolocation({ latitude, longitude });
  await page.waitForTimeout(2500);

  card = await turnCard(page);
  seen.push(card.instruction);
  console.log(`  at turn ${i}: ${card.distance} - ${card.instruction}`);
}

// now go the wrong way
await context.setGeolocation(WRONG_WAY);
await page.waitForTimeout(2500);
const warned = await page.getByText(/gone off the route/i).isVisible().catch(() => false);

await page.screenshot({ path: 'nav-check.png' });
await browser.close();

// it passes if the turn card changed by itself and the warning appeared.
// there are no next/back buttons any more so nothing could have clicked it.
const advanced = new Set(seen).size > 1;
console.log('\n--- results ---');
console.log(`turns shown:         ${seen.join(' | ')}`);
console.log(`advanced on its own: ${advanced ? 'YES' : 'NO'}`);
console.log(`off-route warning:   ${warned ? 'YES' : 'NO'}`);
if (errors.length) console.log(`page errors:         ${errors.length}`);
console.log(`\n${advanced && warned && !errors.length ? 'PASS' : 'FAIL'}  (screenshot: nav-check.png)`);

process.exit(advanced && warned && !errors.length ? 0 : 1);
