import { test } from 'node:test';
import assert from 'node:assert/strict';
import { PoseVoice } from '../web/pose_voice.mjs';

function setup(voices = [{ lang: 'vi-VN' }]) {
  let time = 0, cancellations = 0;
  const messages = [], errors = [];
  const synth = { speaking: false, getVoices: () => voices,
    cancel() { cancellations++; }, resume() {}, speak(message) { messages.push(message); } };
  const voice = new PoseVoice({ synth, Utterance: class { constructor(text) { this.text = text; } },
    now: () => time, onError: message => errors.push(message) });
  return { voice, synth, messages, errors, tick: value => { time = value; }, cancelled: () => cancellations };
}

test('enabled by default, selects Vietnamese voice and uses Vietnamese language', () => {
  const vietnamese = { lang: 'vi-VN', name: 'Google Tiếng Việt' };
  const f = setup([{ lang: 'en-US' }, vietnamese]);
  assert.equal(f.voice.enabled, true);
  assert.equal(f.voice.hasVietnameseVoice, true);
  assert.equal(f.voice.speak('Bắt đầu tập luyện.'), true);
  assert.equal(f.messages[0].lang, 'vi-VN');
  assert.equal(f.messages[0].voice, vietnamese);
  assert.equal(f.messages[0].rate, .95);
});

test('missing Vietnamese voice never sends Vietnamese text to the English default', () => {
  const f = setup([{ lang: 'en-US', default: true }]);
  assert.equal(f.voice.speak('Nghe thử tiếng Việt.', true), false);
  assert.equal(f.messages.length, 0);
  assert.equal(f.errors.length, 1);
});

test('bundled Vietnamese audio works without browser voices and stops on mute', async () => {
  const played = [], clips = [], errors = [];
  class Audio {
    constructor(url) { this.url = url; clips.push(this); }
    play() { played.push(this.url); return Promise.resolve(); }
    pause() { this.paused = true; }
  }
  const voice = new PoseVoice({ synth: null, Utterance: null, Audio, onError: e => errors.push(e) });
  assert.equal(voice.supported, true);
  assert.equal(voice.speak('Xin chào! Tôi sẽ hướng dẫn bạn tập luyện bằng tiếng Việt. Hãy giữ lưng thẳng và thực hiện động tác chậm rãi.', true), true);
  assert.match(played[0], /pose-audio\/vi\/preview\.mp3$/);
  assert.equal(voice.speak('Giữ vai, hông và cổ chân thành một đường thẳng.'), false);
  voice.enabled = false;
  assert.equal(clips[0].paused, true);
  clips[0].onended?.();
  assert.equal(played.length, 1);
  voice.enabled = true;
  assert.equal(voice.speak('21 lần.', true), true);
  assert.match(played[1], /number-20\.mp3$/);
  clips[1].onended();
  assert.match(played[2], /number-mot\.mp3$/);
  voice.dispose();
  clips[2].onended?.();
  assert.equal(played.length, 3);
  assert.deepEqual(errors, []);
});

test('rejected audio playback reports an error without using an English voice', async () => {
  const errors = [];
  class Audio { play() { return Promise.reject(new Error('blocked')); } pause() {} }
  const voice = new PoseVoice({ synth: null, Utterance: null, Audio, onError: e => errors.push(e) });
  assert.equal(voice.speak('Đã tạm dừng. Bấm tiếp tục khi bạn sẵn sàng.', true), true);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(errors.length, 1);
  assert.equal(voice.speak('Đã tạm dừng. Bấm tiếp tục khi bạn sẵn sàng.', true), true);
  voice.dispose();
});

test('voices arriving later are selected at playback time', () => {
  const voices = [];
  const f = setup(voices);
  assert.equal(f.voice.hasVietnameseVoice, false);
  voices.push({ lang: 'vi-VN' });
  assert.equal(f.voice.hasVietnameseVoice, true);
  f.voice.speak('Nghe thử tiếng Việt.');
  assert.equal(f.messages[0].voice, voices[0]);
});

test('feedback is throttled and never interrupts an ongoing instruction', () => {
  const f = setup();
  f.voice.speak('Hạ thấp hông.');
  f.tick(1000);
  assert.equal(f.voice.speak('Giữ lưng thẳng.'), false);
  f.tick(6000);
  f.synth.speaking = true;
  assert.equal(f.voice.speak('Giữ lưng thẳng.'), false);
  f.synth.speaking = false;
  assert.equal(f.voice.speak('Hạ thấp hông.'), false);
  f.tick(16000);
  assert.equal(f.voice.speak('Hạ thấp hông.'), true);
});

test('mute stops speech immediately and disposal prevents later playback', () => {
  const f = setup();
  f.voice.speak('Một lần.');
  const before = f.cancelled();
  f.voice.enabled = false;
  assert.equal(f.cancelled(), before + 1);
  assert.equal(f.voice.speak('Hai lần.', true), false);
  f.voice.enabled = true;
  f.voice.dispose();
  assert.equal(f.voice.speak('Ba lần.', true), false);
});

test('unsupported browsers do not throw and real speech errors are reported', () => {
  const unsupported = new PoseVoice({ synth: null, Utterance: null });
  assert.equal(unsupported.supported, false);
  assert.equal(unsupported.speak('Nghe thử.'), false);
  unsupported.dispose();
  const f = setup();
  f.voice.speak('Nghe thử.');
  f.messages[0].onerror({ error: 'interrupted' });
  assert.equal(f.errors.length, 0);
  f.messages[0].onerror({ error: 'language-unavailable' });
  assert.equal(f.errors.length, 1);
});
