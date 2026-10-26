import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { vietnameseClips } from '../web/pose_voice_clips.mjs';
import phrases from '../web/pose-audio/vi/phrases.json' with { type: 'json' };

test('Vietnamese recordings cover feedback, combined corrections and camera failures', () => {
  assert.deepEqual(vietnameseClips('Giữ thân người ổn định khi đẩy tay lên. Đưa hai tay lên xuống cùng nhịp.'),
    ['shoulder-lock', 'shoulder-symmetry']);
  assert.deepEqual(vietnameseClips('Không mở được camera: Device not found'), ['camera-error']);
  assert.equal(vietnameseClips('Unknown English instruction'), null);
});

test('rep totals and summaries preserve Vietnamese number pronunciation', () => {
  for (const [text, expected] of [
    ['0 lần.', ['number-0', 'times']],
    ['15 lần.', ['number-10', 'number-lam', 'times']],
    ['21 lần.', ['number-20', 'number-mot', 'times']],
    ['105 lần.', ['number-1', 'number-hundred', 'number-linh', 'number-5', 'times']],
    ['1011 lần.', ['number-1', 'number-thousand', 'number-0', 'number-hundred', 'number-10', 'number-1', 'times']],
    ['Đã kết thúc phiên tập. Bạn hoàn thành 12 lần, trong đó 9 lần đạt tư thế.',
      ['finished', 'number-10', 'number-2', 'correct-prefix', 'number-9', 'correct-suffix']],
  ]) assert.deepEqual(vietnameseClips(text), expected);
  assert.equal(vietnameseClips('1000000 lần.'), null);
});

test('every bundled phrase has an MP3 recording, including the preview and count fragments', async () => {
  for (const key of Object.keys(phrases)) {
    const bytes = await readFile(new URL(`../web/pose-audio/vi/${key}.mp3`, import.meta.url));
    assert.ok(bytes.length > 500, `${key} must contain audio`);
    // MPEG sync or ID3 header: fail if an HTML error response was saved instead.
    assert.ok(bytes.subarray(0, 3).toString() === 'ID3' || (bytes[0] === 0xff && (bytes[1] & 0xe0) === 0xe0), key);
  }
});
