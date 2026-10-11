const { chromium } = require('playwright');
const { PNG } = require('pngjs');
const fs = require('node:fs');

function soldierCenter(bytes) {
  const img = PNG.sync.read(bytes);
  let sum = 0, count = 0, colors = new Set();
  for (let y = Math.floor(img.height * 0.45); y < img.height * 0.9; y++) {
    for (let x = 0; x < img.width; x++) {
      const i = (y * img.width + x) * 4;
      const [r, g, b] = img.data.subarray(i, i + 3);
      colors.add((r << 16) | (g << 8) | b);
      if (Math.abs(r - 54) < 4 && Math.abs(g - 134) < 4 && Math.abs(b - 188) < 4) {
        sum += x;
        count++;
      }
    }
  }
  if (colors.size < 15 || count < 15) throw Error('Scene or squad missing');
  return sum / count;
}

(async () => {
  fs.mkdirSync('build/browser-check', { recursive: true });
  const browser = await chromium.launch({ headless: true });
  try {
    for (const [name, width, height, touch] of [
      ['desktop', 1280, 720, false], ['phone-landscape', 844, 390, true],
    ]) {
      const context = await browser.newContext({
        viewport: { width, height }, deviceScaleFactor: 1, hasTouch: touch,
      });
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', e => errors.push(String(e)));
      page.on('console', m => console.log(name + ': ' + m.type() + ': ' + m.text()));
      page.on('requestfailed', r => console.log('REQUEST FAILED: ' + r.url() + ' ' + r.failure()?.errorText));
      await page.goto('http://127.0.0.1:8765');
      let visible = false;
      for (let attempt = 0; attempt < 30; attempt++) {
        await page.waitForTimeout(1000);
        const frame = await page.screenshot({ path: 'build/browser-check/' + name + '-loading.png' });
        try { soldierCenter(frame); visible = true; break; } catch (_) {}
      }
      if (!visible) {
        console.log('PAGE HTML: ' + await page.content());
        console.log('PREVIEW_BASE64=' + (await page.screenshot()).toString('base64'));
        throw Error(name + ': no rendered squad; ' + errors.join('; '));
      }
      const initial = await page.screenshot({ path: 'build/browser-check/' + name + '-start.png' });
      console.log('PREVIEW_BASE64=' + initial.toString('base64'));
      const x1 = soldierCenter(initial);
      if (touch) {
        const cdp = await context.newCDPSession(page);
        await cdp.send('Input.dispatchTouchEvent', {
          type: 'touchStart', touchPoints: [{ x: width / 2, y: height * 0.8 }],
        });
        for (let i = 1; i <= 12; i++) {
          await cdp.send('Input.dispatchTouchEvent', {
            type: 'touchMove', touchPoints: [{ x: width / 2 + i * 10, y: height * 0.8 }],
          });
          await page.waitForTimeout(16);
        }
        await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      } else {
        await page.mouse.move(width / 2, height * 0.8);
        await page.mouse.down();
        await page.mouse.move(width / 2 + 150, height * 0.8, { steps: 12 });
        await page.mouse.up();
      }
      await page.waitForTimeout(250);
      const moved = await page.screenshot({ path: 'build/browser-check/' + name + '-moved.png' });
      const x2 = soldierCenter(moved);
      if (x2 - x1 < 60) throw Error(name + ': squad did not follow pointer');
      await page.keyboard.press('Escape');
      await page.waitForTimeout(250);
      const paused1 = await page.screenshot();
      await page.waitForTimeout(500);
      const paused2 = await page.screenshot({ path: 'build/browser-check/' + name + '-paused.png' });
      if (!paused1.equals(paused2)) throw Error(name + ': paused scene keeps moving');
      if (errors.length) throw Error(errors.join('\n'));
      console.log(name + ': visible scene, pointer movement and pause passed');
      await context.close();
    }
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
