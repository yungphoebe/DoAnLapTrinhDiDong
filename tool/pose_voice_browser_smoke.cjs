// Run with playwright-core available, while Flutter is serving on localhost:5353.
const assert = require('node:assert/strict');
const { chromium } = require('playwright-core');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  try {
    const page = await browser.newPage();
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.addInitScript(() => {
      // Reproduce a machine with an English default and no Vietnamese system voice.
      speechSynthesis.getVoices = () => [{ lang: 'en-US', default: true }];
      speechSynthesis.speak = () => { throw new Error('English default must never be used'); };
      const play = HTMLMediaElement.prototype.play;
      window.playedAudio = [];
      HTMLMediaElement.prototype.play = function () {
        window.playedAudio.push(this);
        return play.call(this);
      };
    });
    await page.goto('http://localhost:5353/pose_camera.html');
    await page.locator('#voice-test').click();
    await page.waitForFunction(() => window.playedAudio.some(audio =>
      audio.src.endsWith('/preview.mp3') && audio.currentTime > 0.2 && !audio.paused));
    assert.match(await page.locator('#voice-note').textContent(), /âm thanh tiếng Việt có sẵn/);
    const duration = await page.evaluate(() => window.playedAudio[0].duration);
    assert.ok(duration > 5, 'Vietnamese preview must decode and play actual audio');
    await page.locator('#voice').uncheck();
    assert.equal(await page.evaluate(() => window.playedAudio.every(audio => audio.paused)), true);
    await page.evaluate(async () => {
      const { PoseVoice } = await import('/pose_voice.mjs');
      window.countVoice = new PoseVoice({ onError: message => { throw new Error(message); } });
      window.countVoice.speak('21 lần.', true);
    });
    await page.waitForFunction(() => window.playedAudio.length === 4 &&
      window.playedAudio[3].ended && window.countVoice.audio === null);
    assert.deepEqual(await page.evaluate(() => window.playedAudio.slice(1).map(audio =>
      new URL(audio.src).pathname.split('/').pop())), ['number-20.mp3', 'number-mot.mp3', 'times.mp3']);
    await page.evaluate(() => window.countVoice.dispose());
    assert.deepEqual(errors, []);
    console.log(`PASS: Vietnamese preview decoded (${duration.toFixed(1)}s), stopped on mute, and count 21 played fully without a Vietnamese system voice.`);
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
